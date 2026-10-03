-- keystone_35_fixes — correctifs relevés à la vérification post-migration (2026-10-02)
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

-- 1) next_ref insensible à la casse : le code d'origine appelle next_ref('wo'), le nouveau next_ref('WO').
--    Deux compteurs distincts produisaient la même référence → collision uq_wo_ref. On unifie sur le préfixe en majuscules.
INSERT INTO keystone.ref_counters(tenant_id, prefix, year, n)
SELECT tenant_id, upper(prefix), year, max(n) FROM keystone.ref_counters GROUP BY 1, 2, 3
ON CONFLICT (tenant_id, prefix, year) DO UPDATE SET n = GREATEST(keystone.ref_counters.n, EXCLUDED.n);
-- resynchronise sur les références réellement présentes (même logique que 26c)
INSERT INTO keystone.ref_counters(tenant_id, prefix, year, n)
SELECT tenant_id, split_part(ref, '-', 1), split_part(ref, '-', 2)::int, max(split_part(ref, '-', 3)::int)
FROM (
  SELECT tenant_id, ref FROM keystone.work_orders
  UNION ALL SELECT tenant_id, ref FROM keystone.service_requests
  UNION ALL SELECT tenant_id, ref FROM keystone.hsse_events
  UNION ALL SELECT tenant_id, ref FROM keystone.capa_actions
  UNION ALL SELECT tenant_id, ref FROM keystone.work_permits
) x
WHERE ref ~ '^[A-Z]+-[0-9]{4}-[0-9]+$'
GROUP BY 1, 2, 3
ON CONFLICT (tenant_id, prefix, year) DO UPDATE SET n = GREATEST(keystone.ref_counters.n, EXCLUDED.n);

CREATE OR REPLACE FUNCTION keystone.next_ref(p_prefix text, p_year integer)
RETURNS text LANGUAGE plpgsql SET search_path TO 'keystone', 'public', 'extensions' AS $function$
DECLARE v bigint;
BEGIN
  INSERT INTO keystone.ref_counters(tenant_id, prefix, year, n)
    VALUES (keystone.current_tenant(), upper(p_prefix), p_year, 1)
  ON CONFLICT (tenant_id, prefix, year) DO UPDATE SET n = keystone.ref_counters.n + 1
  RETURNING n INTO v;
  RETURN upper(p_prefix) || '-' || p_year || '-' || lpad(v::text, 6, '0');
END $function$;

-- 2) Portail : n'afficher que les OT avec une activité portail (devis/avenant/rapport/pause) ou encore ouverts
CREATE OR REPLACE FUNCTION keystone.portal_board(p_contractor uuid DEFAULT NULL)
RETURNS TABLE(wo_id uuid, wo_ref text, title text, type text, status text, priority int, contractor_id uuid, contractor text,
  asset_tag text, location text, created_at timestamptz, sla_due timestamptz,
  quote_id uuid, quote_ref text, quote_status text, quote_total numeric,
  variations_pending int, variations_total numeric, report_id uuid, report_status text, anomalies int,
  elapsed_h numeric, paused_h numeric, pending_pause_h numeric, paused_now boolean, open_pause_id uuid, open_pause_reason text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT w.id, w.ref, w.title, w.type::text, w.status::text, w.priority, w.contractor_id, c.name, a.tag, l.name, w.created_at, w.sla_due,
    q.id, q.ref, q.status, (SELECT sum(total) FROM wo_quote_items i WHERE i.quote_id = q.id),
    (SELECT count(*) FROM wo_variations v WHERE v.work_order_id = w.id AND v.status IN ('pending','escalated'))::int,
    (SELECT coalesce(sum(extra_cost), 0) FROM wo_variations v WHERE v.work_order_id = w.id AND v.status = 'approved'),
    r.id, r.status, (SELECT count(*) FROM wo_anomalies an WHERE an.report_id = r.id)::int,
    (keystone.wo_sla_clock(w.id)->>'elapsed_h')::numeric, (keystone.wo_sla_clock(w.id)->>'paused_h')::numeric,
    (keystone.wo_sla_clock(w.id)->>'pending_h')::numeric, (keystone.wo_sla_clock(w.id)->>'paused_now')::boolean,
    op.id, op.reason
  FROM work_orders w
  JOIN contractors c ON c.id = w.contractor_id
  LEFT JOIN assets a ON a.id = w.asset_id
  LEFT JOIN locations l ON l.id = w.location_id
  LEFT JOIN LATERAL (SELECT * FROM wo_quotes x WHERE x.work_order_id = w.id ORDER BY x.created_at DESC LIMIT 1) q ON true
  LEFT JOIN LATERAL (SELECT * FROM wo_reports x WHERE x.work_order_id = w.id ORDER BY x.created_at DESC LIMIT 1) r ON true
  LEFT JOIN LATERAL (SELECT * FROM wo_sla_pauses x WHERE x.work_order_id = w.id AND x.ended_at IS NULL LIMIT 1) op ON true
  WHERE w.deleted_at IS NULL AND w.status <> 'cancelled'
    AND (p_contractor IS NULL OR w.contractor_id = p_contractor)
    AND (keystone.current_contractor() IS NULL OR w.contractor_id = keystone.current_contractor())
    AND (w.status NOT IN ('done','verified')
         OR q.id IS NOT NULL OR r.id IS NOT NULL
         OR EXISTS (SELECT 1 FROM wo_variations v WHERE v.work_order_id = w.id)
         OR EXISTS (SELECT 1 FROM wo_sla_pauses p WHERE p.work_order_id = w.id))
    AND NOT (r.status = 'validated' AND w.updated_at < now() - interval '30 days')
  ORDER BY (r.status = 'submitted' OR q.status = 'submitted') DESC NULLS LAST, w.priority, w.created_at DESC;
$$;

-- 3) Démo : surfaces réalistes d'un centre commercial (≈ 21 000 m² + 11 000 m² SHON) pour une EnPI crédible.
--    Les 7 espaces du plan démo restent ; on ajoute la surface des zones non dessinées comme lots agrégés vérifiés.
INSERT INTO keystone.space_units(tenant_id, code, name, type, surface_m2, status, is_verified, polygon)
SELECT 'a0000000-0000-4000-8000-000000000001', v.code, v.name, v.type::keystone.space_unit_type, v.m2, v.st, true, NULL
FROM (VALUES
  ('AGG-GAL', 'Galerie & lots commerciaux (agrégé)', 'tenant_lot', 14500, 'occupied'),
  ('AGG-HYP', 'Hypermarché (agrégé)', 'tenant_lot', 9500, 'occupied'),
  ('AGG-CIRC', 'Circulations & parties communes (agrégé)', 'common_area', 4800, 'occupied'),
  ('AGG-TECH', 'Locaux techniques & réserves (agrégé)', 'technical_room', 2400, 'occupied')
) v(code, name, type, m2, st)
WHERE NOT EXISTS (SELECT 1 FROM keystone.space_units su WHERE su.code = v.code
                  AND su.tenant_id = 'a0000000-0000-4000-8000-000000000001');

COMMIT;

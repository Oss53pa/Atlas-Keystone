-- Atlas Keystone · migrations 36 (espace prestataire) + 37 (Tour de contrôle étendue) — coller en une fois dans le SQL Editor
-- Projet vgtmljfayiysuvrcmunt · chaque migration est dans sa propre transaction

-- keystone_36_contractor_app — Espace prestataire (?prestataire) : identité + stockage des photos d'intervention
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

-- Qui suis-je ? Prestataire connecté (cloisonné) ou exploitant (mode aperçu autorisé)
CREATE OR REPLACE FUNCTION keystone.portal_me()
RETURNS json LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'contractor_id', keystone.current_contractor(),
    'contractor_name', (SELECT name FROM contractors WHERE id = keystone.current_contractor()),
    'is_contractor', keystone.current_contractor() IS NOT NULL,
    'tenant_id', keystone.current_tenant(),
    'full_name', (SELECT full_name FROM users WHERE id = auth.uid())
  );
$$;

-- Prestataires disponibles pour le mode aperçu (exploitant uniquement ; un prestataire ne voit que lui-même)
CREATE OR REPLACE FUNCTION keystone.portal_contractors()
RETURNS TABLE(id uuid, name text, open_wo int)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
  SELECT c.id, c.name,
    (SELECT count(*) FROM work_orders w WHERE w.contractor_id = c.id AND w.deleted_at IS NULL
       AND w.status NOT IN ('done','verified','cancelled'))::int
  FROM contractors c
  WHERE c.deleted_at IS NULL
    AND (keystone.current_contractor() IS NULL OR c.id = keystone.current_contractor())
    AND EXISTS (SELECT 1 FROM work_orders w WHERE w.contractor_id = c.id)
  ORDER BY 3 DESC, c.name;
$$;

GRANT EXECUTE ON FUNCTION keystone.portal_me(), keystone.portal_contractors() TO authenticated;

-- Bucket privé des photos d'intervention : chemin = <tenant_id>/<wo_id>/<avant|apres>-<horodatage>.jpg
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('keystone-wo-photos', 'keystone-wo-photos', false, 8388608, ARRAY['image/jpeg','image/png','image/webp','image/heic'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS keystone_wo_photos_read ON storage.objects;
CREATE POLICY keystone_wo_photos_read ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'keystone-wo-photos' AND (storage.foldername(name))[1] = keystone.current_tenant()::text AND (storage.foldername(name))[2] IN (
    SELECT w.id::text FROM keystone.work_orders w
    WHERE keystone.current_contractor() IS NULL OR w.contractor_id = keystone.current_contractor()));
DROP POLICY IF EXISTS keystone_wo_photos_write ON storage.objects;
CREATE POLICY keystone_wo_photos_write ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'keystone-wo-photos' AND (storage.foldername(name))[1] = keystone.current_tenant()::text AND (storage.foldername(name))[2] IN (
    SELECT w.id::text FROM keystone.work_orders w
    WHERE keystone.current_contractor() IS NULL OR w.contractor_id = keystone.current_contractor()));

COMMIT;

-- keystone_37_cockpit_new_modules — la Tour de contrôle voit les modules issus de WiseFM
-- attention_feed() : + ruptures de stock, NC en retard, gammes préventives en retard, DA urgentes,
--   pauses SLA à arbitrer, rapports prestataires à signer, dépassements énergie critiques,
--   certificats déchets manquants, agréments opérateurs déchets à échéance.
-- cockpit_summary() : + compteurs correspondants (clés ajoutées, clés existantes inchangées).
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

CREATE OR REPLACE FUNCTION keystone.attention_feed()
 RETURNS TABLE(level text, domain text, ref text, title text, scope text, risk integer, detail text)
 LANGUAGE sql STABLE SET search_path TO 'keystone', 'public', 'extensions'
AS $function$
  -- ===== sources d'origine (inchangées) =====
  SELECT (CASE WHEN w.priority = 1 THEN 'critical' ELSE 'high' END), 'Hard FM · GMAO', w.ref, w.title,
         COALESCE(a.tag, l.name, ''), GREATEST(55, 95 - w.priority * 12),
         'SLA +' || CEIL(EXTRACT(epoch FROM (now() - w.sla_due)) / 3600)::int || ' h'
  FROM keystone.work_orders w
  LEFT JOIN keystone.assets a ON a.id = w.asset_id
  LEFT JOIN keystone.locations l ON l.id = w.location_id
  WHERE w.sla_due < now() AND w.status NOT IN ('verified','cancelled') AND w.deleted_at IS NULL
  UNION ALL
  SELECT 'critical', 'Conformité · CRP', '', rc.regime || COALESCE(' — ' || a.tag, ''),
         COALESCE(a.tag, ''), 92, 'échéance +' || (now()::date - rc.next_due_date) || ' j'
  FROM keystone.regulatory_controls rc
  LEFT JOIN keystone.assets a ON a.id = rc.asset_id
  WHERE rc.next_due_date < now()::date AND rc.deleted_at IS NULL
  UNION ALL
  SELECT (CASE WHEN c.priority = 1 THEN 'high' ELSE 'medium' END), 'HSSE · CAPA', c.ref, c.title, '',
         GREATEST(45, 70 - c.priority * 6), 'échéance +' || (now()::date - c.due_date) || ' j'
  FROM keystone.capa_actions c
  WHERE c.due_date < now()::date AND c.status NOT IN ('closed','cancelled') AND c.deleted_at IS NULL
  UNION ALL
  SELECT (CASE WHEN e.risk_score >= 15 THEN 'critical' WHEN e.risk_score >= 9 THEN 'high' ELSE 'medium' END),
         'HSSE · Événement', e.ref, e.title, COALESCE(l.name, ''), COALESCE(e.risk_score, 0),
         'il y a ' || GREATEST(1, CEIL(EXTRACT(epoch FROM (now() - e.occurred_at)) / 3600)::int) || ' h'
  FROM keystone.hsse_events e
  LEFT JOIN keystone.locations l ON l.id = e.location_id
  WHERE e.status NOT IN ('closed','rejected') AND e.deleted_at IS NULL AND COALESCE(e.risk_score,0) >= 6
  UNION ALL
  SELECT 'high', 'HSSE · Permis', p.ref, 'Consignation non vérifiée — ' || p.type::text,
         COALESCE(a.tag, ''), 68, 'activation bloquée'
  FROM keystone.work_permits p
  LEFT JOIN keystone.assets a ON a.id = p.asset_id
  WHERE p.requires_isolation AND p.status IN ('approved','requested') AND p.deleted_at IS NULL
    AND EXISTS (SELECT 1 FROM keystone.permit_isolations pi WHERE pi.permit_id = p.id AND pi.zero_energy_verified = false)
  -- ===== nouveaux modules =====
  UNION ALL   -- Stock : rupture imminente, ou alerte sur article critique
  SELECT (CASE WHEN s.level = 'critical' THEN 'critical' ELSE 'high' END), 'Achats · Stock', s.ref,
         (CASE WHEN s.qty <= 0 THEN 'Rupture — ' ELSE 'Stock bas — ' END) || s.name, COALESCE(s.warehouse, ''),
         (CASE WHEN s.level = 'critical' THEN 78 ELSE 60 END) + (CASE WHEN s.is_critical THEN 8 ELSE 0 END),
         CASE WHEN s.days_cover IS NOT NULL AND s.days_cover < s.lead_time_days
              THEN 'couverture ' || s.days_cover || ' j < délai ' || s.lead_time_days || ' j'
              ELSE s.qty || ' / min ' || s.min_qty END
  FROM keystone.stock_board() s
  WHERE (s.level = 'critical' OR (s.level <> 'ok' AND s.is_critical)) AND s.on_order = 0
  UNION ALL   -- Non-conformités échues
  SELECT (CASE n.severity WHEN 'critical' THEN 'critical' WHEN 'major' THEN 'high' ELSE 'medium' END), 'Qualité · NC', n.ref, n.title,
         COALESCE(l.name, ''), CASE n.severity WHEN 'critical' THEN 88 WHEN 'major' THEN 66 ELSE 46 END,
         'échéance +' || (current_date - n.due_date) || ' j'
  FROM keystone.non_conformities n
  LEFT JOIN keystone.locations l ON l.id = n.location_id
  WHERE n.status NOT IN ('closed','rejected') AND n.due_date < current_date
  UNION ALL   -- Gammes préventives en retard (au-delà de la tolérance)
  SELECT (CASE WHEN b.regulatory THEN 'high' ELSE 'medium' END), 'Hard FM · Préventif', '', b.name, COALESCE(b.asset_tag, ''),
         (CASE WHEN b.regulatory THEN 74 ELSE 52 END) + LEAST(10, -b.days_to_due / 7),
         '+' || (-b.days_to_due) || ' j de retard'
  FROM keystone.pm_board() b
  WHERE b.status = 'overdue'
  UNION ALL   -- DA urgentes en attente de validation
  SELECT (CASE WHEN r.urgency = 'critical' THEN 'high' ELSE 'medium' END), 'Achats · DA', r.ref, r.title, COALESCE(c.name, ''),
         CASE WHEN r.urgency = 'critical' THEN 64 ELSE 50 END,
         'en attente depuis ' || GREATEST(1, (current_date - r.created_at::date)) || ' j'
  FROM keystone.purchase_requests r
  LEFT JOIN keystone.contractors c ON c.id = r.supplier_id
  WHERE r.status IN ('submitted','tech_approved','budget_approved') AND r.urgency <> 'normal'
  UNION ALL   -- Pauses SLA prestataire à arbitrer
  SELECT 'medium', 'Prestataires · SLA', w.ref, 'Pause à arbitrer — ' || replace(p.reason, '_', ' '), c.name, 58,
         'depuis ' || GREATEST(1, CEIL(EXTRACT(epoch FROM (now() - p.started_at)) / 3600)::int) || ' h'
  FROM keystone.wo_sla_pauses p
  JOIN keystone.work_orders w ON w.id = p.work_order_id
  JOIN keystone.contractors c ON c.id = p.contractor_id
  WHERE p.justified IS NULL
  UNION ALL   -- Rapports d'intervention à signer
  SELECT 'medium', 'Prestataires · Rapport', w.ref, 'Rapport à signer — ' || w.title, c.name,
         CASE WHEN EXISTS (SELECT 1 FROM keystone.wo_anomalies an WHERE an.report_id = rp.id AND an.severity IN ('major','critical')) THEN 62 ELSE 48 END,
         'reçu il y a ' || GREATEST(1, CEIL(EXTRACT(epoch FROM (now() - rp.created_at)) / 3600)::int) || ' h'
  FROM keystone.wo_reports rp
  JOIN keystone.work_orders w ON w.id = rp.work_order_id
  JOIN keystone.contractors c ON c.id = rp.contractor_id
  WHERE rp.status = 'submitted'
  UNION ALL   -- Énergie : dépassement du seuil critique sur le dernier mois relevé
  SELECT 'high', 'Énergie', '', 'Seuil critique dépassé — ' || t.carrier, t.site, 63,
         '+' || t.gap_pct || ' % vs cible'
  FROM keystone.energy_targets_status() t
  WHERE t.status = 'critical'
  UNION ALL   -- Déchets dangereux sans certificat de traitement
  SELECT 'high', 'Environnement · Déchets', coalesce(w.bsd_ref, ''), 'Certificat de traitement manquant — ' || w.stream, w.site, 70,
         'enlevé le ' || to_char(w.collected_on, 'DD/MM')
  FROM keystone.waste_board(12) w
  WHERE w.missing_certificate
  UNION ALL   -- Agréments d'opérateurs déchets à échéance (< 60 j)
  SELECT (CASE WHEN c.waste_approval_until < current_date + 15 THEN 'high' ELSE 'medium' END), 'Environnement · Déchets',
         coalesce(c.waste_approval_ref, ''), 'Agrément à renouveler — ' || c.name, '',
         CASE WHEN c.waste_approval_until < current_date + 15 THEN 66 ELSE 44 END,
         'expire dans ' || (c.waste_approval_until - current_date) || ' j'
  FROM keystone.contractors c
  WHERE c.is_waste_operator AND c.waste_approval_until < current_date + 60 AND c.deleted_at IS NULL
  ORDER BY 6 DESC
  LIMIT 20;
$function$;

CREATE OR REPLACE FUNCTION keystone.cockpit_summary()
 RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone', 'public', 'extensions'
AS $function$
  SELECT json_build_object(
    'wo_open',    (SELECT count(*) FROM keystone.work_orders WHERE status NOT IN ('verified','cancelled') AND deleted_at IS NULL),
    'wo_overdue', (SELECT count(*) FROM keystone.work_orders WHERE sla_due < now() AND status NOT IN ('verified','cancelled') AND deleted_at IS NULL),
    'crp_overdue',(SELECT count(*) FROM keystone.regulatory_controls WHERE next_due_date < now()::date AND deleted_at IS NULL),
    'capa_open',  (SELECT count(*) FROM keystone.capa_actions WHERE status NOT IN ('closed','cancelled') AND deleted_at IS NULL),
    'capa_overdue',(SELECT count(*) FROM keystone.capa_actions WHERE due_date < now()::date AND status NOT IN ('closed','cancelled') AND deleted_at IS NULL),
    'events_open',(SELECT count(*) FROM keystone.hsse_events WHERE status NOT IN ('closed','rejected') AND deleted_at IS NULL),
    'permits_active',(SELECT count(*) FROM keystone.work_permits WHERE status = 'active' AND deleted_at IS NULL),
    'assets',     (SELECT count(*) FROM keystone.assets WHERE deleted_at IS NULL),
    -- nouveaux modules
    'stock_critical', (SELECT count(*) FROM keystone.stock_board() WHERE level = 'critical' OR (level <> 'ok' AND is_critical)),
    'nc_overdue',     (SELECT count(*) FROM keystone.non_conformities WHERE status NOT IN ('closed','rejected') AND due_date < current_date),
    'pm_overdue',     (SELECT count(*) FROM keystone.pm_board() WHERE status = 'overdue'),
    'pr_pending',     (SELECT count(*) FROM keystone.purchase_requests WHERE status IN ('submitted','tech_approved','budget_approved')),
    'portal_pending', (SELECT count(*) FROM keystone.wo_reports WHERE status = 'submitted')
                    + (SELECT count(*) FROM keystone.wo_quotes WHERE status = 'submitted')
                    + (SELECT count(*) FROM keystone.wo_sla_pauses WHERE justified IS NULL)
  );
$function$;

COMMIT;

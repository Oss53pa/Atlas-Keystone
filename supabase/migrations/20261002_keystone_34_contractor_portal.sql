-- keystone_34_contractor_portal — Portail prestataire : devis, avenants, rapports d'intervention, chrono SLA
-- Porté depuis WiseFM (supplier-portal/types.ts : Quote, Variation, InterventionReport, Anomaly, SLATimer/PauseReason) et amélioré :
--   · cloisonnement EN BASE : policy restrictive — un prestataire connecté ne voit que ses lignes (current_contractor())
--   · devis : seul le client valide (SEGREGATION_OF_DUTIES si un prestataire tente de valider) ; approbation → coûts estimés de l'OT
--   · avenants : cumul > 20 % du devis approuvé ⇒ statut « escalated » (double validation) au lieu d'« approved »
--   · rapport : photos AVANT et APRÈS obligatoires sur un correctif (PHOTO_EVIDENCE_REQUIRED) ; validation = signature client
--   · anomalies majeures/critiques du rapport ⇒ OT correctif de suivi en BROUILLON, lié
--   · chrono SLA : seules les pauses JUSTIFIÉES et acceptées par le client sont déduites (WiseFM : toute pause déduite)

CREATE TABLE IF NOT EXISTS keystone.wo_quotes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  ref text NOT NULL,
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','approved','rejected')),
  notes text,
  valid_until date,
  decided_by uuid, decided_at timestamptz, rejection_reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.wo_quote_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  quote_id uuid NOT NULL REFERENCES keystone.wo_quotes(id) ON DELETE CASCADE,
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  kind text NOT NULL CHECK (kind IN ('labor','material','travel','other')),
  label text NOT NULL,
  qty numeric NOT NULL CHECK (qty > 0),
  unit_price numeric NOT NULL CHECK (unit_price >= 0),
  total numeric GENERATED ALWAYS AS (qty * unit_price) STORED
);
CREATE TABLE IF NOT EXISTS keystone.wo_variations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  reason text NOT NULL,
  extra_cost numeric NOT NULL DEFAULT 0,
  extra_hours numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','escalated','rejected')),
  decided_by uuid, decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.wo_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  summary text NOT NULL,
  photos_before text[] NOT NULL DEFAULT '{}',
  photos_after text[] NOT NULL DEFAULT '{}',
  technician_name text NOT NULL,
  technician_signed_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','validated','rejected')),
  client_signed_by text, client_signed_at timestamptz, rejection_reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.wo_anomalies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  report_id uuid NOT NULL REFERENCES keystone.wo_reports(id) ON DELETE CASCADE,
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  severity text NOT NULL CHECK (severity IN ('minor','major','critical')),
  description text NOT NULL,
  follow_up_wo_id uuid REFERENCES keystone.work_orders(id)
);
CREATE TABLE IF NOT EXISTS keystone.wo_sla_pauses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id),
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  reason text NOT NULL CHECK (reason IN ('waiting_quote','waiting_permit','waiting_parts','client_delay','force_majeure')),
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  justified boolean               -- NULL = en attente d'arbitrage client
);

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['wo_quotes','wo_quote_items','wo_variations','wo_reports','wo_anomalies','wo_sla_pauses'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    -- Cloisonnement prestataire : restrictive ⇒ s'ajoute (ET) à l'isolation tenant
    EXECUTE format('DROP POLICY IF EXISTS contractor_scope ON keystone.%I', t);
    EXECUTE format('CREATE POLICY contractor_scope ON keystone.%I AS RESTRICTIVE USING (keystone.current_contractor() IS NULL OR contractor_id = keystone.current_contractor()) WITH CHECK (keystone.current_contractor() IS NULL OR contractor_id = keystone.current_contractor())', t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON keystone.%I TO authenticated', t);
    EXECUTE format('ALTER TABLE keystone.%I REPLICA IDENTITY FULL', t);
  END LOOP;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE keystone.wo_quotes, keystone.wo_reports, keystone.wo_variations;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Le prestataire agit uniquement sur SES OT ; le client (current_contractor() NULL) peut agir pour le compte du prestataire affecté
CREATE OR REPLACE FUNCTION keystone.portal_wo(p_wo uuid) RETURNS keystone.work_orders
LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders;
BEGIN
  SELECT * INTO w FROM work_orders WHERE id = p_wo;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF w.contractor_id IS NULL THEN RAISE EXCEPTION 'NO_CONTRACTOR' USING DETAIL = 'OT non confié à un prestataire.'; END IF;
  IF keystone.current_contractor() IS NOT NULL AND keystone.current_contractor() <> w.contractor_id THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;
  RETURN w;
END $$;

CREATE OR REPLACE FUNCTION keystone.quote_submit(p_wo uuid, p_items jsonb, p_notes text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; q uuid; v_ref text; it jsonb;
BEGIN
  w := portal_wo(p_wo);
  IF jsonb_array_length(coalesce(p_items, '[]')) = 0 THEN RAISE EXCEPTION 'EMPTY_QUOTE'; END IF;
  IF EXISTS (SELECT 1 FROM wo_quotes WHERE work_order_id = p_wo AND status = 'submitted') THEN RAISE EXCEPTION 'QUOTE_PENDING'; END IF;
  v_ref := keystone.next_ref('DV');
  INSERT INTO wo_quotes(tenant_id, ref, work_order_id, contractor_id, notes, valid_until)
  VALUES (w.tenant_id, v_ref, p_wo, w.contractor_id, p_notes, current_date + 30) RETURNING id INTO q;
  FOR it IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    INSERT INTO wo_quote_items(tenant_id, quote_id, contractor_id, kind, label, qty, unit_price)
    VALUES (w.tenant_id, q, w.contractor_id, it->>'kind', it->>'label', (it->>'qty')::numeric, (it->>'unit_price')::numeric);
  END LOOP;
  RETURN json_build_object('quote_id', q, 'ref', v_ref, 'total', (SELECT sum(total) FROM wo_quote_items WHERE quote_id = q));
END $$;

CREATE OR REPLACE FUNCTION keystone.quote_decide(p_quote uuid, p_approve boolean, p_reason text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE q wo_quotes;
BEGIN
  IF keystone.current_contractor() IS NOT NULL THEN
    RAISE EXCEPTION 'SEGREGATION_OF_DUTIES' USING DETAIL = 'Un prestataire ne peut pas valider son propre devis.';
  END IF;
  SELECT * INTO q FROM wo_quotes WHERE id = p_quote FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF q.status <> 'submitted' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
  IF p_approve AND q.valid_until < current_date THEN RAISE EXCEPTION 'QUOTE_EXPIRED'; END IF;
  UPDATE wo_quotes SET status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END, decided_by = auth.uid(), decided_at = now(),
    rejection_reason = CASE WHEN p_approve THEN NULL ELSE coalesce(p_reason, 'Rejeté') END
  WHERE id = p_quote;
  IF p_approve THEN
    UPDATE work_orders SET
      cost_labor = (SELECT coalesce(sum(total), 0) FROM wo_quote_items WHERE quote_id = p_quote AND kind IN ('labor','travel')),
      cost_parts = (SELECT coalesce(sum(total), 0) FROM wo_quote_items WHERE quote_id = p_quote AND kind IN ('material','other')),
      updated_at = now()
    WHERE id = q.work_order_id;
  END IF;
  RETURN json_build_object('status', CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END);
END $$;

CREATE OR REPLACE FUNCTION keystone.variation_submit(p_wo uuid, p_reason text, p_cost numeric, p_hours numeric DEFAULT 0)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; v uuid;
BEGIN
  w := portal_wo(p_wo);
  IF NOT EXISTS (SELECT 1 FROM wo_quotes WHERE work_order_id = p_wo AND status = 'approved') THEN
    RAISE EXCEPTION 'NO_APPROVED_QUOTE' USING DETAIL = 'Un avenant suppose un devis approuvé.';
  END IF;
  INSERT INTO wo_variations(tenant_id, work_order_id, contractor_id, reason, extra_cost, extra_hours)
  VALUES (w.tenant_id, p_wo, w.contractor_id, p_reason, p_cost, p_hours) RETURNING id INTO v;
  RETURN json_build_object('variation_id', v);
END $$;

CREATE OR REPLACE FUNCTION keystone.variation_decide(p_var uuid, p_approve boolean)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE v wo_variations; base numeric; cumul numeric; st text;
BEGIN
  IF keystone.current_contractor() IS NOT NULL THEN RAISE EXCEPTION 'SEGREGATION_OF_DUTIES'; END IF;
  SELECT * INTO v FROM wo_variations WHERE id = p_var FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF v.status NOT IN ('pending','escalated') THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
  IF NOT p_approve THEN
    st := 'rejected';
  ELSE
    SELECT coalesce(sum(i.total), 0) INTO base FROM wo_quote_items i JOIN wo_quotes q ON q.id = i.quote_id
      WHERE q.work_order_id = v.work_order_id AND q.status = 'approved';
    SELECT coalesce(sum(extra_cost), 0) + v.extra_cost INTO cumul FROM wo_variations
      WHERE work_order_id = v.work_order_id AND status = 'approved' AND id <> v.id;
    -- 1re validation d'un avenant qui porte le cumul au-delà de 20 % ⇒ escalade (2e validation requise)
    IF v.status = 'pending' AND base > 0 AND cumul > 0.2 * base THEN st := 'escalated';
    ELSIF v.status = 'escalated' AND v.decided_by = auth.uid() THEN
      RAISE EXCEPTION 'SEGREGATION_OF_DUTIES' USING DETAIL = 'La seconde validation doit être faite par une autre personne.';
    ELSE st := 'approved';
    END IF;
  END IF;
  UPDATE wo_variations SET status = st, decided_by = auth.uid(), decided_at = now() WHERE id = p_var;
  IF st = 'approved' THEN
    UPDATE work_orders SET cost_labor = coalesce(cost_labor, 0) + v.extra_cost, updated_at = now() WHERE id = v.work_order_id;
  END IF;
  RETURN json_build_object('status', st);
END $$;

CREATE OR REPLACE FUNCTION keystone.report_submit(p_wo uuid, p_summary text, p_technician text, p_before text[], p_after text[], p_anomalies jsonb DEFAULT '[]')
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; r uuid; an jsonb;
BEGIN
  w := portal_wo(p_wo);
  IF w.type = 'corrective' AND (coalesce(array_length(p_before, 1), 0) = 0 OR coalesce(array_length(p_after, 1), 0) = 0) THEN
    RAISE EXCEPTION 'PHOTO_EVIDENCE_REQUIRED' USING DETAIL = 'Photos avant ET après obligatoires sur un OT correctif.';
  END IF;
  INSERT INTO wo_reports(tenant_id, work_order_id, contractor_id, summary, technician_name, photos_before, photos_after)
  VALUES (w.tenant_id, p_wo, w.contractor_id, p_summary, p_technician, coalesce(p_before, '{}'), coalesce(p_after, '{}')) RETURNING id INTO r;
  FOR an IN SELECT * FROM jsonb_array_elements(coalesce(p_anomalies, '[]')) LOOP
    INSERT INTO wo_anomalies(tenant_id, report_id, contractor_id, severity, description)
    VALUES (w.tenant_id, r, w.contractor_id, an->>'severity', an->>'description');
  END LOOP;
  -- fin d'éventuelle pause en cours
  UPDATE wo_sla_pauses SET ended_at = now() WHERE work_order_id = p_wo AND ended_at IS NULL;
  RETURN json_build_object('report_id', r);
END $$;

CREATE OR REPLACE FUNCTION keystone.report_validate(p_report uuid, p_signer text, p_approve boolean, p_reason text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE rp wo_reports; w work_orders; an record; v_wo uuid; n int := 0;
BEGIN
  IF keystone.current_contractor() IS NOT NULL THEN RAISE EXCEPTION 'SEGREGATION_OF_DUTIES'; END IF;
  SELECT * INTO rp FROM wo_reports WHERE id = p_report FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF rp.status <> 'submitted' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
  IF p_approve AND coalesce(trim(p_signer), '') = '' THEN RAISE EXCEPTION 'SIGNATURE_REQUIRED'; END IF;
  UPDATE wo_reports SET status = CASE WHEN p_approve THEN 'validated' ELSE 'rejected' END,
    client_signed_by = CASE WHEN p_approve THEN p_signer END, client_signed_at = CASE WHEN p_approve THEN now() END,
    rejection_reason = CASE WHEN p_approve THEN NULL ELSE coalesce(p_reason, 'Rapport incomplet') END
  WHERE id = p_report;
  IF p_approve THEN
    SELECT * INTO w FROM work_orders WHERE id = rp.work_order_id;
    FOR an IN SELECT * FROM wo_anomalies WHERE report_id = p_report AND severity IN ('major','critical') AND follow_up_wo_id IS NULL LOOP
      INSERT INTO work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, description, contractor_id, currency)
      VALUES (w.tenant_id, w.legal_entity_id, keystone.next_ref('WO'), w.asset_id, w.location_id, 'corrective',
              CASE an.severity WHEN 'critical' THEN 1 ELSE 2 END, 'draft', 'Suite ' || w.ref || ' · ' || left(an.description, 80),
              'Anomalie relevée par le prestataire : ' || an.description, w.contractor_id, 'XOF')
      RETURNING id INTO v_wo;
      UPDATE wo_anomalies SET follow_up_wo_id = v_wo WHERE id = an.id;
      n := n + 1;
    END LOOP;
  END IF;
  RETURN json_build_object('status', CASE WHEN p_approve THEN 'validated' ELSE 'rejected' END, 'follow_ups', n);
END $$;

CREATE OR REPLACE FUNCTION keystone.sla_pause(p_wo uuid, p_reason text)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; v uuid;
BEGIN
  w := portal_wo(p_wo);
  IF EXISTS (SELECT 1 FROM wo_sla_pauses WHERE work_order_id = p_wo AND ended_at IS NULL) THEN RAISE EXCEPTION 'ALREADY_PAUSED'; END IF;
  INSERT INTO wo_sla_pauses(tenant_id, work_order_id, contractor_id, reason, justified)
  VALUES (w.tenant_id, p_wo, w.contractor_id, p_reason, CASE WHEN p_reason IN ('waiting_permit','client_delay') THEN true END)  -- imputables au client : acceptées d'office
  RETURNING id INTO v;
  RETURN json_build_object('pause_id', v);
END $$;
CREATE OR REPLACE FUNCTION keystone.sla_resume(p_wo uuid) RETURNS void
LANGUAGE sql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
  UPDATE wo_sla_pauses SET ended_at = now() WHERE work_order_id = (keystone.portal_wo(p_wo)).id AND ended_at IS NULL;
$$;
CREATE OR REPLACE FUNCTION keystone.pause_arbitrate(p_pause uuid, p_justified boolean) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
BEGIN
  IF keystone.current_contractor() IS NOT NULL THEN RAISE EXCEPTION 'SEGREGATION_OF_DUTIES'; END IF;
  UPDATE wo_sla_pauses SET justified = p_justified WHERE id = p_pause;
END $$;

-- Chrono SLA effectif (h) = écoulé − pauses justifiées
CREATE OR REPLACE FUNCTION keystone.wo_sla_clock(p_wo uuid)
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'elapsed_h', round(EXTRACT(epoch FROM (coalesce(w.actual_end, now()) - w.created_at)) / 3600, 1),
    'paused_h', round(coalesce((SELECT sum(EXTRACT(epoch FROM (coalesce(p.ended_at, now()) - p.started_at))) FROM wo_sla_pauses p
                                WHERE p.work_order_id = w.id AND p.justified), 0) / 3600, 1),
    'pending_h', round(coalesce((SELECT sum(EXTRACT(epoch FROM (coalesce(p.ended_at, now()) - p.started_at))) FROM wo_sla_pauses p
                                 WHERE p.work_order_id = w.id AND p.justified IS NULL), 0) / 3600, 1),
    'paused_now', EXISTS (SELECT 1 FROM wo_sla_pauses p WHERE p.work_order_id = w.id AND p.ended_at IS NULL),
    'sla_due', w.sla_due)
  FROM work_orders w WHERE w.id = p_wo;
$$;

-- Tableau du portail (filtré par RLS pour un prestataire connecté ; filtrable par prestataire pour le client)
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
  WHERE w.deleted_at IS NULL AND w.status NOT IN ('cancelled')
    AND (p_contractor IS NULL OR w.contractor_id = p_contractor)
    AND (keystone.current_contractor() IS NULL OR w.contractor_id = keystone.current_contractor())
    AND (w.status NOT IN ('done','verified') OR w.updated_at > now() - interval '30 days' OR r.status = 'submitted')
  ORDER BY (r.status = 'submitted' OR q.status = 'submitted') DESC NULLS LAST, w.priority, w.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION keystone.portal_detail(p_wo uuid)
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'quote_items', (SELECT json_agg(json_build_object('kind', i.kind, 'label', i.label, 'qty', i.qty, 'unit_price', i.unit_price, 'total', i.total) ORDER BY i.kind)
                    FROM wo_quote_items i JOIN wo_quotes q ON q.id = i.quote_id
                    WHERE q.work_order_id = p_wo AND q.created_at = (SELECT max(created_at) FROM wo_quotes WHERE work_order_id = p_wo)),
    'variations', (SELECT json_agg(json_build_object('id', v.id, 'reason', v.reason, 'extra_cost', v.extra_cost, 'extra_hours', v.extra_hours, 'status', v.status) ORDER BY v.created_at)
                   FROM wo_variations v WHERE v.work_order_id = p_wo),
    'report', (SELECT json_build_object('id', r.id, 'summary', r.summary, 'technician', r.technician_name, 'before', r.photos_before, 'after', r.photos_after,
                                        'status', r.status, 'client_signed_by', r.client_signed_by,
                                        'anomalies', (SELECT json_agg(json_build_object('severity', an.severity, 'description', an.description,
                                                       'follow_up', (SELECT ref FROM work_orders WHERE id = an.follow_up_wo_id))) FROM wo_anomalies an WHERE an.report_id = r.id))
               FROM wo_reports r WHERE r.work_order_id = p_wo ORDER BY r.created_at DESC LIMIT 1),
    'pauses', (SELECT json_agg(json_build_object('id', p.id, 'reason', p.reason, 'started_at', p.started_at, 'ended_at', p.ended_at, 'justified', p.justified) ORDER BY p.started_at)
               FROM wo_sla_pauses p WHERE p.work_order_id = p_wo)
  );
$$;

GRANT EXECUTE ON FUNCTION keystone.portal_wo(uuid), keystone.quote_submit(uuid, jsonb, text), keystone.quote_decide(uuid, boolean, text),
  keystone.variation_submit(uuid, text, numeric, numeric), keystone.variation_decide(uuid, boolean),
  keystone.report_submit(uuid, text, text, text[], text[], jsonb), keystone.report_validate(uuid, text, boolean, text),
  keystone.sla_pause(uuid, text), keystone.sla_resume(uuid), keystone.pause_arbitrate(uuid, boolean),
  keystone.wo_sla_clock(uuid), keystone.portal_board(uuid), keystone.portal_detail(uuid) TO authenticated;

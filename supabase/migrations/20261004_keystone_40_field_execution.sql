-- keystone_40_field_execution — Exécution terrain des OT (technicien interne) + modèles d'OT
--   · modèles d'OT : procédure pas à pas (contrôle / mesure avec plage / photo / texte, étapes critiques),
--     consignes de sécurité, pièces requises, permis requis — instanciés sur un OT (checklist)
--   · pointage GPS arrivée/départ horodaté, distance au site (alerte « hors site » > 300 m)
--   · démarrage/clôture via wo_transition (les verrous existants PERMIT_REQUIRED, etc. s'appliquent)
--   · verrous terrain : CHECKLIST_INCOMPLETE (étapes obligatoires non renseignées), CRITICAL_STEP_FAILED
--   · sortie de pièces via consume_part (INSUFFICIENT_STOCK), coûts pièces + main d'œuvre (temps pointé × taux horaire)
--   · scan QR/étiquette → fiche équipement terrain (santé, OT ouverts, historique, risque AMDEC)
--   · correctif : la couverture de stock lit les sorties en valeur absolue (consume_part les enregistre en négatif)
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

ALTER TABLE keystone.persons ADD COLUMN IF NOT EXISTS hourly_rate numeric NOT NULL DEFAULT 4000;
ALTER TABLE keystone.work_orders
  ADD COLUMN IF NOT EXISTS template_id uuid,
  ADD COLUMN IF NOT EXISTS checklist jsonb NOT NULL DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS safety_instructions text,
  ADD COLUMN IF NOT EXISTS completion_notes text,
  ADD COLUMN IF NOT EXISTS signed_by text;

-- Pièces prévues par un modèle (distinctes des pièces réellement sorties) : extension additive de la contrainte
ALTER TABLE keystone.work_order_lines DROP CONSTRAINT IF EXISTS work_order_lines_kind_check;
ALTER TABLE keystone.work_order_lines ADD CONSTRAINT work_order_lines_kind_check CHECK (kind IN ('labor','part','task','note','planned_part'));

CREATE TABLE IF NOT EXISTS keystone.wo_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  name text NOT NULL,
  wo_type keystone.wo_type NOT NULL DEFAULT 'corrective',
  category_id uuid REFERENCES keystone.asset_categories(id),
  estimated_minutes int NOT NULL DEFAULT 60,
  requires_permit boolean NOT NULL DEFAULT false,
  safety_instructions text,
  steps jsonb NOT NULL DEFAULT '[]',          -- [{label, type: check|numeric|photo|text, min, max, unit, required, critical}]
  required_parts jsonb NOT NULL DEFAULT '[]', -- [{part_ref, qty}]
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  ALTER TABLE keystone.work_orders ADD CONSTRAINT work_orders_template_fk FOREIGN KEY (template_id) REFERENCES keystone.wo_templates(id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS keystone.wo_time_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  work_order_id uuid NOT NULL REFERENCES keystone.work_orders(id) ON DELETE CASCADE,
  person_id uuid REFERENCES keystone.persons(id),
  kind text NOT NULL CHECK (kind IN ('check_in','check_out','pause','resume')),
  at timestamptz NOT NULL DEFAULT now(),
  lat numeric, lng numeric, accuracy_m numeric,
  distance_to_site_m numeric
);
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['wo_templates','wo_time_entries'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('DROP POLICY IF EXISTS staff_only ON keystone.%I', t);
    EXECUTE format('CREATE POLICY staff_only ON keystone.%I AS RESTRICTIVE USING (keystone.current_lessee() IS NULL AND keystone.current_contractor() IS NULL)', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
GRANT INSERT, UPDATE ON keystone.wo_templates TO authenticated;

-- Distance (m) entre deux points GPS (haversine)
CREATE OR REPLACE FUNCTION keystone.geo_distance_m(lat1 numeric, lng1 numeric, lat2 numeric, lng2 numeric) RETURNS numeric
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN lat1 IS NULL OR lat2 IS NULL THEN NULL ELSE
    round((2 * 6371000 * asin(sqrt(power(sin(radians(lat2 - lat1) / 2), 2)
      + cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2))))::numeric) END;
$$;

-- Technicien courant (personne liée à l'utilisateur) ; un exploitant peut prévisualiser un technicien
CREATE OR REPLACE FUNCTION keystone.tech_person(p_person uuid DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
DECLARE me uuid;
BEGIN
  IF keystone.current_lessee() IS NOT NULL OR keystone.current_contractor() IS NOT NULL THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  SELECT id INTO me FROM persons WHERE user_id = auth.uid() LIMIT 1;
  RETURN coalesce(p_person, me);
END $$;

-- Instancie un modèle sur un OT : checklist, consignes, permis, lignes de pièces prévues
CREATE OR REPLACE FUNCTION keystone.wo_apply_template(p_wo uuid, p_template uuid)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE t wo_templates; w work_orders; rp jsonb; v_part spare_parts; n int := 0;
BEGIN
  SELECT * INTO t FROM wo_templates WHERE id = p_template AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  SELECT * INTO w FROM work_orders WHERE id = p_wo FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF w.status NOT IN ('draft','planned','assigned') THEN RAISE EXCEPTION 'INVALID_TRANSITION' USING DETAIL = 'Modèle applicable avant le démarrage uniquement.'; END IF;
  UPDATE work_orders SET template_id = t.id,
    checklist = (SELECT coalesce(jsonb_agg(s || jsonb_build_object('index', i - 1, 'value', NULL, 'ok', NULL, 'done_at', NULL)), '[]')
                 FROM jsonb_array_elements(t.steps) WITH ORDINALITY AS x(s, i)),
    safety_instructions = t.safety_instructions,
    requires_permit = w.requires_permit OR t.requires_permit, updated_at = now()
  WHERE id = p_wo;
  FOR rp IN SELECT * FROM jsonb_array_elements(t.required_parts) LOOP
    SELECT * INTO v_part FROM spare_parts WHERE ref = rp->>'part_ref' AND deleted_at IS NULL LIMIT 1;
    IF FOUND THEN
      INSERT INTO work_order_lines(tenant_id, work_order_id, kind, label, qty, unit_cost, currency, part_id)
      VALUES (w.tenant_id, w.id, 'planned_part', v_part.ref || ' · ' || v_part.name, (rp->>'qty')::numeric, v_part.unit_cost, 'XOF', v_part.id);
      n := n + 1;
    END IF;
  END LOOP;
  RETURN json_build_object('steps', jsonb_array_length(t.steps), 'planned_parts', n);
END $$;

-- Journée du technicien
CREATE OR REPLACE FUNCTION keystone.tech_my_day(p_person uuid DEFAULT NULL)
RETURNS TABLE(wo_id uuid, ref text, title text, type text, status text, priority int, asset_tag text, asset_name text, location text,
  planned_start timestamptz, sla_due timestamptz, requires_permit boolean, permit_active boolean, steps_total int, steps_done int,
  checked_in_at timestamptz, template text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT w.id, w.ref, w.title, w.type::text, w.status::text, w.priority, a.tag, a.name, l.name, w.planned_start, w.sla_due, w.requires_permit,
    EXISTS (SELECT 1 FROM work_permits p WHERE p.work_order_id = w.id AND p.status = 'active'),
    jsonb_array_length(w.checklist),
    (SELECT count(*) FROM jsonb_array_elements(w.checklist) c WHERE c->>'done_at' IS NOT NULL)::int,
    (SELECT max(te.at) FROM wo_time_entries te WHERE te.work_order_id = w.id AND te.kind = 'check_in'),
    (SELECT name FROM wo_templates t WHERE t.id = w.template_id)
  FROM work_orders w LEFT JOIN assets a ON a.id = w.asset_id LEFT JOIN locations l ON l.id = w.location_id
  WHERE w.deleted_at IS NULL AND w.contractor_id IS NULL
    AND w.assignee_id = keystone.tech_person(p_person)
    AND (w.status IN ('assigned','in_progress','on_hold') OR (w.status = 'done' AND w.actual_end > now() - interval '24 hours'))
  ORDER BY w.status = 'done', w.status = 'in_progress' DESC, w.priority, coalesce(w.sla_due, w.planned_start);
$$;

CREATE OR REPLACE FUNCTION keystone.tech_wo_detail(p_wo uuid)
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'id', w.id, 'ref', w.ref, 'title', w.title, 'description', w.description, 'status', w.status, 'priority', w.priority, 'type', w.type,
    'asset', (SELECT json_build_object('tag', a.tag, 'name', a.name, 'manufacturer', a.manufacturer, 'model', a.model) FROM assets a WHERE a.id = w.asset_id),
    'location', (SELECT name FROM locations WHERE id = w.location_id),
    'safety', w.safety_instructions, 'requires_permit', w.requires_permit,
    'permit_active', EXISTS (SELECT 1 FROM work_permits p WHERE p.work_order_id = w.id AND p.status = 'active'),
    'checklist', w.checklist, 'sla_due', w.sla_due, 'notes', w.completion_notes,
    'parts', (SELECT json_agg(json_build_object('id', ol.id, 'kind', ol.kind, 'label', ol.label, 'qty', ol.qty, 'unit_cost', ol.unit_cost, 'part_id', ol.part_id,
                'in_stock', (SELECT qty FROM spare_parts sp WHERE sp.id = ol.part_id)) ORDER BY ol.created_at)
              FROM work_order_lines ol WHERE ol.work_order_id = w.id AND ol.deleted_at IS NULL AND ol.kind IN ('part','planned_part')),
    'time', (SELECT json_agg(json_build_object('kind', te.kind, 'at', te.at, 'distance', te.distance_to_site_m) ORDER BY te.at) FROM wo_time_entries te WHERE te.work_order_id = w.id)
  ) FROM work_orders w WHERE w.id = p_wo;
$$;

-- Arrivée sur site : pointage GPS + démarrage (via wo_transition ⇒ verrou PERMIT_REQUIRED)
CREATE OR REPLACE FUNCTION keystone.tech_check_in(p_wo uuid, p_lat numeric DEFAULT NULL, p_lng numeric DEFAULT NULL, p_accuracy numeric DEFAULT NULL, p_person uuid DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; v_dist numeric; s sites;
BEGIN
  SELECT * INTO w FROM work_orders WHERE id = p_wo;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF w.status = 'assigned' THEN PERFORM keystone.wo_transition(p_wo, 'in_progress');
  ELSIF w.status = 'on_hold' THEN PERFORM keystone.wo_transition(p_wo, 'in_progress');
  ELSIF w.status <> 'in_progress' THEN RAISE EXCEPTION 'INVALID_TRANSITION' USING DETAIL = 'OT ' || w.status;
  END IF;
  SELECT si.* INTO s FROM sites si JOIN locations l ON l.site_id = si.id WHERE l.id = w.location_id;
  v_dist := keystone.geo_distance_m(p_lat, p_lng, s.latitude, s.longitude);
  INSERT INTO wo_time_entries(tenant_id, work_order_id, person_id, kind, lat, lng, accuracy_m, distance_to_site_m)
  VALUES (w.tenant_id, w.id, keystone.tech_person(p_person), CASE WHEN w.status = 'on_hold' THEN 'resume' ELSE 'check_in' END, p_lat, p_lng, p_accuracy, v_dist);
  RETURN json_build_object('status', 'in_progress', 'distance_m', v_dist, 'off_site', v_dist > 300);
END $$;

CREATE OR REPLACE FUNCTION keystone.tech_hold(p_wo uuid, p_reason text, p_person uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders;
BEGIN
  IF coalesce(trim(p_reason), '') = '' THEN RAISE EXCEPTION 'REASON_REQUIRED'; END IF;
  SELECT * INTO w FROM work_orders WHERE id = p_wo;
  PERFORM keystone.wo_transition(p_wo, 'on_hold', jsonb_build_object('reason', p_reason));
  INSERT INTO wo_time_entries(tenant_id, work_order_id, person_id, kind) VALUES (w.tenant_id, w.id, keystone.tech_person(p_person), 'pause');
  UPDATE work_orders SET completion_notes = trim(both E'\n' FROM coalesce(completion_notes, '') || E'\n[Pause] ' || p_reason) WHERE id = p_wo;
END $$;

-- Renseigne une étape de checklist (mesure contrôlée contre sa plage)
CREATE OR REPLACE FUNCTION keystone.tech_check_step(p_wo uuid, p_index int, p_value jsonb)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; st jsonb; v_ok boolean;
BEGIN
  SELECT * INTO w FROM work_orders WHERE id = p_wo FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF w.status <> 'in_progress' THEN RAISE EXCEPTION 'NOT_STARTED' USING DETAIL = 'Pointez votre arrivée avant de renseigner la checklist.'; END IF;
  st := w.checklist -> p_index;
  IF st IS NULL THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  v_ok := CASE st->>'type'
    WHEN 'check' THEN (p_value #>> '{}')::boolean
    WHEN 'numeric' THEN (st->>'min' IS NULL OR (p_value #>> '{}')::numeric >= (st->>'min')::numeric)
                    AND (st->>'max' IS NULL OR (p_value #>> '{}')::numeric <= (st->>'max')::numeric)
    ELSE coalesce(length(p_value #>> '{}'), 0) > 0 END;
  UPDATE work_orders SET checklist = jsonb_set(checklist, ARRAY[p_index::text],
      st || jsonb_build_object('value', p_value, 'ok', v_ok, 'done_at', now(), 'by', auth.uid())), updated_at = now()
  WHERE id = p_wo;
  RETURN json_build_object('ok', v_ok);
END $$;

-- Sortie de pièce pour l'OT (stock atomique) + coût pièces
CREATE OR REPLACE FUNCTION keystone.tech_use_part(p_wo uuid, p_part uuid, p_qty numeric)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; p spare_parts;
BEGIN
  SELECT * INTO w FROM work_orders WHERE id = p_wo;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF w.status NOT IN ('in_progress','on_hold') THEN RAISE EXCEPTION 'NOT_STARTED'; END IF;
  IF p_qty <= 0 THEN RAISE EXCEPTION 'INVALID_QTY'; END IF;
  SELECT * INTO p FROM spare_parts WHERE id = p_part;
  PERFORM keystone.consume_part(p_part, p_qty, p_wo);
  INSERT INTO work_order_lines(tenant_id, work_order_id, kind, label, qty, unit_cost, currency, part_id)
  VALUES (w.tenant_id, w.id, 'part', p.ref || ' · ' || p.name, p_qty, p.unit_cost, 'XOF', p.id);
  UPDATE work_orders SET cost_parts = (SELECT coalesce(sum(qty * coalesce(unit_cost, 0)), 0) FROM work_order_lines WHERE work_order_id = p_wo AND kind = 'part' AND deleted_at IS NULL)
  WHERE id = p_wo;
  RETURN json_build_object('remaining', p.qty - p_qty);
END $$;

-- Clôture terrain : verrous checklist, pointage départ, main d'œuvre, passage à « done »
CREATE OR REPLACE FUNCTION keystone.tech_complete(p_wo uuid, p_notes text, p_signed_by text, p_lat numeric DEFAULT NULL, p_lng numeric DEFAULT NULL, p_person uuid DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders; v_missing int; v_failed text; v_minutes int; v_person uuid; v_rate numeric; s sites;
BEGIN
  SELECT * INTO w FROM work_orders WHERE id = p_wo FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF w.status <> 'in_progress' THEN RAISE EXCEPTION 'NOT_STARTED'; END IF;
  SELECT count(*) INTO v_missing FROM jsonb_array_elements(w.checklist) c WHERE coalesce((c->>'required')::boolean, true) AND c->>'done_at' IS NULL;
  IF v_missing > 0 THEN RAISE EXCEPTION 'CHECKLIST_INCOMPLETE' USING DETAIL = v_missing || ' étape(s) obligatoire(s) non renseignée(s).'; END IF;
  SELECT c->>'label' INTO v_failed FROM jsonb_array_elements(w.checklist) c WHERE coalesce((c->>'critical')::boolean, false) AND (c->>'ok')::boolean = false LIMIT 1;
  IF v_failed IS NOT NULL THEN
    RAISE EXCEPTION 'CRITICAL_STEP_FAILED' USING DETAIL = 'Étape critique non conforme : « ' || v_failed || ' ». Mettez l''OT en pause et escaladez.';
  END IF;
  IF coalesce(trim(p_signed_by), '') = '' THEN RAISE EXCEPTION 'SIGNATURE_REQUIRED'; END IF;

  v_person := keystone.tech_person(p_person);
  SELECT si.* INTO s FROM sites si JOIN locations l ON l.site_id = si.id WHERE l.id = w.location_id;
  INSERT INTO wo_time_entries(tenant_id, work_order_id, person_id, kind, lat, lng, distance_to_site_m)
  VALUES (w.tenant_id, w.id, v_person, 'check_out', p_lat, p_lng, keystone.geo_distance_m(p_lat, p_lng, s.latitude, s.longitude));
  -- temps pointé = Σ (sortie/pause − arrivée/reprise)
  SELECT coalesce(sum(EXTRACT(epoch FROM (nxt - at)) / 60), 0)::int INTO v_minutes FROM (
    SELECT kind, at, lead(at) OVER (ORDER BY at) AS nxt FROM wo_time_entries WHERE work_order_id = w.id
  ) x WHERE kind IN ('check_in','resume') AND nxt IS NOT NULL;
  SELECT coalesce(hourly_rate, 4000) INTO v_rate FROM persons WHERE id = v_person;
  IF v_minutes > 0 THEN
    INSERT INTO work_order_lines(tenant_id, work_order_id, kind, label, qty, unit_cost, currency, person_id, minutes)
    VALUES (w.tenant_id, w.id, 'labor', 'Main d''œuvre interne', round(v_minutes / 60.0, 2), coalesce(v_rate, 4000), 'XOF', v_person, v_minutes);
  END IF;
  UPDATE work_orders SET completion_notes = trim(both E'\n' FROM coalesce(completion_notes, '') || E'\n' || coalesce(p_notes, '')),
    signed_by = p_signed_by,
    cost_labor = coalesce(cost_labor, 0) + round(v_minutes / 60.0 * coalesce(v_rate, 4000))
  WHERE id = p_wo;
  PERFORM keystone.wo_transition(p_wo, 'done');
  RETURN json_build_object('minutes', v_minutes, 'labor_cost', round(v_minutes / 60.0 * coalesce(v_rate, 4000)));
END $$;

-- Scan d'une étiquette (QR / code-barres / tag) → fiche équipement terrain
CREATE OR REPLACE FUNCTION keystone.asset_scan(p_code text)
RETURNS json LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
DECLARE v uuid;
BEGIN
  SELECT asset_id INTO v FROM asset_identifiers WHERE value = trim(p_code) LIMIT 1;
  IF v IS NULL THEN SELECT id INTO v FROM assets WHERE upper(tag) = upper(trim(p_code)) AND deleted_at IS NULL LIMIT 1; END IF;
  IF v IS NULL THEN RAISE EXCEPTION 'ASSET_NOT_FOUND' USING DETAIL = 'Aucun équipement pour le code « ' || p_code || ' ».'; END IF;
  RETURN (
    SELECT json_build_object(
      'asset', json_build_object('id', b.id, 'tag', b.tag, 'name', b.name, 'category', b.category, 'location', b.location, 'site', b.site,
               'criticality', b.criticality, 'status', b.status, 'manufacturer', b.manufacturer, 'model', b.model, 'health', b.health,
               'mtbf_h', b.mtbf_h, 'max_rpn', b.max_rpn, 'rul_days', b.prediction_rul_days, 'warranty_until', b.warranty_until),
      'open_wo', (SELECT json_agg(json_build_object('ref', w.ref, 'title', w.title, 'status', w.status, 'priority', w.priority) ORDER BY w.priority)
                  FROM work_orders w WHERE w.asset_id = v AND w.deleted_at IS NULL AND w.status NOT IN ('done','verified','cancelled')),
      'history', (SELECT json_agg(h) FROM (SELECT w.ref, w.title, w.type, w.actual_end FROM work_orders w
                  WHERE w.asset_id = v AND w.status IN ('done','verified') ORDER BY w.actual_end DESC NULLS LAST LIMIT 5) h),
      'top_risk', (SELECT json_build_object('component', f.component, 'rpn', f.rpn, 'effect', f.effect) FROM fmea_items f
                   WHERE f.asset_id = v AND f.action_status <> 'done' ORDER BY f.rpn DESC LIMIT 1))
    FROM keystone.assets_board() b WHERE b.id = v);
END $$;

-- Signalement terrain depuis un scan : OT correctif en brouillon (planification humaine)
CREATE OR REPLACE FUNCTION keystone.tech_report_issue(p_asset uuid, p_title text, p_priority int DEFAULT 3)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE a assets; v_ref text; v_id uuid;
BEGIN
  PERFORM keystone.tech_person(NULL);
  IF coalesce(length(trim(p_title)), 0) < 5 THEN RAISE EXCEPTION 'DESCRIPTION_REQUIRED'; END IF;
  SELECT * INTO a FROM assets WHERE id = p_asset;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  v_ref := keystone.next_ref('WO');
  INSERT INTO work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, description, currency, created_by)
  VALUES (a.tenant_id, a.legal_entity_id, v_ref, a.id, a.location_id, 'corrective', LEAST(4, GREATEST(1, p_priority)), 'draft', trim(p_title),
          'Signalé sur le terrain (scan ' || a.tag || ')', 'XOF', auth.uid())
  RETURNING id INTO v_id;
  RETURN json_build_object('id', v_id, 'ref', v_ref);
END $$;

CREATE OR REPLACE FUNCTION keystone.tech_people()
RETURNS TABLE(id uuid, name text, open_wo int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT p.id, trim(p.first_name || ' ' || p.last_name),
    (SELECT count(*) FROM work_orders w WHERE w.assignee_id = p.id AND w.status IN ('assigned','in_progress','on_hold') AND w.deleted_at IS NULL)::int
  FROM persons p WHERE p.type = 'employee' AND p.deleted_at IS NULL ORDER BY 3 DESC, 2;
$$;

CREATE OR REPLACE FUNCTION keystone.wo_templates_board()
RETURNS TABLE(id uuid, name text, wo_type text, category text, estimated_minutes int, requires_permit boolean, steps jsonb, required_parts jsonb,
  safety_instructions text, is_active boolean, uses int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT t.id, t.name, t.wo_type::text, c.name, t.estimated_minutes, t.requires_permit, t.steps, t.required_parts, t.safety_instructions, t.is_active,
    (SELECT count(*) FROM work_orders w WHERE w.template_id = t.id)::int
  FROM wo_templates t LEFT JOIN asset_categories c ON c.id = t.category_id ORDER BY t.is_active DESC, t.name;
$$;

-- Correctif couverture de stock : consume_part enregistre les sorties en négatif ⇒ valeur absolue
CREATE OR REPLACE FUNCTION keystone.stock_board()
RETURNS TABLE(id uuid, ref text, name text, category text, unit text, warehouse text, qty numeric, min_qty numeric, max_qty numeric,
  reorder_point numeric, unit_cost numeric, stock_value numeric, is_critical boolean, lead_time_days int, supplier text,
  daily_use numeric, days_cover numeric, level text, suggested_qty numeric, on_order numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH s AS (
    SELECT sp.*, w.name AS wh, c.name AS sup,
      coalesce(sp.reorder_point, sp.min_qty * 1.5) AS rop,
      coalesce(sp.max_qty, sp.min_qty * 4) AS mx,
      (SELECT coalesce(sum(abs(m.qty)), 0) / 90.0 FROM stock_movements m
         WHERE m.part_id = sp.id AND m.direction = 'out' AND m.at > now() - interval '90 days') AS use_d,
      (SELECT coalesce(sum(pol.qty_ordered - pol.qty_received), 0) FROM purchase_order_lines pol
         JOIN purchase_orders po ON po.id = pol.order_id
         WHERE pol.part_id = sp.id AND po.status IN ('sent','confirmed','partially_received')) AS ordered
    FROM spare_parts sp
    LEFT JOIN warehouses w ON w.id = sp.warehouse_id
    LEFT JOIN contractors c ON c.id = sp.preferred_supplier_id
    WHERE sp.deleted_at IS NULL
  )
  SELECT s.id, s.ref, s.name, s.category, s.unit, s.wh, s.qty, s.min_qty, s.mx, s.rop, s.unit_cost, s.qty * coalesce(s.unit_cost, 0),
    s.is_critical, s.lead_time_days, s.sup, round(s.use_d, 3),
    CASE WHEN s.use_d > 0 THEN round(s.qty / s.use_d, 0) ELSE NULL END,
    CASE WHEN s.qty <= 0.5 * s.min_qty THEN 'critical' WHEN s.qty <= s.min_qty THEN 'low' WHEN s.qty <= s.rop THEN 'warning' ELSE 'ok' END,
    GREATEST(0, s.mx - s.qty - s.ordered), s.ordered
  FROM s
  ORDER BY CASE WHEN s.qty <= 0.5 * s.min_qty THEN 0 WHEN s.qty <= s.min_qty THEN 1 WHEN s.qty <= s.rop THEN 2 ELSE 3 END, s.is_critical DESC, s.name;
$$;

GRANT EXECUTE ON FUNCTION keystone.geo_distance_m(numeric, numeric, numeric, numeric), keystone.tech_person(uuid),
  keystone.wo_apply_template(uuid, uuid), keystone.tech_my_day(uuid), keystone.tech_wo_detail(uuid),
  keystone.tech_check_in(uuid, numeric, numeric, numeric, uuid), keystone.tech_hold(uuid, text, uuid), keystone.tech_check_step(uuid, int, jsonb),
  keystone.tech_use_part(uuid, uuid, numeric), keystone.tech_complete(uuid, text, text, numeric, numeric, uuid),
  keystone.asset_scan(text), keystone.tech_report_issue(uuid, text, int), keystone.tech_people(), keystone.wo_templates_board()
  TO authenticated;

COMMIT;

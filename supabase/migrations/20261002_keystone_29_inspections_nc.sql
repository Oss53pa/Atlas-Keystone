-- keystone_29_inspections_nc — Rondes d'inspection & non-conformités (ISO 9001 §10.2 / ISO 45001 §10.2)
-- Porté depuis WiseFM (inspection-templates, inspections, non-conformities) et amélioré :
--   · points de contrôle typés : boolean | numeric (plage min/max + unité) | choice | text ; required ; critical
--   · score pondéré : un point critique compte ×3 (WiseFM : moyenne simple)
--   · chaque point en échec ouvre automatiquement une NC ; échéance selon gravité (critique 2 j · majeure 7 j · mineure 30 j)
--   · NC critique sur un équipement → OT correctif en BROUILLON (garde-fou : planification humaine)
--   · interlock ACTION_REQUIRED : une NC ne passe pas en validation sans action corrective ni cause racine
--   · planification : prochaine ronde due = dernière + fréquence du modèle

CREATE TABLE IF NOT EXISTS keystone.inspection_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  name text NOT NULL,
  domain text NOT NULL CHECK (domain IN ('technique','securite','proprete','environnement')),
  frequency_days int NOT NULL DEFAULT 7,
  location_id uuid REFERENCES keystone.locations(id),
  asset_id uuid REFERENCES keystone.assets(id),
  requires_signature boolean NOT NULL DEFAULT false,
  checkpoints jsonb NOT NULL,   -- [{key,label,type,min,max,unit,options,required,critical}]
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.inspections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  ref text NOT NULL,
  template_id uuid NOT NULL REFERENCES keystone.inspection_templates(id),
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('in_progress','completed','validated')),
  inspector_id uuid DEFAULT auth.uid(),
  inspector_name text,
  answers jsonb NOT NULL DEFAULT '{}',
  score numeric,
  failed int NOT NULL DEFAULT 0,
  signed boolean NOT NULL DEFAULT false,
  completed_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.non_conformities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  ref text NOT NULL,
  title text NOT NULL,
  type text NOT NULL DEFAULT 'maintenance' CHECK (type IN ('security','quality','environmental','regulatory','maintenance')),
  severity text NOT NULL CHECK (severity IN ('minor','major','critical')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','pending_validation','closed','rejected')),
  source text NOT NULL DEFAULT 'inspection' CHECK (source IN ('inspection','audit','incident','complaint','observation')),
  inspection_id uuid REFERENCES keystone.inspections(id),
  checkpoint_key text,
  location_id uuid REFERENCES keystone.locations(id),
  asset_id uuid REFERENCES keystone.assets(id),
  observed_value text,
  immediate_action text,
  root_cause text,
  corrective_action text,
  due_date date NOT NULL,
  work_order_id uuid REFERENCES keystone.work_orders(id),
  closed_by uuid,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['inspection_templates','inspections','non_conformities'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
    EXECUTE format('ALTER TABLE keystone.%I REPLICA IDENTITY FULL', t);
  END LOOP;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE keystone.non_conformities, keystone.inspections;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
GRANT INSERT ON keystone.inspections, keystone.non_conformities TO authenticated;
GRANT UPDATE ON keystone.non_conformities TO authenticated;

-- Évalue une réponse : NULL = non renseignée, true = conforme, false = non conforme
CREATE OR REPLACE FUNCTION keystone.checkpoint_ok(p_cp jsonb, p_val jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  IF p_val IS NULL OR p_val = 'null'::jsonb OR p_val = '""'::jsonb THEN RETURN NULL; END IF;
  CASE p_cp->>'type'
    WHEN 'boolean' THEN RETURN (p_val #>> '{}')::boolean;
    WHEN 'numeric' THEN
      RETURN (p_cp->>'min' IS NULL OR (p_val #>> '{}')::numeric >= (p_cp->>'min')::numeric)
         AND (p_cp->>'max' IS NULL OR (p_val #>> '{}')::numeric <= (p_cp->>'max')::numeric);
    WHEN 'choice' THEN RETURN NOT ((p_cp->'fail_options') ? (p_val #>> '{}'));
    ELSE RETURN true;
  END CASE;
END $$;

-- Clôture d'une ronde : contrôle des champs requis, score pondéré, NC + OT automatiques
CREATE OR REPLACE FUNCTION keystone.inspection_submit(p_template uuid, p_answers jsonb, p_inspector text DEFAULT NULL, p_signed boolean DEFAULT false)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE
  t inspection_templates; cp jsonb; ok boolean; w int; num numeric := 0; den numeric := 0;
  v_insp uuid; v_ref text; v_failed int := 0; v_sev text; v_nc uuid; v_wo uuid; a assets; v_ncs int := 0; v_wos int := 0;
BEGIN
  SELECT * INTO t FROM inspection_templates WHERE id = p_template AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF t.requires_signature AND NOT p_signed THEN RAISE EXCEPTION 'SIGNATURE_REQUIRED'; END IF;

  FOR cp IN SELECT * FROM jsonb_array_elements(t.checkpoints) LOOP
    ok := checkpoint_ok(cp, p_answers->(cp->>'key'));
    IF ok IS NULL THEN
      IF coalesce((cp->>'required')::boolean, true) THEN
        RAISE EXCEPTION 'MISSING_REQUIRED' USING DETAIL = cp->>'label';
      END IF;
      CONTINUE;
    END IF;
    w := CASE WHEN coalesce((cp->>'critical')::boolean, false) THEN 3 ELSE 1 END;
    den := den + w;
    IF ok THEN num := num + w; ELSE v_failed := v_failed + 1; END IF;
  END LOOP;

  v_ref := keystone.next_ref('INS');
  INSERT INTO inspections(tenant_id, ref, template_id, inspector_name, answers, score, failed, signed)
  VALUES (t.tenant_id, v_ref, t.id, p_inspector, p_answers, CASE WHEN den > 0 THEN round(100 * num / den, 1) END, v_failed, p_signed)
  RETURNING id INTO v_insp;

  IF t.asset_id IS NOT NULL THEN SELECT * INTO a FROM assets WHERE id = t.asset_id; END IF;

  FOR cp IN SELECT * FROM jsonb_array_elements(t.checkpoints) LOOP
    IF checkpoint_ok(cp, p_answers->(cp->>'key')) IS DISTINCT FROM false THEN CONTINUE; END IF;
    v_sev := CASE WHEN coalesce((cp->>'critical')::boolean, false) THEN 'critical'
                  WHEN cp->>'type' = 'numeric' THEN 'major' ELSE 'minor' END;
    INSERT INTO non_conformities(tenant_id, ref, title, type, severity, source, inspection_id, checkpoint_key, location_id, asset_id,
                                 observed_value, due_date)
    VALUES (t.tenant_id, keystone.next_ref('NC'), cp->>'label',
            CASE t.domain WHEN 'securite' THEN 'security' WHEN 'environnement' THEN 'environmental' WHEN 'proprete' THEN 'quality' ELSE 'maintenance' END,
            v_sev, 'inspection', v_insp, cp->>'key', t.location_id, t.asset_id,
            (p_answers->>(cp->>'key')) || coalesce(' ' || (cp->>'unit'), ''),
            current_date + CASE v_sev WHEN 'critical' THEN 2 WHEN 'major' THEN 7 ELSE 30 END)
    RETURNING id INTO v_nc;
    v_ncs := v_ncs + 1;
    IF v_sev = 'critical' AND a.id IS NOT NULL THEN
      INSERT INTO work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, description, currency)
      VALUES (t.tenant_id, a.legal_entity_id, keystone.next_ref('WO'), a.id, coalesce(t.location_id, a.location_id), 'corrective', 1, 'draft',
              'NC critique · ' || (cp->>'label'), 'Ouvert automatiquement par la ronde ' || v_ref, 'XOF')
      RETURNING id INTO v_wo;
      UPDATE non_conformities SET work_order_id = v_wo WHERE id = v_nc;
      v_wos := v_wos + 1;
    END IF;
  END LOOP;

  RETURN json_build_object('inspection_id', v_insp, 'ref', v_ref, 'score', CASE WHEN den > 0 THEN round(100 * num / den, 1) END,
                           'failed', v_failed, 'nc_created', v_ncs, 'wo_created', v_wos);
END $$;

CREATE OR REPLACE FUNCTION keystone.nc_transition(p_nc uuid, p_action text, p_root_cause text DEFAULT NULL, p_corrective text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE n non_conformities; v_next text;
BEGIN
  SELECT * INTO n FROM non_conformities WHERE id = p_nc FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  UPDATE non_conformities SET root_cause = coalesce(p_root_cause, root_cause), corrective_action = coalesce(p_corrective, corrective_action) WHERE id = p_nc;
  SELECT * INTO n FROM non_conformities WHERE id = p_nc;
  IF p_action = 'start' AND n.status = 'open' THEN v_next := 'in_progress';
  ELSIF p_action = 'submit' AND n.status IN ('open','in_progress') THEN
    IF coalesce(n.corrective_action, '') = '' OR coalesce(n.root_cause, '') = '' THEN
      RAISE EXCEPTION 'ACTION_REQUIRED' USING DETAIL = 'Cause racine et action corrective obligatoires avant validation.';
    END IF;
    v_next := 'pending_validation';
  ELSIF p_action = 'close' AND n.status = 'pending_validation' THEN
    UPDATE non_conformities SET closed_by = auth.uid(), closed_at = now() WHERE id = p_nc;
    v_next := 'closed';
  ELSIF p_action = 'reject' AND n.status = 'pending_validation' THEN v_next := 'in_progress';
  ELSE RAISE EXCEPTION 'INVALID_TRANSITION' USING DETAIL = format('%s depuis %s', p_action, n.status);
  END IF;
  UPDATE non_conformities SET status = v_next WHERE id = p_nc;
  RETURN json_build_object('status', v_next);
END $$;

CREATE OR REPLACE FUNCTION keystone.inspection_rounds()
RETURNS TABLE(template_id uuid, name text, domain text, frequency_days int, location text, asset_tag text, checkpoints jsonb,
  requires_signature boolean, last_done timestamptz, last_score numeric, next_due date, days_to_due int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT t.id, t.name, t.domain, t.frequency_days, l.name, a.tag, t.checkpoints, t.requires_signature, i.completed_at, i.score,
    coalesce((i.completed_at)::date + t.frequency_days, current_date),
    coalesce((i.completed_at)::date + t.frequency_days, current_date) - current_date
  FROM inspection_templates t
  LEFT JOIN locations l ON l.id = t.location_id
  LEFT JOIN assets a ON a.id = t.asset_id
  LEFT JOIN LATERAL (SELECT * FROM inspections x WHERE x.template_id = t.id ORDER BY x.completed_at DESC LIMIT 1) i ON true
  WHERE t.is_active
  ORDER BY 12, t.name;
$$;

CREATE OR REPLACE FUNCTION keystone.inspections_history(p_limit int DEFAULT 30)
RETURNS TABLE(id uuid, ref text, template text, domain text, inspector text, score numeric, failed int, completed_at timestamptz)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT i.id, i.ref, t.name, t.domain, i.inspector_name, i.score, i.failed, i.completed_at
  FROM inspections i JOIN inspection_templates t ON t.id = i.template_id
  ORDER BY i.completed_at DESC LIMIT p_limit;
$$;

CREATE OR REPLACE FUNCTION keystone.nc_board()
RETURNS TABLE(id uuid, ref text, title text, type text, severity text, status text, source text, location text, asset_tag text,
  observed_value text, root_cause text, corrective_action text, due_date date, overdue boolean, wo_ref text, inspection_ref text, created_at timestamptz)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT n.id, n.ref, n.title, n.type, n.severity, n.status, n.source, l.name, a.tag, n.observed_value, n.root_cause, n.corrective_action,
    n.due_date, n.status NOT IN ('closed','rejected') AND n.due_date < current_date, w.ref, i.ref, n.created_at
  FROM non_conformities n
  LEFT JOIN locations l ON l.id = n.location_id
  LEFT JOIN assets a ON a.id = n.asset_id
  LEFT JOIN work_orders w ON w.id = n.work_order_id
  LEFT JOIN inspections i ON i.id = n.inspection_id
  ORDER BY n.status IN ('closed','rejected'), CASE n.severity WHEN 'critical' THEN 0 WHEN 'major' THEN 1 ELSE 2 END, n.due_date;
$$;

CREATE OR REPLACE FUNCTION keystone.quality_summary()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'score_30d', (SELECT round(avg(score), 1) FROM inspections WHERE completed_at > now() - interval '30 days'),
    'rounds_30d', (SELECT count(*) FROM inspections WHERE completed_at > now() - interval '30 days'),
    'rounds_overdue', (SELECT count(*) FROM inspection_rounds() WHERE days_to_due < 0),
    'nc_open', (SELECT count(*) FROM non_conformities WHERE status NOT IN ('closed','rejected')),
    'nc_critical', (SELECT count(*) FROM non_conformities WHERE status NOT IN ('closed','rejected') AND severity = 'critical'),
    'nc_overdue', (SELECT count(*) FROM non_conformities WHERE status NOT IN ('closed','rejected') AND due_date < current_date),
    'nc_closed_on_time_pct', (SELECT round(100.0 * count(*) FILTER (WHERE closed_at::date <= due_date) / NULLIF(count(*), 0), 1)
                              FROM non_conformities WHERE status = 'closed')
  );
$$;

GRANT EXECUTE ON FUNCTION keystone.checkpoint_ok(jsonb, jsonb), keystone.inspection_submit(uuid, jsonb, text, boolean),
  keystone.nc_transition(uuid, text, text, text), keystone.inspection_rounds(), keystone.inspections_history(int),
  keystone.nc_board(), keystone.quality_summary() TO authenticated;

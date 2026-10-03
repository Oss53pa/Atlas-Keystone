-- keystone_26_assets_amdec — Actifs & composants : fiche enrichie + AMDEC (IEC 60812) + indice de santé
-- Porté depuis WiseFM (module amdec / failure-modes) et amélioré pour Keystone :
--   · RPN = G × O × D calculé en base (colonne générée), RPN révisé après action
--   · la gravité ≥ 9 (sécurité des personnes) classe « critique » quel que soit le RPN
--   · une ligne AMDEC génère un OT préventif en BROUILLON (garde-fou : planification humaine)
--   · indice de santé d'actif 0..100 déterministe et explicable (drivers renvoyés)

-- Surcharge pratique : next_ref(préfixe) = next_ref(préfixe, année courante)
CREATE OR REPLACE FUNCTION keystone.next_ref(p_prefix text) RETURNS text
LANGUAGE sql SET search_path TO 'keystone','public' AS $$
  SELECT keystone.next_ref(p_prefix, extract(year FROM current_date)::int);
$$;
GRANT EXECUTE ON FUNCTION keystone.next_ref(text) TO authenticated;

ALTER TABLE keystone.assets
  ADD COLUMN IF NOT EXISTS install_date date,
  ADD COLUMN IF NOT EXISTS warranty_until date,
  ADD COLUMN IF NOT EXISTS design_life_years int,
  ADD COLUMN IF NOT EXISTS replacement_value numeric;

CREATE TABLE IF NOT EXISTS keystone.fmea_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  asset_id uuid NOT NULL REFERENCES keystone.assets(id) ON DELETE CASCADE,
  failure_mode_id uuid REFERENCES keystone.failure_modes(id),
  component text NOT NULL,
  function_lost text,
  effect text NOT NULL,
  cause text NOT NULL,
  detection_method text,
  severity int NOT NULL CHECK (severity BETWEEN 1 AND 10),
  occurrence int NOT NULL CHECK (occurrence BETWEEN 1 AND 10),
  detection int NOT NULL CHECK (detection BETWEEN 1 AND 10),
  rpn int GENERATED ALWAYS AS (severity * occurrence * detection) STORED,
  action text,
  action_status text NOT NULL DEFAULT 'none' CHECK (action_status IN ('none','planned','in_progress','done')),
  rev_severity int CHECK (rev_severity BETWEEN 1 AND 10),
  rev_occurrence int CHECK (rev_occurrence BETWEEN 1 AND 10),
  rev_detection int CHECK (rev_detection BETWEEN 1 AND 10),
  rev_rpn int GENERATED ALWAYS AS (rev_severity * rev_occurrence * rev_detection) STORED,
  action_wo_id uuid REFERENCES keystone.work_orders(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE keystone.fmea_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON keystone.fmea_items;
CREATE POLICY tenant_isolation ON keystone.fmea_items
  USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant());
GRANT SELECT, UPDATE ON keystone.fmea_items TO authenticated;

-- Classe de criticité : la gravité ≥ 9 prime toujours sur le RPN
CREATE OR REPLACE FUNCTION keystone.fmea_class(p_rpn int, p_sev int)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_sev >= 9 OR p_rpn >= 200 THEN 'critical'
    WHEN p_rpn >= 120 THEN 'high'
    WHEN p_rpn >= 60 THEN 'medium'
    ELSE 'low' END;
$$;

CREATE OR REPLACE FUNCTION keystone.fmea_board()
RETURNS TABLE(id uuid, asset_id uuid, asset_tag text, asset_name text, component text, failure_code text, failure_label text,
  function_lost text, effect text, cause text, detection_method text, severity int, occurrence int, detection int, rpn int, class text,
  action text, action_status text, rev_rpn int, rev_class text, action_wo_ref text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT f.id, a.id, a.tag, a.name, f.component, fm.code, fm.label, f.function_lost, f.effect, f.cause, f.detection_method,
    f.severity, f.occurrence, f.detection, f.rpn, keystone.fmea_class(f.rpn, f.severity),
    f.action, f.action_status, f.rev_rpn,
    CASE WHEN f.rev_rpn IS NULL THEN NULL ELSE keystone.fmea_class(f.rev_rpn, f.rev_severity) END,
    w.ref
  FROM keystone.fmea_items f
  JOIN keystone.assets a ON a.id = f.asset_id
  LEFT JOIN keystone.failure_modes fm ON fm.id = f.failure_mode_id
  LEFT JOIN keystone.work_orders w ON w.id = f.action_wo_id
  ORDER BY keystone.fmea_class(f.rpn, f.severity) = 'critical' DESC, f.rpn DESC;
$$;

-- Indice de santé d'actif (0..100) = 100 − pénalités (âge, pannes 12 mois, AMDEC ouverte, RUL prédite, OT ouverts)
CREATE OR REPLACE FUNCTION keystone.assets_board()
RETURNS TABLE(id uuid, tag text, name text, category text, location text, site text, criticality text, status text, workcenter text,
  manufacturer text, model text, install_date date, warranty_until date, design_life_years int, age_years numeric,
  replacement_value numeric, wo_open int, wo_corrective_12m int, mtbf_h numeric, mttr_h numeric, downtime_12m_h numeric,
  cost_12m numeric, max_rpn int, fmea_count int, prediction_rul_days numeric, health int, health_drivers jsonb)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH base AS (
    SELECT a.*, c.name AS cat, l.name AS loc, s.name AS site_name,
      CASE WHEN a.install_date IS NULL THEN NULL ELSE round(((current_date - a.install_date) / 365.25)::numeric, 1) END AS age,
      (SELECT count(*) FROM work_orders w WHERE w.asset_id = a.id AND w.deleted_at IS NULL
         AND w.status IN ('draft','planned','assigned','in_progress','on_hold'))::int AS wo_open,
      (SELECT count(*) FROM work_orders w WHERE w.asset_id = a.id AND w.deleted_at IS NULL
         AND w.type = 'corrective' AND w.created_at > now() - interval '12 months')::int AS corr,
      (SELECT avg(EXTRACT(epoch FROM (w.actual_end - w.actual_start)) / 3600) FROM work_orders w
         WHERE w.asset_id = a.id AND w.type = 'corrective' AND w.actual_end IS NOT NULL) AS mttr,
      (SELECT coalesce(sum(w.downtime_hours), 0) FROM work_orders w
         WHERE w.asset_id = a.id AND w.created_at > now() - interval '12 months') AS dt,
      (SELECT coalesce(sum(coalesce(w.cost_labor, 0) + coalesce(w.cost_parts, 0)), 0) FROM work_orders w
         WHERE w.asset_id = a.id AND w.created_at > now() - interval '12 months') AS cost,
      (SELECT max(f.rpn) FROM fmea_items f WHERE f.asset_id = a.id AND f.action_status <> 'done') AS mrpn,
      (SELECT count(*) FROM fmea_items f WHERE f.asset_id = a.id)::int AS nfm,
      (SELECT min(EXTRACT(day FROM p.rul_estimate))::numeric
         FROM predictions p WHERE p.asset_id = a.id AND p.status = 'open') AS rul
    FROM assets a
    LEFT JOIN asset_categories c ON c.id = a.category_id
    LEFT JOIN locations l ON l.id = a.location_id
    LEFT JOIN sites s ON s.id = l.site_id
    WHERE a.deleted_at IS NULL
  ), pen AS (
    SELECT b.*,
      LEAST(30, CASE WHEN b.age IS NULL OR coalesce(b.design_life_years, 0) = 0 THEN 0
                     ELSE round(30 * b.age / b.design_life_years) END)::int AS p_age,
      LEAST(25, b.corr * 6)::int AS p_corr,
      CASE WHEN b.mrpn IS NULL THEN 0 WHEN b.mrpn >= 200 THEN 20 WHEN b.mrpn >= 120 THEN 12 WHEN b.mrpn >= 60 THEN 5 ELSE 0 END AS p_rpn,
      CASE WHEN b.rul IS NULL THEN 0 WHEN b.rul <= 7 THEN 20 WHEN b.rul <= 30 THEN 10 ELSE 3 END AS p_rul,
      LEAST(10, b.wo_open * 3)::int AS p_open
    FROM base b
  )
  SELECT p.id, p.tag, p.name, p.cat, p.loc, p.site_name, p.criticality::text, p.status, p.workcenter, p.manufacturer, p.model,
    p.install_date, p.warranty_until, p.design_life_years, p.age, p.replacement_value, p.wo_open, p.corr,
    CASE WHEN p.corr > 0 THEN round(8760.0 / p.corr, 0) ELSE NULL END, round(p.mttr, 2), p.dt, p.cost, p.mrpn, p.nfm, p.rul,
    GREATEST(0, 100 - p.p_age - p.p_corr - p.p_rpn - p.p_rul - p.p_open)::int,
    jsonb_build_object('age', p.p_age, 'pannes', p.p_corr, 'amdec', p.p_rpn, 'prediction', p.p_rul, 'ot_ouverts', p.p_open)
  FROM pen p
  ORDER BY 26, p.tag;
$$;

-- Action AMDEC → OT préventif en brouillon (garde-fou : planification humaine)
CREATE OR REPLACE FUNCTION keystone.fmea_create_action(p_item uuid)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE f keystone.fmea_items; a keystone.assets; v_wo uuid; v_ref text;
BEGIN
  SELECT * INTO f FROM fmea_items WHERE id = p_item;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF f.action_wo_id IS NOT NULL THEN RAISE EXCEPTION 'ALREADY_LINKED'; END IF;
  SELECT * INTO a FROM assets WHERE id = f.asset_id;
  v_ref := keystone.next_ref('WO');
  INSERT INTO work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, description, failure_mode_id, currency)
  VALUES (f.tenant_id, a.legal_entity_id, v_ref, a.id, a.location_id, 'preventive',
    CASE keystone.fmea_class(f.rpn, f.severity) WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END,
    'draft', 'AMDEC · ' || f.component || ' — ' || coalesce(f.action, 'action de maîtrise'),
    'Effet : ' || f.effect || ' / cause : ' || f.cause || ' (RPN ' || f.rpn || ')', f.failure_mode_id, 'XOF')
  RETURNING id INTO v_wo;
  UPDATE fmea_items SET action_wo_id = v_wo, action_status = 'planned', updated_at = now() WHERE id = p_item;
  RETURN json_build_object('wo_id', v_wo, 'ref', v_ref);
END $$;

GRANT EXECUTE ON FUNCTION keystone.fmea_board(), keystone.assets_board(), keystone.fmea_create_action(uuid),
  keystone.fmea_class(int, int) TO authenticated;

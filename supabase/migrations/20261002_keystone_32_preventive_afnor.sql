-- keystone_32_preventive_afnor — Gammes préventives & niveaux de maintenance (NF X60-000 / EN 13306)
-- Porté depuis WiseFM (maintenance-levels CONDUITE/I..V, maintenance-ranges + tasks, range-applications, executions) et amélioré :
--   · niveau AFNOR porté PAR LA GAMME + garde-fou LEVEL_COMPETENCY :
--       niveau 1 → opérateur/conduite autorisé · 2-3 → technicien interne ou prestataire · 4 → équipe spécialisée (pas d'opérateur)
--       niveau 5 → constructeur / prestataire uniquement
--   · étapes séquencées avec point de contrôle optionnel (plage min/max) et critère d'acceptation
--   · échéancier calculé (dernière réalisation + intervalle), conformité préventive EN 15341 (réalisé ≤ échéance + tolérance)
--   · génération des OT à horizon (anti-doublon : un seul OT ouvert par gamme)
--   · charge prévisionnelle hebdomadaire (h) vs capacité des équipes

ALTER TABLE keystone.maintenance_plans
  ADD COLUMN IF NOT EXISTS afnor_level int CHECK (afnor_level BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS executor_kind text NOT NULL DEFAULT 'internal' CHECK (executor_kind IN ('operator','internal','contractor')),
  ADD COLUMN IF NOT EXISTS contractor_id uuid REFERENCES keystone.contractors(id),
  ADD COLUMN IF NOT EXISTS estimated_hours numeric NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS tolerance_days int NOT NULL DEFAULT 7,
  ADD COLUMN IF NOT EXISTS regulatory boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS keystone.plan_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  plan_id uuid NOT NULL REFERENCES keystone.maintenance_plans(id) ON DELETE CASCADE,
  seq int NOT NULL,
  label text NOT NULL,
  duration_min int NOT NULL DEFAULT 10,
  is_critical boolean NOT NULL DEFAULT false,
  acceptance text,
  checkpoint jsonb,                 -- {type:'numeric',min,max,unit} | {type:'boolean'}
  UNIQUE (plan_id, seq)
);
ALTER TABLE keystone.plan_steps ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON keystone.plan_steps;
CREATE POLICY tenant_isolation ON keystone.plan_steps USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant());
GRANT SELECT ON keystone.plan_steps TO authenticated;

CREATE OR REPLACE FUNCTION keystone.afnor_level_label(p int) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p
    WHEN 1 THEN 'N1 · Réglages simples, sans démontage (opérateur)'
    WHEN 2 THEN 'N2 · Opérations simples, procédure (technicien habilité)'
    WHEN 3 THEN 'N3 · Diagnostic, réparation de composants (technicien qualifié)'
    WHEN 4 THEN 'N4 · Travaux importants (équipe spécialisée)'
    WHEN 5 THEN 'N5 · Rénovation, reconstruction (constructeur)'
  END;
$$;

-- Garde-fou : cohérence niveau AFNOR ↔ exécutant
CREATE OR REPLACE FUNCTION keystone.trg_plan_level_check() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.afnor_level IS NULL THEN RETURN NEW; END IF;
  IF NEW.afnor_level >= 2 AND NEW.executor_kind = 'operator' THEN
    RAISE EXCEPTION 'LEVEL_COMPETENCY' USING DETAIL = 'Un opérateur ne peut exécuter qu''un niveau 1 (NF X60-000).';
  END IF;
  IF NEW.afnor_level = 5 AND NEW.executor_kind <> 'contractor' THEN
    RAISE EXCEPTION 'LEVEL_COMPETENCY' USING DETAIL = 'Le niveau 5 relève du constructeur ou d''un prestataire spécialisé.';
  END IF;
  IF NEW.executor_kind = 'contractor' AND NEW.contractor_id IS NULL THEN
    RAISE EXCEPTION 'CONTRACTOR_REQUIRED';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS plan_level_check ON keystone.maintenance_plans;
CREATE TRIGGER plan_level_check BEFORE INSERT OR UPDATE ON keystone.maintenance_plans
  FOR EACH ROW EXECUTE FUNCTION keystone.trg_plan_level_check();

-- Intervalle en jours d'une gamme calendaire
CREATE OR REPLACE FUNCTION keystone.plan_interval_days(p keystone.maintenance_plans) RETURNS int LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE coalesce(p.interval_unit, 'day')
    WHEN 'day' THEN p.interval_value WHEN 'days' THEN p.interval_value
    WHEN 'week' THEN p.interval_value * 7 WHEN 'weeks' THEN p.interval_value * 7
    WHEN 'month' THEN p.interval_value * 30 WHEN 'months' THEN p.interval_value * 30
    WHEN 'year' THEN p.interval_value * 365 WHEN 'years' THEN p.interval_value * 365
    ELSE p.interval_value END;
$$;

CREATE OR REPLACE FUNCTION keystone.pm_board()
RETURNS TABLE(id uuid, name text, asset_tag text, asset_name text, afnor_level int, level_label text, executor_kind text, contractor text,
  interval_days int, estimated_hours numeric, steps int, critical_steps int, regulatory boolean,
  last_done date, next_due date, days_to_due int, status text, open_wo_ref text, done_12m int, on_time_12m int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH p AS (
    SELECT mp.*, keystone.plan_interval_days(mp) AS ivl,
      (SELECT max(w.actual_end)::date FROM work_orders w WHERE w.source_plan_id = mp.id AND w.status IN ('done','verified')) AS last_done
    FROM maintenance_plans mp
    WHERE mp.is_active AND mp.deleted_at IS NULL AND coalesce(mp.interval_value, 0) > 0
      AND coalesce(mp.trigger_type, 'calendar') NOT IN ('meter','predictive','conditional')
  )
  SELECT p.id, p.name, a.tag, a.name, p.afnor_level, keystone.afnor_level_label(p.afnor_level), p.executor_kind, c.name,
    p.ivl, p.estimated_hours,
    (SELECT count(*) FROM plan_steps s WHERE s.plan_id = p.id)::int,
    (SELECT count(*) FROM plan_steps s WHERE s.plan_id = p.id AND s.is_critical)::int,
    p.regulatory, p.last_done,
    coalesce(p.last_done, p.last_generated_on, current_date) + p.ivl,
    coalesce(p.last_done, p.last_generated_on, current_date) + p.ivl - current_date,
    CASE WHEN o.ref IS NOT NULL THEN 'scheduled'
         WHEN coalesce(p.last_done, p.last_generated_on, current_date) + p.ivl + p.tolerance_days < current_date THEN 'overdue'
         WHEN coalesce(p.last_done, p.last_generated_on, current_date) + p.ivl <= current_date + p.lead_time_days THEN 'due'
         ELSE 'ok' END,
    o.ref,
    (SELECT count(*) FROM work_orders w WHERE w.source_plan_id = p.id AND w.status IN ('done','verified') AND w.actual_end > now() - interval '12 months')::int,
    (SELECT count(*) FROM work_orders w WHERE w.source_plan_id = p.id AND w.status IN ('done','verified') AND w.actual_end > now() - interval '12 months'
       AND (w.planned_end IS NULL OR w.actual_end::date <= w.planned_end::date + p.tolerance_days))::int
  FROM p
  LEFT JOIN assets a ON a.id = p.asset_id
  LEFT JOIN contractors c ON c.id = p.contractor_id
  LEFT JOIN LATERAL (SELECT w.ref FROM work_orders w WHERE w.source_plan_id = p.id
                     AND w.status IN ('draft','planned','assigned','in_progress','on_hold') LIMIT 1) o ON true
  ORDER BY 16, p.name;
$$;

CREATE OR REPLACE FUNCTION keystone.pm_steps(p_plan uuid)
RETURNS TABLE(seq int, label text, duration_min int, is_critical boolean, acceptance text, checkpoint jsonb)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT seq, label, duration_min, is_critical, acceptance, checkpoint FROM plan_steps WHERE plan_id = p_plan ORDER BY seq;
$$;

-- Charge prévisionnelle (h) par semaine sur l'horizon, par type d'exécutant
CREATE OR REPLACE FUNCTION keystone.pm_workload(p_weeks int DEFAULT 8)
RETURNS TABLE(week date, internal_h numeric, contractor_h numeric, operator_h numeric, capacity_h numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH weeks AS (SELECT g::date AS w FROM generate_series(date_trunc('week', current_date::timestamp), date_trunc('week', current_date::timestamp) + make_interval(days => (p_weeks - 1) * 7), interval '7 days') g),
  occ AS (   -- occurrences de chaque gamme dans l'horizon
    SELECT b.executor_kind, b.estimated_hours, (b.next_due + k * b.interval_days) AS d
    FROM pm_board() b, generate_series(0, 60) k
    WHERE b.interval_days > 0 AND b.next_due + k * b.interval_days < date_trunc('week', current_date)::date + p_weeks * 7
  )
  SELECT weeks.w,
    coalesce(sum(o.estimated_hours) FILTER (WHERE o.executor_kind = 'internal'), 0),
    coalesce(sum(o.estimated_hours) FILTER (WHERE o.executor_kind = 'contractor'), 0),
    coalesce(sum(o.estimated_hours) FILTER (WHERE o.executor_kind = 'operator'), 0),
    -- capacité préventive interne : 35 % de 40 h par technicien actif (hypothèse paramétrable)
    round((SELECT count(*) FROM persons) * 40 * 0.35, 0)
  FROM weeks LEFT JOIN occ o ON date_trunc('week', greatest(o.d, current_date))::date = weeks.w
  GROUP BY weeks.w ORDER BY weeks.w;
$$;

-- Génère les OT préventifs des gammes dues dans l'horizon (planifiés, jamais affectés automatiquement)
CREATE OR REPLACE FUNCTION keystone.pm_generate_horizon(p_days int DEFAULT 14)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE b record; mp maintenance_plans; a assets; n int := 0; refs text[] := '{}'; v_ref text;
BEGIN
  FOR b IN SELECT * FROM pm_board() WHERE status IN ('due','overdue') OR (status = 'ok' AND days_to_due <= p_days) LOOP
    SELECT * INTO mp FROM maintenance_plans WHERE id = b.id;
    SELECT * INTO a FROM assets WHERE id = mp.asset_id;
    v_ref := keystone.next_ref('WO');
    INSERT INTO work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, description,
                            contractor_id, planned_start, planned_end, source_plan_id, currency)
    VALUES (mp.tenant_id, a.legal_entity_id, v_ref, a.id, a.location_id, (CASE WHEN mp.regulatory THEN 'regulatory' ELSE 'preventive' END)::keystone.wo_type,
            CASE WHEN b.status = 'overdue' THEN 2 ELSE 3 END, 'planned', mp.name,
            'Gamme ' || coalesce(keystone.afnor_level_label(mp.afnor_level), '') || ' · ' || b.steps || ' étapes',
            mp.contractor_id, b.next_due::timestamptz, b.next_due::timestamptz + make_interval(hours => ceil(mp.estimated_hours)::int), mp.id, 'XOF');
    UPDATE maintenance_plans SET last_generated_on = current_date WHERE id = mp.id;
    n := n + 1; refs := refs || v_ref;
  END LOOP;
  RETURN json_build_object('created', n, 'refs', refs);
END $$;

CREATE OR REPLACE FUNCTION keystone.pm_summary()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'plans', count(*),
    'overdue', count(*) FILTER (WHERE status = 'overdue'),
    'due', count(*) FILTER (WHERE status = 'due'),
    'scheduled', count(*) FILTER (WHERE status = 'scheduled'),
    'compliance_pct', round(100.0 * sum(on_time_12m) / NULLIF(sum(done_12m), 0), 1),
    'hours_per_year', round(sum(estimated_hours * 365.0 / NULLIF(interval_days, 0)))
  ) FROM pm_board();
$$;

GRANT EXECUTE ON FUNCTION keystone.afnor_level_label(int), keystone.plan_interval_days(keystone.maintenance_plans), keystone.pm_board(),
  keystone.pm_steps(uuid), keystone.pm_workload(int), keystone.pm_generate_horizon(int), keystone.pm_summary() TO authenticated;

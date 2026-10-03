-- keystone_31_contractor_sla — SLA contractuels mesurés & évaluation prestataires (EN 15221 / ISO 41001 §8.1)
-- Porté depuis WiseFM (suppliers-contracts, evaluations/sla-evaluation-module) et amélioré :
--   · SLA MESURÉS sur les OT réels du prestataire (WiseFM : saisie déclarative)
--       response_time = actual_start − created_at ; resolution_time = actual_end − created_at (heures, P90 ou moyenne)
--   · pénalités calculées en FCFA par unité de dépassement, PLAFONNÉES (% du montant mensuel du contrat)
--   · score global RÉELLEMENT pondéré (WiseFM : moyenne simple) = 60 % SLA (pondérés) + 40 % grille qualitative pondérée
--     grille WiseFM conservée : qualité, délais, communication, innovation, coût, fiabilité (0..100)
--   · alerte de préavis de renouvellement (renewal_notice_days) et reconduction tacite

ALTER TABLE keystone.maintenance_contracts
  ADD COLUMN IF NOT EXISTS renewal_notice_days int NOT NULL DEFAULT 90,
  ADD COLUMN IF NOT EXISTS auto_renewal boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS penalty_cap_pct numeric NOT NULL DEFAULT 10;

CREATE TABLE IF NOT EXISTS keystone.contract_slas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  contract_id uuid NOT NULL REFERENCES keystone.maintenance_contracts(id) ON DELETE CASCADE,
  metric text NOT NULL CHECK (metric IN ('response_time','resolution_time','first_time_fix','qc_score')),
  label text NOT NULL,
  target numeric NOT NULL,
  unit text NOT NULL,                          -- h | % | /100
  lower_is_better boolean NOT NULL DEFAULT true,
  weight numeric NOT NULL DEFAULT 1 CHECK (weight > 0),
  priority_scope int,                          -- NULL = tous les OT ; sinon OT de priorité ≤ valeur
  penalty_per_unit numeric NOT NULL DEFAULT 0, -- FCFA par unité de dépassement (h ou point)
  UNIQUE (contract_id, metric, priority_scope)
);
CREATE TABLE IF NOT EXISTS keystone.contractor_evaluations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  contractor_id uuid NOT NULL REFERENCES keystone.contractors(id),
  period date NOT NULL,                        -- 1er jour du mois évalué
  scores jsonb NOT NULL,                       -- {quality, timing, communication, innovation, cost, reliability} 0..100
  comment text,
  evaluated_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (contractor_id, period)
);
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['contract_slas','contractor_evaluations'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
GRANT INSERT, UPDATE ON keystone.contractor_evaluations TO authenticated;

-- Pondération de la grille qualitative (somme = 1)
CREATE OR REPLACE FUNCTION keystone.qualitative_score(p jsonb) RETURNS numeric
LANGUAGE sql IMMUTABLE AS $$
  SELECT round(
      0.25 * coalesce((p->>'quality')::numeric, 0)
    + 0.20 * coalesce((p->>'timing')::numeric, 0)
    + 0.20 * coalesce((p->>'reliability')::numeric, 0)
    + 0.15 * coalesce((p->>'cost')::numeric, 0)
    + 0.10 * coalesce((p->>'communication')::numeric, 0)
    + 0.10 * coalesce((p->>'innovation')::numeric, 0), 1);
$$;

-- Mesure des SLA sur une fenêtre (par défaut : 90 derniers jours)
CREATE OR REPLACE FUNCTION keystone.sla_measures(p_days int DEFAULT 90)
RETURNS TABLE(contractor_id uuid, contractor text, contract_id uuid, sla_id uuid, label text, metric text, unit text, target numeric,
  achieved numeric, samples int, compliant boolean, attainment numeric, weight numeric, overrun numeric, penalty numeric,
  lower_is_better boolean)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH m AS (
    SELECT c.id AS contractor_id, c.name, s.*,
      (SELECT CASE s.metric
          WHEN 'response_time' THEN avg(EXTRACT(epoch FROM (w.actual_start - w.created_at)) / 3600)
          WHEN 'resolution_time' THEN avg(EXTRACT(epoch FROM (w.actual_end - w.created_at)) / 3600)
          WHEN 'first_time_fix' THEN 100.0 * count(*) FILTER (WHERE NOT EXISTS (
              SELECT 1 FROM work_orders w2 WHERE w2.asset_id = w.asset_id AND w2.type = 'corrective'
                AND w2.created_at > w.actual_end AND w2.created_at < w.actual_end + interval '7 days')) / NULLIF(count(*), 0)
        END
       FROM work_orders w
       WHERE w.contractor_id = c.id AND w.deleted_at IS NULL AND w.actual_start IS NOT NULL
         AND w.created_at > now() - make_interval(days => p_days)
         AND (s.priority_scope IS NULL OR w.priority <= s.priority_scope)) AS achieved,
      (SELECT count(*) FROM work_orders w WHERE w.contractor_id = c.id AND w.deleted_at IS NULL AND w.actual_start IS NOT NULL
         AND w.created_at > now() - make_interval(days => p_days)
         AND (s.priority_scope IS NULL OR w.priority <= s.priority_scope))::int AS samples
    FROM contract_slas s
    JOIN maintenance_contracts k ON k.id = s.contract_id AND k.is_active AND k.deleted_at IS NULL
    JOIN contractors c ON c.id = k.contractor_id
  )
  SELECT m.contractor_id, m.name, m.contract_id, m.id, m.label, m.metric, m.unit, m.target, round(m.achieved, 2), m.samples,
    CASE WHEN m.achieved IS NULL THEN NULL WHEN m.lower_is_better THEN m.achieved <= m.target ELSE m.achieved >= m.target END,
    -- taux d'atteinte 0..100 (100 = cible tenue)
    CASE WHEN m.achieved IS NULL THEN NULL
         WHEN m.lower_is_better THEN round(LEAST(100, 100 * m.target / NULLIF(m.achieved, 0)), 1)
         ELSE round(LEAST(100, 100 * m.achieved / NULLIF(m.target, 0)), 1) END,
    m.weight,
    CASE WHEN m.achieved IS NULL THEN 0 WHEN m.lower_is_better THEN GREATEST(0, m.achieved - m.target) ELSE GREATEST(0, m.target - m.achieved) END,
    round(CASE WHEN m.achieved IS NULL THEN 0
               WHEN m.lower_is_better THEN GREATEST(0, m.achieved - m.target) ELSE GREATEST(0, m.target - m.achieved) END
          * m.penalty_per_unit * m.samples),
    m.lower_is_better
  FROM m ORDER BY m.name, m.label;
$$;

-- Fiche de performance consolidée par prestataire
CREATE OR REPLACE FUNCTION keystone.contractor_scorecards(p_days int DEFAULT 90)
RETURNS TABLE(contractor_id uuid, contractor text, scope text, contract_end date, days_to_end int, renewal_due boolean, auto_renewal boolean,
  sla_count int, sla_compliant int, sla_score numeric, qualitative numeric, global_score numeric, last_eval date,
  penalty_raw numeric, penalty_cap numeric, penalty numeric, grade text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH s AS (
    SELECT contractor_id, count(*)::int AS n, count(*) FILTER (WHERE compliant)::int AS ok,
      sum(attainment * weight) / NULLIF(sum(weight) FILTER (WHERE attainment IS NOT NULL), 0) AS sla_score,
      sum(penalty) AS pen
    FROM sla_measures(p_days) GROUP BY contractor_id
  ), e AS (
    SELECT DISTINCT ON (contractor_id) contractor_id, period, qualitative_score(scores) AS q
    FROM contractor_evaluations ORDER BY contractor_id, period DESC
  )
  SELECT c.id, c.name, k.scope, k.end_date, k.end_date - current_date,
    k.end_date - current_date <= k.renewal_notice_days, k.auto_renewal,
    coalesce(s.n, 0), coalesce(s.ok, 0), round(s.sla_score, 1), e.q,
    round(CASE WHEN s.sla_score IS NOT NULL AND e.q IS NOT NULL THEN 0.6 * s.sla_score + 0.4 * e.q
               ELSE coalesce(s.sla_score, e.q) END, 1),
    e.period, coalesce(s.pen, 0),
    round(coalesce(k.amount, 0) / 12 * k.penalty_cap_pct / 100),
    LEAST(coalesce(s.pen, 0), round(coalesce(k.amount, 0) / 12 * k.penalty_cap_pct / 100)),
    CASE WHEN coalesce(0.6 * s.sla_score + 0.4 * e.q, s.sla_score, e.q) IS NULL THEN '—'
         WHEN coalesce(0.6 * s.sla_score + 0.4 * e.q, s.sla_score, e.q) >= 90 THEN 'A'
         WHEN coalesce(0.6 * s.sla_score + 0.4 * e.q, s.sla_score, e.q) >= 80 THEN 'B'
         WHEN coalesce(0.6 * s.sla_score + 0.4 * e.q, s.sla_score, e.q) >= 60 THEN 'C' ELSE 'D' END
  FROM contractors c
  JOIN LATERAL (SELECT * FROM maintenance_contracts mc WHERE mc.contractor_id = c.id AND mc.is_active AND mc.deleted_at IS NULL
                ORDER BY mc.end_date DESC LIMIT 1) k ON true
  LEFT JOIN s ON s.contractor_id = c.id
  LEFT JOIN e ON e.contractor_id = c.id
  WHERE c.deleted_at IS NULL
  ORDER BY 12 NULLS LAST, c.name;
$$;

CREATE OR REPLACE FUNCTION keystone.evaluation_submit(p_contractor uuid, p_scores jsonb, p_comment text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE k text; v numeric; p date := date_trunc('month', current_date)::date;
BEGIN
  FOREACH k IN ARRAY ARRAY['quality','timing','communication','innovation','cost','reliability'] LOOP
    v := (p_scores->>k)::numeric;
    IF v IS NULL OR v < 0 OR v > 100 THEN RAISE EXCEPTION 'INVALID_SCORE' USING DETAIL = k; END IF;
  END LOOP;
  INSERT INTO contractor_evaluations(tenant_id, contractor_id, period, scores, comment)
  VALUES (keystone.current_tenant(), p_contractor, p, p_scores, p_comment)
  ON CONFLICT (contractor_id, period) DO UPDATE SET scores = EXCLUDED.scores, comment = EXCLUDED.comment, created_at = now();
  RETURN json_build_object('period', p, 'qualitative', qualitative_score(p_scores));
END $$;

GRANT EXECUTE ON FUNCTION keystone.qualitative_score(jsonb), keystone.sla_measures(int), keystone.contractor_scorecards(int),
  keystone.evaluation_submit(uuid, jsonb, text) TO authenticated;

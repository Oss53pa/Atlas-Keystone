-- keystone_33_waste_register — Registre déchets & filières (ISO 14001 §8.1, traçabilité des déchets dangereux)
-- Porté depuis WiseFM (waste-providers, waste-records, waste-objectives) et amélioré :
--   · flux WiseFM : papier, plastique, DIB, dangereux, organique, verre, métal, DEEE
--   · interlock BSD_REQUIRED : un enlèvement de déchet dangereux (ou DEEE) exige un bordereau de suivi + un opérateur agréé
--   · interlock OPERATOR_NOT_APPROVED : l'opérateur doit avoir un agrément valide à la date d'enlèvement
--   · taux de valorisation = (recyclage + valorisation + réemploi) / total, par mois et par site
--   · empreinte carbone des déchets (facteurs indicatifs par flux/filière) → reportée en scope 3
--   · objectifs avec statut calculé (on_track / at_risk / achieved / failed) au lieu d'un statut saisi

ALTER TABLE keystone.contractors
  ADD COLUMN IF NOT EXISTS is_waste_operator boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS waste_approval_ref text,
  ADD COLUMN IF NOT EXISTS waste_approval_until date;

CREATE TABLE IF NOT EXISTS keystone.waste_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  site_id uuid NOT NULL REFERENCES keystone.sites(id),
  stream text NOT NULL CHECK (stream IN ('paper','plastic','dib','dangerous','organic','glass','metal','electronic')),
  treatment text NOT NULL CHECK (treatment IN ('recycling','valorization','reuse','elimination')),
  quantity_kg numeric NOT NULL CHECK (quantity_kg > 0),
  operator_id uuid REFERENCES keystone.contractors(id),
  collected_on date NOT NULL,
  bsd_ref text,                          -- bordereau de suivi de déchets
  certificate_ref text,                  -- certificat de traitement / destruction
  source text NOT NULL DEFAULT 'weighbridge' CHECK (source IN ('manual','weighbridge','estimation','certificate')),
  cost numeric,
  currency bpchar(3) NOT NULL DEFAULT 'XOF',
  validated boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS keystone.waste_objectives (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  kind text NOT NULL CHECK (kind IN ('valorization_rate','reduction','dangerous_max')),
  label text NOT NULL,
  target numeric NOT NULL,              -- % (taux, réduction vs N-1) ou kg/mois (dangerous_max)
  year int NOT NULL,
  UNIQUE (tenant_id, kind, year)
);
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['waste_records','waste_objectives'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
GRANT INSERT, UPDATE ON keystone.waste_records TO authenticated;

-- Garde-fous réglementaires à l'écriture
CREATE OR REPLACE FUNCTION keystone.trg_waste_check() RETURNS trigger LANGUAGE plpgsql SET search_path TO 'keystone','public' AS $$
DECLARE op contractors;
BEGIN
  IF NEW.stream IN ('dangerous','electronic') THEN
    IF coalesce(NEW.bsd_ref, '') = '' THEN
      RAISE EXCEPTION 'BSD_REQUIRED' USING DETAIL = 'Bordereau de suivi obligatoire pour les déchets dangereux et DEEE.';
    END IF;
    IF NEW.treatment = 'reuse' AND NEW.stream = 'dangerous' THEN RAISE EXCEPTION 'INVALID_TREATMENT'; END IF;
  END IF;
  IF NEW.operator_id IS NOT NULL THEN
    SELECT * INTO op FROM contractors WHERE id = NEW.operator_id;
    IF NOT op.is_waste_operator OR op.waste_approval_until IS NULL OR op.waste_approval_until < NEW.collected_on THEN
      RAISE EXCEPTION 'OPERATOR_NOT_APPROVED' USING DETAIL = coalesce(op.name, '?') || ' : agrément déchets absent ou échu.';
    END IF;
  ELSIF NEW.stream IN ('dangerous','electronic') THEN
    RAISE EXCEPTION 'OPERATOR_NOT_APPROVED' USING DETAIL = 'Un opérateur agréé est obligatoire pour ce flux.';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS waste_check ON keystone.waste_records;
CREATE TRIGGER waste_check BEFORE INSERT OR UPDATE ON keystone.waste_records FOR EACH ROW EXECUTE FUNCTION keystone.trg_waste_check();

-- Facteurs carbone indicatifs (kgCO2e / kg) par flux × filière — à remplacer par des facteurs officiels
CREATE OR REPLACE FUNCTION keystone.waste_factor(p_stream text, p_treatment text) RETURNS numeric LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_treatment IN ('recycling','reuse') THEN 0.03
    WHEN p_treatment = 'valorization' THEN CASE p_stream WHEN 'organic' THEN 0.05 ELSE 0.10 END
    ELSE CASE p_stream WHEN 'paper' THEN 0.924 WHEN 'plastic' THEN 2.89 WHEN 'glass' THEN 0.593 WHEN 'organic' THEN 0.52
                       WHEN 'dangerous' THEN 1.2 WHEN 'electronic' THEN 1.0 WHEN 'metal' THEN 0.05 ELSE 0.6 END
  END;
$$;

CREATE OR REPLACE FUNCTION keystone.waste_board(p_months int DEFAULT 12)
RETURNS TABLE(id uuid, collected_on date, site text, stream text, treatment text, quantity_kg numeric, operator text,
  bsd_ref text, certificate_ref text, source text, cost numeric, validated boolean, kg_co2e numeric, missing_certificate boolean)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT w.id, w.collected_on, s.name, w.stream, w.treatment, w.quantity_kg, c.name, w.bsd_ref, w.certificate_ref, w.source, w.cost, w.validated,
    round(w.quantity_kg * keystone.waste_factor(w.stream, w.treatment), 1),
    w.stream IN ('dangerous','electronic') AND coalesce(w.certificate_ref, '') = '' AND w.collected_on < current_date - 30
  FROM waste_records w JOIN sites s ON s.id = w.site_id LEFT JOIN contractors c ON c.id = w.operator_id
  WHERE w.collected_on >= date_trunc('month', current_date) - make_interval(months => p_months - 1)
  ORDER BY w.collected_on DESC;
$$;

CREATE OR REPLACE FUNCTION keystone.waste_monthly(p_months int DEFAULT 12)
RETURNS TABLE(period date, total_kg numeric, valorized_kg numeric, eliminated_kg numeric, dangerous_kg numeric, valorization_pct numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT date_trunc('month', collected_on)::date, sum(quantity_kg),
    sum(quantity_kg) FILTER (WHERE treatment <> 'elimination'),
    coalesce(sum(quantity_kg) FILTER (WHERE treatment = 'elimination'), 0),
    coalesce(sum(quantity_kg) FILTER (WHERE stream = 'dangerous'), 0),
    round(100.0 * coalesce(sum(quantity_kg) FILTER (WHERE treatment <> 'elimination'), 0) / NULLIF(sum(quantity_kg), 0), 1)
  FROM waste_records
  WHERE collected_on >= date_trunc('month', current_date) - make_interval(months => p_months - 1)
  GROUP BY 1 ORDER BY 1;
$$;

CREATE OR REPLACE FUNCTION keystone.waste_summary()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH y AS (SELECT * FROM waste_records WHERE collected_on >= date_trunc('year', current_date)),
       p AS (SELECT * FROM waste_records WHERE collected_on >= date_trunc('year', current_date) - interval '1 year'
                                          AND collected_on < current_date - interval '1 year')
  SELECT json_build_object(
    'total_t_ytd', (SELECT round(sum(quantity_kg) / 1000, 1) FROM y),
    'total_t_prev_ytd', (SELECT round(sum(quantity_kg) / 1000, 1) FROM p),
    'valorization_pct', (SELECT round(100.0 * sum(quantity_kg) FILTER (WHERE treatment <> 'elimination') / NULLIF(sum(quantity_kg), 0), 1) FROM y),
    'dangerous_t_ytd', (SELECT round(coalesce(sum(quantity_kg) FILTER (WHERE stream = 'dangerous'), 0) / 1000, 2) FROM y),
    't_co2e_ytd', (SELECT round(sum(quantity_kg * keystone.waste_factor(stream, treatment)) / 1000, 1) FROM y),
    'cost_ytd', (SELECT coalesce(sum(cost), 0) FROM y),
    'missing_certificates', (SELECT count(*) FROM waste_records WHERE stream IN ('dangerous','electronic')
                              AND coalesce(certificate_ref, '') = '' AND collected_on < current_date - 30),
    'operators_expiring', (SELECT count(*) FROM contractors WHERE is_waste_operator AND waste_approval_until < current_date + 60)
  );
$$;

CREATE OR REPLACE FUNCTION keystone.waste_objectives_status()
RETURNS TABLE(kind text, label text, target numeric, actual numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH s AS (SELECT waste_summary() AS j),
       months AS (SELECT GREATEST(1, extract(month FROM current_date)::int) AS m)
  SELECT o.kind, o.label, o.target,
    CASE o.kind
      WHEN 'valorization_rate' THEN (s.j->>'valorization_pct')::numeric
      WHEN 'reduction' THEN round(100 * (1 - (s.j->>'total_t_ytd')::numeric / NULLIF((s.j->>'total_t_prev_ytd')::numeric, 0)), 1)
      WHEN 'dangerous_max' THEN round((s.j->>'dangerous_t_ytd')::numeric * 1000 / months.m, 0)
    END AS actual
  FROM waste_objectives o, s, months WHERE o.year = extract(year FROM current_date)::int;
$$;
-- statut calculé dans une vue d'ensemble (sens « plus haut = mieux » sauf dangerous_max)
CREATE OR REPLACE FUNCTION keystone.waste_objectives_board()
RETURNS TABLE(kind text, label text, target numeric, actual numeric, status text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT kind, label, target, actual,
    CASE WHEN actual IS NULL THEN 'no_data'
         WHEN kind = 'dangerous_max' THEN CASE WHEN actual <= target THEN 'on_track' WHEN actual <= target * 1.15 THEN 'at_risk' ELSE 'failed' END
         ELSE CASE WHEN actual >= target THEN 'achieved' WHEN actual >= target * 0.9 THEN 'on_track' WHEN actual >= target * 0.75 THEN 'at_risk' ELSE 'failed' END
    END
  FROM keystone.waste_objectives_status();
$$;

GRANT EXECUTE ON FUNCTION keystone.waste_factor(text, text), keystone.waste_board(int), keystone.waste_monthly(int), keystone.waste_summary(),
  keystone.waste_objectives_status(), keystone.waste_objectives_board() TO authenticated;

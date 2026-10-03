-- keystone_28_energy_carbon — Énergie & carbone (ISO 50001 / GHG Protocol)
-- Porté depuis WiseFM (consumption, carbon-footprint, env-indicators) et amélioré :
--   · facteurs d'émission versionnés PAR PAYS (packs CI/SN/CM…) et sourcés — WiseFM : table figée France/ADEME
--   · scope 1 inclut les fuites de fluides frigorigènes (kg × PRG) ; scope 2 électricité réseau ; scope 3 eau/déchets
--   · intensité énergétique EnPI = kWh / m² (surfaces réelles du Space Management)
--   · objectifs mensuels avec statut WiseFM : ≥ critique → critique ; ≥ alerte → alerte ; ≤ cible → conforme ; sinon attention
--   · relevés validés (validated) seuls comptés dans le bilan officiel ; les autres apparaissent « à valider »

CREATE TABLE IF NOT EXISTS keystone.emission_factors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  country text NOT NULL,                 -- ISO 3166 alpha-2, '*' = valeur générique
  carrier text NOT NULL,                 -- electricity | diesel | lpg | water | refrigerant_r134a | refrigerant_r410a | refrigerant_r404a | waste_dib
  scope int NOT NULL CHECK (scope IN (1, 2, 3)),
  unit text NOT NULL,                    -- kWh | L | m3 | kg | t
  kg_co2e_per_unit numeric NOT NULL,
  source text NOT NULL,
  is_indicative boolean NOT NULL DEFAULT true,
  valid_from date NOT NULL DEFAULT '2024-01-01',
  UNIQUE (country, carrier, valid_from)
);
GRANT SELECT ON keystone.emission_factors TO authenticated;

CREATE TABLE IF NOT EXISTS keystone.energy_readings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  site_id uuid NOT NULL REFERENCES keystone.sites(id),
  carrier text NOT NULL,
  period date NOT NULL,                  -- 1er jour du mois
  quantity numeric NOT NULL CHECK (quantity >= 0),
  unit text NOT NULL,
  cost numeric,
  currency bpchar(3) NOT NULL DEFAULT 'XOF',
  source text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','invoice','sensor','import')),
  validated boolean NOT NULL DEFAULT false,
  validated_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, site_id, carrier, period)
);
CREATE TABLE IF NOT EXISTS keystone.energy_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  site_id uuid NOT NULL REFERENCES keystone.sites(id),
  carrier text NOT NULL,
  monthly_target numeric NOT NULL,
  alert_threshold numeric NOT NULL,
  critical_threshold numeric NOT NULL,
  CHECK (monthly_target <= alert_threshold AND alert_threshold <= critical_threshold),
  UNIQUE (tenant_id, site_id, carrier)
);
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['energy_readings','energy_targets'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
GRANT UPDATE (validated, validated_by) ON keystone.energy_readings TO authenticated;

-- Pays d'un site : colonne country si présente, sinon 'CI' (pack par défaut du tenant démo)
CREATE OR REPLACE FUNCTION keystone.site_country(p_site uuid) RETURNS text
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT coalesce((SELECT to_jsonb(s)->>'country' FROM sites s WHERE s.id = p_site), 'CI');
$$;

-- Facteur applicable : pays du site, sinon générique, à la date de la période
CREATE OR REPLACE FUNCTION keystone.emission_factor(p_country text, p_carrier text, p_at date)
RETURNS keystone.emission_factors LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT * FROM emission_factors
  WHERE carrier = p_carrier AND country IN (p_country, '*') AND valid_from <= p_at
  ORDER BY (country = p_country) DESC, valid_from DESC LIMIT 1;
$$;

CREATE OR REPLACE VIEW keystone.v_energy_emissions WITH (security_invoker = true) AS
  SELECT r.*, f.scope, f.kg_co2e_per_unit, f.source AS factor_source, f.is_indicative,
    r.quantity * coalesce(f.kg_co2e_per_unit, 0) AS kg_co2e,
    CASE WHEN r.carrier = 'electricity' THEN r.quantity
         WHEN r.carrier = 'diesel' THEN r.quantity * 9.96      -- PCI gazole ≈ 9,96 kWh/L
         WHEN r.carrier = 'lpg' THEN r.quantity * 7.08          -- PCI GPL ≈ 7,08 kWh/L
         ELSE 0 END AS kwh_final
  FROM keystone.energy_readings r
  LEFT JOIN LATERAL (SELECT * FROM keystone.emission_factor(keystone.site_country(r.site_id), r.carrier, r.period)) f ON true;
GRANT SELECT ON keystone.v_energy_emissions TO authenticated;

CREATE OR REPLACE FUNCTION keystone.energy_monthly(p_months int DEFAULT 12)
RETURNS TABLE(period date, carrier text, quantity numeric, unit text, kwh numeric, kg_co2e numeric, cost numeric, validated boolean)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT e.period, e.carrier, sum(e.quantity), min(e.unit), sum(e.kwh_final), round(sum(e.kg_co2e)), sum(coalesce(e.cost, 0)), bool_and(e.validated)
  FROM v_energy_emissions e
  WHERE e.period >= date_trunc('month', current_date) - make_interval(months => p_months - 1)
  GROUP BY e.period, e.carrier ORDER BY e.period, e.carrier;
$$;

CREATE OR REPLACE FUNCTION keystone.energy_summary()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH cur AS (SELECT * FROM v_energy_emissions WHERE period >= date_trunc('month', current_date) - interval '11 months'),
       prev AS (SELECT * FROM v_energy_emissions WHERE period >= date_trunc('month', current_date) - interval '23 months'
                                                  AND period < date_trunc('month', current_date) - interval '11 months'),
       surf AS (SELECT coalesce(sum(surface_m2), 0) AS m2 FROM space_units WHERE deleted_at IS NULL)
  SELECT json_build_object(
    'kwh_12m', (SELECT round(sum(kwh_final)) FROM cur),
    'kwh_prev_12m', (SELECT round(sum(kwh_final)) FROM prev),
    'cost_12m', (SELECT coalesce(sum(cost), 0) FROM cur),
    't_co2e_12m', (SELECT round(sum(kg_co2e) / 1000, 1) FROM cur),
    't_co2e_prev_12m', (SELECT round(sum(kg_co2e) / 1000, 1) FROM prev),
    'scope1_t', (SELECT round(coalesce(sum(kg_co2e) FILTER (WHERE scope = 1), 0) / 1000, 1) FROM cur),
    'scope2_t', (SELECT round(coalesce(sum(kg_co2e) FILTER (WHERE scope = 2), 0) / 1000, 1) FROM cur),
    'scope3_t', (SELECT round(coalesce(sum(kg_co2e) FILTER (WHERE scope = 3), 0) / 1000, 1) FROM cur),
    'refrigerant_t', (SELECT round(coalesce(sum(kg_co2e) FILTER (WHERE carrier LIKE 'refrigerant%'), 0) / 1000, 1) FROM cur),
    'surface_m2', (SELECT m2 FROM surf),
    'intensity_kwh_m2', (SELECT CASE WHEN surf.m2 > 0 THEN round((SELECT sum(kwh_final) FROM cur) / surf.m2, 1) END FROM surf),
    'to_validate', (SELECT count(*) FROM energy_readings WHERE NOT validated),
    'indicative_factors', (SELECT bool_or(is_indicative) FROM cur)
  );
$$;

-- Suivi des objectifs (dernier mois clos) avec la règle de statut WiseFM
CREATE OR REPLACE FUNCTION keystone.energy_targets_status()
RETURNS TABLE(site text, carrier text, unit text, period date, actual numeric, target numeric, alert numeric, critical numeric, status text, gap_pct numeric)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT s.name, t.carrier, r.unit, r.period, r.quantity, t.monthly_target, t.alert_threshold, t.critical_threshold,
    CASE WHEN r.quantity IS NULL THEN 'no_data'
         WHEN r.quantity >= t.critical_threshold THEN 'critical'
         WHEN r.quantity >= t.alert_threshold THEN 'alert'
         WHEN r.quantity <= t.monthly_target THEN 'compliant'
         ELSE 'watch' END,
    round(100.0 * (r.quantity - t.monthly_target) / NULLIF(t.monthly_target, 0), 1)
  FROM energy_targets t
  JOIN sites s ON s.id = t.site_id
  LEFT JOIN LATERAL (SELECT * FROM energy_readings er WHERE er.site_id = t.site_id AND er.carrier = t.carrier
                     ORDER BY er.period DESC LIMIT 1) r ON true
  ORDER BY s.name, t.carrier;
$$;

CREATE OR REPLACE FUNCTION keystone.energy_validate(p_id uuid) RETURNS void
LANGUAGE sql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
  UPDATE energy_readings SET validated = true, validated_by = auth.uid() WHERE id = p_id;
$$;

GRANT EXECUTE ON FUNCTION keystone.site_country(uuid), keystone.emission_factor(text, text, date), keystone.energy_monthly(int),
  keystone.energy_summary(), keystone.energy_targets_status(), keystone.energy_validate(uuid) TO authenticated;

-- ---------- Référentiel de facteurs (INDICATIFS — à remplacer par les facteurs officiels de chaque pays) ----------
INSERT INTO keystone.emission_factors(country, carrier, scope, unit, kg_co2e_per_unit, source, is_indicative) VALUES
  ('*',  'diesel',            1, 'L',  2.51,  'ADEME Base Empreinte (gazole, combustion)', true),
  ('*',  'lpg',               1, 'L',  1.51,  'ADEME Base Empreinte (propane)', true),
  ('*',  'refrigerant_r134a', 1, 'kg', 1430,  'GIEC AR4 — PRG 100 ans', false),
  ('*',  'refrigerant_r410a', 1, 'kg', 2088,  'GIEC AR4 — PRG 100 ans', false),
  ('*',  'refrigerant_r404a', 1, 'kg', 3922,  'GIEC AR4 — PRG 100 ans', false),
  ('*',  'electricity',       2, 'kWh', 0.475, 'Moyenne mondiale (repli)', true),
  ('*',  'water',             3, 'm3', 0.132, 'ADEME (eau potable)', true),
  ('CI', 'electricity',       2, 'kWh', 0.43,  'Indicatif — mix réseau Côte d''Ivoire, à valider', true),
  ('SN', 'electricity',       2, 'kWh', 0.60,  'Indicatif — mix réseau Sénégal, à valider', true),
  ('CM', 'electricity',       2, 'kWh', 0.20,  'Indicatif — mix réseau Cameroun (hydro), à valider', true)
ON CONFLICT (country, carrier, valid_from) DO NOTHING;

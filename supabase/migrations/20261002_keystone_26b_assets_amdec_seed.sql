-- Seed démo (tenant New Heaven SA) — parc d'actifs Cosmos + AMDEC. Idempotent (ON CONFLICT / NOT EXISTS).
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  le uuid; loc_cvc uuid; loc_gal uuid;
  c_cvc uuid; c_asc uuid; c_elec uuid; c_ssi uuid; c_plomb uuid;
  gf02 uuid; asc3 uuid;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  SELECT legal_entity_id, location_id, category_id, id INTO le, loc_cvc, c_cvc, gf02 FROM keystone.assets WHERE tag = 'GF-02' AND tenant_id = t;
  SELECT location_id, category_id, id INTO loc_gal, c_asc, asc3 FROM keystone.assets WHERE tag = 'ASC-A3' AND tenant_id = t;

  INSERT INTO keystone.asset_categories(tenant_id, name) SELECT t, n FROM unnest(ARRAY['Électricité HT/BT','Sécurité incendie','Plomberie & pompage']) n
    WHERE NOT EXISTS (SELECT 1 FROM keystone.asset_categories WHERE tenant_id = t AND name = n);
  SELECT id INTO c_elec FROM keystone.asset_categories WHERE tenant_id = t AND name = 'Électricité HT/BT';
  SELECT id INTO c_ssi FROM keystone.asset_categories WHERE tenant_id = t AND name = 'Sécurité incendie';
  SELECT id INTO c_plomb FROM keystone.asset_categories WHERE tenant_id = t AND name = 'Plomberie & pompage';

  UPDATE keystone.assets SET manufacturer = 'Carrier', model = '30XA-1002', install_date = '2016-03-01', warranty_until = '2018-03-01',
    design_life_years = 15, replacement_value = 185000000 WHERE id = gf02;
  UPDATE keystone.assets SET manufacturer = 'Schindler', model = '5500 MRL', install_date = '2014-09-15', warranty_until = '2016-09-15',
    design_life_years = 25, replacement_value = 95000000 WHERE id = asc3;

  INSERT INTO keystone.assets(tenant_id, legal_entity_id, location_id, category_id, name, tag, manufacturer, model, criticality, status, workcenter,
                              install_date, warranty_until, design_life_years, replacement_value, currency)
  SELECT t, le, v.loc, v.cat, v.name, v.tag, v.mf, v.model, v.crit::keystone.asset_criticality, v.st, v.wc, v.inst::date, v.war::date, v.life, v.rv, 'XOF'
  FROM (VALUES
    ('Groupe froid n°1', 'GF-01', 'Carrier', '30XA-1002', loc_cvc, c_cvc, 'high', 'operational', 'CVC', '2016-03-01', '2018-03-01', 15, 185000000),
    ('CTA galerie Nord', 'CTA-N1', 'France Air', 'Optima 25', loc_gal, c_cvc, 'medium', 'operational', 'CVC', '2019-06-10', '2024-06-10', 20, 42000000),
    ('Transformateur TR1 1600 kVA', 'TR-01', 'Schneider', 'Trihal 1600', loc_cvc, c_elec, 'safety_critical', 'operational', 'Électricité', '2014-08-01', '2016-08-01', 30, 68000000),
    ('Groupe électrogène 800 kVA', 'GE-01', 'SDMO', 'X800C', loc_cvc, c_elec, 'high', 'degraded', 'Électricité', '2015-01-20', '2017-01-20', 20, 120000000),
    ('Centrale SSI catégorie A', 'SSI-01', 'Siemens', 'Cerberus FC2080', loc_gal, c_ssi, 'safety_critical', 'operational', 'Sécurité', '2020-11-05', '2025-11-05', 15, 36000000),
    ('Surpresseur eau froide', 'SUR-01', 'Grundfos', 'Hydro MPC-E', loc_cvc, c_plomb, 'medium', 'operational', 'Plomberie', '2021-02-14', '2026-12-31', 15, 18500000)
  ) v(name, tag, mf, model, loc, cat, crit, st, wc, inst, war, life, rv)
  WHERE NOT EXISTS (SELECT 1 FROM keystone.assets WHERE tenant_id = t AND tag = v.tag);

  INSERT INTO keystone.fmea_items(tenant_id, asset_id, failure_mode_id, component, function_lost, effect, cause, detection_method,
                                  severity, occurrence, detection, action, action_status, rev_severity, rev_occurrence, rev_detection)
  SELECT t, a.id, fm.id, v.comp, v.fn, v.eff, v.cause, v.det, v.s, v.o, v.d, v.act, v.ast, v.rs, v.ro, v.rd
  FROM (VALUES
    ('GF-02', 'VIB', 'Compresseur à vis', 'Production d''eau glacée', 'Arrêt froid galerie, inconfort occupants', 'Usure roulements', 'Analyse vibratoire trimestrielle', 7, 6, 5, 'Capteur vibratoire en continu + seuil Sentinelle', 'in_progress', 7, 4, 2),
    ('GF-02', 'ELU', 'Circuit frigorifique', 'Maintien charge R134a', 'Perte de puissance, rejet fluide (F-Gas)', 'Brasure fissurée', 'Contrôle étanchéité annuel', 6, 4, 6, 'Contrôle étanchéité semestriel + détecteur', 'none', NULL, NULL, NULL),
    ('ASC-A3', 'SER', 'Parachute & limiteur', 'Arrêt sécurisé de la cabine', 'Risque chute cabine — sécurité des personnes', 'Grippage du limiteur', 'Essai réglementaire', 10, 2, 4, 'Essai parachute semestriel', 'none', NULL, NULL, NULL),
    ('ASC-A3', 'FTS', 'Opérateur de portes', 'Ouverture/fermeture palière', 'Blocage passagers', 'Patins usés, cellule encrassée', 'Plainte occupant', 6, 7, 6, 'Remplacement patins + nettoyage mensuel cellule', 'none', NULL, NULL, NULL),
    ('TR-01', 'OHE', 'Enroulements', 'Transformation HT/BT', 'Coupure générale du centre', 'Surcharge estivale + ventilation local', 'Sondes PT100', 9, 3, 3, 'Thermographie IR annuelle', 'done', 9, 2, 2),
    ('GE-01', 'FTS', 'Démarreur & batteries', 'Secours en cas de délestage CIE', 'Black-out lors du délestage', 'Batteries sulfatées', 'Essai mensuel à vide', 8, 6, 4, 'Essai en charge mensuel + test batteries', 'none', NULL, NULL, NULL),
    ('SSI-01', 'SER', 'Détecteurs optiques', 'Détection incendie', 'Retard d''alarme évacuation', 'Encrassement (poussière harmattan)', 'Test annuel', 10, 3, 5, 'Nettoyage semestriel + test 100 % des boucles', 'none', NULL, NULL, NULL),
    ('CTA-N1', 'LOO', 'Courroies ventilateur', 'Soufflage air neuf', 'Qualité d''air dégradée', 'Détente/usure courroie', 'Ronde visuelle', 4, 6, 4, NULL, 'none', NULL, NULL, NULL),
    ('SUR-01', 'ELU', 'Garniture mécanique', 'Pression réseau', 'Fuite local technique', 'Coup de bélier', 'Ronde visuelle', 5, 3, 3, NULL, 'none', NULL, NULL, NULL)
  ) v(tag, fmc, comp, fn, eff, cause, det, s, o, d, act, ast, rs, ro, rd)
  JOIN keystone.assets a ON a.tenant_id = t AND a.tag = v.tag
  LEFT JOIN keystone.failure_modes fm ON fm.code = v.fmc
  WHERE NOT EXISTS (SELECT 1 FROM keystone.fmea_items f WHERE f.asset_id = a.id AND f.component = v.comp);
END $$;

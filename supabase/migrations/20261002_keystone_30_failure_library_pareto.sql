-- keystone_30_failure_library_pareto — Bibliothèque de modes de défaillance + Pareto des pannes
-- Porté depuis WiseFM (failure-modes « predefinedFailureModes », failure-history + utils/pareto-analysis) et amélioré :
--   · bibliothèque en BASE (WiseFM : constante en dur dans l'écran) — 15 familles bâtiment × 4 modes
--   · cotation G/O/D SUGGÉRÉE par mode (à ajuster par l'analyste) + rattachement code ISO 14224
--   · fmea_from_library(actif, famille) : initialise l'AMDEC d'un actif en un clic (anti-doublon)
--   · Pareto 80/20 calculé en base sur les OT correctifs réels : fréquence | coût | durée d'arrêt

CREATE TABLE IF NOT EXISTS keystone.failure_mode_library (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family text NOT NULL,
  family_label text NOT NULL,
  mode text NOT NULL,
  consequences text NOT NULL,
  causes text NOT NULL,
  detection text NOT NULL,
  suggested_severity int NOT NULL CHECK (suggested_severity BETWEEN 1 AND 10),
  suggested_occurrence int NOT NULL CHECK (suggested_occurrence BETWEEN 1 AND 10),
  suggested_detection int NOT NULL CHECK (suggested_detection BETWEEN 1 AND 10),
  iso14224_code text,
  UNIQUE (family, mode)
);
GRANT SELECT ON keystone.failure_mode_library TO authenticated;

INSERT INTO keystone.failure_mode_library(family, family_label, mode, consequences, causes, detection,
  suggested_severity, suggested_occurrence, suggested_detection, iso14224_code) VALUES
  ('ECLAIRAGE', 'Éclairage', 'Ampoule / tube grillé', 'Zone non éclairée', 'Vieillissement, surtension', 'Inspection visuelle', 3, 6, 3, 'LOO'),
  ('ECLAIRAGE', 'Éclairage', 'Ballast HS', 'Lumière clignotante ou absente', 'Surchauffe, défaut composant', 'Clignotement, absence d’allumage', 3, 4, 3, 'FTS'),
  ('ECLAIRAGE', 'Éclairage', 'Court-circuit', 'Coupure circuit, disjoncteur déclenché', 'Humidité, fil dénudé, surcharge', 'Disjoncteur déclenché', 6, 3, 4, 'LOO'),
  ('ECLAIRAGE', 'Éclairage', 'Détecteur de présence HS', 'Lumière reste allumée / éteinte', 'Usure, défaut électronique', 'Test manuel', 2, 4, 5, NULL),
  ('CLIMATISATION', 'Climatisation / CVC', 'Compresseur en panne', 'Plus de froid, inconfort occupants', 'Usure, manque d’huile, surcharge', 'Alarme, absence de régulation', 7, 4, 4, 'FTS'),
  ('CLIMATISATION', 'Climatisation / CVC', 'Fuite de fluide frigorigène', 'Perte d’efficacité, arrêt, rejet F-Gas', 'Vieillissement, joint défectueux', 'Baisse de pression, détecteur de fuite', 6, 4, 6, 'ELU'),
  ('CLIMATISATION', 'Climatisation / CVC', 'Filtre colmaté', 'Débit d’air faible, surchauffe', 'Manque d’entretien, poussière (harmattan)', 'Pression différentielle, bruit', 4, 7, 4, 'LOO'),
  ('CLIMATISATION', 'Climatisation / CVC', 'Sonde de température HS', 'Mauvaise régulation', 'Défaut électronique, câble coupé', 'Température incohérente', 4, 3, 5, NULL),
  ('ASCENSEUR', 'Ascenseur', 'Blocage cabine', 'Personnes bloquées', 'Défaut capteur, panne moteur', 'Alarme, appel usager', 8, 4, 2, 'LOO'),
  ('ASCENSEUR', 'Ascenseur', 'Porte ne s’ouvre pas', 'Blocage accès, attente', 'Capteur encrassé, moteur HS', 'Signal défaut, test manuel', 6, 6, 4, 'FTS'),
  ('ASCENSEUR', 'Ascenseur', 'Défaut variateur', 'Arrêt brutal, secousses', 'Surtension, composant HS', 'Code erreur, bruit anormal', 6, 3, 4, NULL),
  ('ASCENSEUR', 'Ascenseur', 'Usure câble de traction', 'Risque de rupture, arrêt sécurité', 'Vieillissement, surcharge', 'Inspection visuelle, contrôle réglementaire', 10, 2, 4, 'SER'),
  ('ESCALATOR', 'Escalier mécanique', 'Arrêt brutal', 'Chute d’usagers, arrêt service', 'Corps étranger, sécurité activée', 'Alarme, arrêt immédiat', 9, 3, 2, 'LOO'),
  ('ESCALATOR', 'Escalier mécanique', 'Main courante bloquée / désynchronisée', 'Danger pour usagers', 'Usure, manque de graissage', 'Inspection, bruit', 7, 4, 4, NULL),
  ('ESCALATOR', 'Escalier mécanique', 'Bruit anormal', 'Usure mécanique', 'Roulement HS, pièce desserrée', 'Bruit, vibration', 4, 5, 4, 'VIB'),
  ('ESCALATOR', 'Escalier mécanique', 'Défaut capteur de sécurité', 'Non-arrêt en cas d’obstacle', 'Capteur sale ou défectueux', 'Test sécurité', 10, 2, 6, 'SER'),
  ('PORTES_AUTOMATIQUES', 'Portes automatiques', 'Non-ouverture', 'Blocage accès, évacuation gênée', 'Capteur HS, moteur HS', 'Test manuel, alarme', 7, 4, 3, 'FTS'),
  ('PORTES_AUTOMATIQUES', 'Portes automatiques', 'Ouverture intempestive', 'Perte sécurité, énergie', 'Capteur mal réglé, interférence', 'Observation, plainte usager', 4, 4, 5, NULL),
  ('PORTES_AUTOMATIQUES', 'Portes automatiques', 'Bruit mécanique', 'Usure, risque de panne', 'Manque de graissage, pièce usée', 'Bruit, vibration', 3, 5, 4, 'VIB'),
  ('PORTES_AUTOMATIQUES', 'Portes automatiques', 'Porte reste ouverte', 'Perte énergie, sûreté', 'Capteur défectueux, réglage', 'Observation, test', 4, 4, 4, NULL),
  ('SECURITE_INCENDIE', 'Sécurité incendie (SSI)', 'Déclenchement intempestif', 'Fausse alerte, évacuation', 'Détecteur poussiéreux, humidité', 'Historique alarmes', 5, 5, 3, NULL),
  ('SECURITE_INCENDIE', 'Sécurité incendie (SSI)', 'Non-déclenchement', 'Non-évacuation, danger vital', 'Batterie HS, détecteur HS', 'Test périodique, voyant défaut', 10, 2, 6, 'SER'),
  ('SECURITE_INCENDIE', 'Sécurité incendie (SSI)', 'Défaut de transmission d’alarme', 'Secours non informés', 'Liaison coupée, panne centrale', 'Test, voyant défaut centrale', 9, 2, 5, 'SER'),
  ('SECURITE_INCENDIE', 'Sécurité incendie (SSI)', 'Sirène / diffuseur HS', 'Alarme inaudible', 'Haut-parleur HS, fil coupé', 'Test sonore', 9, 2, 5, 'SER'),
  ('PLOMBERIE', 'Plomberie & pompage', 'Fuite visible', 'Inondation, dégâts matériels', 'Usure, joint HS, coup de bélier', 'Inspection visuelle, humidité', 5, 5, 3, 'ELU'),
  ('PLOMBERIE', 'Plomberie & pompage', 'Robinet / vanne bloqué', 'Inconfort, coupure d’eau', 'Calcaire, usure', 'Test manuel', 3, 4, 4, NULL),
  ('PLOMBERIE', 'Plomberie & pompage', 'Canalisation bouchée', 'Refoulement, inondation', 'Dépôt, objet, graisse', 'Écoulement lent, bruit', 5, 5, 4, NULL),
  ('PLOMBERIE', 'Plomberie & pompage', 'Chasse d’eau HS', 'Gaspillage d’eau, fuite', 'Mécanisme usé, flotteur HS', 'Bruit, écoulement continu', 2, 6, 4, 'ELU'),
  ('GROUPES_ELECTROGENES', 'Groupe électrogène', 'Non-démarrage', 'Black-out lors du délestage', 'Batteries HS, manque de carburant', 'Essai de démarrage, voyant défaut', 8, 5, 4, 'FTS'),
  ('GROUPES_ELECTROGENES', 'Groupe électrogène', 'Surchauffe', 'Arrêt sécurité en charge', 'Ventilation obstruée, manque d’huile / eau', 'Alarme, température élevée', 7, 3, 3, 'OHE'),
  ('GROUPES_ELECTROGENES', 'Groupe électrogène', 'Défaut alternateur', 'Pas de production électrique', 'Usure, surcharge', 'Test tension, voyant défaut', 8, 2, 4, 'LOO'),
  ('GROUPES_ELECTROGENES', 'Groupe électrogène', 'Fuite de carburant', 'Pollution, risque incendie', 'Joint HS, réservoir percé', 'Odeur, tache, inspection', 8, 3, 4, 'ELU'),
  ('ARMOIRES_ELECTRIQUES', 'Armoires & TGBT', 'Surchauffe / point chaud', 'Coupure, incendie', 'Surcharge, mauvais serrage', 'Thermographie infrarouge', 9, 3, 4, 'OHE'),
  ('ARMOIRES_ELECTRIQUES', 'Armoires & TGBT', 'Disjoncteur déclenché', 'Coupure partielle ou totale', 'Court-circuit, surcharge', 'Voyant, inspection', 5, 5, 2, 'LOO'),
  ('ARMOIRES_ELECTRIQUES', 'Armoires & TGBT', 'Court-circuit', 'Coupure, risque incendie', 'Fil dénudé, humidité', 'Disjoncteur, inspection', 8, 2, 4, 'LOO'),
  ('ARMOIRES_ELECTRIQUES', 'Armoires & TGBT', 'Défaut différentiel', 'Personnes non protégées', 'Usure, défaut composant', 'Test différentiel', 10, 2, 6, 'SER'),
  ('CAMERAS_VIDEOSURVEILLANCE', 'Vidéosurveillance', 'Image noire', 'Perte de surveillance', 'Alimentation coupée, caméra HS', 'Test visuel, alarme logiciel', 5, 4, 3, 'LOO'),
  ('CAMERAS_VIDEOSURVEILLANCE', 'Vidéosurveillance', 'Perte de signal', 'Zone non couverte', 'Câble débranché, switch HS', 'Test réseau, voyant', 5, 4, 3, 'LOO'),
  ('CAMERAS_VIDEOSURVEILLANCE', 'Vidéosurveillance', 'Enregistrement HS', 'Perte de preuve, insécurité', 'Disque plein / HS, bug logiciel', 'Test de lecture', 6, 3, 6, NULL),
  ('CAMERAS_VIDEOSURVEILLANCE', 'Vidéosurveillance', 'Optique sale', 'Image floue', 'Poussière, humidité', 'Inspection visuelle', 3, 6, 4, NULL),
  ('BARRIERES_AUTOMATIQUES', 'Barrières automatiques', 'Non-ouverture', 'Blocage accès parking', 'Capteur HS, moteur HS', 'Test manuel, alarme', 4, 5, 2, 'FTS'),
  ('BARRIERES_AUTOMATIQUES', 'Barrières automatiques', 'Blocage mécanique', 'Arrêt service', 'Choc véhicule, pièce cassée', 'Inspection, bruit', 4, 4, 2, NULL),
  ('BARRIERES_AUTOMATIQUES', 'Barrières automatiques', 'Détection absente', 'Risque de choc usager / véhicule', 'Boucle ou cellule défectueuse', 'Test sécurité', 8, 3, 5, 'SER'),
  ('BARRIERES_AUTOMATIQUES', 'Barrières automatiques', 'Ouverture intempestive', 'Perte de contrôle d’accès', 'Réglage, interférence', 'Observation, plainte', 3, 4, 5, NULL),
  ('VENTILATION_PARKING', 'Ventilation / désenfumage parking', 'Extracteur HS', 'Accumulation de CO, danger', 'Usure moteur, surcharge', 'Alarme CO, test extracteur', 9, 3, 4, 'LOO'),
  ('VENTILATION_PARKING', 'Ventilation / désenfumage parking', 'Capteur CO défaillant', 'Ventilation non déclenchée', 'Capteur encrassé ou HS', 'Test capteur', 9, 3, 6, 'SER'),
  ('VENTILATION_PARKING', 'Ventilation / désenfumage parking', 'Bruit anormal', 'Usure mécanique', 'Roulement HS, pièce desserrée', 'Bruit, vibration', 4, 5, 4, 'VIB'),
  ('VENTILATION_PARKING', 'Ventilation / désenfumage parking', 'Arrêt intempestif', 'Arrêt service, danger', 'Surcharge, coupure alimentation', 'Alarme, voyant', 7, 3, 3, 'LOO'),
  ('SANITAIRES_PUBLICS', 'Sanitaires publics', 'Chasse d’eau bloquée', 'Inconfort, gaspillage', 'Calcaire, mécanisme HS', 'Test manuel, bruit', 2, 6, 3, NULL),
  ('SANITAIRES_PUBLICS', 'Sanitaires publics', 'Fuite de robinet', 'Gaspillage, inondation', 'Joint HS, usure', 'Inspection, humidité', 3, 6, 3, 'ELU'),
  ('SANITAIRES_PUBLICS', 'Sanitaires publics', 'WC bouché', 'Refoulement, insalubrité', 'Dépôt, objet, manque d’entretien', 'Écoulement lent, odeur', 4, 6, 2, NULL),
  ('SANITAIRES_PUBLICS', 'Sanitaires publics', 'Sèche-mains HS', 'Inconfort usager', 'Moteur HS, alimentation coupée', 'Test manuel', 1, 5, 3, 'FTS'),
  ('SYSTEMES_INFORMATIQUES', 'Systèmes IT / GTB', 'Perte de connexion réseau', 'Supervision GTB aveugle', 'Switch HS, câble coupé, panne FAI', 'Test réseau, voyant', 6, 4, 3, 'LOO'),
  ('SYSTEMES_INFORMATIQUES', 'Systèmes IT / GTB', 'Panne serveur', 'Arrêt service, perte de données', 'Surcharge, composant HS', 'Alarme, test d’accès', 7, 3, 3, 'LOO'),
  ('SYSTEMES_INFORMATIQUES', 'Systèmes IT / GTB', 'Virus / cyberattaque', 'Perte de données, sûreté', 'Protection insuffisante, hameçonnage', 'Antivirus, journaux, alertes', 8, 3, 5, NULL),
  ('SYSTEMES_INFORMATIQUES', 'Systèmes IT / GTB', 'Sauvegarde non fonctionnelle', 'Perte de données', 'Mauvaise configuration, disque HS', 'Test de restauration', 8, 3, 7, NULL),
  ('COMPACTEURS_POUBELLES', 'Compacteurs & déchets', 'Blocage mécanique', 'Accumulation de déchets', 'Surcharge, objet dur', 'Inspection, bruit', 4, 4, 3, NULL),
  ('COMPACTEURS_POUBELLES', 'Compacteurs & déchets', 'Fuite de lixiviats', 'Insalubrité, odeur, pollution', 'Bac percé, joint HS', 'Inspection, odeur', 5, 4, 4, 'ELU'),
  ('COMPACTEURS_POUBELLES', 'Compacteurs & déchets', 'Non-démarrage', 'Arrêt service', 'Alimentation coupée, moteur HS', 'Test manuel, voyant', 4, 3, 2, 'FTS'),
  ('COMPACTEURS_POUBELLES', 'Compacteurs & déchets', 'Surcharge', 'Arrêt sécurité', 'Trop-plein, mauvais tri', 'Alarme, inspection', 3, 5, 3, NULL)
ON CONFLICT (family, mode) DO NOTHING;

CREATE OR REPLACE FUNCTION keystone.failure_library_families()
RETURNS TABLE(family text, family_label text, modes int, max_severity int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT family, min(family_label), count(*)::int, max(suggested_severity) FROM failure_mode_library GROUP BY family ORDER BY 2;
$$;

-- Initialise l'AMDEC d'un actif depuis une famille (ignore les composants déjà analysés)
CREATE OR REPLACE FUNCTION keystone.fmea_from_library(p_asset uuid, p_family text)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE a assets; n int;
BEGIN
  SELECT * INTO a FROM assets WHERE id = p_asset;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  INSERT INTO fmea_items(tenant_id, asset_id, failure_mode_id, component, effect, cause, detection_method, severity, occurrence, detection)
  SELECT a.tenant_id, a.id,
    (SELECT fm.id FROM failure_modes fm WHERE fm.code = l.iso14224_code AND (fm.tenant_id = a.tenant_id OR fm.is_global) LIMIT 1),
    l.mode, l.consequences, l.causes, l.detection, l.suggested_severity, l.suggested_occurrence, l.suggested_detection
  FROM failure_mode_library l
  WHERE l.family = p_family
    AND NOT EXISTS (SELECT 1 FROM fmea_items f WHERE f.asset_id = a.id AND f.component = l.mode);
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN json_build_object('created', n);
END $$;

-- Pareto des pannes (OT correctifs, fenêtre glissante) — règle 80/20 et classe WiseFM
CREATE OR REPLACE FUNCTION keystone.failure_pareto(p_criterion text DEFAULT 'frequency', p_months int DEFAULT 12)
RETURNS TABLE(asset_id uuid, asset_tag text, asset_name text, failures int, cost numeric, downtime_h numeric,
  value numeric, pct numeric, cumulative_pct numeric, in_vital_few boolean, mtbf_h numeric, mttr_h numeric, availability_pct numeric, class text)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH f AS (
    SELECT a.id, a.tag, a.name, count(w.id)::int AS n,
      coalesce(sum(coalesce(w.cost_labor, 0) + coalesce(w.cost_parts, 0)), 0) AS cost,
      coalesce(sum(w.downtime_hours), 0) AS dt,
      avg(EXTRACT(epoch FROM (w.actual_end - w.actual_start)) / 3600) FILTER (WHERE w.actual_end IS NOT NULL) AS mttr
    FROM work_orders w JOIN assets a ON a.id = w.asset_id
    WHERE w.type = 'corrective' AND w.deleted_at IS NULL
      AND w.created_at > now() - make_interval(months => p_months)
    GROUP BY a.id, a.tag, a.name
  ), v AS (
    SELECT f.*, (CASE p_criterion WHEN 'cost' THEN f.cost WHEN 'downtime' THEN f.dt ELSE f.n END)::numeric AS val FROM f
  ), r AS (
    SELECT v.*,
      100.0 * val / NULLIF(sum(val) OVER (), 0) AS p,
      100.0 * sum(val) OVER (ORDER BY val DESC, tag ROWS UNBOUNDED PRECEDING) / NULLIF(sum(val) OVER (), 0) AS cum,
      100.0 * (sum(val) OVER (ORDER BY val DESC, tag ROWS UNBOUNDED PRECEDING) - val) / NULLIF(sum(val) OVER (), 0) AS cum_before,
      8760.0 * p_months / 12 / NULLIF(n, 0) AS mtbf
    FROM v
  )
  SELECT r.id, r.tag, r.name, r.n, r.cost, r.dt, r.val, round(r.p, 1), round(r.cum, 1),
    coalesce(r.cum_before < 80, false),           -- « vital few » : jusqu'au 1er élément qui franchit 80 %
    round(r.mtbf, 0), round(r.mttr, 2),
    round(100 * r.mtbf / NULLIF(r.mtbf + coalesce(r.mttr, 0), 0), 2),
    CASE WHEN r.p > 20 OR r.n > 15 THEN 'critical' WHEN r.p > 10 OR r.n > 8 THEN 'major' ELSE 'minor' END
  FROM r ORDER BY r.val DESC, r.tag;
$$;

GRANT EXECUTE ON FUNCTION keystone.failure_library_families(), keystone.fmea_from_library(uuid, text),
  keystone.failure_pareto(text, int) TO authenticated;
GRANT INSERT ON keystone.fmea_items TO authenticated;

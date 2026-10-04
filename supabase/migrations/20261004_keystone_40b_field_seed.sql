-- Seed démo exécution terrain : coordonnées des sites, modèles d'OT, OT du jour affectés aux techniciens. Idempotent.
BEGIN;
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  c_cvc uuid; tpl_filtre uuid; tpl_fuite uuid; tpl_gf uuid; tpl_led uuid;
  aka uuid; dio uuid; kof uuid; awa uuid; r record; a record; w uuid;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  -- Coordonnées approximatives (pointage GPS : distance au site)
  UPDATE keystone.sites SET latitude = 5.3399, longitude = -4.0730 WHERE tenant_id = t AND name ILIKE '%Yopougon%' AND latitude IS NULL;
  UPDATE keystone.sites SET latitude = 5.3946, longitude = -3.9891 WHERE tenant_id = t AND name ILIKE '%Angré%' AND latitude IS NULL;
  -- Seul le numéro de l'OT existant fait foi : on recale les compteurs (idempotent) avant de créer des OT
  INSERT INTO keystone.ref_counters(tenant_id, prefix, year, n)
  SELECT tenant_id, 'WO', split_part(ref, '-', 2)::int, max(split_part(ref, '-', 3)::int) FROM keystone.work_orders
  WHERE tenant_id = t AND ref ~ '^WO-[0-9]{4}-[0-9]+$' GROUP BY 1, 3
  ON CONFLICT (tenant_id, prefix, year) DO UPDATE SET n = GREATEST(keystone.ref_counters.n, EXCLUDED.n);

  IF EXISTS (SELECT 1 FROM keystone.wo_templates WHERE tenant_id = t) THEN RETURN; END IF;
  SELECT id INTO c_cvc FROM keystone.asset_categories WHERE tenant_id = t AND name = 'CVC';

  INSERT INTO keystone.wo_templates(tenant_id, name, wo_type, category_id, estimated_minutes, requires_permit, safety_instructions, steps, required_parts)
  VALUES (t, 'Remplacement des filtres CTA', 'preventive', c_cvc, 45, false,
    'Arrêter la CTA depuis la GTB et condamner le sectionneur avant ouverture des caissons. Port des gants et du masque FFP2.',
    '[{"label":"CTA arrêtée et sectionneur condamné","type":"check","required":true,"critical":true},
      {"label":"Photo des filtres avant remplacement","type":"photo","required":true},
      {"label":"Pression différentielle avant (Pa)","type":"numeric","min":0,"max":450,"unit":"Pa","required":true},
      {"label":"Filtres G4 remplacés et datés","type":"check","required":true},
      {"label":"Pression différentielle après (Pa)","type":"numeric","min":40,"max":150,"unit":"Pa","required":true,"critical":true},
      {"label":"Remise en service, absence de vibration","type":"check","required":true}]',
    '[{"part_ref":"FLT-G4-592","qty":4}]')
  RETURNING id INTO tpl_filtre;
  INSERT INTO keystone.wo_templates(tenant_id, name, wo_type, estimated_minutes, safety_instructions, steps, required_parts)
  VALUES (t, 'Réparation fuite sanitaire', 'corrective', 40, 'Couper l''arrivée d''eau du local. Baliser la zone glissante.',
    '[{"label":"Vanne d''arrêt fermée","type":"check","required":true,"critical":true},
      {"label":"Photo avant intervention","type":"photo","required":true},
      {"label":"Remplacement du joint / flexible","type":"check","required":true},
      {"label":"Pression d''essai (bar)","type":"numeric","min":2,"max":4,"unit":"bar","required":true,"critical":true},
      {"label":"Photo après intervention","type":"photo","required":true},
      {"label":"Zone nettoyée et sèche","type":"check","required":true}]',
    '[]')
  RETURNING id INTO tpl_fuite;
  INSERT INTO keystone.wo_templates(tenant_id, name, wo_type, category_id, estimated_minutes, requires_permit, safety_instructions, steps, required_parts)
  VALUES (t, 'Diagnostic groupe froid en défaut', 'corrective', c_cvc, 90, true,
    'Consignation électrique obligatoire (permis + VAT). Fluide frigorigène : intervention par personnel attesté F-Gas uniquement.',
    '[{"label":"Permis actif et consignation vérifiée","type":"check","required":true,"critical":true},
      {"label":"Code défaut automate relevé","type":"text","required":true},
      {"label":"Haute pression (bar)","type":"numeric","min":10,"max":16,"unit":"bar","required":true,"critical":true},
      {"label":"Température départ eau glacée (°C)","type":"numeric","min":5,"max":8,"unit":"°C","required":true},
      {"label":"Recherche de fuite au détecteur : absence de fuite","type":"check","required":true,"critical":true},
      {"label":"Photo du tableau de commande","type":"photo","required":false}]',
    '[]')
  RETURNING id INTO tpl_gf;
  INSERT INTO keystone.wo_templates(tenant_id, name, wo_type, estimated_minutes, safety_instructions, steps, required_parts)
  VALUES (t, 'Remplacement d''éclairage', 'corrective', 20, 'Travail en hauteur : escabeau 3 marches maximum, sinon PIRL. Couper le circuit au tableau.',
    '[{"label":"Circuit coupé au tableau","type":"check","required":true,"critical":true},
      {"label":"Tubes / spots remplacés","type":"check","required":true},
      {"label":"Essai d''allumage concluant","type":"check","required":true}]',
    '[{"part_ref":"LED-T8-18","qty":2}]')
  RETURNING id INTO tpl_led;

  SELECT id INTO aka FROM keystone.persons WHERE tenant_id = t AND first_name = 'Kouassi';
  SELECT id INTO dio FROM keystone.persons WHERE tenant_id = t AND first_name = 'Moussa';
  SELECT id INTO kof FROM keystone.persons WHERE tenant_id = t AND first_name = 'Salif';
  SELECT id INTO awa FROM keystone.persons WHERE tenant_id = t AND first_name = 'Awa';

  -- OT du jour (affectés), avec modèle appliqué
  FOR r IN SELECT * FROM (VALUES
    ('CTA-N1', 'Remplacement filtres CTA galerie Nord', 'preventive', 3, 'filtre', aka, 2),
    ('SUR-01', 'Fuite sur flexible — sanitaires hommes R+1', 'corrective', 2, 'fuite', aka, 4),
    ('GF-01', 'Groupe froid n°1 en défaut haute pression', 'corrective', 1, 'gf', dio, 1),
    ('CTA-N1', 'Tubes LED HS — couloir de service', 'corrective', 3, 'led', kof, 6),
    ('SUR-01', 'Fuite robinet local technique', 'corrective', 3, 'fuite', awa, 3)
  ) v(tag, title, typ, prio, tpl, person, sla_h) LOOP
    CONTINUE WHEN r.person IS NULL;
    SELECT id, legal_entity_id, location_id INTO a FROM keystone.assets WHERE tenant_id = t AND tag = r.tag;
    INSERT INTO keystone.work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, assignee_id,
                                     planned_start, planned_end, sla_due, currency, description)
    VALUES (t, a.legal_entity_id, keystone.next_ref('WO'), a.id, a.location_id, r.typ::keystone.wo_type, r.prio, 'assigned', r.title, r.person,
            date_trunc('day', now()) + interval '8 hours', date_trunc('day', now()) + interval '17 hours', now() + make_interval(hours => r.sla_h), 'XOF',
            'seed-terrain')
    RETURNING id INTO w;
    PERFORM keystone.wo_apply_template(w, CASE r.tpl WHEN 'filtre' THEN tpl_filtre WHEN 'fuite' THEN tpl_fuite WHEN 'gf' THEN tpl_gf ELSE tpl_led END);
  END LOOP;
END $$;
COMMIT;

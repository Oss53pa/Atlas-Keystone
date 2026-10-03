-- Seed démo rondes & NC (tenant New Heaven SA). Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  loc_cvc uuid; loc_gal uuid; gf02 uuid; ssi uuid; tpl_cvc uuid; tpl_ssi uuid; tpl_san uuid; i int; v_insp uuid;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  IF EXISTS (SELECT 1 FROM keystone.inspection_templates WHERE tenant_id = t) THEN RETURN; END IF;
  SELECT id INTO loc_cvc FROM keystone.locations WHERE tenant_id = t AND code = 'LOC-CVC';
  SELECT id INTO loc_gal FROM keystone.locations WHERE tenant_id = t AND code = 'LOC-GAL';
  SELECT id INTO gf02 FROM keystone.assets WHERE tenant_id = t AND tag = 'GF-02';
  SELECT id INTO ssi FROM keystone.assets WHERE tenant_id = t AND tag = 'SSI-01';

  INSERT INTO keystone.inspection_templates(tenant_id, name, domain, frequency_days, location_id, asset_id, requires_signature, checkpoints)
  VALUES (t, 'Ronde technique — production d''eau glacée', 'technique', 1, loc_cvc, gf02, false, '[
    {"key":"t_depart","label":"Température départ eau glacée","type":"numeric","min":5,"max":8,"unit":"°C","required":true,"critical":false},
    {"key":"hp","label":"Pression HP compresseur","type":"numeric","min":10,"max":16,"unit":"bar","required":true,"critical":true},
    {"key":"vib","label":"Absence de vibration / bruit anormal","type":"boolean","required":true,"critical":false},
    {"key":"fuite","label":"Aucune trace de fuite d''huile ou de fluide","type":"boolean","required":true,"critical":true},
    {"key":"etat","label":"État général du local","type":"choice","options":["Propre","À nettoyer","Encombré"],"fail_options":["Encombré"],"required":true,"critical":false},
    {"key":"obs","label":"Observations","type":"text","required":false,"critical":false}
  ]'::jsonb) RETURNING id INTO tpl_cvc;

  INSERT INTO keystone.inspection_templates(tenant_id, name, domain, frequency_days, location_id, asset_id, requires_signature, checkpoints)
  VALUES (t, 'Ronde sécurité incendie ERP', 'securite', 7, loc_gal, ssi, true, '[
    {"key":"ssi_veille","label":"Centrale SSI en veille, aucun dérangement","type":"boolean","required":true,"critical":true},
    {"key":"issues","label":"Issues de secours dégagées et balisées","type":"boolean","required":true,"critical":true},
    {"key":"baes","label":"BAES fonctionnels (test)","type":"boolean","required":true,"critical":false},
    {"key":"extinct","label":"Extincteurs présents et plombés","type":"boolean","required":true,"critical":false},
    {"key":"portes_cf","label":"Portes coupe-feu fermées","type":"boolean","required":true,"critical":false}
  ]'::jsonb) RETURNING id INTO tpl_ssi;

  INSERT INTO keystone.inspection_templates(tenant_id, name, domain, frequency_days, location_id, requires_signature, checkpoints)
  VALUES (t, 'Contrôle propreté sanitaires publics', 'proprete', 1, loc_gal, false, '[
    {"key":"sols","label":"Sols propres et secs","type":"boolean","required":true,"critical":false},
    {"key":"consommables","label":"Savon / papier approvisionnés","type":"boolean","required":true,"critical":false},
    {"key":"odeur","label":"Niveau d''odeur","type":"choice","options":["Aucune","Légère","Forte"],"fail_options":["Forte"],"required":true,"critical":false}
  ]'::jsonb) RETURNING id INTO tpl_san;

  -- Historique : 10 rondes CVC, 4 rondes SSI, 8 contrôles sanitaires
  FOR i IN 1..10 LOOP
    INSERT INTO keystone.inspections(tenant_id, ref, template_id, inspector_name, answers, score, failed, completed_at)
    VALUES (t, keystone.next_ref('INS'), tpl_cvc, CASE WHEN i % 2 = 0 THEN 'Aka K.' ELSE 'Diomandé S.' END,
            jsonb_build_object('t_depart', 6.5, 'hp', 13.2, 'vib', i <> 3, 'fuite', true, 'etat', 'Propre'),
            CASE WHEN i = 3 THEN 88.9 ELSE 100 END, (i = 3)::int, now() - make_interval(days => i + 1));
  END LOOP;
  FOR i IN 1..4 LOOP
    INSERT INTO keystone.inspections(tenant_id, ref, template_id, inspector_name, answers, score, failed, signed, completed_at)
    VALUES (t, keystone.next_ref('INS'), tpl_ssi, 'Toko A.', jsonb_build_object('ssi_veille', true, 'issues', i <> 2, 'baes', true, 'extinct', true, 'portes_cf', i <> 1),
            CASE i WHEN 1 THEN 88.9 WHEN 2 THEN 66.7 ELSE 100 END, (i <= 2)::int, true, now() - make_interval(days => 7 * i + 2))
    RETURNING id INTO v_insp;
    IF i = 2 THEN
      INSERT INTO keystone.non_conformities(tenant_id, ref, title, type, severity, status, source, inspection_id, checkpoint_key, location_id, asset_id,
                                            immediate_action, root_cause, corrective_action, due_date, closed_at, created_at)
      VALUES (t, keystone.next_ref('NC'), 'Issues de secours dégagées et balisées', 'security', 'critical', 'closed', 'inspection', v_insp, 'issues', loc_gal, ssi,
              'Palettes déplacées immédiatement', 'Livraisons stockées dans le dégagement par un preneur', 'Marquage au sol + rappel au règlement intérieur des preneurs',
              (now() - interval '14 days')::date, now() - interval '15 days', now() - interval '16 days');
    END IF;
    IF i = 1 THEN
      INSERT INTO keystone.non_conformities(tenant_id, ref, title, type, severity, status, source, inspection_id, checkpoint_key, location_id, asset_id, due_date, created_at)
      VALUES (t, keystone.next_ref('NC'), 'Portes coupe-feu fermées', 'security', 'minor', 'in_progress', 'inspection', v_insp, 'portes_cf', loc_gal, ssi,
              (now() - interval '9 days')::date + 30, now() - interval '9 days');
    END IF;
  END LOOP;
  FOR i IN 1..8 LOOP
    INSERT INTO keystone.inspections(tenant_id, ref, template_id, inspector_name, answers, score, failed, completed_at)
    VALUES (t, keystone.next_ref('INS'), tpl_san, 'CleanPro — équipe B', jsonb_build_object('sols', true, 'consommables', i NOT IN (2, 5), 'odeur', 'Aucune'),
            CASE WHEN i IN (2, 5) THEN 66.7 ELSE 100 END, (i IN (2, 5))::int, now() - make_interval(days => i));
  END LOOP;
  INSERT INTO keystone.non_conformities(tenant_id, ref, title, type, severity, status, source, location_id, due_date, created_at)
  VALUES (t, keystone.next_ref('NC'), 'Savon / papier approvisionnés', 'quality', 'minor', 'open', 'inspection', loc_gal, current_date + 25, now() - interval '5 days'),
         (t, keystone.next_ref('NC'), 'Fuite d''eau sous lavabo sanitaire H', 'maintenance', 'major', 'open', 'complaint', loc_gal, current_date - 2, now() - interval '9 days');
END $$;

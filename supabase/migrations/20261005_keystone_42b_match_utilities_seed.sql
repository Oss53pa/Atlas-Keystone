-- Seed démo rapprochement 3 voies & sous-comptage (tenant démo). Idempotent.
-- Grilles CIE / SODECI : valeurs INDICATIVES de démonstration, à recaler sur une facture réelle du site.
BEGIN;
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  yop uuid; s record; s_froid uuid; s_elec uuid; s_ssi uuid;
  tf_mt uuid; tf_bt uuid; tf_eau uuid; m_main uuid; m_sub uuid; r record; k int; p date; idx numeric; q numeric; base numeric;
  pr uuid; po uuid; inv uuid; l1 uuid; l2 uuid; l3 uuid; v_spike numeric;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  IF EXISTS (SELECT 1 FROM keystone.meters WHERE tenant_id = t) THEN RETURN; END IF;
  SELECT id INTO yop FROM keystone.sites WHERE tenant_id = t AND name ILIKE '%Yopougon%';

  -- ---------------- Tolérances de rapprochement ----------------
  INSERT INTO keystone.notification_rules(tenant_id, event_type, channel, audience, is_enabled)
  VALUES (t, 'invoice.discrepancy', 'in_app', 'staff', true), (t, 'invoice.discrepancy', 'email', 'staff', true)
  ON CONFLICT (tenant_id, event_type, channel, audience) DO NOTHING;
  INSERT INTO keystone.notification_templates(tenant_id, event_type, channel, locale, subject, body) VALUES
    (t, 'invoice.discrepancy', 'in_app', 'fr', 'Facture {{ref}} en écart', 'Facture {{supplier_ref}} (BC {{po_ref}}) bloquée au rapprochement : {{issues}}. Écart {{variance}} FCFA HT.'),
    (t, 'invoice.discrepancy', 'email', 'fr', 'Facture fournisseur {{supplier_ref}} bloquée au rapprochement', 'Bonjour,

La facture {{supplier_ref}} (réf. interne {{ref}}, BC {{po_ref}}) ne peut pas recevoir de bon à payer :
{{issues}}

Écart : {{variance}} FCFA HT.

Atlas Keystone'),
    (t, 'invoice.discrepancy', 'in_app', 'en', 'Invoice {{ref}} on hold', 'Invoice {{supplier_ref}} (PO {{po_ref}}) failed matching: {{issues}}. Variance {{variance}} XOF excl. VAT.')
  ON CONFLICT (tenant_id, event_type, channel, locale) DO NOTHING;
  UPDATE keystone.company_profile SET match_price_tolerance_pct = 2, match_amount_tolerance = 10000 WHERE tenant_id = t;

  -- ---------------- Grilles tarifaires (indicatives) ----------------
  INSERT INTO keystone.utility_tariffs(tenant_id, code, provider, country, carrier, name, unit, fixed_monthly, demand_charge, default_profile, levies, source)
  VALUES (t, 'CIE-MT-GEN', 'CIE', 'CI', 'electricity', 'Moyenne tension — usage général', 'kWh', 25000, 4500,
          '{"offpeak":0.30,"full":0.55,"peak":0.15}', '[{"label":"Redevances & taxes (indicatif)","pct":2}]',
          'Grille indicative Keystone (démo) — à recaler sur la dernière facture CIE du site')
  RETURNING id INTO tf_mt;
  INSERT INTO keystone.utility_tariff_bands(tenant_id, tariff_id, slot, unit_price, label) VALUES
    (t, tf_mt, 'offpeak', 55, 'Heures creuses (23 h – 7 h)'), (t, tf_mt, 'full', 78, 'Heures pleines (7 h – 19 h)'), (t, tf_mt, 'peak', 105, 'Heures de pointe (19 h – 23 h)');

  INSERT INTO keystone.utility_tariffs(tenant_id, code, provider, country, carrier, name, unit, fixed_monthly, levies, source)
  VALUES (t, 'CIE-BT-PRO', 'CIE', 'CI', 'electricity', 'Basse tension — professionnel', 'kWh', 8000,
          '[{"label":"Redevances & taxes (indicatif)","pct":2}]', 'Grille indicative Keystone (démo) — référence pour simulation des lots BT')
  RETURNING id INTO tf_bt;
  INSERT INTO keystone.utility_tariff_bands(tenant_id, tariff_id, slot, from_qty, to_qty, unit_price) VALUES
    (t, tf_bt, 'all', 0, 1000, 92), (t, tf_bt, 'all', 1000, NULL, 101);

  INSERT INTO keystone.utility_tariffs(tenant_id, code, provider, country, carrier, name, unit, fixed_monthly, levies, source)
  VALUES (t, 'SODECI-PRO', 'SODECI', 'CI', 'water', 'Eau — usage professionnel', 'm3', 10000,
          '[{"label":"Assainissement & FDE (indicatif)","pct":5}]', 'Grille indicative Keystone (démo) — à recaler sur la dernière facture SODECI du site')
  RETURNING id INTO tf_eau;
  INSERT INTO keystone.utility_tariff_bands(tenant_id, tariff_id, slot, from_qty, to_qty, unit_price) VALUES
    (t, tf_eau, 'all', 0, 500, 480), (t, tf_eau, 'all', 500, 2000, 560), (t, tf_eau, 'all', 2000, NULL, 620);

  -- ---------------- Compteurs généraux (tous sites) — index cohérents avec les factures saisies ----------------
  FOR s IN SELECT id, name FROM keystone.sites WHERE tenant_id = t LOOP
    FOR r IN SELECT * FROM (VALUES ('electricity', 'kWh', 'ELEC', tf_mt, 1000000::numeric), ('water', 'm3', 'EAU', tf_eau, 50000::numeric)) v(carrier, unit, pfx, tariff, start_idx) LOOP
      INSERT INTO keystone.meters(tenant_id, site_id, code, name, carrier, unit, kind, tariff_id, subscribed_kva, provider_contract, usage)
      VALUES (t, s.id, r.pfx || '-' || upper(left(regexp_replace((string_to_array(s.name, ' '))[array_length(string_to_array(s.name, ' '), 1)], '[^A-Za-z]', '', 'g'), 3)) || '-GEN',
              CASE r.carrier WHEN 'electricity' THEN 'Poste de livraison CIE — ' ELSE 'Compteur général SODECI — ' END || s.name,
              r.carrier, r.unit, 'main', r.tariff,
              CASE WHEN r.carrier = 'electricity' THEN CASE WHEN s.id = yop THEN 1600 ELSE 1000 END END,
              CASE r.carrier WHEN 'electricity' THEN 'CIE-MT-' ELSE 'SOD-' END || lpad((abs(hashtext(s.name)) % 1000000)::text, 6, '0'), 'Général')
      RETURNING id INTO m_main;
      idx := r.start_idx;
      FOR k IN 0..6 LOOP
        p := (date_trunc('month', current_date) - make_interval(months => 6 - k))::date;
        INSERT INTO keystone.meter_readings(tenant_id, meter_id, read_at, index_value, source) VALUES (t, m_main, p, idx, 'manual');
        IF k < 6 THEN
          SELECT quantity INTO q FROM keystone.energy_readings WHERE tenant_id = t AND site_id = s.id AND carrier = r.carrier AND period = p;
          idx := idx + coalesce(q, 0);
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  -- ---------------- Sous-compteurs du Cosmos Yopougon ----------------
  -- (code, nom, fluide, lot ou NULL = parties communes, usage, part du général)
  FOR r IN SELECT * FROM (VALUES
    ('ELEC-YOP-HYP', 'Hyper Cosmos', 'electricity', 'AGG-HYP', 'Lot', 0.300),
    ('ELEC-YOP-CINE', 'Ciné Lagune', 'electricity', 'A-R1-020', 'Lot', 0.075),
    ('ELEC-YOP-MODE', 'Mode Ivoire', 'electricity', 'A-RDC-001', 'Lot', 0.040),
    ('ELEC-YOP-POUL', 'Poulet Doré', 'electricity', 'A-R1-005', 'Lot', 0.035),
    ('ELEC-YOP-PAP', 'Pas à Pas', 'electricity', 'LOT-B12', 'Lot', 0.015),
    ('ELEC-YOP-PHAR', 'Pharmacie du Cosmos', 'electricity', 'A-RDC-022', 'Lot', 0.012),
    ('ELEC-YOP-BANQ', 'Banque Lagune', 'electricity', 'A-RDC-030', 'Lot', 0.010),
    ('ELEC-YOP-TEL', 'TélécomPlus', 'electricity', 'A-RDC-014', 'Lot', 0.006),
    ('ELEC-YOP-CVC', 'Centrale froid & CTA (parties communes)', 'electricity', NULL, 'CVC', 0.320),
    ('ELEC-YOP-ECL', 'Éclairage mail & parkings (parties communes)', 'electricity', NULL, 'Éclairage', 0.090),
    ('EAU-YOP-HYP', 'Hyper Cosmos', 'water', 'AGG-HYP', 'Lot', 0.340),
    ('EAU-YOP-POUL', 'Poulet Doré', 'water', 'A-R1-005', 'Lot', 0.070),
    ('EAU-YOP-CINE', 'Ciné Lagune', 'water', 'A-R1-020', 'Lot', 0.050),
    ('EAU-YOP-SAN', 'Sanitaires publics (parties communes)', 'water', NULL, 'Sanitaires', 0.300),
    ('EAU-YOP-EXT', 'Espaces verts & nettoyage (parties communes)', 'water', NULL, 'Extérieurs', 0.120)
  ) v(code, name, carrier, lot, usage, share) LOOP
    SELECT id INTO m_main FROM keystone.meters WHERE tenant_id = t AND site_id = yop AND carrier = r.carrier AND kind = 'main';
    INSERT INTO keystone.meters(tenant_id, site_id, code, name, carrier, unit, kind, parent_id, space_unit_id, usage)
    VALUES (t, yop, r.code, r.name, r.carrier, CASE r.carrier WHEN 'electricity' THEN 'kWh' ELSE 'm3' END, 'sub', m_main,
            (SELECT id FROM keystone.space_units WHERE tenant_id = t AND code = r.lot), r.usage)
    RETURNING id INTO m_sub;
    idx := round(1000 + abs(hashtext(r.code)) % 90000);
    FOR k IN 0..6 LOOP
      p := (date_trunc('month', current_date) - make_interval(months => 6 - k))::date;
      -- Banque Lagune : relevés interrompus depuis 2 mois (local en préavis, accès refusé)
      IF NOT (r.code = 'ELEC-YOP-BANQ' AND k >= 5) THEN
        INSERT INTO keystone.meter_readings(tenant_id, meter_id, read_at, index_value, source)
        VALUES (t, m_sub, p, idx, CASE WHEN k % 3 = 0 THEN 'photo' ELSE 'manual' END);
      END IF;
      IF k < 6 THEN
        SELECT quantity INTO q FROM keystone.energy_readings WHERE tenant_id = t AND site_id = yop AND carrier = r.carrier AND period = p;
        v_spike := 1;
        IF r.code = 'ELEC-YOP-POUL' AND k = 5 THEN v_spike := 2.3; END IF;        -- pic : friteuses supplémentaires, compresseur en défaut
        IF r.code = 'ELEC-YOP-CVC' AND k = 3 THEN v_spike := 0.75; END IF;        -- mois « fuite » : branchement non compté suspecté
        idx := idx + round(coalesce(q, 0) * r.share * v_spike * (0.97 + (abs(hashtext(r.code || k)) % 60) / 1000.0));
      END IF;
    END LOOP;
  END LOOP;

  -- Facture CIE du mois M-2 surfacturée (+15 %) — sera détectée par le contrôle de facture
  UPDATE keystone.energy_readings SET cost = round(cost * 1.15)
  WHERE tenant_id = t AND site_id = yop AND carrier = 'electricity' AND period = (date_trunc('month', current_date) - interval '2 months')::date;

  -- ---------------- Rapprochement 3 voies : BC, réceptions, factures ----------------
  SELECT id INTO s_froid FROM keystone.contractors WHERE tenant_id = t AND name = 'Frigo Services CI';
  SELECT id INTO s_elec FROM keystone.contractors WHERE tenant_id = t AND name = 'Électro Distribution Abidjan';
  SELECT id INTO s_ssi FROM keystone.contractors WHERE tenant_id = t AND name = 'Sécurité Feu Afrique';

  -- BC A — Électro : livré, facturé conforme, payé
  INSERT INTO keystone.purchase_requests(tenant_id, ref, title, source, urgency, status, supplier_id)
  VALUES (t, keystone.next_ref('PR'), 'Relamping LED galerie Sud', 'manual', 'normal', 'ordered', s_elec) RETURNING id INTO pr;
  INSERT INTO keystone.purchase_orders(tenant_id, ref, request_id, supplier_id, amount_ht, expected_at, created_at)
  VALUES (t, keystone.next_ref('PO'), pr, s_elec, 200 * 3500 + 12 * 28000, current_date - 40, now() - interval '55 days') RETURNING id INTO po;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, part_id, label, qty_ordered, unit_price) VALUES
    (t, po, (SELECT id FROM keystone.spare_parts WHERE tenant_id = t AND ref = 'LED-T8-18'), 'Tubes LED T8 18 W', 200, 3500) RETURNING id INTO l1;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, label, qty_ordered, unit_price) VALUES (t, po, 'Disjoncteurs 63 A courbe C', 12, 28000) RETURNING id INTO l2;
  PERFORM keystone.po_receive_lines(po, jsonb_build_array(jsonb_build_object('line_id', l1, 'qty', 200), jsonb_build_object('line_id', l2, 'qty', 12)), 'accepted', 'Livraison complète');
  INSERT INTO keystone.supplier_invoices(tenant_id, ref, supplier_ref, order_id, supplier_id, invoice_date, due_date, amount_ht, created_at)
  VALUES (t, keystone.next_ref('FF'), 'FA-ED-2026-0912', po, s_elec, current_date - 35, current_date - 5, 1036000, now() - interval '35 days') RETURNING id INTO inv;
  INSERT INTO keystone.supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price) VALUES
    (t, inv, l1, 'Tubes LED T8 18 W', 200, 3500), (t, inv, l2, 'Disjoncteurs 63 A courbe C', 12, 28000);
  PERFORM keystone.invoice_match(inv);
  UPDATE keystone.supplier_invoices SET status = 'paid', approved_at = now() - interval '20 days', paid_at = now() - interval '8 days', payment_ref = 'VIR-SGBCI-88412' WHERE id = inv;

  -- BC B — Frigo Services : livré ; facture avec courroies à 21 500 au lieu de 18 500 (+16 %) ⇒ écart de prix
  INSERT INTO keystone.purchase_requests(tenant_id, ref, title, source, urgency, status, supplier_id)
  VALUES (t, keystone.next_ref('PR'), 'Révision CTA mail Est', 'manual', 'normal', 'ordered', s_froid) RETURNING id INTO pr;
  INSERT INTO keystone.purchase_orders(tenant_id, ref, request_id, supplier_id, amount_ht, expected_at, created_at)
  VALUES (t, keystone.next_ref('PO'), pr, s_froid, 4 * 38000 + 6 * 18500 + 650000, current_date - 15, now() - interval '30 days') RETURNING id INTO po;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, label, qty_ordered, unit_price) VALUES (t, po, 'Roulements ventilateur SKF 6308', 4, 38000) RETURNING id INTO l1;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, part_id, label, qty_ordered, unit_price) VALUES
    (t, po, (SELECT id FROM keystone.spare_parts WHERE tenant_id = t AND ref = 'CRR-SPA-1250'), 'Courroies SPA 1250', 6, 18500) RETURNING id INTO l2;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, label, qty_ordered, unit_price) VALUES (t, po, 'Main d''œuvre révision (forfait)', 1, 650000) RETURNING id INTO l3;
  PERFORM keystone.po_receive_lines(po, jsonb_build_array(jsonb_build_object('line_id', l1, 'qty', 4), jsonb_build_object('line_id', l2, 'qty', 6), jsonb_build_object('line_id', l3, 'qty', 1)), 'accepted', 'PV de fin de travaux signé');
  INSERT INTO keystone.supplier_invoices(tenant_id, ref, supplier_ref, order_id, supplier_id, invoice_date, due_date, amount_ht, created_at)
  VALUES (t, keystone.next_ref('FF'), 'FSC/0457/26', po, s_froid, current_date - 6, current_date + 24, 4 * 38000 + 6 * 21500 + 650000, now() - interval '6 days') RETURNING id INTO inv;
  INSERT INTO keystone.supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price) VALUES
    (t, inv, l1, 'Roulements ventilateur SKF 6308', 4, 38000), (t, inv, l2, 'Courroies SPA 1250', 6, 21500), (t, inv, l3, 'Main d''œuvre révision (forfait)', 1, 650000);
  PERFORM keystone.invoice_match(inv);

  -- BC C — Sécurité Feu Afrique : 24 détecteurs reçus sur 40, mais facture des 40 ⇒ facturé > reçu
  INSERT INTO keystone.purchase_requests(tenant_id, ref, title, source, urgency, status, supplier_id)
  VALUES (t, keystone.next_ref('PR'), 'Remplacement détecteurs SSI niveau R+1', 'manual', 'urgent', 'ordered', s_ssi) RETURNING id INTO pr;
  INSERT INTO keystone.purchase_orders(tenant_id, ref, request_id, supplier_id, amount_ht, expected_at, created_at)
  VALUES (t, keystone.next_ref('PO'), pr, s_ssi, 40 * 24000 + 25 * 9500, current_date - 3, now() - interval '21 days') RETURNING id INTO po;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, part_id, label, qty_ordered, unit_price) VALUES
    (t, po, (SELECT id FROM keystone.spare_parts WHERE tenant_id = t AND ref = 'DET-OPT-FC'), 'Détecteurs optiques de fumée', 40, 24000) RETURNING id INTO l1;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, label, qty_ordered, unit_price) VALUES (t, po, 'Recharge extincteurs CO2 2 kg', 25, 9500) RETURNING id INTO l2;
  PERFORM keystone.po_receive_lines(po, jsonb_build_array(jsonb_build_object('line_id', l1, 'qty', 24), jsonb_build_object('line_id', l2, 'qty', 25)), 'accepted_with_reserves', 'Reliquat de 16 détecteurs annoncé sous 10 jours');
  INSERT INTO keystone.supplier_invoices(tenant_id, ref, supplier_ref, order_id, supplier_id, invoice_date, due_date, amount_ht, created_at)
  VALUES (t, keystone.next_ref('FF'), 'SFA-2026-118', po, s_ssi, current_date - 4, current_date + 26, 40 * 24000 + 25 * 9500, now() - interval '4 days') RETURNING id INTO inv;
  INSERT INTO keystone.supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price) VALUES
    (t, inv, l1, 'Détecteurs optiques de fumée', 40, 24000), (t, inv, l2, 'Recharge extincteurs CO2 2 kg', 25, 9500);
  PERFORM keystone.invoice_match(inv);

  -- BC D — Électro : projecteurs livrés ; facture conforme à valider + une 2e facture même montant 3 jours après ⇒ doublon probable
  INSERT INTO keystone.purchase_requests(tenant_id, ref, title, source, urgency, status, supplier_id)
  VALUES (t, keystone.next_ref('PR'), 'Projecteurs LED parking P2', 'manual', 'normal', 'ordered', s_elec) RETURNING id INTO pr;
  INSERT INTO keystone.purchase_orders(tenant_id, ref, request_id, supplier_id, amount_ht, expected_at, created_at)
  VALUES (t, keystone.next_ref('PO'), pr, s_elec, 10 * 85000, current_date - 12, now() - interval '25 days') RETURNING id INTO po;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, label, qty_ordered, unit_price) VALUES (t, po, 'Projecteurs LED 150 W IP66', 10, 85000) RETURNING id INTO l1;
  PERFORM keystone.po_receive_lines(po, jsonb_build_array(jsonb_build_object('line_id', l1, 'qty', 10)), 'accepted', NULL);
  INSERT INTO keystone.supplier_invoices(tenant_id, ref, supplier_ref, order_id, supplier_id, invoice_date, due_date, amount_ht, created_at)
  VALUES (t, keystone.next_ref('FF'), 'FA-ED-2026-0951', po, s_elec, current_date - 9, current_date + 21, 850000, now() - interval '9 days') RETURNING id INTO inv;
  INSERT INTO keystone.supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price) VALUES (t, inv, l1, 'Projecteurs LED 150 W IP66', 10, 85000);
  PERFORM keystone.invoice_match(inv);
  INSERT INTO keystone.supplier_invoices(tenant_id, ref, supplier_ref, order_id, supplier_id, invoice_date, due_date, amount_ht, created_at)
  VALUES (t, keystone.next_ref('FF'), 'FA-ED-2026-0951-R', po, s_elec, current_date - 6, current_date + 24, 850000, now() - interval '6 days') RETURNING id INTO inv;
  INSERT INTO keystone.supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price) VALUES (t, inv, l1, 'Projecteurs LED 150 W IP66', 10, 85000);
  PERFORM keystone.invoice_match(inv);

  -- BC E — Frigo Services : gaz frigorigène, facture validée, échue et non payée
  INSERT INTO keystone.purchase_requests(tenant_id, ref, title, source, urgency, status, supplier_id)
  VALUES (t, keystone.next_ref('PR'), 'Appoint fluide R134a groupe froid n°2', 'manual', 'urgent', 'ordered', s_froid) RETURNING id INTO pr;
  INSERT INTO keystone.purchase_orders(tenant_id, ref, request_id, supplier_id, amount_ht, expected_at, created_at)
  VALUES (t, keystone.next_ref('PO'), pr, s_froid, 3 * 145000, current_date - 50, now() - interval '60 days') RETURNING id INTO po;
  INSERT INTO keystone.purchase_order_lines(tenant_id, order_id, part_id, label, qty_ordered, unit_price) VALUES
    (t, po, (SELECT id FROM keystone.spare_parts WHERE tenant_id = t AND ref = 'R134A-13'), 'Bouteille R134a 13,6 kg', 3, 145000) RETURNING id INTO l1;
  PERFORM keystone.po_receive_lines(po, jsonb_build_array(jsonb_build_object('line_id', l1, 'qty', 3)), 'accepted', NULL);
  INSERT INTO keystone.supplier_invoices(tenant_id, ref, supplier_ref, order_id, supplier_id, invoice_date, due_date, amount_ht, created_at)
  VALUES (t, keystone.next_ref('FF'), 'FSC/0398/26', po, s_froid, current_date - 45, current_date - 15, 435000, now() - interval '45 days') RETURNING id INTO inv;
  INSERT INTO keystone.supplier_invoice_lines(tenant_id, invoice_id, po_line_id, label, qty, unit_price) VALUES (t, inv, l1, 'Bouteille R134a 13,6 kg', 3, 145000);
  PERFORM keystone.invoice_match(inv);
  UPDATE keystone.supplier_invoices SET status = 'approved', approved_at = now() - interval '30 days' WHERE id = inv;
END $$;
COMMIT;

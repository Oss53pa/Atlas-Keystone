-- Seed démo registre déchets (24 mois, 2 sites, opérateurs agréés). Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  op_rec uuid; op_dd uuid; s record; m int; d date; scale numeric;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  IF EXISTS (SELECT 1 FROM keystone.waste_records WHERE tenant_id = t) THEN RETURN; END IF;

  INSERT INTO keystone.contractors(tenant_id, name, prequalified, rating, is_waste_operator, waste_approval_ref, waste_approval_until)
  SELECT t, v.n, true, v.r, true, v.ref, v.until::date FROM (VALUES
    ('Recycl''Abidjan', 4.2, 'AGR-ANAGED-2024-117', (current_date + 400)::text),
    ('EcoTraitement Déchets Spéciaux', 4.5, 'AGR-CIAPOL-DD-0931', (current_date + 45)::text)
  ) v(n, r, ref, until)
  WHERE NOT EXISTS (SELECT 1 FROM keystone.contractors WHERE tenant_id = t AND name = v.n);
  SELECT id INTO op_rec FROM keystone.contractors WHERE tenant_id = t AND name = 'Recycl''Abidjan';
  SELECT id INTO op_dd FROM keystone.contractors WHERE tenant_id = t AND name = 'EcoTraitement Déchets Spéciaux';

  FOR s IN SELECT id, name FROM keystone.sites WHERE tenant_id = t LOOP
    scale := CASE WHEN s.name ILIKE '%Yopougon%' THEN 1.0 ELSE 0.6 END;
    FOR m IN 0..23 LOOP
      d := (date_trunc('month', current_date) - make_interval(months => m))::date + 12;
      CONTINUE WHEN d > current_date;
      -- amélioration progressive du tri : la part valorisée augmente sur l'année récente
      INSERT INTO keystone.waste_records(tenant_id, site_id, stream, treatment, quantity_kg, operator_id, collected_on, source, cost, validated) VALUES
        (t, s.id, 'dib', CASE WHEN m < 12 THEN 'valorization' ELSE 'elimination' END, round(scale * 14000 * (1 + 0.05 * (m >= 12)::int)), op_rec, d, 'weighbridge', round(scale * 14000 * 45), true),
        (t, s.id, 'paper', 'recycling', round(scale * 3800), op_rec, d, 'weighbridge', round(scale * 3800 * 20), true),
        (t, s.id, 'plastic', CASE WHEN m < 12 THEN 'recycling' ELSE 'elimination' END, round(scale * 2100), op_rec, d, 'weighbridge', round(scale * 2100 * 30), true),
        (t, s.id, 'organic', 'valorization', round(scale * 5200), op_rec, d, 'estimation', round(scale * 5200 * 25), m >= 1),
        (t, s.id, 'glass', 'recycling', round(scale * 900), op_rec, d, 'weighbridge', round(scale * 900 * 15), true);
      IF m % 3 = 0 THEN
        INSERT INTO keystone.waste_records(tenant_id, site_id, stream, treatment, quantity_kg, operator_id, collected_on, bsd_ref, certificate_ref, source, cost, validated)
        VALUES (t, s.id, 'dangerous', 'elimination', round(scale * 420), op_dd, d, 'BSD-' || to_char(d, 'YYMM') || '-' || left(s.name, 3),
                CASE WHEN m = 0 THEN NULL ELSE 'CERT-' || to_char(d, 'YYMM') END, 'certificate', round(scale * 420 * 650), m > 0),
               (t, s.id, 'electronic', 'recycling', round(scale * 160), op_dd, d, 'BSD-E' || to_char(d, 'YYMM'),
                CASE WHEN m <= 1 THEN NULL ELSE 'CERT-E' || to_char(d, 'YYMM') END, 'certificate', round(scale * 160 * 300), true);
      END IF;
    END LOOP;
  END LOOP;

  INSERT INTO keystone.waste_objectives(tenant_id, kind, label, target, year) VALUES
    (t, 'valorization_rate', 'Taux de valorisation matière & énergie', 75, extract(year FROM current_date)::int),
    (t, 'reduction', 'Réduction du tonnage total vs N-1', 5, extract(year FROM current_date)::int),
    (t, 'dangerous_max', 'Déchets dangereux ≤ 200 kg / mois', 200, extract(year FROM current_date)::int)
  ON CONFLICT (tenant_id, kind, year) DO NOTHING;
END $$;

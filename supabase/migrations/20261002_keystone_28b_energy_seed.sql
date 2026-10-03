-- Seed démo énergie (24 mois, 2 sites) — saisonnalité CVC et délestages. Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  s record; m int; p date; season numeric; scale numeric;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  FOR s IN SELECT id, name FROM keystone.sites WHERE tenant_id = t LOOP
    scale := CASE WHEN s.name ILIKE '%Yopougon%' THEN 1.0 ELSE 0.62 END;
    FOR m IN 0..23 LOOP
      p := (date_trunc('month', current_date) - make_interval(months => m + 1))::date;
      -- pic de chaleur mars–mai, creux juillet–septembre (saison des pluies)
      season := CASE extract(month FROM p)::int WHEN 3 THEN 1.18 WHEN 4 THEN 1.22 WHEN 5 THEN 1.15 WHEN 7 THEN 0.88 WHEN 8 THEN 0.86 WHEN 9 THEN 0.9 ELSE 1.0 END;
      INSERT INTO keystone.energy_readings(tenant_id, site_id, carrier, period, quantity, unit, cost, source, validated)
      VALUES
        (t, s.id, 'electricity', p, round(scale * 380000 * season * (1 - 0.04 * (m < 12)::int)), 'kWh',
            round(scale * 380000 * season * 92), 'invoice', m >= 2),
        (t, s.id, 'diesel', p, round(scale * CASE WHEN extract(month FROM p)::int IN (3,4,5) THEN 4200 ELSE 1600 END), 'L',
            round(scale * CASE WHEN extract(month FROM p)::int IN (3,4,5) THEN 4200 ELSE 1600 END * 715), 'manual', m >= 2),
        (t, s.id, 'water', p, round(scale * 2800 * (0.95 + 0.1 * random())), 'm3', round(scale * 2800 * 600), 'invoice', m >= 2)
      ON CONFLICT (tenant_id, site_id, carrier, period) DO NOTHING;
      IF m IN (4, 15) AND s.name ILIKE '%Yopougon%' THEN
        INSERT INTO keystone.energy_readings(tenant_id, site_id, carrier, period, quantity, unit, source, validated)
        VALUES (t, s.id, 'refrigerant_r134a', p, CASE m WHEN 4 THEN 18 ELSE 9 END, 'kg', 'manual', true)
        ON CONFLICT (tenant_id, site_id, carrier, period) DO NOTHING;
      END IF;
    END LOOP;
    INSERT INTO keystone.energy_targets(tenant_id, site_id, carrier, monthly_target, alert_threshold, critical_threshold)
    VALUES (t, s.id, 'electricity', round(scale * 360000), round(scale * 400000), round(scale * 440000)),
           (t, s.id, 'diesel', round(scale * 1500), round(scale * 2500), round(scale * 4000)),
           (t, s.id, 'water', round(scale * 2700), round(scale * 3000), round(scale * 3400))
    ON CONFLICT (tenant_id, site_id, carrier) DO NOTHING;
  END LOOP;
END $$;

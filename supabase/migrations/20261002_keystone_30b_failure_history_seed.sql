-- Seed démo : historique 12 mois d'OT correctifs (alimente Pareto, MTBF/MTTR, indice de santé). Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  r record; i int; a record; d timestamptz;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  IF EXISTS (SELECT 1 FROM keystone.work_orders WHERE tenant_id = t AND description = 'seed-historique-pannes') THEN RETURN; END IF;
  -- (tag, nb pannes, durée intervention h, arrêt h, coût MO, coût pièces)
  FOR r IN SELECT * FROM (VALUES
    ('ASC-A3', 9, 3.5, 6, 85000, 120000),
    ('GE-01',  6, 5.0, 4, 140000, 380000),
    ('GF-02',  4, 6.0, 18, 210000, 950000),
    ('CTA-N1', 3, 2.0, 3, 45000, 37000),
    ('GF-01',  2, 4.0, 8, 160000, 240000),
    ('SUR-01', 1, 3.0, 2, 60000, 87000),
    ('TR-01',  1, 8.0, 5, 320000, 0)
  ) v(tag, n, dur, dt, lab, parts) LOOP
    SELECT id, legal_entity_id, location_id INTO a FROM keystone.assets WHERE tenant_id = t AND tag = r.tag;
    CONTINUE WHEN a.id IS NULL;
    FOR i IN 1..r.n LOOP
      d := now() - make_interval(days => (i * 330 / r.n)::int + 5);
      INSERT INTO keystone.work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, description,
                                       actual_start, actual_end, downtime_hours, cost_labor, cost_parts, currency, created_at)
      VALUES (t, a.legal_entity_id, keystone.next_ref('WO'), a.id, a.location_id, 'corrective', 2, 'done',
              'Dépannage ' || r.tag, 'seed-historique-pannes', d, d + make_interval(mins => (r.dur * 60)::int),
              r.dt, r.lab, r.parts, 'XOF', d);
    END LOOP;
  END LOOP;
END $$;

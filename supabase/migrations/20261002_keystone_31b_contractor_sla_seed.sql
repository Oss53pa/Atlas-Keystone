-- Seed démo SLA prestataires : contrats + SLA + affectation de l'historique de pannes + évaluations. Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  c_froid uuid; c_elec uuid; k uuid; r record;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  SELECT id INTO c_froid FROM keystone.contractors WHERE tenant_id = t AND name = 'Frigo Services CI';
  SELECT id INTO c_elec FROM keystone.contractors WHERE tenant_id = t AND name ILIKE 'Élec%' ORDER BY created_at LIMIT 1;

  -- Contrats (si absents) : CVC + Électricité/levage
  FOR r IN SELECT * FROM (VALUES
    (c_froid, 'Maintenance CVC — groupes froids & CTA', 42000000, current_date + 75, 90, true),
    (c_elec, 'Maintenance électricité HT/BT, groupes électrogènes & ascenseurs', 36000000, current_date + 240, 90, false)
  ) v(cid, scope, amount, end_d, notice, auto) LOOP
    CONTINUE WHEN r.cid IS NULL;
    SELECT id INTO k FROM keystone.maintenance_contracts WHERE tenant_id = t AND contractor_id = r.cid AND is_active ORDER BY end_date DESC LIMIT 1;
    IF k IS NULL THEN
      INSERT INTO keystone.maintenance_contracts(tenant_id, contractor_id, scope, start_date, end_date, amount, currency, is_active, renewal_notice_days, auto_renewal)
      VALUES (t, r.cid, r.scope, r.end_d - 365, r.end_d, r.amount, 'XOF', true, r.notice, r.auto) RETURNING id INTO k;
    END IF;
    INSERT INTO keystone.contract_slas(tenant_id, contract_id, metric, label, target, unit, lower_is_better, weight, priority_scope, penalty_per_unit) VALUES
      (t, k, 'response_time', 'Délai d''intervention (P1-P2)', 4, 'h', true, 2, 2, 25000),
      (t, k, 'resolution_time', 'Délai de rétablissement', 24, 'h', true, 2, NULL, 10000),
      (t, k, 'first_time_fix', 'Réparation au 1er passage', 85, '%', false, 1, NULL, 0)
    ON CONFLICT (contract_id, metric, priority_scope) DO NOTHING;
    k := NULL;
  END LOOP;

  -- Affecte l'historique de pannes aux prestataires + délais réalistes (créé avant l'intervention)
  UPDATE keystone.work_orders w SET
    contractor_id = CASE WHEN a.tag IN ('GF-01','GF-02','CTA-N1','SUR-01') THEN c_froid ELSE c_elec END,
    created_at = w.actual_start - make_interval(mins => CASE WHEN a.tag IN ('GF-01','GF-02','CTA-N1','SUR-01') THEN 150 ELSE 330 END
                                                       + (abs(hashtext(w.ref)) % 120))
  FROM keystone.assets a
  WHERE a.id = w.asset_id AND w.tenant_id = t AND w.description = 'seed-historique-pannes' AND w.contractor_id IS NULL;

  INSERT INTO keystone.contractor_evaluations(tenant_id, contractor_id, period, scores, comment)
  SELECT t, x.cid, date_trunc('month', current_date - interval '1 month')::date, x.sc::jsonb, x.cm
  FROM (VALUES
    (c_froid, '{"quality":88,"timing":84,"communication":90,"innovation":70,"cost":76,"reliability":86}', 'Réactif, rapports d''intervention complets.'),
    (c_elec,  '{"quality":74,"timing":58,"communication":66,"innovation":55,"cost":80,"reliability":62}', 'Délais P1 non tenus sur l''ascenseur A3.')
  ) x(cid, sc, cm)
  WHERE x.cid IS NOT NULL
  ON CONFLICT (contractor_id, period) DO NOTHING;
END $$;

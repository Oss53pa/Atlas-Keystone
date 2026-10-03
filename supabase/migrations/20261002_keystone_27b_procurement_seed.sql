-- Seed démo achats & stocks (tenant New Heaven SA). Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  wh uuid; s_froid uuid; s_elec uuid; s_ssi uuid; bl uuid; pr uuid; p record;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  SELECT id INTO wh FROM keystone.warehouses WHERE tenant_id = t ORDER BY created_at LIMIT 1;
  SELECT id INTO bl FROM keystone.budget_lines WHERE tenant_id = t LIMIT 1;

  INSERT INTO keystone.contractors(tenant_id, name, prequalified, rating, is_supplier)
  SELECT t, n, true, r, true FROM (VALUES ('Frigo Services CI', 4.4), ('Électro Distribution Abidjan', 4.1), ('Sécurité Feu Afrique', 4.6)) v(n, r)
  WHERE NOT EXISTS (SELECT 1 FROM keystone.contractors WHERE tenant_id = t AND name = v.n);
  SELECT id INTO s_froid FROM keystone.contractors WHERE tenant_id = t AND name = 'Frigo Services CI';
  SELECT id INTO s_elec FROM keystone.contractors WHERE tenant_id = t AND name = 'Électro Distribution Abidjan';
  SELECT id INTO s_ssi FROM keystone.contractors WHERE tenant_id = t AND name = 'Sécurité Feu Afrique';

  UPDATE keystone.spare_parts SET is_critical = true, preferred_supplier_id = s_froid, lead_time_days = 45, max_qty = 3, category = 'spare_part'
    WHERE tenant_id = t AND ref = 'CRG-COMP-02';

  INSERT INTO keystone.spare_parts(tenant_id, warehouse_id, ref, name, category, unit, qty, min_qty, max_qty, reorder_point, unit_cost, currency,
                                   is_critical, lead_time_days, preferred_supplier_id)
  SELECT t, wh, v.ref, v.name, v.cat, v.unit, v.qty, v.mn, v.mx, v.rop, v.cost, 'XOF', v.crit, v.lead, v.sup
  FROM (VALUES
    ('FLT-G4-592', 'Filtre G4 592×592 (CTA)', 'consumable', 'u', 6, 12, 48, 18, 9500, false, 10, s_froid),
    ('R134A-13', 'Fluide R134a bouteille 13,6 kg', 'consumable', 'u', 1, 2, 6, 3, 145000, true, 21, s_froid),
    ('CRR-SPA-1250', 'Courroie SPA 1250', 'spare_part', 'u', 4, 4, 12, 6, 18500, false, 7, s_froid),
    ('BAT-GE-12V', 'Batterie démarrage GE 12 V 200 Ah', 'spare_part', 'u', 0, 2, 4, 2, 210000, true, 14, s_elec),
    ('FUS-HPC-63', 'Fusible HPC 63 A', 'spare_part', 'u', 22, 10, 40, 15, 4200, false, 5, s_elec),
    ('LED-T8-18', 'Tube LED T8 18 W', 'consumable', 'u', 35, 40, 160, 60, 3800, false, 10, s_elec),
    ('DET-OPT-FC', 'Détecteur optique de fumée', 'safety', 'u', 3, 8, 24, 12, 62000, true, 30, s_ssi),
    ('EPI-HARN', 'Harnais antichute EN 361', 'safety', 'u', 5, 4, 10, 5, 48000, false, 14, s_ssi),
    ('JNT-GM-35', 'Garniture mécanique Ø35 surpresseur', 'spare_part', 'u', 2, 1, 3, 1, 87000, false, 30, s_froid)
  ) v(ref, name, cat, unit, qty, mn, mx, rop, cost, crit, lead, sup)
  WHERE NOT EXISTS (SELECT 1 FROM keystone.spare_parts WHERE tenant_id = t AND ref = v.ref);

  -- Consommations 90 j (sorties) pour calculer la couverture réelle
  IF NOT EXISTS (SELECT 1 FROM keystone.stock_movements WHERE tenant_id = t AND reason = 'seed-conso') THEN
    FOR p IN SELECT id, ref FROM keystone.spare_parts WHERE tenant_id = t LOOP
      INSERT INTO keystone.stock_movements(tenant_id, part_id, qty, direction, reason, at)
      SELECT t, p.id,
        CASE p.ref WHEN 'FLT-G4-592' THEN 4 WHEN 'LED-T8-18' THEN 9 WHEN 'FUS-HPC-63' THEN 2 WHEN 'CRR-SPA-1250' THEN 1
                   WHEN 'DET-OPT-FC' THEN 1 WHEN 'R134A-13' THEN 1 ELSE 0 END,
        'out', 'seed-conso', now() - (g * interval '15 days')
      FROM generate_series(1, 5) g
      WHERE p.ref IN ('FLT-G4-592','LED-T8-18','FUS-HPC-63','CRR-SPA-1250','DET-OPT-FC','R134A-13');
    END LOOP;
  END IF;

  -- Une DA manuelle soumise (palier 2 : technique + budget)
  IF NOT EXISTS (SELECT 1 FROM keystone.purchase_requests WHERE tenant_id = t AND title = 'Kit révision CTA galerie Nord') THEN
    INSERT INTO keystone.purchase_requests(tenant_id, ref, title, justification, source, urgency, status, supplier_id, budget_line_id)
    VALUES (t, keystone.next_ref('PR'), 'Kit révision CTA galerie Nord', 'Révision annuelle — plan de maintenance CTA-N1', 'manual', 'normal', 'submitted', s_froid, bl)
    RETURNING id INTO pr;
    INSERT INTO keystone.purchase_request_lines(tenant_id, request_id, label, qty, unit_price) VALUES
      (t, pr, 'Roulements ventilateur SKF 6308', 4, 38000), (t, pr, 'Courroies SPA 1250', 6, 18500), (t, pr, 'Main d''œuvre révision (forfait)', 1, 650000);
  END IF;
END $$;

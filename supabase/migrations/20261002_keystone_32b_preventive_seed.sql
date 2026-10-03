-- Seed démo gammes préventives AFNOR (tenant New Heaven SA). Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  c_froid uuid; c_elec uuid; r record; a uuid; p uuid; s record; i int;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  SELECT id INTO c_froid FROM keystone.contractors WHERE tenant_id = t AND name = 'Frigo Services CI';
  SELECT id INTO c_elec FROM keystone.contractors WHERE tenant_id = t AND name ILIKE 'Élec%' ORDER BY created_at LIMIT 1;

  FOR r IN SELECT * FROM (VALUES
    ('GF-02', 'Ronde de conduite groupe froid', 1, 'operator', NULL::uuid, 1, 'day', 0.5, false, 2),
    ('GF-02', 'Visite trimestrielle groupe froid (contrôle étanchéité F-Gas)', 3, 'contractor', c_froid, 3, 'month', 6, true, 70),
    ('CTA-N1', 'Changement filtres & courroies CTA', 2, 'internal', NULL, 1, 'month', 2, false, 40),
    ('GE-01', 'Essai mensuel en charge groupe électrogène', 2, 'internal', NULL, 1, 'month', 1.5, false, 38),
    ('GE-01', 'Révision annuelle moteur & alternateur', 4, 'contractor', c_elec, 12, 'month', 16, false, 300),
    ('TR-01', 'Thermographie IR TGBT & transformateur', 3, 'contractor', c_elec, 12, 'month', 4, true, 330),
    ('SSI-01', 'Vérification semestrielle SSI (APSAD R7)', 3, 'contractor', c_elec, 6, 'month', 8, true, 190),
    ('ASC-A3', 'Entretien mensuel ascenseur', 2, 'contractor', c_elec, 1, 'month', 2, true, 35),
    ('SUR-01', 'Contrôle surpresseur & garniture', 2, 'internal', NULL, 3, 'month', 1, false, 100)
  ) v(tag, name, lvl, exe, cid, ivl, unit, hrs, reg, last_ago) LOOP
    CONTINUE WHEN r.exe = 'contractor' AND r.cid IS NULL;
    SELECT id INTO a FROM keystone.assets WHERE tenant_id = t AND tag = r.tag;
    CONTINUE WHEN a IS NULL OR EXISTS (SELECT 1 FROM keystone.maintenance_plans WHERE tenant_id = t AND name = r.name);
    INSERT INTO keystone.maintenance_plans(tenant_id, asset_id, name, trigger_type, interval_value, interval_unit, lead_time_days, is_active,
                                           afnor_level, executor_kind, contractor_id, estimated_hours, regulatory, last_generated_on)
    VALUES (t, a, r.name, 'calendar', r.ivl, r.unit, 7, true, r.lvl, r.exe, r.cid, r.hrs, r.reg, current_date - r.last_ago)
    RETURNING id INTO p;
    i := 0;
    FOR s IN SELECT * FROM (VALUES
      ('Consignation / mise en sécurité selon procédure', 10, true, 'VAT réalisée, cadenas posé', NULL::jsonb),
      ('Relevé des paramètres de fonctionnement', 15, false, 'Valeurs dans la plage constructeur', '{"type":"numeric","min":5,"max":8,"unit":"°C"}'::jsonb),
      ('Inspection visuelle : fuites, corrosion, fixations', 15, false, 'Aucune anomalie', '{"type":"boolean"}'::jsonb),
      ('Opérations de la gamme (nettoyage, serrage, remplacement)', 45, false, 'Pièces d''usure remplacées si nécessaire', NULL),
      ('Essai fonctionnel et remise en service', 15, true, 'Fonctionnement nominal constaté', '{"type":"boolean"}'::jsonb)
    ) x(label, dur, crit, acc, cp) LOOP
      i := i + 1;
      CONTINUE WHEN r.lvl = 1 AND i IN (1, 4);       -- niveau 1 : ni consignation ni démontage
      INSERT INTO keystone.plan_steps(tenant_id, plan_id, seq, label, duration_min, is_critical, acceptance, checkpoint)
      VALUES (t, p, i, s.label, s.dur, s.crit, s.acc, s.cp);
    END LOOP;
  END LOOP;
END $$;

-- Seed démo portail prestataire : 4 OT à différentes étapes du cycle. Idempotent.
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  c_froid uuid; c_elec uuid; r record; a record; w uuid; q uuid; rp uuid;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  IF EXISTS (SELECT 1 FROM keystone.wo_quotes WHERE tenant_id = t) THEN RETURN; END IF;
  SELECT id INTO c_froid FROM keystone.contractors WHERE tenant_id = t AND name = 'Frigo Services CI';
  SELECT id INTO c_elec FROM keystone.contractors WHERE tenant_id = t AND name ILIKE 'Élec%' ORDER BY created_at LIMIT 1;
  IF c_froid IS NULL OR c_elec IS NULL THEN RETURN; END IF;

  FOR r IN SELECT * FROM (VALUES
    (1, 'GF-02', c_froid, 'Remplacement roulements compresseur à vis', 'assigned', 'quote_submitted', 30),
    (2, 'CTA-N1', c_froid, 'Remplacement moteur ventilateur CTA', 'in_progress', 'quote_approved_variation', 52),
    (3, 'GE-01', c_elec, 'Batteries de démarrage HS — groupe électrogène', 'done', 'report_submitted', 20),
    (4, 'ASC-A3', c_elec, 'Porte palière niveau 2 bloquée', 'in_progress', 'paused', 9)
  ) v(n, tag, cid, title, st, stage, hours_ago) LOOP
    SELECT id, legal_entity_id, location_id INTO a FROM keystone.assets WHERE tenant_id = t AND tag = r.tag;
    CONTINUE WHEN a.id IS NULL;
    INSERT INTO keystone.work_orders(tenant_id, legal_entity_id, ref, asset_id, location_id, type, priority, status, title, contractor_id,
                                     created_at, sla_due, actual_start, actual_end, currency)
    VALUES (t, a.legal_entity_id, keystone.next_ref('WO'), a.id, a.location_id, 'corrective', CASE WHEN r.n = 4 THEN 1 ELSE 2 END,
            r.st::keystone.wo_status, r.title, r.cid,
            now() - make_interval(hours => r.hours_ago), now() - make_interval(hours => r.hours_ago) + interval '24 hours',
            CASE WHEN r.st IN ('in_progress','done') THEN now() - make_interval(hours => r.hours_ago - 3) END,
            CASE WHEN r.st = 'done' THEN now() - interval '2 hours' END, 'XOF')
    RETURNING id INTO w;

    IF r.stage IN ('quote_submitted','quote_approved_variation','report_submitted') THEN
      INSERT INTO keystone.wo_quotes(tenant_id, ref, work_order_id, contractor_id, status, notes, valid_until, decided_at)
      VALUES (t, keystone.next_ref('DV'), w, r.cid, CASE WHEN r.stage = 'quote_submitted' THEN 'submitted' ELSE 'approved' END,
              'Intervention sous 48 h après accord.', current_date + 30, CASE WHEN r.stage <> 'quote_submitted' THEN now() - interval '1 day' END)
      RETURNING id INTO q;
      INSERT INTO keystone.wo_quote_items(tenant_id, quote_id, contractor_id, kind, label, qty, unit_price)
      SELECT t, q, r.cid, x.k, x.l, x.qty, x.pu FROM (VALUES
        (1, 'labor', 'Main d''œuvre technicien frigoriste', 8, 18500), (1, 'material', 'Jeu de roulements SKF compresseur', 1, 640000), (1, 'travel', 'Déplacement Abidjan', 1, 25000),
        (2, 'labor', 'Main d''œuvre (2 techniciens)', 6, 17000), (2, 'material', 'Moteur 7,5 kW IE3', 1, 980000),
        (3, 'labor', 'Main d''œuvre électricien', 2, 16000), (3, 'material', 'Batteries 12 V 200 Ah', 2, 210000)
      ) x(n, k, l, qty, pu) WHERE x.n = r.n;
    END IF;

    IF r.stage = 'quote_approved_variation' THEN
      INSERT INTO keystone.wo_variations(tenant_id, work_order_id, contractor_id, reason, extra_cost, extra_hours)
      VALUES (t, w, r.cid, 'Accouplement moteur fissuré découvert au démontage — remplacement nécessaire', 265000, 2);
    END IF;

    IF r.stage = 'report_submitted' THEN
      INSERT INTO keystone.wo_reports(tenant_id, work_order_id, contractor_id, summary, technician_name, photos_before, photos_after)
      VALUES (t, w, r.cid, 'Remplacement des deux batteries de démarrage, test de démarrage OK (3 essais). Chargeur contrôlé.',
              'Koné M.', ARRAY['avant-batteries-1', 'avant-borniers-2'], ARRAY['apres-batteries-1', 'apres-essai-2'])
      RETURNING id INTO rp;
      INSERT INTO keystone.wo_anomalies(tenant_id, report_id, contractor_id, severity, description) VALUES
        (t, rp, r.cid, 'major', 'Fuite légère de liquide de refroidissement sur la durite inférieure'),
        (t, rp, r.cid, 'minor', 'Étiquetage du tableau de commande effacé');
    END IF;

    IF r.stage = 'paused' THEN
      INSERT INTO keystone.wo_sla_pauses(tenant_id, work_order_id, contractor_id, reason, started_at, justified)
      VALUES (t, w, r.cid, 'waiting_parts', now() - interval '5 hours', NULL);
    END IF;
  END LOOP;
END $$;

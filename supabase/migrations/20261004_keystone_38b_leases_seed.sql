-- Seed démo gestion locative — Cosmos Yopougon (enseignes FICTIVES). Idempotent.
BEGIN;
DO $$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  yop uuid; r record; le uuid; l uuid; su uuid; n int; tk uuid; mode_id uuid;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  IF EXISTS (SELECT 1 FROM keystone.leases WHERE tenant_id = t) THEN RETURN; END IF;
  SELECT id INTO yop FROM keystone.sites WHERE tenant_id = t AND name ILIKE '%Yopougon%';

  -- Lots locatifs individualisés (pris sur la surface agrégée de la galerie pour garder la surface totale constante)
  INSERT INTO keystone.space_units(tenant_id, code, name, type, surface_m2, status, occupant_kind, is_verified)
  SELECT t, v.code, v.name, 'tenant_lot', v.m2, 'occupied', 'tenant_locataire', true FROM (VALUES
    ('A-RDC-001', 'Lot A-RDC-001 — mail principal', 420),
    ('A-RDC-014', 'Lot A-RDC-014', 95),
    ('A-RDC-022', 'Lot A-RDC-022', 180),
    ('A-RDC-030', 'Lot A-RDC-030 — angle parvis', 150),
    ('A-R1-005', 'Lot A-R1-005 — food court', 260),
    ('A-R1-020', 'Lot A-R1-020 — pôle loisirs', 1200)
  ) v(code, name, m2)
  WHERE NOT EXISTS (SELECT 1 FROM keystone.space_units WHERE tenant_id = t AND code = v.code);
  UPDATE keystone.space_units SET surface_m2 = 14500 - 2305 WHERE tenant_id = t AND code = 'AGG-GAL' AND surface_m2 = 14500;

  FOR r IN SELECT * FROM (VALUES
    -- société, enseigne, secteur, lot, loyer/mois, provision/mois, poids charges, début, fin, indexation, taux, période, prochaine, base indice, statut
    ('Mode Ivoire SARL', 'Mode Ivoire', 'Prêt-à-porter', 'A-RDC-001', 7560000, 1176000, 1.0, '2022-01-01', '2030-12-31', 'fixed', 3.0, 12, '2027-01-01', NULL::numeric, 'active'),
    ('Hyper Cosmos SA', 'Hyper Cosmos', 'Alimentaire', 'AGG-HYP', 39900000, 11400000, 0.5, '2019-03-01', '2034-02-28', 'index', NULL, 36, '2026-03-01', 100.0, 'active'),
    ('TélécomPlus CI', 'TélécomPlus', 'Téléphonie', 'A-RDC-014', 2375000, 285000, 1.0, '2024-06-01', '2027-05-31', 'fixed', 4.0, 12, '2026-06-01', NULL, 'active'),
    ('Pharmacie du Cosmos', 'Pharmacie du Cosmos', 'Santé', 'A-RDC-022', 2880000, 504000, 1.0, '2021-09-01', '2030-08-31', 'fixed', 3.0, 12, '2026-09-01', NULL, 'active'),
    ('Poulet Doré SARL', 'Poulet Doré', 'Restauration', 'A-R1-005', 3640000, 728000, 1.2, '2023-02-01', '2029-01-31', 'fixed', 3.5, 12, '2027-02-01', NULL, 'active'),
    ('Banque Lagune SA', 'Banque Lagune', 'Banque', 'A-RDC-030', 3300000, 420000, 1.0, '2020-01-01', '2026-12-31', 'fixed', 2.5, 12, '2027-01-01', NULL, 'notice'),
    ('Pas à Pas Chaussures', 'Pas à Pas', 'Chaussures', 'LOT-B12', 5100000, 952000, 1.0, '2022-07-01', '2031-06-30', 'fixed', 3.0, 12, '2027-07-01', NULL, 'active'),
    ('Ciné Lagune SAS', 'Ciné Lagune', 'Loisirs', 'A-R1-020', 7200000, 1800000, 0.7, '2025-04-01', '2037-03-31', 'fixed', 2.0, 12, '2027-04-01', NULL, 'active')
  ) v(co, trade, sector, lot, rent, prov, w, sd, ed, ix, rate, per, nxt, base, st)
  LOOP
    INSERT INTO keystone.lessees(tenant_id, company_name, trade_name, sector, rccm, contact_name, contact_phone, contact_email)
    VALUES (t, r.co, r.trade, r.sector, 'CI-ABJ-' || (2015 + length(r.co) % 9) || '-B-' || lpad((length(r.co) * 1373 % 99999)::text, 5, '0'),
            'Responsable ' || r.trade, '+225 07 00 00 ' || lpad((length(r.co) * 7 % 100)::text, 2, '0') || ' 00',
            lower(regexp_replace(r.trade, '[^A-Za-z]', '', 'g')) || '@exemple.ci')
    RETURNING id INTO le;
    IF r.trade = 'Mode Ivoire' THEN mode_id := le; END IF;
    INSERT INTO keystone.leases(tenant_id, ref, lessee_id, site_id, start_date, end_date, monthly_rent, charges_provision, charges_weight,
                                deposit_amount, indexation_type, indexation_rate, indexation_period_months, next_indexation_date, index_base, status)
    VALUES (t, 'BL-YOP-' || to_char(r.sd::date, 'YY') || '-' || lpad((SELECT count(*) + 1 FROM keystone.leases WHERE tenant_id = t)::text, 3, '0'),
            le, yop, r.sd::date, r.ed::date, r.rent, r.prov, r.w, r.rent * 3, r.ix, r.rate, r.per, r.nxt::date, r.base, r.st)
    RETURNING id INTO l;
    SELECT id INTO su FROM keystone.space_units WHERE tenant_id = t AND code = r.lot;
    INSERT INTO keystone.lease_spaces(lease_id, space_unit_id, tenant_id) VALUES (l, su, t);
    PERFORM keystone.lease_generate_schedule(l, 1);
  END LOOP;

  -- Historique : tout le passé est soldé, sauf les cas d'impayés de la démo
  UPDATE keystone.rent_schedules SET paid_amount = total_due WHERE tenant_id = t AND due_date < current_date;
  -- Poulet Doré : 3 derniers mois impayés (balance âgée 0-30 / 31-60 / 61-90)
  UPDATE keystone.rent_schedules rs SET paid_amount = 0, reminders_sent = CASE WHEN rs.due_date < current_date - 45 THEN 2 ELSE 1 END,
         last_reminder_at = now() - interval '6 days'
  FROM keystone.leases l JOIN keystone.lessees le ON le.id = l.lessee_id
  WHERE rs.lease_id = l.id AND le.trade_name = 'Poulet Doré' AND rs.due_date < current_date AND rs.due_date >= current_date - 92;
  -- Pas à Pas : dernier mois réglé à 50 %
  UPDATE keystone.rent_schedules rs SET paid_amount = round(rs.total_due / 2)
  FROM keystone.leases l JOIN keystone.lessees le ON le.id = l.lessee_id
  WHERE rs.lease_id = l.id AND le.trade_name = 'Pas à Pas' AND rs.due_date < current_date AND rs.due_date >= current_date - 31;
  -- Banque Lagune (préavis donné) : dernier mois impayé
  UPDATE keystone.rent_schedules rs SET paid_amount = 0
  FROM keystone.leases l JOIN keystone.lessees le ON le.id = l.lessee_id
  WHERE rs.lease_id = l.id AND le.trade_name = 'Banque Lagune' AND rs.due_date < current_date AND rs.due_date >= current_date - 31;

  -- Traces d'encaissement des 12 derniers mois (méthodes variées)
  INSERT INTO keystone.rent_payments(tenant_id, schedule_id, lessee_id, amount, method, provider_ref, paid_at)
  SELECT t, rs.id, rs.lessee_id, rs.paid_amount,
    (ARRAY['transfer','mobile_money','transfer','cheque'])[1 + abs(hashtext(rs.id::text)) % 4],
    CASE WHEN abs(hashtext(rs.id::text)) % 4 = 1 THEN 'CP-' || upper(substr(md5(rs.id::text), 1, 10)) END,
    rs.due_date + (abs(hashtext(rs.id::text)) % 9)
  FROM keystone.rent_schedules rs
  WHERE rs.tenant_id = t AND rs.paid_amount > 0 AND rs.due_date >= current_date - 365 AND rs.due_date < current_date;

  -- Charges récupérables réelles de l'exercice précédent
  INSERT INTO keystone.charge_pools(tenant_id, site_id, year, category, amount) VALUES
    (t, yop, extract(year FROM current_date)::int - 1, 'Nettoyage parties communes', 64000000),
    (t, yop, extract(year FROM current_date)::int - 1, 'Sécurité & gardiennage', 52000000),
    (t, yop, extract(year FROM current_date)::int - 1, 'Énergie parties communes', 71000000),
    (t, yop, extract(year FROM current_date)::int - 1, 'Maintenance technique', 26000000),
    (t, yop, extract(year FROM current_date)::int - 1, 'Assurance multirisque', 9000000),
    (t, yop, extract(year FROM current_date)::int - 1, 'Espaces verts & déchets', 6000000)
  ON CONFLICT DO NOTHING;

  INSERT INTO keystone.site_contacts(site_id, tenant_id, emergency_phone, management_email, management_phone, reception)
  VALUES (yop, t, '+225 27 23 00 00 00 (24 h/24)', 'gestion@cosmos-yopougon.demo', '+225 27 23 00 00 01', 'Accueil — RDC, hall principal, 8 h-21 h')
  ON CONFLICT (site_id) DO NOTHING;

  INSERT INTO keystone.center_news(tenant_id, site_id, kind, title, body, event_date, published_at) VALUES
    (t, yop, 'safety', 'Exercice d''évacuation incendie', 'Exercice obligatoire de 10 h à 11 h. Merci de faire évacuer vos clients et de rejoindre le point de rassemblement parking Nord.', current_date + 6, now() - interval '1 day'),
    (t, yop, 'maintenance', 'Maintenance ascenseur A3', 'Service réduit côté galerie Est de 6 h à 9 h. Utilisez l''ascenseur B ou les escaliers mécaniques.', current_date + 3, now() - interval '2 days'),
    (t, yop, 'event', 'Nuit du shopping', 'Ouverture prolongée jusqu''à 23 h, animations sur l''atrium. Inscription des enseignes participantes auprès de la gestion.', current_date + 15, now() - interval '4 days'),
    (t, yop, 'info', 'Nouveau parcours de livraison', 'Les livraisons se font désormais par le quai Sud entre 6 h et 10 h. Badge d''accès à retirer à l''accueil.', NULL, now() - interval '9 days');

  -- Demandes d'un locataire (circuit tickets existant)
  IF mode_id IS NOT NULL THEN
    INSERT INTO keystone.service_requests(tenant_id, ref, channel, requester_kind, requester_name, lessee_id, category, description, priority, status, sla_due, resolved_at, satisfaction, created_at)
    VALUES (t, keystone.next_ref('TK'), 'tenant_portal', 'lessee', 'Mode Ivoire', mode_id, 'climatisation', 'Climatisation insuffisante dans la cabine d''essayage [local A-RDC-001]', 2, 'resolved', now() - interval '9 days', now() - interval '10 days', 5, now() - interval '11 days')
    RETURNING id INTO tk;
    INSERT INTO keystone.service_requests(tenant_id, ref, channel, requester_kind, requester_name, lessee_id, category, description, priority, status, sla_due, created_at)
    VALUES (t, keystone.next_ref('TK'), 'tenant_portal', 'lessee', 'Mode Ivoire', mode_id, 'plomberie', 'Fuite sous l''évier de la réserve [local A-RDC-001]', 2, 'in_progress', now() + interval '3 hours', now() - interval '5 hours')
    RETURNING id INTO tk;
    INSERT INTO keystone.ticket_messages(tenant_id, ticket_id, body, is_internal, at)
    VALUES (t, tk, 'Technicien sur place, remplacement du joint en cours. Résolution estimée : 1 h.', false, now() - interval '40 minutes');
    INSERT INTO keystone.service_requests(tenant_id, ref, channel, requester_kind, requester_name, lessee_id, category, description, priority, status, sla_due, created_at)
    VALUES (t, keystone.next_ref('TK'), 'tenant_portal', 'lessee', 'Mode Ivoire', mode_id, 'eclairage', 'Deux spots de vitrine hors service [local A-RDC-001]', 3, 'new', now() + interval '2 days', now() - interval '20 minutes');
  END IF;
END $$;
COMMIT;

-- Atlas Keystone · contrôle du cloisonnement (migration 44) — SANS EFFET EN BASE
-- Simule un compte locataire (Poulet Doré) puis un compte prestataire, compte ce que chacun voit, puis lève une
-- exception volontaire : PostgreSQL annule tout (aucune écriture conservée). Le résultat s'affiche dans le message d'erreur.
DO LANGUAGE plpgsql $test$
DECLARE
  t uuid := 'a0000000-0000-4000-8000-000000000001';
  u uuid; le uuid; co uuid; staff json; asl json; asc_ json;
  q text := '
    SELECT json_build_object(
      ''work_orders'', (SELECT count(*) FROM keystone.work_orders),
      ''assets'', (SELECT count(*) FROM keystone.assets),
      ''users'', (SELECT count(*) FROM keystone.users),
      ''persons'', (SELECT count(*) FROM keystone.persons),
      ''budgets'', (SELECT count(*) FROM keystone.budgets),
      ''purchase_orders'', (SELECT count(*) FROM keystone.purchase_orders),
      ''supplier_invoices'', (SELECT count(*) FROM keystone.supplier_invoices),
      ''contractor_invoices'', (SELECT count(*) FROM keystone.contractor_invoices),
      ''contractors'', (SELECT count(*) FROM keystone.contractors),
      ''hsse_events'', (SELECT count(*) FROM keystone.hsse_events),
      ''audit_trail'', (SELECT count(*) FROM keystone.audit_trail),
      ''leases'', (SELECT count(*) FROM keystone.leases),
      ''rent_schedules'', (SELECT count(*) FROM keystone.rent_schedules),
      ''service_requests'', (SELECT count(*) FROM keystone.service_requests),
      ''ticket_msgs_internal'', (SELECT count(*) FROM keystone.ticket_messages WHERE is_internal),
      ''space_units'', (SELECT count(*) FROM keystone.space_units),
      ''sites'', (SELECT count(*) FROM keystone.sites),
      ''wo_quotes'', (SELECT count(*) FROM keystone.wo_quotes),
      ''utility_meters'', (SELECT count(*) FROM keystone.utility_meters))';
BEGIN
  SELECT id INTO u FROM keystone.users WHERE tenant_id = t AND lessee_id IS NULL AND contractor_id IS NULL ORDER BY created_at LIMIT 1;
  SELECT id INTO le FROM keystone.lessees WHERE tenant_id = t AND trade_name = 'Poulet Doré';
  SELECT contractor_id INTO co FROM keystone.work_orders WHERE tenant_id = t AND contractor_id IS NOT NULL GROUP BY 1 ORDER BY count(*) DESC LIMIT 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated', 'tenant_id', t)::text, true);

  -- 1. exploitant (référence)
  EXECUTE 'SET LOCAL ROLE authenticated';
  EXECUTE q INTO staff;
  EXECUTE 'RESET ROLE';

  -- 2. même compte rattaché au locataire Poulet Doré
  UPDATE keystone.users SET lessee_id = le, contractor_id = NULL WHERE id = u;
  EXECUTE 'SET LOCAL ROLE authenticated';
  EXECUTE q INTO asl;
  EXECUTE 'RESET ROLE';

  -- 3. même compte rattaché au prestataire ayant le plus d’OT
  UPDATE keystone.users SET lessee_id = NULL, contractor_id = co WHERE id = u;
  EXECUTE 'SET LOCAL ROLE authenticated';
  EXECUTE q INTO asc_;
  EXECUTE 'RESET ROLE';

  RAISE EXCEPTION 'TEST_RBAC (annulé, rien n''est modifié) %', json_build_object('exploitant', staff, 'locataire', asl, 'prestataire', asc_);
END $test$;

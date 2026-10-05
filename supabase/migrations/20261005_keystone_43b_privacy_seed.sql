-- Seed démo registre des demandes « données personnelles » (tenant démo). Idempotent.
BEGIN;
DO $$
DECLARE t uuid := 'a0000000-0000-4000-8000-000000000001'; s record;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);
  IF EXISTS (SELECT 1 FROM keystone.privacy_requests WHERE tenant_id = t) THEN RETURN; END IF;
  SELECT requester_contact, max(requester_name) AS n INTO s FROM keystone.service_requests
   WHERE tenant_id = t AND requester_contact IS NOT NULL GROUP BY requester_contact ORDER BY count(*) DESC LIMIT 1;
  IF FOUND THEN
    INSERT INTO keystone.privacy_requests(tenant_id, ref, subject_kind, subject_key, subject_label, request_type, channel, received_at, due_date)
    VALUES (t, keystone.next_ref('RGPD'), 'requester', s.requester_contact, coalesce(s.n, s.requester_contact), 'access', 'email', current_date - 12, current_date + 18);
  END IF;
  INSERT INTO keystone.privacy_requests(tenant_id, ref, subject_kind, subject_label, request_type, channel, received_at, due_date, status, outcome, handled_at)
  VALUES (t, keystone.next_ref('RGPD'), 'lessee_contact', 'Ancien gérant — Pas à Pas', 'rectification', 'courrier', current_date - 40, current_date - 10, 'done',
          'Coordonnées du contact preneur mises à jour à la demande de l''intéressé.', now() - interval '20 days');
END $$;
COMMIT;

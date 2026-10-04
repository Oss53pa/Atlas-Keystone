-- keystone_39_notifications — Notifications multicanal (WhatsApp · SMS · email · in-app)
-- Prérequis : migration 38 (baux & portail locataire).
-- Chaîne : événement métier (trigger) → règles (événement × canal × audience) → modèle FR/EN rendu → boîte d'envoi (outbox)
--          → envoi : mode SIMULATION (dispatch en base, journalisé) ou LIVE (Edge Function notify-dispatch, secrets hors base).
-- Garde-fous :
--   · plages de non-dérangement pour SMS/WhatsApp (envoi différé), sauf gravité « critical » qui passe toujours
--   · anti-doublon : même événement × entité × canal × destinataire ignoré pendant 10 min
--   · aucun secret en base (clés API dans les secrets Supabase de l'Edge Function) ; outbox invisible aux locataires/prestataires
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

ALTER TABLE keystone.contractors ADD COLUMN IF NOT EXISTS contact_phone text, ADD COLUMN IF NOT EXISTS contact_email text;

CREATE TABLE IF NOT EXISTS keystone.notification_channels (
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  channel text NOT NULL CHECK (channel IN ('whatsapp','sms','email','in_app')),
  is_enabled boolean NOT NULL DEFAULT true,
  mode text NOT NULL DEFAULT 'simulation' CHECK (mode IN ('simulation','live')),
  provider text,                 -- whatsapp_cloud | orange_sms | twilio | resend | smtp | internal
  sender text,                   -- n° expéditeur / adresse d'envoi (non secret)
  PRIMARY KEY (tenant_id, channel)
);
CREATE TABLE IF NOT EXISTS keystone.notification_quiet_hours (
  tenant_id uuid PRIMARY KEY DEFAULT keystone.current_tenant(),
  start_local time NOT NULL DEFAULT '21:00',
  end_local time NOT NULL DEFAULT '07:00',
  timezone text NOT NULL DEFAULT 'Africa/Abidjan',
  applies_to text[] NOT NULL DEFAULT ARRAY['sms','whatsapp']
);
CREATE TABLE IF NOT EXISTS keystone.notification_events (
  event_type text PRIMARY KEY,
  label text NOT NULL,
  domain text NOT NULL,
  default_severity text NOT NULL DEFAULT 'info' CHECK (default_severity IN ('info','warning','high','critical')),
  placeholders text[] NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS keystone.notification_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  event_type text NOT NULL REFERENCES keystone.notification_events(event_type),
  channel text NOT NULL CHECK (channel IN ('whatsapp','sms','email','in_app')),
  audience text NOT NULL CHECK (audience IN ('lessee','contractor','staff','requester')),
  is_enabled boolean NOT NULL DEFAULT true,
  UNIQUE (tenant_id, event_type, channel, audience)
);
CREATE TABLE IF NOT EXISTS keystone.notification_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  event_type text NOT NULL REFERENCES keystone.notification_events(event_type),
  channel text NOT NULL CHECK (channel IN ('whatsapp','sms','email','in_app')),
  locale text NOT NULL DEFAULT 'fr' CHECK (locale IN ('fr','en')),
  subject text,
  body text NOT NULL,
  wa_template_name text,         -- modèle WhatsApp pré-approuvé (messages hors fenêtre de 24 h)
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, event_type, channel, locale)
);
CREATE TABLE IF NOT EXISTS keystone.notification_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  event_type text NOT NULL,
  severity text NOT NULL DEFAULT 'info',
  entity_ref text,
  entity_id uuid,
  channel text NOT NULL,
  audience text NOT NULL,
  recipient_label text,
  address text,                  -- téléphone E.164 / email / user_id (in_app)
  user_id uuid,
  subject text,
  body text NOT NULL,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','deferred','sent','failed','suppressed')),
  status_reason text,
  scheduled_for timestamptz NOT NULL DEFAULT now(),
  attempts int NOT NULL DEFAULT 0,
  provider_ref text,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notification_outbox_due ON keystone.notification_outbox (status, scheduled_for);
CREATE INDEX IF NOT EXISTS notification_outbox_dedup ON keystone.notification_outbox (tenant_id, event_type, entity_id, channel, address, created_at);

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['notification_channels','notification_quiet_hours','notification_rules','notification_templates','notification_outbox'] LOOP
    EXECUTE format('ALTER TABLE keystone.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON keystone.%I', t);
    EXECUTE format('CREATE POLICY tenant_isolation ON keystone.%I USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', t);
    -- configuration et journal réservés à l'exploitant
    EXECUTE format('DROP POLICY IF EXISTS staff_only ON keystone.%I', t);
    EXECUTE format('CREATE POLICY staff_only ON keystone.%I AS RESTRICTIVE USING (keystone.current_lessee() IS NULL AND keystone.current_contractor() IS NULL)', t);
    EXECUTE format('GRANT SELECT ON keystone.%I TO authenticated', t);
  END LOOP;
END $$;
GRANT SELECT ON keystone.notification_events TO authenticated;
GRANT UPDATE (is_enabled, mode, provider, sender) ON keystone.notification_channels TO authenticated;
GRANT UPDATE (is_enabled) ON keystone.notification_rules TO authenticated;
GRANT UPDATE (subject, body, wa_template_name, updated_at) ON keystone.notification_templates TO authenticated;
GRANT UPDATE (start_local, end_local, applies_to) ON keystone.notification_quiet_hours TO authenticated;
ALTER TABLE keystone.notification_outbox REPLICA IDENTITY FULL;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE keystone.notification_outbox; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ===================== Moteur =====================
CREATE OR REPLACE FUNCTION keystone.render_template(p_text text, p_payload jsonb) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE k text; v text; out text := p_text;
BEGIN
  IF out IS NULL THEN RETURN NULL; END IF;
  FOR k, v IN SELECT key, value FROM jsonb_each_text(coalesce(p_payload, '{}')) LOOP
    out := replace(out, '{{' || k || '}}', coalesce(v, ''));
  END LOOP;
  RETURN regexp_replace(out, '\{\{[a-z_]+\}\}', '', 'g');   -- placeholders non fournis : retirés
END $$;

-- Prochain instant hors plage de non-dérangement (NULL si l'instant courant est déjà autorisé)
CREATE OR REPLACE FUNCTION keystone.quiet_until(p_tenant uuid, p_channel text, p_at timestamptz) RETURNS timestamptz
LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
DECLARE q notification_quiet_hours; loc timestamp; t time;
BEGIN
  SELECT * INTO q FROM notification_quiet_hours WHERE tenant_id = p_tenant;
  IF NOT FOUND OR NOT (p_channel = ANY (q.applies_to)) THEN RETURN NULL; END IF;
  loc := p_at AT TIME ZONE q.timezone;
  t := loc::time;
  IF q.start_local > q.end_local THEN               -- plage à cheval sur minuit (ex. 21:00 → 07:00)
    IF t >= q.start_local THEN RETURN ((loc::date + 1) + q.end_local) AT TIME ZONE q.timezone; END IF;
    IF t < q.end_local THEN RETURN (loc::date + q.end_local) AT TIME ZONE q.timezone; END IF;
  ELSIF t >= q.start_local AND t < q.end_local THEN
    RETURN (loc::date + q.end_local) AT TIME ZONE q.timezone;
  END IF;
  RETURN NULL;
END $$;

-- Destinataires d'une audience : (libellé, téléphone, email, user_id)
CREATE OR REPLACE FUNCTION keystone.notification_recipients(p_tenant uuid, p_audience text, p_payload jsonb)
RETURNS TABLE(label text, phone text, email text, user_id uuid)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT coalesce(le.trade_name, le.company_name), le.contact_phone, le.contact_email,
         (SELECT u.id FROM users u WHERE u.lessee_id = le.id LIMIT 1)
  FROM lessees le WHERE p_audience = 'lessee' AND le.id = (p_payload->>'lessee_id')::uuid AND le.tenant_id = p_tenant
  UNION ALL
  SELECT c.name, c.contact_phone, c.contact_email, (SELECT u.id FROM users u WHERE u.contractor_id = c.id LIMIT 1)
  FROM contractors c WHERE p_audience = 'contractor' AND c.id = (p_payload->>'contractor_id')::uuid AND c.tenant_id = p_tenant
  UNION ALL
  SELECT coalesce(u.full_name, trim(coalesce(pe.first_name, '') || ' ' || coalesce(pe.last_name, '')), u.email), pe.phone, coalesce(u.email, pe.email), u.id
  FROM users u LEFT JOIN persons pe ON pe.id = u.person_id
  WHERE p_audience = 'staff' AND u.tenant_id = p_tenant AND coalesce(u.is_active, true) AND u.lessee_id IS NULL AND u.contractor_id IS NULL
  UNION ALL
  SELECT coalesce(p_payload->>'requester_name', 'Demandeur'),
         CASE WHEN p_payload->>'requester_contact' ~ '^\+?[0-9 ]{8,}$' THEN p_payload->>'requester_contact' END,
         CASE WHEN p_payload->>'requester_contact' LIKE '%@%' THEN p_payload->>'requester_contact' END, NULL::uuid
  WHERE p_audience = 'requester' AND p_payload->>'requester_contact' IS NOT NULL;
$$;

-- Point d'entrée unique : publie un événement → lignes d'outbox
CREATE OR REPLACE FUNCTION keystone.notify_event(p_tenant uuid, p_event text, p_payload jsonb, p_severity text DEFAULT NULL)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE r record; rc record; ch notification_channels; tpl notification_templates; v_addr text; v_status text; v_reason text;
        v_when timestamptz; v_q timestamptz; n int := 0; v_sev text; v_eid uuid := nullif(p_payload->>'entity_id', '')::uuid;
BEGIN
  SELECT coalesce(p_severity, default_severity) INTO v_sev FROM notification_events WHERE event_type = p_event;
  IF v_sev IS NULL THEN RETURN 0; END IF;
  FOR r IN SELECT * FROM notification_rules WHERE tenant_id = p_tenant AND event_type = p_event AND is_enabled LOOP
    SELECT * INTO ch FROM notification_channels WHERE tenant_id = p_tenant AND channel = r.channel;
    CONTINUE WHEN NOT FOUND OR NOT ch.is_enabled;
    SELECT * INTO tpl FROM notification_templates WHERE tenant_id = p_tenant AND event_type = p_event AND channel = r.channel
      ORDER BY (locale = coalesce(p_payload->>'locale', 'fr')) DESC LIMIT 1;
    CONTINUE WHEN NOT FOUND;
    FOR rc IN SELECT * FROM keystone.notification_recipients(p_tenant, r.audience, p_payload) LOOP
      v_addr := CASE r.channel WHEN 'email' THEN rc.email WHEN 'in_app' THEN rc.user_id::text ELSE rc.phone END;
      v_status := 'queued'; v_reason := NULL; v_when := now();
      IF v_addr IS NULL THEN
        v_status := 'suppressed'; v_reason := 'Aucune coordonnée ' || r.channel || ' pour ce destinataire';
      ELSIF EXISTS (SELECT 1 FROM notification_outbox o WHERE o.tenant_id = p_tenant AND o.event_type = p_event
                      AND o.entity_id IS NOT DISTINCT FROM v_eid AND o.channel = r.channel AND o.address = v_addr
                      AND o.created_at > now() - interval '10 minutes') THEN
        v_status := 'suppressed'; v_reason := 'Doublon (< 10 min)';
      ELSIF v_sev <> 'critical' THEN
        v_q := keystone.quiet_until(p_tenant, r.channel, now());
        IF v_q IS NOT NULL THEN v_status := 'deferred'; v_reason := 'Plage de non-dérangement'; v_when := v_q; END IF;
      END IF;
      INSERT INTO notification_outbox(tenant_id, event_type, severity, entity_ref, entity_id, channel, audience, recipient_label, address, user_id,
                                      subject, body, status, status_reason, scheduled_for)
      VALUES (p_tenant, p_event, v_sev, p_payload->>'ref', v_eid, r.channel, r.audience, rc.label, v_addr, rc.user_id,
              keystone.render_template(tpl.subject, p_payload), keystone.render_template(tpl.body, p_payload), v_status, v_reason, v_when);
      n := n + 1;
    END LOOP;
  END LOOP;
  RETURN n;
END $$;

-- Envoi des messages dus : simulation en base (le mode live est traité par l'Edge Function notify-dispatch)
CREATE OR REPLACE FUNCTION keystone.notification_dispatch(p_limit int DEFAULT 200)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE o record; n_sent int := 0;
BEGIN
  FOR o IN
    SELECT ob.* FROM notification_outbox ob
    JOIN notification_channels ch ON ch.tenant_id = ob.tenant_id AND ch.channel = ob.channel
    WHERE ob.status IN ('queued','deferred') AND ob.scheduled_for <= now() AND (ch.mode = 'simulation' OR ob.channel = 'in_app')
    ORDER BY ob.scheduled_for LIMIT p_limit FOR UPDATE OF ob SKIP LOCKED
  LOOP
    IF o.channel = 'in_app' AND o.user_id IS NOT NULL THEN
      INSERT INTO notifications(tenant_id, user_id, kind, payload)
      VALUES (o.tenant_id, o.user_id, o.event_type, jsonb_build_object('title', o.subject, 'body', o.body, 'ref', o.entity_ref, 'severity', o.severity));
    END IF;
    UPDATE notification_outbox SET status = 'sent', sent_at = now(), attempts = attempts + 1,
      provider_ref = CASE WHEN channel = 'in_app' THEN 'in-app' ELSE 'SIM-' || upper(substr(md5(id::text || now()::text), 1, 8)) END
    WHERE id = o.id;
    n_sent := n_sent + 1;
  END LOOP;
  RETURN json_build_object('sent', n_sent);
END $$;

-- ===================== Branchements métier (triggers) =====================
CREATE OR REPLACE FUNCTION keystone.ticket_status_label(s text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE s WHEN 'new' THEN 'reçue' WHEN 'triaged' THEN 'prise en compte' WHEN 'assigned' THEN 'confiée à un technicien'
    WHEN 'in_progress' THEN 'en cours d''intervention' WHEN 'resolved' THEN 'résolue' WHEN 'closed' THEN 'clôturée'
    WHEN 'rejected' THEN 'non retenue' WHEN 'reopened' THEN 'réouverte' ELSE s END;
$$;

CREATE OR REPLACE FUNCTION keystone.trg_notify_ticket() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE p jsonb;
BEGIN
  p := jsonb_build_object('entity_id', NEW.id, 'ref', NEW.ref, 'category', coalesce(NEW.category, 'demande'),
         'description', left(coalesce(NEW.description, ''), 140), 'lessee_id', NEW.lessee_id,
         'requester_name', NEW.requester_name, 'requester_contact', NEW.requester_contact,
         'status_label', keystone.ticket_status_label(NEW.status::text));
  IF TG_OP = 'INSERT' THEN
    PERFORM keystone.notify_event(NEW.tenant_id, 'ticket.created', p, CASE WHEN NEW.priority = 1 THEN 'high' END);
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM keystone.notify_event(NEW.tenant_id, CASE WHEN NEW.status IN ('resolved','closed') THEN 'ticket.resolved' ELSE 'ticket.status_changed' END, p);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_ticket ON keystone.service_requests;
CREATE TRIGGER notify_ticket AFTER INSERT OR UPDATE OF status ON keystone.service_requests FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_ticket();

CREATE OR REPLACE FUNCTION keystone.trg_notify_wo() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
BEGIN
  IF NEW.priority = 1 AND NEW.type = 'corrective' AND NEW.description IS DISTINCT FROM 'seed-historique-pannes' THEN
    PERFORM keystone.notify_event(NEW.tenant_id, 'wo.critical', jsonb_build_object('entity_id', NEW.id, 'ref', NEW.ref, 'title', NEW.title,
      'asset', (SELECT tag FROM assets WHERE id = NEW.asset_id), 'contractor_id', NEW.contractor_id), 'critical');
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_wo ON keystone.work_orders;
CREATE TRIGGER notify_wo AFTER INSERT ON keystone.work_orders FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_wo();

CREATE OR REPLACE FUNCTION keystone.trg_notify_hsse() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
BEGIN
  IF coalesce(NEW.risk_score, 0) >= 9 OR NEW.type IN ('accident','env_spill') THEN
    PERFORM keystone.notify_event(NEW.tenant_id, 'hsse.incident', jsonb_build_object('entity_id', NEW.id, 'ref', NEW.ref, 'title', NEW.title,
      'location', (SELECT name FROM locations WHERE id = NEW.location_id)),
      CASE WHEN coalesce(NEW.risk_score, 0) >= 15 OR NEW.type = 'accident' THEN 'critical' ELSE 'high' END);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_hsse ON keystone.hsse_events;
CREATE TRIGGER notify_hsse AFTER INSERT ON keystone.hsse_events FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_hsse();

CREATE OR REPLACE FUNCTION keystone.trg_notify_nc() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
BEGIN
  IF NEW.severity = 'critical' THEN
    PERFORM keystone.notify_event(NEW.tenant_id, 'nc.critical', jsonb_build_object('entity_id', NEW.id, 'ref', NEW.ref, 'title', NEW.title,
      'due_date', to_char(NEW.due_date, 'DD/MM/YYYY')), 'high');
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_nc ON keystone.non_conformities;
CREATE TRIGGER notify_nc AFTER INSERT ON keystone.non_conformities FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_nc();

CREATE OR REPLACE FUNCTION keystone.trg_notify_portal() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE w work_orders;
BEGIN
  SELECT * INTO w FROM work_orders WHERE id = NEW.work_order_id;
  PERFORM keystone.notify_event(NEW.tenant_id, CASE TG_TABLE_NAME WHEN 'wo_reports' THEN 'portal.report_submitted' ELSE 'portal.quote_submitted' END,
    jsonb_build_object('entity_id', NEW.id, 'ref', w.ref, 'title', w.title, 'contractor', (SELECT name FROM contractors WHERE id = NEW.contractor_id)));
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_report ON keystone.wo_reports;
CREATE TRIGGER notify_report AFTER INSERT ON keystone.wo_reports FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_portal();
DROP TRIGGER IF EXISTS notify_quote ON keystone.wo_quotes;
CREATE TRIGGER notify_quote AFTER INSERT ON keystone.wo_quotes FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_portal();

CREATE OR REPLACE FUNCTION keystone.trg_notify_rent() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE l leases;
BEGIN
  SELECT * INTO l FROM leases WHERE id = NEW.lease_id;
  IF TG_TABLE_NAME = 'rent_schedules' THEN
    IF NEW.reminders_sent > OLD.reminders_sent THEN
      PERFORM keystone.notify_event(NEW.tenant_id, 'rent.reminder', jsonb_build_object('entity_id', NEW.id, 'ref', l.ref, 'lessee_id', NEW.lessee_id,
        'lessee', (SELECT coalesce(trade_name, company_name) FROM lessees WHERE id = NEW.lessee_id),
        'amount', to_char(NEW.total_due - NEW.paid_amount, 'FM999G999G999G990') || ' FCFA',
        'period', to_char(NEW.period_start, 'MM/YYYY'), 'due_date', to_char(NEW.due_date, 'DD/MM/YYYY'),
        'reminder_no', NEW.reminders_sent::text), CASE WHEN NEW.reminders_sent >= 3 THEN 'high' ELSE 'warning' END);
    END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_rent ON keystone.rent_schedules;
CREATE TRIGGER notify_rent AFTER UPDATE OF reminders_sent ON keystone.rent_schedules FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_rent();

CREATE OR REPLACE FUNCTION keystone.trg_notify_payment() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE s rent_schedules;
BEGIN
  SELECT * INTO s FROM rent_schedules WHERE id = NEW.schedule_id;
  PERFORM keystone.notify_event(NEW.tenant_id, 'rent.payment_received', jsonb_build_object('entity_id', NEW.id, 'lessee_id', NEW.lessee_id,
    'ref', (SELECT ref FROM leases WHERE id = s.lease_id),
    'lessee', (SELECT coalesce(trade_name, company_name) FROM lessees WHERE id = NEW.lessee_id),
    'amount', to_char(NEW.amount, 'FM999G999G999G990') || ' FCFA', 'period', to_char(s.period_start, 'MM/YYYY'),
    'payment_ref', coalesce(NEW.provider_ref, '')));
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_payment ON keystone.rent_payments;
CREATE TRIGGER notify_payment AFTER INSERT ON keystone.rent_payments FOR EACH ROW EXECUTE FUNCTION keystone.trg_notify_payment();

-- ===================== Lecture / pilotage =====================
CREATE OR REPLACE FUNCTION keystone.notification_journal(p_limit int DEFAULT 80)
RETURNS TABLE(id uuid, event_type text, event_label text, severity text, entity_ref text, channel text, audience text, recipient_label text,
  address text, subject text, body text, status text, status_reason text, scheduled_for timestamptz, sent_at timestamptz, provider_ref text, created_at timestamptz)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT o.id, o.event_type, e.label, o.severity, o.entity_ref, o.channel, o.audience, o.recipient_label,
    CASE WHEN o.channel = 'in_app' THEN 'notification in-app' ELSE o.address END,
    o.subject, o.body, o.status, o.status_reason, o.scheduled_for, o.sent_at, o.provider_ref, o.created_at
  FROM notification_outbox o LEFT JOIN notification_events e ON e.event_type = o.event_type
  ORDER BY o.created_at DESC LIMIT p_limit;
$$;

CREATE OR REPLACE FUNCTION keystone.notification_stats()
RETURNS json LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object(
    'sent_24h', (SELECT count(*) FROM notification_outbox WHERE status = 'sent' AND sent_at > now() - interval '24 hours'),
    'queued', (SELECT count(*) FROM notification_outbox WHERE status = 'queued'),
    'deferred', (SELECT count(*) FROM notification_outbox WHERE status = 'deferred'),
    'suppressed_24h', (SELECT count(*) FROM notification_outbox WHERE status = 'suppressed' AND created_at > now() - interval '24 hours'),
    'failed_24h', (SELECT count(*) FROM notification_outbox WHERE status = 'failed' AND created_at > now() - interval '24 hours'),
    'by_channel', (SELECT json_object_agg(channel, c) FROM (SELECT channel, count(*) c FROM notification_outbox WHERE created_at > now() - interval '7 days' GROUP BY channel) x),
    'live_channels', (SELECT count(*) FROM notification_channels WHERE mode = 'live' AND is_enabled AND channel <> 'in_app')
  );
$$;

CREATE OR REPLACE FUNCTION keystone.notification_matrix()
RETURNS TABLE(rule_id uuid, event_type text, label text, domain text, default_severity text, channel text, audience text, is_enabled boolean, has_template boolean)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT r.id, e.event_type, e.label, e.domain, e.default_severity, r.channel, r.audience, r.is_enabled,
    EXISTS (SELECT 1 FROM notification_templates t WHERE t.tenant_id = r.tenant_id AND t.event_type = r.event_type AND t.channel = r.channel)
  FROM notification_rules r JOIN notification_events e ON e.event_type = r.event_type
  ORDER BY e.domain, e.label, r.audience, r.channel;
$$;

-- Envoi d'un message de test vers l'utilisateur connecté (vérifie la chaîne de bout en bout)
CREATE OR REPLACE FUNCTION keystone.notification_test(p_channel text)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE u users; pe persons; v_addr text; v_id uuid;
BEGIN
  IF keystone.current_lessee() IS NOT NULL OR keystone.current_contractor() IS NOT NULL THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  SELECT * INTO u FROM users WHERE id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  SELECT * INTO pe FROM persons WHERE id = u.person_id;
  v_addr := CASE p_channel WHEN 'email' THEN coalesce(u.email, pe.email) WHEN 'in_app' THEN u.id::text ELSE pe.phone END;
  INSERT INTO notification_outbox(tenant_id, event_type, severity, channel, audience, recipient_label, address, user_id, subject, body, status, status_reason)
  VALUES (u.tenant_id, 'system.test', 'info', p_channel, 'staff', coalesce(u.full_name, u.email), v_addr, u.id,
          'Test Atlas Keystone', 'Message de test du canal ' || p_channel || ' — si vous le lisez, la chaîne de notification fonctionne.',
          CASE WHEN v_addr IS NULL THEN 'suppressed' ELSE 'queued' END,
          CASE WHEN v_addr IS NULL THEN 'Aucune coordonnée ' || p_channel || ' sur votre fiche' END)
  RETURNING id INTO v_id;
  PERFORM keystone.notification_dispatch(50);
  RETURN (SELECT json_build_object('status', status, 'provider_ref', provider_ref, 'reason', status_reason) FROM notification_outbox WHERE id = v_id);
END $$;

GRANT EXECUTE ON FUNCTION keystone.render_template(text, jsonb), keystone.notification_journal(int), keystone.notification_stats(),
  keystone.notification_matrix(), keystone.notification_test(text), keystone.ticket_status_label(text) TO authenticated;
-- moteur et dispatch : SECURITY DEFINER multi-tenant ⇒ jamais appelables directement depuis l'API
REVOKE EXECUTE ON FUNCTION keystone.notify_event(uuid, text, jsonb, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION keystone.notification_dispatch(int) FROM PUBLIC, anon, authenticated;

-- Cloche in-app : flux personnel temps réel + marquage lu
ALTER TABLE keystone.notifications REPLICA IDENTITY FULL;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE keystone.notifications; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
CREATE OR REPLACE FUNCTION keystone.my_notifications(p_limit int DEFAULT 20)
RETURNS TABLE(id uuid, kind text, title text, body text, ref text, severity text, created_at timestamptz, read_at timestamptz)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT n.id, n.kind, coalesce(n.payload->>'title', n.kind), n.payload->>'body', n.payload->>'ref', coalesce(n.payload->>'severity', 'info'), n.created_at, n.read_at
  FROM notifications n WHERE n.user_id = auth.uid() ORDER BY n.created_at DESC LIMIT p_limit;
$$;
CREATE OR REPLACE FUNCTION keystone.my_notifications_read() RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'keystone','public' AS $$
DECLARE n int;
BEGIN
  UPDATE notifications SET read_at = now() WHERE user_id = auth.uid() AND read_at IS NULL;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $$;
GRANT EXECUTE ON FUNCTION keystone.my_notifications(int), keystone.my_notifications_read() TO authenticated;

-- Envoi automatique toutes les 2 minutes (messages dus, y compris différés après la plage de non-dérangement)
DO $$ BEGIN
  PERFORM cron.unschedule('keystone-notify-dispatch');
EXCEPTION WHEN OTHERS THEN NULL; END $$;
SELECT cron.schedule('keystone-notify-dispatch', '*/2 * * * *', $c$SELECT keystone.notification_dispatch(500)$c$);

COMMIT;

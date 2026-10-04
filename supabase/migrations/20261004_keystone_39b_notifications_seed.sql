-- Seed notifications : catalogue d'événements, canaux (simulation), non-dérangement, règles et modèles FR/EN. Idempotent.
BEGIN;
INSERT INTO keystone.notification_events(event_type, label, domain, default_severity, placeholders) VALUES
  ('ticket.created', 'Nouvelle demande', 'Helpdesk', 'info', ARRAY['ref','category','description','status_label']),
  ('ticket.status_changed', 'Évolution d''une demande', 'Helpdesk', 'info', ARRAY['ref','category','status_label']),
  ('ticket.resolved', 'Demande résolue', 'Helpdesk', 'info', ARRAY['ref','category']),
  ('wo.critical', 'OT critique (P1)', 'GMAO', 'critical', ARRAY['ref','title','asset']),
  ('hsse.incident', 'Incident HSSE à risque', 'HSSE', 'high', ARRAY['ref','title','location']),
  ('nc.critical', 'Non-conformité critique', 'Qualité', 'high', ARRAY['ref','title','due_date']),
  ('portal.quote_submitted', 'Devis prestataire reçu', 'Prestataires', 'info', ARRAY['ref','title','contractor']),
  ('portal.report_submitted', 'Rapport d''intervention à signer', 'Prestataires', 'info', ARRAY['ref','title','contractor']),
  ('rent.reminder', 'Relance de loyer impayé', 'Gestion locative', 'warning', ARRAY['ref','lessee','amount','period','due_date','reminder_no']),
  ('rent.payment_received', 'Accusé de paiement de loyer', 'Gestion locative', 'info', ARRAY['ref','lessee','amount','period','payment_ref']),
  ('system.test', 'Message de test', 'Système', 'info', ARRAY[]::text[])
ON CONFLICT (event_type) DO UPDATE SET label = EXCLUDED.label, domain = EXCLUDED.domain, default_severity = EXCLUDED.default_severity, placeholders = EXCLUDED.placeholders;

DO $$
DECLARE t uuid := 'a0000000-0000-4000-8000-000000000001'; u record;
BEGIN
  PERFORM set_config('keystone.tenant_id', t::text, true);

  INSERT INTO keystone.notification_channels(tenant_id, channel, is_enabled, mode, provider, sender) VALUES
    (t, 'whatsapp', true, 'simulation', 'whatsapp_cloud', '+225 27 23 00 00 10'),
    (t, 'sms', true, 'simulation', 'orange_sms', 'COSMOS'),
    (t, 'email', true, 'simulation', 'resend', 'notifications@cosmos-yopougon.demo'),
    (t, 'in_app', true, 'live', 'internal', NULL)
  ON CONFLICT (tenant_id, channel) DO NOTHING;
  INSERT INTO keystone.notification_quiet_hours(tenant_id) VALUES (t) ON CONFLICT DO NOTHING;

  INSERT INTO keystone.notification_rules(tenant_id, event_type, channel, audience, is_enabled)
  SELECT t, v.e, v.c, v.a, v.enabled FROM (VALUES
    ('ticket.created', 'whatsapp', 'lessee', true), ('ticket.created', 'email', 'lessee', true), ('ticket.created', 'in_app', 'staff', true),
    ('ticket.status_changed', 'whatsapp', 'lessee', true),
    ('ticket.resolved', 'whatsapp', 'lessee', true), ('ticket.resolved', 'email', 'lessee', true), ('ticket.resolved', 'sms', 'requester', true),
    ('wo.critical', 'sms', 'staff', true), ('wo.critical', 'whatsapp', 'staff', true), ('wo.critical', 'in_app', 'staff', true), ('wo.critical', 'whatsapp', 'contractor', true),
    ('hsse.incident', 'sms', 'staff', true), ('hsse.incident', 'in_app', 'staff', true), ('hsse.incident', 'email', 'staff', true),
    ('nc.critical', 'in_app', 'staff', true), ('nc.critical', 'email', 'staff', true),
    ('portal.quote_submitted', 'in_app', 'staff', true),
    ('portal.report_submitted', 'in_app', 'staff', true), ('portal.report_submitted', 'email', 'staff', true),
    ('rent.reminder', 'whatsapp', 'lessee', true), ('rent.reminder', 'email', 'lessee', true), ('rent.reminder', 'sms', 'lessee', false),
    ('rent.payment_received', 'whatsapp', 'lessee', true), ('rent.payment_received', 'email', 'lessee', true)
  ) v(e, c, a, enabled)
  ON CONFLICT (tenant_id, event_type, channel, audience) DO NOTHING;

  INSERT INTO keystone.notification_templates(tenant_id, event_type, channel, locale, subject, body, wa_template_name)
  SELECT t, v.e, v.c, v.l, v.s, v.b, v.w FROM (VALUES
    ('ticket.created', 'whatsapp', 'fr', NULL, 'Bonjour, votre demande {{ref}} ({{category}}) est bien reçue par l''équipe technique du centre. Vous serez informé à chaque étape.', 'ks_ticket_received_fr'),
    ('ticket.created', 'whatsapp', 'en', NULL, 'Hello, your request {{ref}} ({{category}}) has been received by the centre''s technical team. We will keep you posted.', 'ks_ticket_received_en'),
    ('ticket.created', 'email', 'fr', 'Demande {{ref}} reçue', E'Bonjour,\n\nNous avons bien reçu votre demande {{ref}} ({{category}}) :\n« {{description}} »\n\nVous pouvez suivre son avancement depuis votre espace locataire.\n\nL''équipe de gestion', NULL),
    ('ticket.created', 'in_app', 'fr', 'Nouvelle demande {{ref}}', '{{category}} — {{description}}', NULL),
    ('ticket.status_changed', 'whatsapp', 'fr', NULL, 'Votre demande {{ref}} est maintenant {{status_label}}.', 'ks_ticket_update_fr'),
    ('ticket.resolved', 'whatsapp', 'fr', NULL, 'Bonne nouvelle : votre demande {{ref}} est résolue. Donnez-nous votre avis en 1 clic depuis votre espace locataire ⭐', 'ks_ticket_resolved_fr'),
    ('ticket.resolved', 'whatsapp', 'en', NULL, 'Good news: your request {{ref}} has been resolved. Rate us in one tap from your tenant space ⭐', 'ks_ticket_resolved_en'),
    ('ticket.resolved', 'email', 'fr', 'Demande {{ref}} résolue', E'Bonjour,\n\nVotre demande {{ref}} ({{category}}) est résolue.\nVotre avis nous aide à progresser : notez l''intervention depuis votre espace locataire.\n\nL''équipe de gestion', NULL),
    ('ticket.resolved', 'sms', 'fr', NULL, 'COSMOS : votre signalement {{ref}} est résolu. Merci de nous avoir alertés.', NULL),
    ('wo.critical', 'sms', 'fr', NULL, 'URGENT P1 {{ref}} : {{title}} ({{asset}}). Intervention immédiate requise.', NULL),
    ('wo.critical', 'whatsapp', 'fr', NULL, '🔴 OT critique {{ref}} — {{title}} · équipement {{asset}}. Merci d''accuser réception et d''intervenir immédiatement.', 'ks_wo_critical_fr'),
    ('wo.critical', 'in_app', 'fr', 'OT critique {{ref}}', '{{title}} · {{asset}}', NULL),
    ('hsse.incident', 'sms', 'fr', NULL, 'HSSE {{ref}} : {{title}} — {{location}}. Consultez Keystone.', NULL),
    ('hsse.incident', 'in_app', 'fr', 'Incident HSSE {{ref}}', '{{title}} — {{location}}', NULL),
    ('hsse.incident', 'email', 'fr', '[HSSE] Incident {{ref}} à risque', E'Un événement HSSE à risque vient d''être déclaré :\n{{title}} — {{location}}\n\nOuvrez Keystone pour l''analyse et les actions immédiates.', NULL),
    ('nc.critical', 'in_app', 'fr', 'NC critique {{ref}}', '{{title}} — échéance {{due_date}}', NULL),
    ('nc.critical', 'email', 'fr', '[Qualité] Non-conformité critique {{ref}}', E'Une non-conformité critique a été ouverte : {{title}}.\nÉchéance de traitement : {{due_date}}.', NULL),
    ('portal.quote_submitted', 'in_app', 'fr', 'Devis reçu · {{ref}}', '{{contractor}} — {{title}}', NULL),
    ('portal.report_submitted', 'in_app', 'fr', 'Rapport à signer · {{ref}}', '{{contractor}} — {{title}}', NULL),
    ('portal.report_submitted', 'email', 'fr', 'Rapport d''intervention à signer — {{ref}}', E'{{contractor}} a transmis son rapport pour {{ref}} ({{title}}).\nMerci de le valider et de le signer depuis l''onglet Portail des prestataires.', NULL),
    ('rent.reminder', 'whatsapp', 'fr', NULL, 'Bonjour {{lessee}}, sauf erreur de notre part, l''échéance {{period}} du bail {{ref}} ({{amount}}, due le {{due_date}}) reste impayée. Merci de régulariser ou de nous contacter. (Relance n°{{reminder_no}})', 'ks_rent_reminder_fr'),
    ('rent.reminder', 'whatsapp', 'en', NULL, 'Hello {{lessee}}, the {{period}} instalment of lease {{ref}} ({{amount}}, due {{due_date}}) is still unpaid. Please settle it or contact us. (Reminder #{{reminder_no}})', 'ks_rent_reminder_en'),
    ('rent.reminder', 'email', 'fr', 'Relance n°{{reminder_no}} — échéance {{period}} impayée', E'Madame, Monsieur,\n\nSauf erreur de notre part, l''échéance {{period}} du bail {{ref}}, d''un montant de {{amount}}, exigible le {{due_date}}, n''a pas été réglée.\nNous vous remercions de bien vouloir régulariser cette situation dans les meilleurs délais ou de prendre contact avec la gestion.\n\nSi le règlement a été effectué entre-temps, merci de ne pas tenir compte de ce message.\n\nLa gestion locative', NULL),
    ('rent.reminder', 'sms', 'fr', NULL, 'COSMOS : échéance {{period}} bail {{ref}} impayée ({{amount}}). Merci de régulariser.', NULL),
    ('rent.payment_received', 'whatsapp', 'fr', NULL, 'Merci {{lessee}} : nous avons bien reçu {{amount}} pour l''échéance {{period}} du bail {{ref}}. Votre quittance est disponible dans votre espace locataire.', 'ks_rent_paid_fr'),
    ('rent.payment_received', 'email', 'fr', 'Paiement reçu — échéance {{period}}', E'Bonjour,\n\nNous accusons réception de votre règlement de {{amount}} pour l''échéance {{period}} du bail {{ref}}.\nRéférence : {{payment_ref}}\nLa quittance est téléchargeable depuis votre espace locataire une fois l''échéance soldée.\n\nLa gestion locative', NULL)
  ) v(e, c, l, s, b, w)
  ON CONFLICT (tenant_id, event_type, channel, locale) DO NOTHING;

  -- Coordonnées démo (fictives) pour que les canaux SMS / WhatsApp aient des destinataires
  UPDATE keystone.persons SET phone = '+225 07 00 00 01 0' || (row_number)::text, email = lower(first_name) || '.' || lower(replace(last_name, 'é', 'e')) || '@cosmos-yopougon.demo'
  FROM (SELECT id AS pid, row_number() OVER (ORDER BY last_name) FROM keystone.persons WHERE tenant_id = t) x
  WHERE keystone.persons.id = x.pid AND keystone.persons.phone IS NULL;
  UPDATE keystone.users SET person_id = (SELECT id FROM keystone.persons WHERE tenant_id = t AND first_name = 'Awa' LIMIT 1)
  WHERE tenant_id = t AND email = 'admin@keystone.demo' AND person_id IS NULL;
  UPDATE keystone.contractors SET contact_phone = '+225 07 00 00 02 ' || lpad((abs(hashtext(name)) % 100)::text, 2, '0'),
         contact_email = 'contact@' || lower(regexp_replace(name, '[^A-Za-z]', '', 'g')) || '.demo'
  WHERE tenant_id = t AND contact_phone IS NULL;
END $$;
COMMIT;

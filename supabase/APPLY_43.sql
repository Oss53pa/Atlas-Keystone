-- Atlas Keystone · migration 43 (recherche globale ⌘K, double authentification, données personnelles, export SYSCOHADA) + seed
-- À coller en une fois dans le SQL Editor (projet vgtmljfayiysuvrcmunt).

-- ==================== 20261005_keystone_43_search_mfa_privacy_accounting.sql ====================
-- keystone_43_search_mfa_privacy_accounting — Recherche globale, double authentification, données personnelles, export comptable
-- A. Recherche plein texte (palette ⌘K) : OT, équipements, tickets, HSSE, NC, permis, prestataires, preneurs, baux, DA/BC,
--    factures fournisseurs, pièces, lots, compteurs — insensible aux accents, tolérante aux fautes (pg_trgm), sous RLS.
-- B. Double authentification (TOTP Supabase Auth) : option client « exiger la 2FA pour les actions financières » ;
--    contrôlée EN BASE par déclencheurs (bon à payer, paiement fournisseur, encaissement de loyer, refacturation,
--    changement de RIB ou de seuils d'approbation) — aal2 du JWT exigé ; le SQL d'administration (sans JWT) n'est pas concerné.
-- C. Données personnelles (CI : loi n° 2013-450 / ARTCI ; SN : loi 2008-12 / CDP…) : registre des demandes des personnes,
--    recherche d'une personne dans toutes les tables, export de ses données (droit d'accès / portabilité), anonymisation
--    des champs de contact (droit à l'effacement) en conservant les pièces soumises à obligation légale de conservation.
-- D. Export comptable SYSCOHADA révisé : écritures journal Achats (AC), Ventes/loyers (VT), Banque (BQ) avec comptes
--    auxiliaires tiers ; plan de comptes paramétrable par client (valeurs par défaut INDICATIVES, à valider par l'expert-comptable).
BEGIN;
SET LOCAL search_path = keystone, public, extensions;

-- ======================================================================
-- A. Recherche globale
-- ======================================================================
CREATE OR REPLACE FUNCTION keystone.fold(p text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT lower(translate(coalesce(p, ''), 'àâäáãéèêëíìîïóòôöõúùûüçñÀÂÄÁÃÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÇÑ’', 'aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn'''));
$$;

CREATE OR REPLACE FUNCTION keystone.global_search(p_q text, p_limit int DEFAULT 24)
RETURNS TABLE(kind text, id uuid, ref text, title text, subtitle text, module text, score real)
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO 'keystone','public','extensions' AS $$
DECLARE t text := keystone.fold(btrim(p_q));
BEGIN
  -- recherche réservée à l'exploitant (les portails locataire / prestataire ont leurs propres écrans)
  IF length(t) < 2 OR keystone.current_lessee() IS NOT NULL OR keystone.current_contractor() IS NOT NULL THEN RETURN; END IF;
  RETURN QUERY
  WITH src AS (
    SELECT 'wo'::text AS k, w.id AS i, w.ref AS r, w.title AS ti, w.status::text || coalesce(' · ' || a.name, '') AS st, 'work-orders'::text AS mo,
           w.ref || ' ' || w.title || ' ' || coalesce(w.description, '') || ' ' || coalesce(a.name, '') || ' ' || coalesce(a.tag, '') AS hay
      FROM work_orders w LEFT JOIN assets a ON a.id = w.asset_id WHERE w.deleted_at IS NULL
    UNION ALL SELECT 'asset', a.id, a.tag, a.name, concat_ws(' · ', a.manufacturer, a.model, a.serial_number), 'assets',
           concat_ws(' ', a.tag, a.name, a.manufacturer, a.model, a.serial_number) FROM assets a WHERE a.deleted_at IS NULL
    UNION ALL SELECT 'ticket', s.id, s.ref, coalesce(s.category, 'Demande') || ' — ' || left(coalesce(s.description, ''), 70), concat_ws(' · ', s.status::text, s.requester_name), 'tickets',
           concat_ws(' ', s.ref, s.category, s.description, s.requester_name) FROM service_requests s WHERE s.deleted_at IS NULL
    UNION ALL SELECT 'hsse', h.id, h.ref, h.title, h.type::text || ' · ' || h.status::text, 'hsse', concat_ws(' ', h.ref, h.title, h.description)
      FROM hsse_events h WHERE h.deleted_at IS NULL
    UNION ALL SELECT 'nc', n.id, n.ref, n.title, n.severity || ' · ' || n.status, 'inspections', concat_ws(' ', n.ref, n.title, n.root_cause) FROM non_conformities n
    UNION ALL SELECT 'permit', p.id, p.ref, 'Permis ' || p.type::text, p.status::text, 'permits', concat_ws(' ', p.ref, p.type::text) FROM work_permits p WHERE p.deleted_at IS NULL
    UNION ALL SELECT 'contractor', c.id, NULL, c.name, concat_ws(' · ', CASE WHEN c.is_supplier THEN 'fournisseur' ELSE 'prestataire' END, c.contact_email), 'contractors',
           concat_ws(' ', c.name, c.contact_email, c.contact_phone) FROM contractors c
    UNION ALL SELECT 'lessee', l.id, NULL, coalesce(l.trade_name, l.company_name), concat_ws(' · ', l.company_name, l.sector), 'leases',
           concat_ws(' ', l.company_name, l.trade_name, l.sector, l.rccm) FROM lessees l
    UNION ALL SELECT 'lease', b.id, b.ref, 'Bail ' || coalesce(le.trade_name, le.company_name), b.status || ' · ' || to_char(b.monthly_rent, 'FM999G999G999') || ' FCFA/mois', 'leases',
           concat_ws(' ', b.ref, le.trade_name, le.company_name) FROM leases b JOIN lessees le ON le.id = b.lessee_id
    UNION ALL SELECT 'pr', r.id, r.ref, r.title, 'Demande d''achat · ' || r.status::text, 'procurement', concat_ws(' ', r.ref, r.title, r.justification) FROM purchase_requests r
    UNION ALL SELECT 'po', o.id, o.ref, 'Bon de commande ' || coalesce(c.name, ''), o.status::text || ' · ' || to_char(o.amount_ht, 'FM999G999G999') || ' FCFA HT', 'procurement',
           concat_ws(' ', o.ref, c.name) FROM purchase_orders o LEFT JOIN contractors c ON c.id = o.supplier_id
    UNION ALL SELECT 'invoice', i.id, i.supplier_ref, 'Facture ' || coalesce(c.name, ''), i.ref || ' · ' || i.status, 'procurement',
           concat_ws(' ', i.ref, i.supplier_ref, c.name) FROM supplier_invoices i LEFT JOIN contractors c ON c.id = i.supplier_id
    UNION ALL SELECT 'part', sp.id, sp.ref, sp.name, 'Stock ' || trim_scale(sp.qty)::text || coalesce(' ' || sp.unit, ''), 'procurement',
           concat_ws(' ', sp.ref, sp.name, sp.category) FROM spare_parts sp WHERE sp.deleted_at IS NULL
    UNION ALL SELECT 'space', su.id, su.code, su.name, coalesce(trim_scale(su.surface_m2)::text || ' m²', ''), 'spaces', concat_ws(' ', su.code, su.name)
      FROM space_units su WHERE su.deleted_at IS NULL
    UNION ALL SELECT 'meter', m.id, m.code, m.name, CASE m.carrier WHEN 'electricity' THEN 'Compteur électricité' ELSE 'Compteur eau' END, 'utilities',
           concat_ws(' ', m.code, m.name, m.usage, m.provider_contract) FROM utility_meters m
  ), scored AS (
    SELECT s.*, keystone.fold(s.hay) AS fh, keystone.fold(s.r) AS fr FROM src s
  )
  SELECT sc.k, sc.i, sc.r, sc.ti, sc.st, sc.mo,
    (CASE WHEN sc.fr = t THEN 3 WHEN sc.fr LIKE t || '%' THEN 2 WHEN sc.fh LIKE '%' || t || '%' THEN 1 ELSE 0 END
      + word_similarity(t, sc.fh))::real
  FROM scored sc
  WHERE sc.fh LIKE '%' || t || '%' OR (length(t) >= 4 AND t <% sc.fh)
  ORDER BY 7 DESC, sc.r NULLS LAST
  LIMIT greatest(1, least(p_limit, 50));
END $$;

-- ======================================================================
-- B. Double authentification exigée pour les actions financières
-- ======================================================================
ALTER TABLE keystone.company_profile ADD COLUMN IF NOT EXISTS mfa_required_for_finance boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION keystone.session_aal() RETURNS text
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT coalesce(auth.jwt()->>'aal', 'aal1');
$$;

-- Lève MFA_REQUIRED si l'option client est active et que la session n'est pas aal2. p_force : exigé même option désactivée.
CREATE OR REPLACE FUNCTION keystone.require_strong_auth(p_action text, p_force boolean DEFAULT false) RETURNS void
LANGUAGE plpgsql STABLE SET search_path TO 'keystone','public' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;           -- administration SQL / tâches planifiées
  IF (p_force OR coalesce((SELECT mfa_required_for_finance FROM keystone.company_profile LIMIT 1), false))
     AND keystone.session_aal() <> 'aal2' THEN
    RAISE EXCEPTION 'MFA_REQUIRED' USING DETAIL = format('%s : confirmez votre identité par double authentification (Paramètres › Sécurité).', p_action);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION keystone.trg_strong_auth() RETURNS trigger
LANGUAGE plpgsql SET search_path TO 'keystone','public' AS $$
BEGIN
  IF TG_TABLE_NAME = 'supplier_invoices' THEN
    IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status IN ('approved','paid') THEN
      PERFORM keystone.require_strong_auth(CASE NEW.status WHEN 'paid' THEN 'Paiement fournisseur' ELSE 'Bon à payer' END);
    END IF;
  ELSIF TG_TABLE_NAME = 'rent_payments' THEN
    PERFORM keystone.require_strong_auth('Encaissement de loyer');
  ELSIF TG_TABLE_NAME = 'utility_rebills' THEN
    PERFORM keystone.require_strong_auth('Refacturation aux preneurs');
  ELSIF TG_TABLE_NAME = 'approval_thresholds' THEN
    PERFORM keystone.require_strong_auth('Modification des seuils d''approbation');
  ELSIF TG_TABLE_NAME = 'company_profile' THEN
    -- activer OU désactiver l'exigence : toujours en session forte (évite de s'enfermer dehors et empêche un contournement)
    IF NEW.mfa_required_for_finance IS DISTINCT FROM OLD.mfa_required_for_finance THEN
      PERFORM keystone.require_strong_auth('Changement de la politique de double authentification', true);
    ELSIF OLD.mfa_required_for_finance AND NEW.bank_account IS DISTINCT FROM OLD.bank_account THEN
      PERFORM keystone.require_strong_auth('Modification du RIB de la société', true);
    END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS strong_auth ON keystone.supplier_invoices;
CREATE TRIGGER strong_auth BEFORE UPDATE OF status ON keystone.supplier_invoices FOR EACH ROW EXECUTE FUNCTION keystone.trg_strong_auth();
DROP TRIGGER IF EXISTS strong_auth ON keystone.rent_payments;
CREATE TRIGGER strong_auth BEFORE INSERT ON keystone.rent_payments FOR EACH ROW EXECUTE FUNCTION keystone.trg_strong_auth();
DROP TRIGGER IF EXISTS strong_auth ON keystone.utility_rebills;
CREATE TRIGGER strong_auth BEFORE INSERT ON keystone.utility_rebills FOR EACH ROW EXECUTE FUNCTION keystone.trg_strong_auth();
DROP TRIGGER IF EXISTS strong_auth ON keystone.approval_thresholds;
CREATE TRIGGER strong_auth BEFORE UPDATE ON keystone.approval_thresholds FOR EACH ROW EXECUTE FUNCTION keystone.trg_strong_auth();
DROP TRIGGER IF EXISTS strong_auth ON keystone.company_profile;
CREATE TRIGGER strong_auth BEFORE UPDATE ON keystone.company_profile FOR EACH ROW EXECUTE FUNCTION keystone.trg_strong_auth();

-- ======================================================================
-- C. Données personnelles
-- ======================================================================
CREATE TABLE IF NOT EXISTS keystone.privacy_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  ref text NOT NULL,
  subject_kind text NOT NULL CHECK (subject_kind IN ('person','user','lessee_contact','requester','contractor_contact')),
  subject_id uuid,
  subject_key text,                                  -- contact (téléphone / email) pour un demandeur sans fiche
  subject_label text NOT NULL,
  request_type text NOT NULL CHECK (request_type IN ('access','rectification','erasure','opposition','portability')),
  channel text NOT NULL DEFAULT 'email',
  received_at date NOT NULL DEFAULT current_date,
  due_date date NOT NULL DEFAULT current_date + 30,  -- délai de réponse retenu par le client (paramétrable à la saisie)
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','rejected')),
  outcome text,
  handled_by uuid, handled_at timestamptz,
  created_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE keystone.privacy_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON keystone.privacy_requests;
CREATE POLICY tenant_isolation ON keystone.privacy_requests USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant());
DROP POLICY IF EXISTS staff_only ON keystone.privacy_requests;
CREATE POLICY staff_only ON keystone.privacy_requests AS RESTRICTIVE USING (keystone.current_lessee() IS NULL AND keystone.current_contractor() IS NULL);
GRANT SELECT, INSERT, UPDATE ON keystone.privacy_requests TO authenticated;

-- Personnes identifiables présentes dans la base (fiches, comptes, contacts preneurs/prestataires, demandeurs de tickets)
CREATE OR REPLACE FUNCTION keystone.personal_data_subjects(p_q text)
RETURNS TABLE(kind text, id uuid, key text, label text, detail text, records int)
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE t text := keystone.fold(btrim(p_q));
BEGIN
  PERFORM keystone.staff_guard();
  IF length(t) < 2 THEN RETURN; END IF;
  RETURN QUERY
  SELECT * FROM (
    SELECT 'person'::text, p.id, NULL::text, btrim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), concat_ws(' · ', p.type::text, p.email, p.phone),
      ((SELECT count(*) FROM work_orders w WHERE w.assignee_id = p.id) + 1)::int
    FROM persons p WHERE p.deleted_at IS NULL AND keystone.fold(concat_ws(' ', p.first_name, p.last_name, p.email, p.phone)) LIKE '%' || t || '%'
    UNION ALL
    SELECT 'user', u.id, NULL, coalesce(u.full_name, u.email), concat_ws(' · ', 'compte ' || u.kind, u.email), 1
    FROM users u WHERE keystone.fold(concat_ws(' ', u.full_name, u.email)) LIKE '%' || t || '%'
    UNION ALL
    SELECT 'lessee_contact', l.id, NULL, l.contact_name, concat_ws(' · ', 'contact preneur ' || coalesce(l.trade_name, l.company_name), l.contact_email, l.contact_phone), 1
    FROM lessees l WHERE l.contact_name IS NOT NULL AND keystone.fold(concat_ws(' ', l.contact_name, l.contact_email, l.contact_phone)) LIKE '%' || t || '%'
    UNION ALL
    SELECT 'contractor_contact', c.id, NULL, c.name, concat_ws(' · ', 'contact prestataire', c.contact_email, c.contact_phone), 1
    FROM contractors c WHERE (c.contact_email IS NOT NULL OR c.contact_phone IS NOT NULL)
      AND keystone.fold(concat_ws(' ', c.contact_email, c.contact_phone)) LIKE '%' || t || '%'
    UNION ALL
    SELECT 'requester', NULL, s.requester_contact, max(s.requester_name), 'demandeur · ' || s.requester_contact, count(*)::int
    FROM service_requests s WHERE s.requester_contact IS NOT NULL
      AND keystone.fold(concat_ws(' ', s.requester_name, s.requester_contact)) LIKE '%' || t || '%'
    GROUP BY s.requester_contact
  ) x LIMIT 40;
END $$;

-- Export des données d'une personne (droit d'accès / portabilité) — JSON lisible par machine
CREATE OR REPLACE FUNCTION keystone.personal_data_export(p_kind text, p_id uuid DEFAULT NULL, p_key text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE v json;
BEGIN
  PERFORM keystone.staff_guard();
  IF p_kind = 'person' THEN
    SELECT json_build_object(
      'fiche', (SELECT to_jsonb(p) - 'tenant_id' FROM persons p WHERE p.id = p_id),
      'compte', (SELECT to_jsonb(u) - 'tenant_id' FROM users u WHERE u.person_id = p_id LIMIT 1),
      'ordres_de_travail', (SELECT json_agg(json_build_object('ref', w.ref, 'titre', w.title, 'statut', w.status, 'debut', w.actual_start, 'fin', w.actual_end) ORDER BY w.created_at)
                            FROM work_orders w WHERE w.assignee_id = p_id),
      'pointages', (SELECT json_agg(to_jsonb(te) - 'tenant_id' ORDER BY te.at) FROM wo_time_entries te WHERE te.person_id = p_id),
      'notifications', (SELECT json_agg(json_build_object('canal', o.channel, 'evenement', o.event_type, 'adresse', o.address, 'date', o.created_at) ORDER BY o.created_at)
                        FROM notification_outbox o WHERE o.address IN (SELECT x FROM persons pp, LATERAL (VALUES (pp.phone), (pp.email)) v(x) WHERE pp.id = p_id AND x IS NOT NULL))
    ) INTO v;
  ELSIF p_kind = 'user' THEN
    SELECT json_build_object(
      'compte', (SELECT to_jsonb(u) - 'tenant_id' FROM users u WHERE u.id = p_id),
      'notifications_in_app', (SELECT json_agg(to_jsonb(n) - 'tenant_id' ORDER BY n.created_at) FROM notifications n WHERE n.user_id = p_id)
    ) INTO v;
  ELSIF p_kind = 'lessee_contact' THEN
    SELECT json_build_object(
      'contact', (SELECT json_build_object('nom', l.contact_name, 'telephone', l.contact_phone, 'email', l.contact_email, 'societe', l.company_name) FROM lessees l WHERE l.id = p_id),
      'demandes', (SELECT json_agg(json_build_object('ref', s.ref, 'categorie', s.category, 'description', s.description, 'date', s.created_at) ORDER BY s.created_at)
                   FROM service_requests s WHERE s.lessee_id = p_id),
      'notifications', (SELECT json_agg(json_build_object('canal', o.channel, 'evenement', o.event_type, 'date', o.created_at) ORDER BY o.created_at)
                        FROM notification_outbox o JOIN lessees l ON l.id = p_id WHERE o.address IN (l.contact_phone, l.contact_email))
    ) INTO v;
  ELSIF p_kind = 'contractor_contact' THEN
    SELECT json_build_object('contact', (SELECT json_build_object('societe', c.name, 'telephone', c.contact_phone, 'email', c.contact_email) FROM contractors c WHERE c.id = p_id)) INTO v;
  ELSIF p_kind = 'requester' THEN
    SELECT json_build_object(
      'demandes', (SELECT json_agg(json_build_object('ref', s.ref, 'nom', s.requester_name, 'contact', s.requester_contact, 'canal', s.channel, 'categorie', s.category,
                          'description', s.description, 'statut', s.status, 'satisfaction', s.satisfaction, 'date', s.created_at) ORDER BY s.created_at)
                   FROM service_requests s WHERE s.requester_contact = p_key),
      'notifications', (SELECT json_agg(json_build_object('canal', o.channel, 'evenement', o.event_type, 'date', o.created_at) ORDER BY o.created_at)
                        FROM notification_outbox o WHERE o.address = p_key)
    ) INTO v;
  ELSE
    RAISE EXCEPTION 'INVALID_KIND';
  END IF;
  RETURN json_build_object('genere_le', now(), 'responsable_du_traitement', (SELECT legal_name FROM company_profile LIMIT 1),
    'categorie', p_kind, 'donnees', v);
END $$;

-- Effacement : anonymise les champs de contact ; conserve les pièces à conservation légale (baux, factures, OT, registres HSSE)
CREATE OR REPLACE FUNCTION keystone.personal_data_anonymize(p_kind text, p_id uuid, p_key text, p_reason text, p_request uuid DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
DECLARE n int := 0; k int; v_tag text := 'ANON-' || upper(substr(md5(gen_random_uuid()::text), 1, 6));
BEGIN
  PERFORM keystone.staff_guard();
  PERFORM keystone.require_strong_auth('Anonymisation de données personnelles');
  IF length(btrim(coalesce(p_reason, ''))) < 10 THEN
    RAISE EXCEPTION 'JUSTIFICATION_REQUIRED' USING DETAIL = 'Motif obligatoire (10 caractères minimum), conservé au registre.';
  END IF;
  IF p_kind = 'person' THEN
    UPDATE notification_outbox SET address = v_tag, recipient_label = v_tag WHERE address IN (SELECT x FROM persons pp, LATERAL (VALUES (pp.phone), (pp.email)) v(x) WHERE pp.id = p_id AND x IS NOT NULL);
    GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
    UPDATE persons SET first_name = 'Personne', last_name = v_tag, phone = NULL, email = NULL, updated_at = now() WHERE id = p_id;
    GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  ELSIF p_kind = 'lessee_contact' THEN
    UPDATE notification_outbox o SET address = v_tag, recipient_label = v_tag FROM lessees l WHERE l.id = p_id AND o.address IN (l.contact_phone, l.contact_email);
    GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
    UPDATE lessees SET contact_name = NULL, contact_phone = NULL, contact_email = NULL WHERE id = p_id;
    GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  ELSIF p_kind = 'contractor_contact' THEN
    UPDATE contractors SET contact_phone = NULL, contact_email = NULL WHERE id = p_id;
    GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  ELSIF p_kind = 'requester' THEN
    UPDATE notification_outbox SET address = v_tag, recipient_label = v_tag WHERE address = p_key;
    GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
    UPDATE service_requests SET requester_name = 'Demandeur anonymisé', requester_contact = NULL, updated_at = now() WHERE requester_contact = p_key;
    GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  ELSIF p_kind = 'user' THEN
    RAISE EXCEPTION 'USER_ACCOUNT' USING DETAIL = 'Un compte utilisateur se supprime depuis l''administration des accès (Supabase Auth), puis sa fiche personne s''anonymise ici.';
  ELSE
    RAISE EXCEPTION 'INVALID_KIND';
  END IF;
  IF p_request IS NOT NULL THEN
    UPDATE privacy_requests SET status = 'done', handled_by = auth.uid(), handled_at = now(),
      outcome = format('Anonymisé (%s) — %s champ(s)/ligne(s). Motif : %s', v_tag, n, p_reason) WHERE id = p_request;
  ELSE
    INSERT INTO privacy_requests(tenant_id, ref, subject_kind, subject_id, subject_key, subject_label, request_type, status, outcome, handled_by, handled_at)
    VALUES (keystone.current_tenant(), keystone.next_ref('RGPD'), p_kind, p_id, NULL, v_tag, 'erasure', 'done',
            format('Anonymisé — %s champ(s)/ligne(s). Motif : %s', n, p_reason), auth.uid(), now());
  END IF;
  RETURN json_build_object('rows', n, 'tag', v_tag);
END $$;

-- Self-service : « mes données » pour l'utilisateur connecté
CREATE OR REPLACE FUNCTION keystone.my_personal_data()
RETURNS json LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
  SELECT json_build_object('genere_le', now(),
    'compte', (SELECT to_jsonb(u) - 'tenant_id' FROM users u WHERE u.id = auth.uid()),
    'fiche', (SELECT to_jsonb(p) - 'tenant_id' FROM persons p JOIN users u ON u.person_id = p.id WHERE u.id = auth.uid()),
    'notifications', (SELECT json_agg(json_build_object('type', n.kind, 'contenu', n.payload, 'date', n.created_at) ORDER BY n.created_at) FROM notifications n WHERE n.user_id = auth.uid()),
    'session', json_build_object('niveau_authentification', keystone.session_aal()));
$$;

CREATE OR REPLACE FUNCTION keystone.privacy_board()
RETURNS TABLE(id uuid, ref text, subject_kind text, subject_label text, request_type text, channel text, received_at date, due_date date,
  status text, outcome text, overdue boolean, days_left int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT r.id, r.ref, r.subject_kind, r.subject_label, r.request_type, r.channel, r.received_at, r.due_date, r.status, r.outcome,
    r.status = 'open' AND r.due_date < current_date, (r.due_date - current_date)
  FROM privacy_requests r ORDER BY (r.status = 'open') DESC, r.due_date;
$$;

-- ======================================================================
-- D. Export comptable SYSCOHADA
-- ======================================================================
CREATE TABLE IF NOT EXISTS keystone.accounting_accounts (
  tenant_id uuid NOT NULL DEFAULT keystone.current_tenant(),
  key text NOT NULL,
  account text NOT NULL CHECK (account ~ '^[0-9]{2,10}$'),
  label text NOT NULL,
  PRIMARY KEY (tenant_id, key)
);
ALTER TABLE keystone.accounting_accounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON keystone.accounting_accounts;
CREATE POLICY tenant_isolation ON keystone.accounting_accounts USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant());
DROP POLICY IF EXISTS staff_only ON keystone.accounting_accounts;
CREATE POLICY staff_only ON keystone.accounting_accounts AS RESTRICTIVE USING (keystone.current_lessee() IS NULL AND keystone.current_contractor() IS NULL);
GRANT SELECT, INSERT, UPDATE ON keystone.accounting_accounts TO authenticated;

-- Plan de comptes par défaut (SYSCOHADA révisé) — INDICATIF, surchargé par accounting_accounts
CREATE OR REPLACE FUNCTION keystone.accounting_defaults()
RETURNS TABLE(key text, account text, label text, ord int)
LANGUAGE sql IMMUTABLE AS $$
  VALUES ('purchase_goods', '604', 'Achats stockés de matières et fournitures consommables', 1),
         ('purchase_services', '624', 'Entretien, réparations, remises en état et maintenance', 2),
         ('electricity', '6052', 'Fournitures non stockables — électricité', 3),
         ('water', '6051', 'Fournitures non stockables — eau', 4),
         ('vat_deductible', '4452', 'État, TVA récupérable sur achats', 5),
         ('suppliers', '401', 'Fournisseurs, dettes en compte', 6),
         ('customers', '411', 'Clients (preneurs)', 7),
         ('rent_income', '706', 'Services vendus — loyers', 8),
         ('charges_income', '708', 'Produits accessoires — charges refacturées', 9),
         ('vat_collected', '4432', 'État, TVA facturée sur prestations de services', 10),
         ('bank', '521', 'Banques locales', 11),
         ('mobile_money', '521', 'Mobile Money (compte de trésorerie)', 12),
         ('cash', '571', 'Caisse', 13);
$$;

CREATE OR REPLACE FUNCTION keystone.acct(p_key text) RETURNS text
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT coalesce((SELECT account FROM accounting_accounts WHERE key = p_key), (SELECT account FROM accounting_defaults() WHERE key = p_key));
$$;

CREATE OR REPLACE FUNCTION keystone.accounting_plan()
RETURNS TABLE(key text, account text, label text, is_default boolean)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT d.key, coalesce(a.account, d.account), coalesce(a.label, d.label), a.key IS NULL
  FROM accounting_defaults() d LEFT JOIN accounting_accounts a ON a.key = d.key ORDER BY d.ord;
$$;

-- Code auxiliaire de tiers : F/C + 8 caractères significatifs du nom
CREATE OR REPLACE FUNCTION keystone.aux_code(p_prefix text, p_name text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT p_prefix || rpad(upper(left(regexp_replace(keystone.fold(coalesce(p_name, 'DIVERS')), '[^a-z0-9]', '', 'g'), 8)), 3, 'X');
$$;

CREATE OR REPLACE FUNCTION keystone.accounting_entries(p_from date, p_to date)
RETURNS TABLE(journal text, entry_date date, piece text, account text, aux text, label text, debit numeric, credit numeric, source text)
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO 'keystone','public' AS $$
BEGIN
  PERFORM keystone.staff_guard();
  IF p_to < p_from THEN RAISE EXCEPTION 'INVALID_PERIOD'; END IF;
  RETURN QUERY
  WITH inv AS (
    SELECT i.*, c.name AS sup FROM supplier_invoices i LEFT JOIN contractors c ON c.id = i.supplier_id
    WHERE i.status IN ('approved','paid') AND i.invoice_date BETWEEN p_from AND p_to
  ), e AS (
    -- Achats : charges HT par nature de ligne
    SELECT 'AC'::text AS j, inv.invoice_date AS d, inv.ref AS pc,
      CASE WHEN pol.part_id IS NOT NULL THEN acct('purchase_goods') ELSE acct('purchase_services') END AS a, NULL::text AS x,
      left(coalesce(inv.sup, '') || ' — ' || il.label, 120) AS l, round(il.line_total) AS dr, 0::numeric AS cr, 'supplier_invoice' AS s, 1 AS o
    FROM inv JOIN supplier_invoice_lines il ON il.invoice_id = inv.id LEFT JOIN purchase_order_lines pol ON pol.id = il.po_line_id
    UNION ALL  -- TVA déductible = TTC − Σ HT des lignes (pièce toujours équilibrée)
    SELECT 'AC', inv.invoice_date, inv.ref, acct('vat_deductible'), NULL, 'TVA déductible ' || inv.supplier_ref,
      inv.amount_ttc - (SELECT round(sum(il.line_total)) FROM supplier_invoice_lines il WHERE il.invoice_id = inv.id), 0, 'supplier_invoice', 2
    FROM inv
    UNION ALL
    SELECT 'AC', inv.invoice_date, inv.ref, acct('suppliers'), aux_code('F', inv.sup), 'Facture ' || inv.supplier_ref || ' — ' || coalesce(inv.sup, ''),
      0, inv.amount_ttc, 'supplier_invoice', 3
    FROM inv
    UNION ALL  -- Règlements fournisseurs
    SELECT 'BQ', i.paid_at::date, coalesce(i.payment_ref, i.ref), acct('suppliers'), aux_code('F', c.name), 'Règlement ' || i.supplier_ref, i.amount_ttc, 0, 'supplier_payment', 1
    FROM supplier_invoices i LEFT JOIN contractors c ON c.id = i.supplier_id WHERE i.status = 'paid' AND i.paid_at::date BETWEEN p_from AND p_to
    UNION ALL
    SELECT 'BQ', i.paid_at::date, coalesce(i.payment_ref, i.ref), acct('bank'), NULL, 'Règlement ' || i.supplier_ref || ' — ' || coalesce(c.name, ''), 0, i.amount_ttc, 'supplier_payment', 2
    FROM supplier_invoices i LEFT JOIN contractors c ON c.id = i.supplier_id WHERE i.status = 'paid' AND i.paid_at::date BETWEEN p_from AND p_to
    UNION ALL  -- Ventes : appels de loyers et charges (échéancier)
    SELECT 'VT', rs.due_date, l.ref || '-' || to_char(rs.period_start, 'YYYYMM'), acct('customers'), aux_code('C', coalesce(le.trade_name, le.company_name)),
      'Avis d''échéance ' || to_char(rs.period_start, 'MM/YYYY') || ' — ' || coalesce(le.trade_name, le.company_name), rs.total_due, 0, 'rent_schedule', 1
    FROM rent_schedules rs JOIN leases l ON l.id = rs.lease_id JOIN lessees le ON le.id = rs.lessee_id WHERE rs.due_date BETWEEN p_from AND p_to
    UNION ALL
    SELECT 'VT', rs.due_date, l.ref || '-' || to_char(rs.period_start, 'YYYYMM'), acct('rent_income'), NULL, 'Loyer ' || to_char(rs.period_start, 'MM/YYYY') || ' — ' || l.ref,
      0, rs.rent_amount, 'rent_schedule', 2
    FROM rent_schedules rs JOIN leases l ON l.id = rs.lease_id WHERE rs.due_date BETWEEN p_from AND p_to AND rs.rent_amount <> 0
    UNION ALL
    SELECT 'VT', rs.due_date, l.ref || '-' || to_char(rs.period_start, 'YYYYMM'), acct('charges_income'), NULL, 'Charges ' || to_char(rs.period_start, 'MM/YYYY') || ' — ' || l.ref,
      0, rs.charges_amount, 'rent_schedule', 3
    FROM rent_schedules rs JOIN leases l ON l.id = rs.lease_id WHERE rs.due_date BETWEEN p_from AND p_to AND rs.charges_amount <> 0
    UNION ALL
    SELECT 'VT', rs.due_date, l.ref || '-' || to_char(rs.period_start, 'YYYYMM'), acct('vat_collected'), NULL, 'TVA collectée ' || to_char(rs.period_start, 'MM/YYYY') || ' — ' || l.ref,
      0, rs.vat_amount, 'rent_schedule', 4
    FROM rent_schedules rs JOIN leases l ON l.id = rs.lease_id WHERE rs.due_date BETWEEN p_from AND p_to AND rs.vat_amount <> 0
    UNION ALL  -- Encaissements de loyers
    SELECT 'BQ', rp.paid_at::date, coalesce(rp.provider_ref, 'ENC-' || upper(substr(rp.id::text, 1, 8))),
      acct(CASE rp.method WHEN 'cash' THEN 'cash' WHEN 'mobile_money' THEN 'mobile_money' ELSE 'bank' END), NULL,
      'Encaissement ' || rp.method || ' — ' || coalesce(le.trade_name, le.company_name), rp.amount, 0, 'rent_payment', 1
    FROM rent_payments rp JOIN lessees le ON le.id = rp.lessee_id WHERE rp.paid_at::date BETWEEN p_from AND p_to
    UNION ALL
    SELECT 'BQ', rp.paid_at::date, coalesce(rp.provider_ref, 'ENC-' || upper(substr(rp.id::text, 1, 8))), acct('customers'), aux_code('C', coalesce(le.trade_name, le.company_name)),
      'Encaissement — ' || coalesce(le.trade_name, le.company_name), 0, rp.amount, 'rent_payment', 2
    FROM rent_payments rp JOIN lessees le ON le.id = rp.lessee_id WHERE rp.paid_at::date BETWEEN p_from AND p_to
  )
  SELECT e.j, e.d, e.pc, e.a, e.x, e.l, e.dr, e.cr, e.s FROM e
  WHERE e.dr <> 0 OR e.cr <> 0
  ORDER BY e.j, e.d, e.pc, e.o;
END $$;

CREATE OR REPLACE FUNCTION keystone.accounting_summary(p_from date, p_to date)
RETURNS TABLE(journal text, entries int, pieces int, debit numeric, credit numeric, unbalanced_pieces int)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  WITH e AS (SELECT * FROM accounting_entries(p_from, p_to)),
       p AS (SELECT e.journal, e.piece, sum(e.debit) - sum(e.credit) AS gap FROM e GROUP BY e.journal, e.piece)
  SELECT e.journal, count(*)::int, count(DISTINCT e.piece)::int, sum(e.debit), sum(e.credit),
    (SELECT count(*) FROM p WHERE p.journal = e.journal AND abs(p.gap) > 0.5)::int
  FROM e GROUP BY e.journal ORDER BY e.journal;
$$;

GRANT EXECUTE ON FUNCTION keystone.fold(text), keystone.global_search(text, int), keystone.session_aal(), keystone.require_strong_auth(text, boolean),
  keystone.personal_data_subjects(text), keystone.personal_data_export(text, uuid, text), keystone.personal_data_anonymize(text, uuid, text, text, uuid),
  keystone.my_personal_data(), keystone.privacy_board(), keystone.accounting_defaults(), keystone.acct(text), keystone.accounting_plan(),
  keystone.aux_code(text, text), keystone.accounting_entries(date, date), keystone.accounting_summary(date, date)
  TO authenticated;
GRANT UPDATE (first_name, last_name, phone, email, updated_at) ON keystone.persons TO authenticated;
GRANT UPDATE (contact_name, contact_phone, contact_email) ON keystone.lessees TO authenticated;
GRANT UPDATE (contact_phone, contact_email) ON keystone.contractors TO authenticated;
GRANT UPDATE (requester_name, requester_contact, updated_at) ON keystone.service_requests TO authenticated;
GRANT UPDATE (address, recipient_label) ON keystone.notification_outbox TO authenticated;

COMMIT;


-- ==================== 20261005_keystone_43b_privacy_seed.sql ====================
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


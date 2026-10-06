-- Atlas Keystone · migration 44 — cloisonnement des comptes locataires / prestataires sur tout le schéma
-- À coller en une fois dans le SQL Editor (projet vgtmljfayiysuvrcmunt), puis coller TEST_44_rbac.sql pour le contrôle.

-- keystone_44_rbac_hardening — Cloisonnement des comptes locataires et prestataires sur TOUT le schéma
-- Constat (audit du 2026-10-06) :
--   · ~90 tables n'avaient que l'isolation par tenant : un compte locataire ou prestataire du tenant pouvait tout lire
--     (budgets, achats, HSSE, personnes, comptes utilisateurs, OT de tous les prestataires…)
--   · keystone.audit_trail : RLS désactivée alors que SELECT est accordé à authenticated ⇒ lisible TOUS tenants confondus
--   · contractor_invoices : la policy de lecture se terminait par « OR tenant_id = current_tenant() » ⇒ un prestataire
--     voyait les factures de tous les prestataires
--   · work_orders : la policy de lecture laissait un compte locataire voir tous les OT
-- Principe : policies RESTRICTIVES (elles s'ajoutent à l'isolation par tenant, sans rien ouvrir) :
--   · exploitant (ni locataire ni prestataire) : aucun changement
--   · locataire : ses baux, échéances, paiements, tickets, messages NON internes, ses lots ; référentiels de site
--   · prestataire : ses OT (et lignes), devis, avenants, rapports, pauses, anomalies, factures et paiements, attestations,
--     contrats, permis, son personnel, les équipements de ses OT ; référentiels de site
--   · toute autre table : invisible pour les comptes portail (règle par défaut, appliquée aussi aux tables futures via
--     keystone.apply_portal_default())
-- Les fonctions SECURITY DEFINER (current_tenant/lessee/contractor, notifications, audit) ne sont pas concernées.
BEGIN;
SET LOCAL search_path = keystone, public, extensions;
SET LOCAL lock_timeout = '15s';

-- ---------- 0. Tables lues par les policies Storage (photos d'OT) : transaction courte dédiée ----------
-- OT : locataire → OT issus de ses tickets ; prestataire → ses OT
DROP POLICY IF EXISTS portal_scope ON keystone.work_orders;
CREATE POLICY portal_scope ON keystone.work_orders AS RESTRICTIVE USING (
  ((SELECT keystone.current_lessee()) IS NULL OR id IN (SELECT sr.work_order_id FROM keystone.service_requests sr WHERE sr.work_order_id IS NOT NULL))
  AND ((SELECT keystone.current_contractor()) IS NULL OR contractor_id = (SELECT keystone.current_contractor())));
DROP POLICY IF EXISTS portal_scope ON keystone.work_order_lines;
CREATE POLICY portal_scope ON keystone.work_order_lines AS RESTRICTIVE USING (
  (SELECT keystone.current_lessee()) IS NULL
  AND ((SELECT keystone.current_contractor()) IS NULL OR work_order_id IN (SELECT w.id FROM keystone.work_orders w)));
-- Équipements : prestataire → ceux de ses OT
DROP POLICY IF EXISTS portal_scope ON keystone.assets;
CREATE POLICY portal_scope ON keystone.assets AS RESTRICTIVE USING (
  (SELECT keystone.current_lessee()) IS NULL
  AND ((SELECT keystone.current_contractor()) IS NULL OR id IN (SELECT w.asset_id FROM keystone.work_orders w WHERE w.asset_id IS NOT NULL)));
-- Comptes utilisateurs : un compte portail ne voit que le sien
DROP POLICY IF EXISTS portal_scope ON keystone.users;
CREATE POLICY portal_scope ON keystone.users AS RESTRICTIVE USING (
  ((SELECT keystone.current_lessee()) IS NULL AND (SELECT keystone.current_contractor()) IS NULL) OR id = (SELECT auth.uid()));
-- Personnes : locataire → lui-même ; prestataire → son personnel
DROP POLICY IF EXISTS portal_scope ON keystone.persons;
CREATE POLICY portal_scope ON keystone.persons AS RESTRICTIVE USING (
  ((SELECT keystone.current_lessee()) IS NULL OR user_id = (SELECT auth.uid()))
  AND ((SELECT keystone.current_contractor()) IS NULL OR contractor_id = (SELECT keystone.current_contractor()) OR user_id = (SELECT auth.uid())));
COMMIT;

BEGIN;
SET LOCAL search_path = keystone, public, extensions;
SET LOCAL lock_timeout = '15s';

-- ---------- 1. Journal d'audit : RLS (trous critique, lecture inter-tenants) ----------
ALTER TABLE keystone.audit_trail ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON keystone.audit_trail;
CREATE POLICY tenant_isolation ON keystone.audit_trail FOR SELECT USING (tenant_id = keystone.current_tenant());
DROP POLICY IF EXISTS portal_scope ON keystone.audit_trail;
CREATE POLICY portal_scope ON keystone.audit_trail AS RESTRICTIVE
  USING ((SELECT keystone.current_lessee()) IS NULL AND (SELECT keystone.current_contractor()) IS NULL);
REVOKE INSERT, UPDATE, DELETE ON keystone.audit_trail FROM authenticated, anon;   -- écrit uniquement par audit_row() (DEFINER)

-- ---------- 2. Factures prestataires : lecture limitée au prestataire concerné ----------
DROP POLICY IF EXISTS p_contractor_invoices_select_04ff ON keystone.contractor_invoices;
CREATE POLICY p_contractor_invoices_select_04ff ON keystone.contractor_invoices FOR SELECT USING (tenant_id = keystone.current_tenant());

-- ---------- 3. Règles explicites des tables partagées avec les portails ----------
-- Notifications in-app : un compte portail ne voit que les siennes
DROP POLICY IF EXISTS portal_scope ON keystone.notifications;
CREATE POLICY portal_scope ON keystone.notifications AS RESTRICTIVE USING (
  ((SELECT keystone.current_lessee()) IS NULL AND (SELECT keystone.current_contractor()) IS NULL) OR user_id = (SELECT auth.uid()));
-- Messages de tickets : locataire → ceux de ses tickets, JAMAIS les notes internes
DROP POLICY IF EXISTS portal_scope ON keystone.ticket_messages;
CREATE POLICY portal_scope ON keystone.ticket_messages AS RESTRICTIVE USING (
  ((SELECT keystone.current_lessee()) IS NULL OR (NOT is_internal AND ticket_id IN (SELECT sr.id FROM keystone.service_requests sr)))
  AND (SELECT keystone.current_contractor()) IS NULL);
-- Lots : locataire → ses lots loués
DROP POLICY IF EXISTS portal_scope ON keystone.space_units;
CREATE POLICY portal_scope ON keystone.space_units AS RESTRICTIVE USING (
  ((SELECT keystone.current_lessee()) IS NULL OR id IN (SELECT ls.space_unit_id FROM keystone.lease_spaces ls))
  AND (SELECT keystone.current_contractor()) IS NULL);
-- Prestataires : un prestataire ne voit que sa fiche ; invisible aux locataires
DROP POLICY IF EXISTS portal_scope ON keystone.contractors;
CREATE POLICY portal_scope ON keystone.contractors AS RESTRICTIVE USING (
  (SELECT keystone.current_lessee()) IS NULL
  AND ((SELECT keystone.current_contractor()) IS NULL OR id = (SELECT keystone.current_contractor())));
-- Tables portant contractor_id : le prestataire voit ses lignes, le locataire rien
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['contractor_invoices','contractor_certifications','maintenance_contracts','work_permits'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS portal_scope ON keystone.%I', t);
    EXECUTE format('CREATE POLICY portal_scope ON keystone.%I AS RESTRICTIVE USING ((SELECT keystone.current_lessee()) IS NULL AND ((SELECT keystone.current_contractor()) IS NULL OR contractor_id = (SELECT keystone.current_contractor())))', t);
  END LOOP;
END $$;
-- Paiements prestataires : via leurs factures (déjà cloisonnées)
DROP POLICY IF EXISTS portal_scope ON keystone.payments;
CREATE POLICY portal_scope ON keystone.payments AS RESTRICTIVE USING (
  (SELECT keystone.current_lessee()) IS NULL
  AND ((SELECT keystone.current_contractor()) IS NULL OR contractor_invoice_id IN (SELECT ci.id FROM keystone.contractor_invoices ci)));

-- ---------- 4. Règle par défaut : toute autre table est invisible aux comptes portail ----------
-- Référentiels de site lisibles par les portails (noms de site, bâtiments, localisations, actualités, contacts, identité société)
CREATE OR REPLACE FUNCTION keystone.portal_readable_tables() RETURNS text[]
LANGUAGE sql IMMUTABLE AS $$
  SELECT ARRAY['sites','buildings','floors','zones','locations','asset_categories','service_types','center_news','site_contacts','company_profile'];
$$;

-- Ajoute les policies restrictives manquantes (idempotent) ; à rappeler après création de nouvelles tables
CREATE OR REPLACE FUNCTION keystone.apply_portal_default() RETURNS json
LANGUAGE plpgsql SET search_path TO 'keystone','public' AS $$
DECLARE r record; n_l int := 0; n_c int := 0;
BEGIN
  FOR r IN
    SELECT c.relname,
      EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = 'keystone' AND p.tablename = c.relname AND p.permissive = 'RESTRICTIVE'
              AND p.cmd IN ('ALL','SELECT') AND p.qual ILIKE '%current_lessee%') AS has_l,
      EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = 'keystone' AND p.tablename = c.relname AND p.permissive = 'RESTRICTIVE'
              AND p.cmd IN ('ALL','SELECT') AND p.qual ILIKE '%current_contractor%') AS has_c
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'keystone' AND c.relkind IN ('r','p') AND c.relrowsecurity
      AND EXISTS (SELECT 1 FROM information_schema.columns ic WHERE ic.table_schema = 'keystone' AND ic.table_name = c.relname AND ic.column_name = 'tenant_id')
      AND NOT (c.relname = ANY (keystone.portal_readable_tables()))
  LOOP
    IF NOT r.has_l THEN
      EXECUTE format('DROP POLICY IF EXISTS portal_no_lessee ON keystone.%I', r.relname);
      EXECUTE format('CREATE POLICY portal_no_lessee ON keystone.%I AS RESTRICTIVE USING ((SELECT keystone.current_lessee()) IS NULL)', r.relname);
      n_l := n_l + 1;
    END IF;
    IF NOT r.has_c THEN
      EXECUTE format('DROP POLICY IF EXISTS portal_no_contractor ON keystone.%I', r.relname);
      EXECUTE format('CREATE POLICY portal_no_contractor ON keystone.%I AS RESTRICTIVE USING ((SELECT keystone.current_contractor()) IS NULL)', r.relname);
      n_c := n_c + 1;
    END IF;
  END LOOP;
  RETURN json_build_object('lessee_policies', n_l, 'contractor_policies', n_c);
END $$;
REVOKE EXECUTE ON FUNCTION keystone.apply_portal_default() FROM PUBLIC, anon, authenticated;

SELECT keystone.apply_portal_default();

-- ---------- 5. Contrôle : rapport de couverture (lecture) ----------
CREATE OR REPLACE FUNCTION keystone.rbac_coverage()
RETURNS TABLE(table_name text, rls boolean, lessee_scoped boolean, contractor_scoped boolean, portal_readable boolean)
LANGUAGE sql STABLE SET search_path TO 'keystone','public' AS $$
  SELECT c.relname::text, c.relrowsecurity,
    EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = 'keystone' AND p.tablename = c.relname AND p.permissive = 'RESTRICTIVE' AND p.cmd IN ('ALL','SELECT') AND p.qual ILIKE '%current_lessee%'),
    EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = 'keystone' AND p.tablename = c.relname AND p.permissive = 'RESTRICTIVE' AND p.cmd IN ('ALL','SELECT') AND p.qual ILIKE '%current_contractor%'),
    c.relname = ANY (keystone.portal_readable_tables())
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'keystone' AND c.relkind IN ('r','p') ORDER BY 1;
$$;
REVOKE EXECUTE ON FUNCTION keystone.rbac_coverage() FROM PUBLIC, anon, authenticated;

COMMIT;

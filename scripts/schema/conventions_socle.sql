-- Conventions du socle appliquées à chaque table (Annexe A §A.0.5 et convention « Sur chaque table » de l'Annexe C).
-- À exécuter APRÈS le schéma candidat. Idempotent : peut être rejoué après chaque nouvelle table.
--
-- Le corpus décrit ces conventions par un gabarit (keystone.<t>, '<module>.read') sans correspondance table -> module.
-- Ce script applique ce qui ne demande aucune supposition :
--   1. RLS activée sur toute table qui porte tenant_id, avec une politique RESTRICTIVE d'isolation par tenant.
--      Sans politique permissive (module), la table reste fermée : refus par défaut. Les politiques par module
--      (gabarit A.0.5) s'ajoutent quand la correspondance table -> module est validée (rls_modules.tsv).
--   2. Audit chaîné keystone.tg_audit() (A47, A87) sur toute table à tenant_id et id uuid, hors tables d'audit.
--   3. Horodatage : keystone.tg_set_updated_at() si updated_at et updated_by existent, sinon keystone.tg_touch_updated_at().
-- Les tables déjà dotées de politiques par les annexes gardent les leurs : la politique restrictive s'y ajoute sans rien ouvrir.

CREATE OR REPLACE FUNCTION keystone.tg_touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;

DO $$
DECLARE
  r record;
  n_rls int := 0; n_audit int := 0; n_upd int := 0;
  skip_audit text[] := ARRAY['audit_trail','audit_heads'];
BEGIN
  FOR r IN
    SELECT c.oid, n.nspname AS sch, c.relname AS tbl,
           EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attname = 'tenant_id' AND NOT a.attisdropped) AS has_tenant,
           EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attname = 'updated_at' AND NOT a.attisdropped) AS has_upd,
           EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attname = 'updated_by' AND NOT a.attisdropped) AS has_upd_by,
           (SELECT format_type(a.atttypid, NULL) FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attname = 'id' AND NOT a.attisdropped) AS id_type
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind IN ('r', 'p') AND n.nspname IN ('keystone', 'atlas_core') AND NOT c.relispartition
  LOOP
    IF r.has_tenant THEN
      EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', r.sch, r.tbl);
      IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = r.oid AND polname = 'tenant_isolation') THEN
        EXECUTE format('CREATE POLICY tenant_isolation ON %I.%I AS RESTRICTIVE USING (tenant_id = keystone.current_tenant()) WITH CHECK (tenant_id = keystone.current_tenant())', r.sch, r.tbl);
        n_rls := n_rls + 1;
      END IF;
      IF r.id_type = 'uuid' AND NOT r.tbl = ANY (skip_audit)
         AND NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = r.oid AND tgname = 'trg_audit') THEN
        EXECUTE format('CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON %I.%I FOR EACH ROW EXECUTE FUNCTION keystone.tg_audit()', r.sch, r.tbl);
        n_audit := n_audit + 1;
      END IF;
    END IF;
    IF r.has_upd AND NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = r.oid AND tgname = 'trg_updated_at') THEN
      EXECUTE format('CREATE TRIGGER trg_updated_at BEFORE UPDATE ON %I.%I FOR EACH ROW EXECUTE FUNCTION %s',
                     r.sch, r.tbl, CASE WHEN r.has_upd_by THEN 'keystone.tg_set_updated_at()' ELSE 'keystone.tg_touch_updated_at()' END);
      n_upd := n_upd + 1;
    END IF;
  END LOOP;
  RAISE NOTICE 'conventions du socle : % politiques d''isolation, % audits chaînés, % horodatages ajoutés', n_rls, n_audit, n_upd;
END $$;

-- 4. Droits d'accès (absents du corpus, nécessaires à PostgREST). Refus par défaut :
--    anon n'a rien ; authenticated accède aux tables, la RLS décide des lignes ; aucune fonction n'est exécutable
--    par PUBLIC (Postgres l'accorde par défaut, y compris pour les fonctions SECURITY DEFINER).
--    Les surfaces publiques sans compte (QR, suivi) passent par des RPC dédiées, accordées une à une à anon.
REVOKE ALL ON SCHEMA keystone, atlas_core FROM PUBLIC;
GRANT USAGE ON SCHEMA keystone TO authenticated, service_role;
GRANT USAGE ON SCHEMA atlas_core TO service_role;
REVOKE ALL ON ALL TABLES IN SCHEMA keystone, atlas_core FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA keystone TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA keystone, atlas_core TO service_role;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA keystone, atlas_core FROM PUBLIC, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA keystone TO authenticated, service_role;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA keystone TO authenticated;
-- Journal d'audit : lecture seule pour l'application, écrit uniquement par tg_audit (SECURITY DEFINER).
REVOKE INSERT, UPDATE, DELETE ON keystone.audit_trail, keystone.audit_heads FROM authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA keystone REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- 5. Retraits APRÈS l'octroi global du point 4 (qui sinon les annulerait) :
--    fonctions de trigger (un trigger se déclenche sans droit EXECUTE de l'appelant), fonctions internes d'audit et de
--    pseudonymisation, écriture brute du journal des accès, crochet de jeton (réservé à supabase_auth_admin), et toute fonction dont le schéma retire explicitement l'exécution à authenticated.
DO $$
DECLARE f record; n int := 0;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
    WHERE ns.nspname IN ('keystone', 'atlas_core')
      AND (p.prorettype = 'trigger'::regtype
           OR p.proname IN ('audit_pseudonymize', 'audit_hash', 'tg_audit', 'tg_audit_immutable',
                             'access_log_write', 'log_access_for', 'custom_access_token_hook'))
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM authenticated', f.sig);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'conventions du socle : exécution retirée à authenticated sur % fonctions internes', n;
END $$;

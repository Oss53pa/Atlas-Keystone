-- Atlas Keystone · réparation du compte démo admin@keystone.demo
-- Constat (2026-10-06) : le compte Supabase Auth a disparu ; la fiche keystone.users subsiste avec l'ancien identifiant.
-- Étape 1 (tableau de bord Supabase › Authentication › Users › Add user) : recréer admin@keystone.demo,
--   cocher « Auto Confirm User », mot de passe = celui de VITE_DEMO_PASSWORD dans apps/web/.env.local.
-- Étape 2 : coller ce script. Il rattache la fiche, ses rôles, son périmètre, sa personne et ses notifications
--   au nouvel identifiant. Il échoue proprement (sans rien modifier) si l'étape 1 n'a pas été faite.
BEGIN;
DO $$
DECLARE v_new uuid; v_old uuid;
BEGIN
  SELECT id INTO v_new FROM auth.users WHERE lower(email) = 'admin@keystone.demo';
  IF v_new IS NULL THEN RAISE EXCEPTION 'Compte Auth admin@keystone.demo introuvable : faites d''abord l''étape 1.'; END IF;
  SELECT id INTO v_old FROM keystone.users WHERE lower(email) = 'admin@keystone.demo' AND id <> v_new;
  IF v_old IS NULL THEN RAISE NOTICE 'Déjà rattaché, rien à faire.'; RETURN; END IF;

  INSERT INTO keystone.users(id, tenant_id, kind, person_id, contractor_id, email, full_name, is_active, invited_by, created_at, lessee_id)
  SELECT v_new, tenant_id, kind, person_id, contractor_id, email || '.tmp', full_name, is_active, invited_by, created_at, lessee_id
  FROM keystone.users WHERE id = v_old;
  UPDATE keystone.user_roles SET user_id = v_new WHERE user_id = v_old;
  UPDATE keystone.user_scope SET user_id = v_new WHERE user_id = v_old;
  UPDATE keystone.user_prefs SET user_id = v_new WHERE user_id = v_old;
  UPDATE keystone.persons SET user_id = v_new WHERE user_id = v_old;
  UPDATE keystone.notifications SET user_id = v_new WHERE user_id = v_old;
  UPDATE keystone.notification_outbox SET user_id = v_new WHERE user_id = v_old;
  DELETE FROM keystone.users WHERE id = v_old;
  UPDATE keystone.users SET email = 'admin@keystone.demo' WHERE id = v_new;
  RAISE NOTICE 'Compte démo rattaché : % → %', v_old, v_new;
END $$;
COMMIT;

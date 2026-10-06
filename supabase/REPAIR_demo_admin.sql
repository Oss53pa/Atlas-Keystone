-- Atlas Keystone · rattacher un compte Supabase Auth EXISTANT au profil administrateur Keystone du tenant démo
-- Contexte (2026-10-06) : le compte admin@keystone.demo a été supprimé de Supabase Auth ; le profil keystone.users subsiste.
-- Mode d'emploi : remplacez l'adresse ci-dessous (ligne v_email) par celle d'un compte qui existe déjà sur ce projet
--   (par exemple le vôtre), puis exécutez. Le profil admin (tenant, rôles, périmètre, personne, notifications) lui est
--   transféré. Échoue sans rien modifier si l'adresse n'existe pas dans Authentication › Users.
BEGIN;
DO $$
DECLARE
  v_email text := 'admin@keystone.demo';   -- ← adresse du compte à rattacher
  v_new uuid; v_old uuid;
BEGIN
  SELECT id INTO v_new FROM auth.users WHERE lower(email) = lower(v_email);
  IF v_new IS NULL THEN RAISE EXCEPTION 'Compte Auth % introuvable sur ce projet : vérifiez l''adresse.', v_email; END IF;
  IF EXISTS (SELECT 1 FROM keystone.users WHERE id = v_new) THEN RAISE NOTICE 'Ce compte a déjà un profil Keystone, rien à faire.'; RETURN; END IF;
  SELECT k.id INTO v_old FROM keystone.users k
   WHERE k.tenant_id = 'a0000000-0000-4000-8000-000000000001' AND NOT EXISTS (SELECT 1 FROM auth.users a WHERE a.id = k.id)
   ORDER BY k.created_at LIMIT 1;
  IF v_old IS NULL THEN RAISE EXCEPTION 'Aucun profil Keystone orphelin à rattacher.'; END IF;

  INSERT INTO keystone.users(id, tenant_id, kind, person_id, contractor_id, email, full_name, is_active, invited_by, created_at, lessee_id)
  SELECT v_new, tenant_id, kind, person_id, contractor_id, lower(v_email) || '.tmp', full_name, is_active, invited_by, created_at, lessee_id
  FROM keystone.users WHERE id = v_old;
  UPDATE keystone.user_roles SET user_id = v_new WHERE user_id = v_old;
  UPDATE keystone.user_scope SET user_id = v_new WHERE user_id = v_old;
  UPDATE keystone.user_prefs SET user_id = v_new WHERE user_id = v_old;
  UPDATE keystone.persons SET user_id = v_new WHERE user_id = v_old;
  UPDATE keystone.notifications SET user_id = v_new WHERE user_id = v_old;
  UPDATE keystone.notification_outbox SET user_id = v_new WHERE user_id = v_old;
  DELETE FROM keystone.users WHERE id = v_old;
  UPDATE keystone.users SET email = lower(v_email) WHERE id = v_new;
  RAISE NOTICE 'Profil administrateur Keystone rattaché à %', v_email;
END $$;
COMMIT;

-- Recette du socle sur une base Supabase (branche), exécutable par l API de gestion ou psql : un seul bloc,
-- annulé par l exception finale (aucune donnée ne reste). Résultat attendu dans le message d erreur « RECETTE: ... ».
DO $$
DECLARE r text := ''; n int; ok boolean;
  ta uuid := 'aaaaaaaa-0000-0000-0000-000000000001'; tb uuid := 'bbbbbbbb-0000-0000-0000-000000000002';
  ua uuid := '11111111-0000-0000-0000-000000000001'; pa uuid := '99999999-0000-0000-0000-000000000009'; ro uuid := '77777777-0000-0000-0000-000000000007';
BEGIN
  ALTER TABLE keystone.compliance_requirements DROP CONSTRAINT ck_cr_src;
  INSERT INTO atlas_core.tenants (id, slug, display_name, country_code, default_currency) VALUES (ta,'recette-a','Client A','CI','XOF'),(tb,'recette-b','Client B','SN','XOF');
  INSERT INTO keystone.compliance_requirements (tenant_id, requirement) VALUES (ta,'Exigence A'),(tb,'Exigence B');
  UPDATE keystone.compliance_requirements SET requirement = requirement||' (révisée)' WHERE tenant_id = ta;
  INSERT INTO auth.users (id, email, aud, role) VALUES (ua,'recette@example.test','authenticated','authenticated');
  INSERT INTO keystone.users (id, tenant_id, full_name, email, status) VALUES (ua,ta,'Utilisateur recette','recette@example.test','active');
  INSERT INTO keystone.user_profiles (id, tenant_id, user_id, kind, label) VALUES (pa,ta,ua,'internal','Console');
  INSERT INTO keystone.permissions (code, module, label) VALUES ('compliance.manage','compliance','Gérer la conformité') ON CONFLICT DO NOTHING;
  INSERT INTO keystone.roles (id, tenant_id, code, label) VALUES (ro,ta,'hse','Responsable HSSE');
  INSERT INTO keystone.role_permissions (tenant_id, role_id, permission_code) VALUES (ta,ro,'compliance.manage');
  -- 1. utilisateur A sans rôle
  PERFORM set_config('request.jwt.claims', json_build_object('sub',ua,'tenant_id',ta,'active_profile_id',pa,'role','authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  SELECT count(*) INTO n FROM keystone.compliance_requirements; r := r||'sans rôle='||n||' ; ';
  RESET ROLE;
  INSERT INTO keystone.user_roles (tenant_id, user_id, profile_id, role_id) VALUES (ta,ua,pa,ro);
  SET LOCAL ROLE authenticated;
  SELECT count(*) INTO n FROM keystone.compliance_requirements; r := r||'avec rôle='||n||' ; ';
  BEGIN INSERT INTO keystone.compliance_requirements (tenant_id, requirement) VALUES (tb,'Intrusion'); r := r||'intrusion ACCEPTÉE ; ';
  EXCEPTION WHEN insufficient_privilege THEN r := r||'intrusion refusée ; '; END;
  BEGIN INSERT INTO keystone.audit_trail (tenant_id, seq) VALUES (ta, 999); r := r||'écriture audit ACCEPTÉE ; ';
  EXCEPTION WHEN insufficient_privilege THEN r := r||'écriture audit refusée ; '; END;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',ua,'tenant_id',tb,'active_profile_id',pa,'role','authenticated')::text, true);
  SELECT count(*) INTO n FROM keystone.compliance_requirements; r := r||'jeton autre tenant='||n||' ; ';
  RESET ROLE;
  SELECT bool_and(CASE WHEN lag_hash IS NULL THEN true ELSE prev_hash = lag_hash END
                  AND row_hash = keystone.audit_hash(seq, tenant_id, table_name, op, actor_id, occurred_at, row_id, before, after, prev_hash)),
         count(*) INTO ok, n
    FROM (SELECT *, lag(row_hash) OVER (PARTITION BY tenant_id ORDER BY seq) lag_hash FROM keystone.audit_trail WHERE tenant_id IN (ta,tb)) x;
  r := r||'audit '||n||' lignes, chaîne et empreintes='||ok;
  RAISE EXCEPTION 'RECETTE: %', r;   -- annule tout
END $$;

-- Recette de la chaîne de profils (C24 à C29) et du journal des accès (C28). Tout est annulé (ROLLBACK).
-- psql -v ON_ERROR_STOP=0 -f scripts/schema/recette_profils.sql : les lignes « ERROR » attendues sont annoncées par « attendu ».
\pset tuples_only on
BEGIN;
INSERT INTO atlas_core.tenants (id, slug, display_name, country_code, default_currency) VALUES
 ('aaaaaaaa-0000-0000-0000-000000000001','recette-a','Client A','CI','XOF'),
 ('bbbbbbbb-0000-0000-0000-000000000002','recette-b','Client B','SN','XOF'),
 ('cccccccc-0000-0000-0000-000000000003','recette-c','Client C','CM','XAF');
INSERT INTO auth.users (id, email) VALUES ('11111111-0000-0000-0000-000000000001','u1@example.test'),('22222222-0000-0000-0000-000000000002','u2@example.test');
INSERT INTO keystone.users (id, tenant_id, full_name, email, status) VALUES ('11111111-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','U1','u1@example.test','active');
INSERT INTO keystone.user_profiles (id, tenant_id, user_id, kind, label, is_default, status, suspended_reason) VALUES
 ('99999999-0000-0000-0000-00000000000a','aaaaaaaa-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','internal','Console A', false,'active',null),
 ('99999999-0000-0000-0000-00000000000b','bbbbbbbb-0000-0000-0000-000000000002','11111111-0000-0000-0000-000000000001','internal','Console B', false,'suspended','Contrat clos'),
 ('99999999-0000-0000-0000-00000000000c','cccccccc-0000-0000-0000-000000000003','11111111-0000-0000-0000-000000000001','internal','Console C', true,'active',null);
INSERT INTO keystone.tenant_surfaces (tenant_id, surface, is_enabled, mfa_policy, session_idle_minutes, session_max_hours) VALUES
 ('aaaaaaaa-0000-0000-0000-000000000001','console',true,'role_based',30,12),
 ('cccccccc-0000-0000-0000-000000000003','console',false,'optional',30,12);
INSERT INTO keystone.tenant_branding (tenant_id, surface, brand_name) VALUES ('aaaaaaaa-0000-0000-0000-000000000001','console','Marque A');
INSERT INTO keystone.roles (id, tenant_id, code, label, requires_mfa) VALUES ('77777777-0000-0000-0000-000000000007','aaaaaaaa-0000-0000-0000-000000000001','hse','Responsable HSSE', true);
INSERT INTO keystone.user_roles (tenant_id, user_id, profile_id, role_id) VALUES ('aaaaaaaa-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','99999999-0000-0000-0000-00000000000a','77777777-0000-0000-0000-000000000007');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"11111111-0000-0000-0000-000000000001","session_id":"55555555-0000-0000-0000-000000000005","role":"authenticated","aal":"aal1"}', true) IS NULL;
SELECT set_config('request.headers', '{"user-agent":"Recette/1.0","x-forwarded-for":"203.0.113.7, 10.0.0.1"}', true) IS NULL;
SELECT '1. cartes (attendu : A puis B suspendu, C absent car surface désactivée) : ' || string_agg(label||' | '||coalesce(organization,'NR')||' | '||coalesce(role_label,'NR')||' | '||status||coalesce(' : '||suspended_reason,'')||' | tous sites '||scope_all, ' ;; ') FROM keystone.my_profiles();
SAVEPOINT s1; SELECT '2. attendu MFA_REQUIRED'; SELECT keystone.switch_profile('99999999-0000-0000-0000-00000000000a'); ROLLBACK TO s1;
SAVEPOINT s2; SELECT '3. attendu PROFILE_NOT_OWNED (suspendu)'; SELECT keystone.switch_profile('99999999-0000-0000-0000-00000000000b'); ROLLBACK TO s2;
SAVEPOINT s3; SELECT '4. attendu SURFACE_DISABLED'; SELECT keystone.switch_profile('99999999-0000-0000-0000-00000000000c'); ROLLBACK TO s3;
SELECT set_config('request.jwt.claims', '{"sub":"11111111-0000-0000-0000-000000000001","session_id":"55555555-0000-0000-0000-000000000005","role":"authenticated","aal":"aal2"}', true) IS NULL;
SELECT '5. aal2, bascule : ' || (keystone.switch_profile('99999999-0000-0000-0000-00000000000a') ->> 'surface');
SELECT keystone.set_default_profile('99999999-0000-0000-0000-00000000000a', true);
RESET ROLE;
SELECT '6. un seul défaut (attendu A) : ' || string_agg(label||'='||is_default, ', ' ORDER BY label) FROM keystone.user_profiles WHERE user_id = '11111111-0000-0000-0000-000000000001';
SELECT '7. crochet : ' || (keystone.custom_access_token_hook('{"user_id":"11111111-0000-0000-0000-000000000001","claims":{"session_id":"55555555-0000-0000-0000-000000000005"}}') -> 'claims' ->> 'tenant_id');
UPDATE keystone.user_profiles SET status = 'suspended', suspended_reason = 'Recette' WHERE id = '99999999-0000-0000-0000-00000000000a';
SELECT '8. crochet après suspension (attendu vide) : ' || coalesce(keystone.custom_access_token_hook('{"user_id":"11111111-0000-0000-0000-000000000001","claims":{"session_id":"55555555-0000-0000-0000-000000000005"}}') -> 'claims' ->> 'tenant_id', 'vide');
SELECT '9. journal : ' || string_agg(seq||' '||event||' '||surface||' '||host(ip)||' '||user_agent, ' ; ') FROM keystone.access_log WHERE tenant_id = 'aaaaaaaa-0000-0000-0000-000000000001';
SELECT '   empreintes recalculées identiques : ' || bool_and(row_hash = keystone.audit_hash(seq, tenant_id, 'access_log', 'INSERT', actor_id, occurred_at, id, NULL,
   jsonb_build_object('actor_id',actor_id,'event',event,'ip',host(ip),'object_id',object_id,'object_table',object_table,
     'occurred_at',to_char(occurred_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'purpose',purpose,'surface',surface,'user_agent',user_agent), prev_hash))
  FROM keystone.access_log WHERE tenant_id = 'aaaaaaaa-0000-0000-0000-000000000001';
SELECT '10. exécution par authenticated (attendu f f f t t t t) : ' || string_agg(has_function_privilege('authenticated', f, 'EXECUTE')::text, ' ' ORDER BY o) FROM unnest(ARRAY[
 'keystone.access_log_write(uuid,uuid,text,text,text,uuid,text)','keystone.log_access_for(uuid,uuid,text,text,text,uuid,jsonb)','keystone.custom_access_token_hook(jsonb)',
 'keystone.log_access(text,text,text,uuid,text)','keystone.switch_profile(uuid)','keystone.set_default_profile(uuid,boolean)','keystone.my_profiles()']) WITH ORDINALITY AS x(f, o);
SELECT '    anon my_profiles (attendu f) : ' || has_function_privilege('anon','keystone.my_profiles()','EXECUTE')
    || ' ; service_role log_access_for (attendu t) : ' || has_function_privilege('service_role','keystone.log_access_for(uuid,uuid,text,text,text,uuid,jsonb)','EXECUTE');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"22222222-0000-0000-0000-000000000002","session_id":"66666666-0000-0000-0000-000000000006","role":"authenticated"}', true) IS NULL;
SELECT '11. autre utilisateur, profils visibles (attendu 0) : ' || count(*) FROM keystone.my_profiles();
SAVEPOINT s4; SELECT '12. attendu PROFILE_NOT_OWNED'; SELECT keystone.set_default_profile('99999999-0000-0000-0000-00000000000a', false); ROLLBACK TO s4;
ROLLBACK;

-- Recette des permissions (lot 1) : règle de lecture par module (rls_lecture.sql) combinée à l'isolation par tenant.
-- Base de TEST seulement, après conventions_socle.sql et rls_lecture.sql ; tout est annulé (ROLLBACK).
-- Attendu : avant rôle 0 ligne ; après rôle 1 ligne ; même rôle avec le jeton d'un autre tenant 0 ligne ; auteur d'audit « user ».
\pset tuples_only on
\set ON_ERROR_STOP on
BEGIN;
ALTER TABLE keystone.compliance_requirements DROP CONSTRAINT ck_cr_src;  -- contrainte métier hors du sujet testé, annulée par ROLLBACK
INSERT INTO atlas_core.tenants (id, slug, display_name, country_code, default_currency) VALUES ('aaaaaaaa-0000-0000-0000-000000000001','client-a','Client A','CI','XOF');
INSERT INTO auth.users (id, email) VALUES ('11111111-0000-0000-0000-000000000001','demo@example.test');
INSERT INTO keystone.users (id, tenant_id, full_name, email, status) VALUES ('11111111-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','Utilisateur Démo','demo@example.test','active');
INSERT INTO keystone.user_profiles (id, tenant_id, user_id, kind, label) VALUES ('99999999-0000-0000-0000-000000000009','aaaaaaaa-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','internal','Console');
INSERT INTO keystone.permissions (code, module, label) VALUES ('compliance.manage','compliance','Gérer la conformité') ON CONFLICT DO NOTHING;
INSERT INTO keystone.roles (id, tenant_id, code, label) VALUES ('77777777-0000-0000-0000-000000000007','aaaaaaaa-0000-0000-0000-000000000001','hse','Responsable HSSE');
INSERT INTO keystone.role_permissions (tenant_id, role_id, permission_code) VALUES ('aaaaaaaa-0000-0000-0000-000000000001','77777777-0000-0000-0000-000000000007','compliance.manage');
INSERT INTO keystone.compliance_requirements (tenant_id, requirement) VALUES ('aaaaaaaa-0000-0000-0000-000000000001','Exigence A');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"11111111-0000-0000-0000-000000000001","tenant_id":"aaaaaaaa-0000-0000-0000-000000000001","active_profile_id":"99999999-0000-0000-0000-000000000009"}', true) IS NOT NULL AS ok \gset
SELECT 'avant attribution du rôle : ' || count(*) || ' ligne(s)' FROM keystone.compliance_requirements;
RESET ROLE;
INSERT INTO keystone.user_roles (tenant_id, user_id, profile_id, role_id) VALUES ('aaaaaaaa-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','99999999-0000-0000-0000-000000000009','77777777-0000-0000-0000-000000000007');
SET LOCAL ROLE authenticated;
SELECT 'après attribution du rôle : ' || count(*) || ' ligne(s)' FROM keystone.compliance_requirements;
SELECT set_config('request.jwt.claims', '{"sub":"11111111-0000-0000-0000-000000000001","tenant_id":"bbbbbbbb-0000-0000-0000-000000000002","active_profile_id":"99999999-0000-0000-0000-000000000009"}', true) IS NOT NULL AS ok \gset
SELECT 'même rôle, jeton d''un autre tenant : ' || count(*) || ' ligne(s)' FROM keystone.compliance_requirements;
RESET ROLE;
SELECT 'auteur journalisé dans l''audit : ' || coalesce(max(actor_kind),'?') FROM keystone.audit_trail WHERE table_name='user_roles';
ROLLBACK;

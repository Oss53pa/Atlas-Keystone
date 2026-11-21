-- Recette du socle (lot 1) : isolation par tenant, refus d'intrusion, journal d'audit en lecture seule, chaîne d'audit.
-- Base de TEST seulement, après conventions_socle.sql ; tout est annulé (ROLLBACK). Résultats attendus en fin de fichier.
\pset tuples_only on
\set ON_ERROR_STOP on
BEGIN;
ALTER TABLE keystone.compliance_requirements DROP CONSTRAINT ck_cr_src;  -- test du socle seulement, annulé par ROLLBACK
INSERT INTO atlas_core.currencies (code, minor_unit, label) VALUES ('XOF',0,'Franc CFA (BCEAO)'), ('XAF',0,'Franc CFA (BEAC)') ON CONFLICT DO NOTHING;
INSERT INTO atlas_core.country_config (country_code, currency, default_timezone, default_locale, zone) VALUES
 ('CI','XOF','Africa/Abidjan','fr-CI','UEMOA'), ('SN','XOF','Africa/Dakar','fr-SN','UEMOA') ON CONFLICT DO NOTHING;
INSERT INTO atlas_core.tenants (id, slug, display_name, country_code, default_currency) VALUES
 ('aaaaaaaa-0000-0000-0000-000000000001','client-a','Client A','CI','XOF'),
 ('bbbbbbbb-0000-0000-0000-000000000002','client-b','Client B','SN','XOF');
INSERT INTO keystone.compliance_requirements (tenant_id, requirement) VALUES
 ('aaaaaaaa-0000-0000-0000-000000000001','Exigence du client A'),
 ('bbbbbbbb-0000-0000-0000-000000000002','Exigence du client B');
UPDATE keystone.compliance_requirements SET requirement = requirement || ' (révisée)' WHERE tenant_id = 'aaaaaaaa-0000-0000-0000-000000000001';
CREATE POLICY test_ouvert ON keystone.compliance_requirements FOR ALL TO authenticated USING (true) WITH CHECK (true);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"11111111-0000-0000-0000-000000000001","tenant_id":"aaaaaaaa-0000-0000-0000-000000000001"}', true) IS NOT NULL AS ok \gset
SELECT 'A voit : ' || coalesce(string_agg(requirement, ' ; '), 'rien') FROM keystone.compliance_requirements;
SELECT set_config('request.jwt.claims', '{"sub":"22222222-0000-0000-0000-000000000002","tenant_id":"bbbbbbbb-0000-0000-0000-000000000002"}', true) IS NOT NULL AS ok \gset
SELECT 'B voit : ' || coalesce(string_agg(requirement, ' ; '), 'rien') FROM keystone.compliance_requirements;
\set ON_ERROR_STOP off
SAVEPOINT s;
INSERT INTO keystone.compliance_requirements (tenant_id, requirement) VALUES ('aaaaaaaa-0000-0000-0000-000000000001','Intrusion de B chez A');
ROLLBACK TO s;
SAVEPOINT s2;
INSERT INTO keystone.audit_trail (tenant_id, seq) VALUES ('bbbbbbbb-0000-0000-0000-000000000002', 999);
ROLLBACK TO s2;
\set ON_ERROR_STOP on
SELECT set_config('request.jwt.claims', '{}', true) IS NOT NULL AS ok \gset
SELECT 'sans jeton : ' || count(*) || ' ligne(s)' FROM keystone.compliance_requirements;
RESET ROLE;
SELECT 'audit : ' || string_agg(format('%s #%s %s chaîne=%s', left(tenant_id::text,8), seq, op,
   CASE WHEN lag_hash IS NULL THEN 'origine' ELSE (prev_hash = lag_hash)::text END
   || ' empreinte=' || (row_hash = keystone.audit_hash(seq, tenant_id, table_name, op, actor_id, occurred_at, row_id, before, after, prev_hash))::text), ' | ' ORDER BY tenant_id, seq)
FROM (SELECT *, lag(row_hash) OVER (PARTITION BY tenant_id ORDER BY seq) lag_hash FROM keystone.audit_trail WHERE table_name = 'compliance_requirements') x;
ROLLBACK;
-- Attendu : A voit seulement A ; B seulement B ; intrusion refusée (tenant_isolation) ; écriture du journal refusée ;
-- sans jeton : 0 ligne ; audit : chaîne=true et empreinte=true pour chaque ligne, numérotation par tenant.

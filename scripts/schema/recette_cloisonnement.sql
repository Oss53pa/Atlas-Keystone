-- Recette de cloisonnement : relève les tables lisibles par `authenticated` sans filtre par client.
-- Lecture seule, à passer sur la base locale (scripts/schema/base_locale.sh). Résultats : docs/lot1/Recette_base_locale.md.
\pset tuples_only on

-- 1. Garde-fou : aucune table portant tenant_id ne doit être dépourvue de RLS.
SELECT 'tables avec tenant_id et sans RLS (attendu 0) : ' || count(*)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname IN ('keystone','atlas_core','atlas_public')
  AND NOT c.relrowsecurity
  AND EXISTS (SELECT 1 FROM pg_attribute a
              WHERE a.attrelid = c.oid AND a.attname = 'tenant_id' AND a.attnum > 0 AND NOT a.attisdropped);

-- 2. Volumétrie.
SELECT 'tables : ' || count(*) || ' dont avec RLS : ' || count(*) FILTER (WHERE c.relrowsecurity)
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname IN ('keystone','atlas_core','atlas_public');

-- 3. Tables filles d'un parent cloisonné : la fille contourne l'isolation du parent.
\echo '-- tables filles sans RLS, parent cloisonné (ecart) --'
WITH ouvertes AS (
  SELECT c.oid, c.relname
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relkind = 'r' AND n.nspname = 'keystone' AND NOT c.relrowsecurity
    AND has_table_privilege('authenticated', c.oid, 'SELECT')
)
SELECT o.relname || ' -> ' || string_agg(DISTINCT pc.relname, ', ' ORDER BY pc.relname)
FROM ouvertes o
JOIN pg_constraint k ON k.conrelid = o.oid AND k.contype = 'f'
JOIN pg_class pc ON pc.oid = k.confrelid
GROUP BY o.relname
HAVING bool_or(pc.relrowsecurity)
ORDER BY 1;

-- 4. Tables sans clé étrangère ni RLS : référentiels partagés ou écarts, à arbitrer.
\echo '-- tables ouvertes sans clé étrangère (a arbitrer) --'
WITH ouvertes AS (
  SELECT c.oid, c.relname
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relkind = 'r' AND n.nspname = 'keystone' AND NOT c.relrowsecurity
    AND has_table_privilege('authenticated', c.oid, 'SELECT')
)
SELECT o.relname FROM ouvertes o
WHERE NOT EXISTS (SELECT 1 FROM pg_constraint k
                  WHERE k.conrelid = o.oid AND k.contype = 'f' AND k.confrelid <> o.oid)
ORDER BY 1;

-- 5. Rien ne doit être lisible par anon.
SELECT 'tables lisibles par anon (attendu 0) : ' || count(*)
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname IN ('keystone','atlas_core','atlas_public')
  AND has_table_privilege('anon', c.oid, 'SELECT');

-- 6. Vues : une vue appartient à postgres (superutilisateur). Sans security_invoker=true, elle lit ses tables
--    avec les droits du propriétaire, donc SANS la RLS de ces tables. Le cloisonnement doit alors venir
--    d'un filtre écrit dans la vue (WHERE tenant_id = current_tenant()). Sans l'un ni l'autre : fuite inter-client.
\echo '-- vues sans security_invoker ET sans filtre par client (fuite) --'
SELECT c.relname || ' -> ' || coalesce(string_agg(DISTINCT t.relname, ', ' ORDER BY t.relname), 'aucune table RLS')
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_depend d ON d.classid = 'pg_rewrite'::regclass AND d.refclassid = 'pg_class'::regclass
     AND d.objid = (SELECT r.oid FROM pg_rewrite r WHERE r.ev_class = c.oid AND r.rulename = '_RETURN')
     AND d.refobjid <> c.oid
LEFT JOIN pg_class t ON t.oid = d.refobjid AND t.relrowsecurity
WHERE c.relkind = 'v' AND n.nspname IN ('keystone','atlas_core')
  AND (c.reloptions IS NULL OR c.reloptions::text NOT LIKE '%security_invoker=true%')
  AND pg_get_viewdef(c.oid, true) !~* 'current_tenant\(\)'
  AND has_table_privilege('authenticated', c.oid, 'SELECT')
GROUP BY c.relname
ORDER BY 1;

SELECT 'vues lisibles par authenticated : ' || count(*)
     || ' dont security_invoker=true : ' || count(*) FILTER (WHERE c.reloptions::text LIKE '%security_invoker=true%')
     || ' dont filtre current_tenant() : ' || count(*) FILTER (WHERE pg_get_viewdef(c.oid, true) ~* 'current_tenant\(\)')
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'v' AND n.nspname IN ('keystone','atlas_core')
  AND has_table_privilege('authenticated', c.oid, 'SELECT');

-- 7. Écriture par les vues. Une vue simple est modifiable ; sans WITH CHECK OPTION, rien n'empêche d'écrire
--    une ligne hors du périmètre de la vue, et sans security_invoker l'écriture contourne la RLS de la table.
\echo '-- vues ouvertes en ecriture a authenticated (INSERT/UPDATE/DELETE) --'
SELECT c.relname
    || ' [' || string_agg(p.priv, ',' ORDER BY p.priv) || ']'
    || ' check_option=' || coalesce(v.check_option, 'NONE')
    || CASE WHEN c.reloptions::text LIKE '%security_invoker=true%' THEN ' security_invoker' ELSE ' SANS security_invoker' END
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN information_schema.views v ON v.table_schema = n.nspname AND v.table_name = c.relname
CROSS JOIN LATERAL (VALUES ('INSERT'), ('UPDATE'), ('DELETE')) AS p(priv)
WHERE c.relkind = 'v' AND n.nspname IN ('keystone','atlas_core')
  AND has_table_privilege('authenticated', c.oid, p.priv)
GROUP BY c.relname, c.reloptions, v.check_option
ORDER BY 1;

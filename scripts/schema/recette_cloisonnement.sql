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

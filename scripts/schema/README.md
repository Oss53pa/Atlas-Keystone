# Essai du schéma des annexes (lot 0)

Éprouve le SQL du cahier des charges sur un Postgres **jetable**. Ne jamais viser la base Supabase partagée.

```bash
python3 -I scripts/schema/annexes_to_sql.py <dossier>/03_Annexes_back_end /tmp/stmts.json scripts/schema/correctifs_post.sql
psql "<dsn de test>" -v ON_ERROR_STOP=1 -f scripts/schema/supabase_stubs.sql
psql "<dsn de test>" -v ON_ERROR_STOP=1 -f scripts/schema/correctifs_corpus.sql
python3 -I scripts/schema/run_fixpoint.py /tmp/stmts.json "<dsn de test>" /tmp/rapport.json
```

Prérequis : PostgreSQL 16 ou plus avec PostGIS et pgvector, `psycopg` 3. Résultats et décisions attendues :
`docs/lot0/Rapport_ecarts_base_annexes.md` §6. Les correctifs (C..) et substitutions (S..) sont provisoires : chacun
disparaît quand l'annexe propriétaire est corrigée.

## Base locale complète (schéma v2 + socle + recettes)

Un seul script monte la base de test, installe ce qui manque dans le conteneur et applique l'ordre de
`supabase/candidates/README.md` :

```bash
bash scripts/schema/base_locale.sh keystone_test
su postgres -c "psql -d keystone_test -f scripts/schema/recette_cloisonnement.sql"
```

Résultats du dernier passage et écarts relevés : `docs/lot1/Recette_base_locale.md`.
Jamais de branche Supabase ni de service facturé (CLAUDE.md règle 5), jamais la base partagée (règle 4).

#!/usr/bin/env bash
# Base Postgres locale et jetable pour éprouver le schéma v2 (CLAUDE.md règle 5 : aucune ressource payante).
# Ne jamais viser la base Supabase partagée. Usage : bash scripts/schema/base_locale.sh [nom_de_base]
set -uo pipefail
DB="${1:-keystone_test}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGS="${LOGS:-$(mktemp -d)}"
mkdir -p "$LOGS" && chmod 777 "$LOGS"

# 1. Dépendances. PostGIS et pgvector viennent de l'archive Ubuntu (gratuites) ; pg_jsonschema est bouché par supabase_stubs.sql.
if [ ! -f /usr/share/postgresql/16/extension/postgis.control ] || [ ! -f /usr/share/postgresql/16/extension/vector.control ]; then
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    postgresql-16 postgresql-16-postgis-3 postgresql-16-pgvector >/dev/null || exit 1
fi
python3 -c 'import psycopg' 2>/dev/null || python3 -m pip install -q --break-system-packages 'psycopg[binary]' || exit 1

# 2. Grappe locale.
pg_isready -q || pg_ctlcluster 16 main start || exit 1
pg_isready -q || { echo "Postgres n'écoute pas"; exit 1; }

# 3. Base neuve.
su postgres -c "dropdb --if-exists '$DB' && createdb '$DB'" || exit 1

# 4. Application dans l'ordre des dépendances (supabase/candidates/README.md).
run() {
  local f="$1" n; n="$(basename "$1" .sql)"
  su postgres -c "psql -q -d '$DB' -v ON_ERROR_STOP=1 -f '$REPO/$f'" >"$LOGS/$n.out" 2>"$LOGS/$n.err"
  local rc=$?
  printf '%-28s rc=%s\n' "$n" "$rc"
  [ $rc -eq 0 ] || { echo "ARRET : $f — voir $LOGS/$n.err"; return 1; }
}
for f in scripts/schema/supabase_stubs.sql \
         scripts/schema/correctifs_corpus.sql \
         supabase/candidates/keystone_v2_schema.sql \
         supabase/candidates/keystone_v2_error_codes.sql \
         supabase/candidates/keystone_v2_seed_reference.sql \
         scripts/schema/conventions_socle.sql \
         scripts/schema/rls_lecture.sql; do
  run "$f" || exit 2
done

# 5. Recettes. Les « ERROR » annoncés par « attendu » sont des cas négatifs voulus.
echo "--- recettes ---"
for f in scripts/schema/recette_socle.sql scripts/schema/recette_permissions.sql scripts/schema/recette_profils.sql; do
  run "$f" || true
done
echo "Base « $DB » prête. Journaux : $LOGS"
echo "Connexion : su postgres -c \"psql -d $DB\""

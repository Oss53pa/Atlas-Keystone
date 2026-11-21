# Candidats de migration (lot 0)

Fichiers **non appliqués**, rangés hors de `supabase/migrations` pour qu'aucun outil ne les exécute.

| Fichier | Contenu | Produit par |
|---|---|---|
| `keystone_v2_schema.sql` | schéma des annexes, instructions validées dans l'ordre des dépendances | `scripts/schema/emit_candidate.py` |
| `keystone_v2_seed_reference.sql` | devises XOF et XAF (I01), quatre pays | écrit à la main |
| `keystone_v2_error_codes.sql` | contenu de `keystone.error_codes` (A96) | `npm run error-codes -- <dossier 04_Design_ecrans> <sql> <json> [sql à contrôler…]` |

Ordre d'application sur une base de test : extensions, `scripts/schema/correctifs_corpus.sql`, `keystone_v2_schema.sql`,
`keystone_v2_error_codes.sql`, `keystone_v2_seed_reference.sql`, `scripts/schema/conventions_socle.sql` (RLS d'isolation, audit chaîné,
horodatage, droits), `scripts/schema/rls_lecture.sql` (lecture par module), puis les recettes
`scripts/schema/recette_socle.sql` et `scripts/schema/recette_permissions.sql`. Application à une base Supabase : seulement après zéro écart bloquant (docs/lot0 §6),
avec l'accord d'Oss53pa, d'abord sur une branche, puis hors des heures d'utilisation (CLAUDE.md, règle 4).

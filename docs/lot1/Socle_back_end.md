# Lot 1 : socle back-end, état au 21/11/2026

Base de test locale (Postgres 16) ; rien n'est appliqué à la base Supabase partagée.

## Fait et vérifié
| Élément | Constat avant | Livré | Vérification |
|---|---|---|---|
| Montants (I01 à I03) | `Money.ts` en centimes, arrondi au demi supérieur | francs entiers `bigint`, arrondi bancaire, répartition au plus fort reste, XOF et XAF jamais additionnés | 4 tests |
| Isolation par tenant | 489 tables à `tenant_id` sans RLS | RLS et politique RESTRICTIVE `tenant_isolation` sur 515 tables (`scripts/schema/conventions_socle.sql`) | recette : A et B ne voient que leurs lignes, intrusion refusée, sans jeton 0 ligne |
| Audit chaîné (A47, A87) | `tg_audit` reliée à aucune table ; `audit_pseudonymize` appelée mais absente (toute écriture aurait échoué) | trigger sur 460 tables ; C20 `audit_pseudonymize` | recette : chaîne et empreintes recalculées identiques |
| Horodatage | `tg_set_updated_at` reliée à aucune table | trigger sur 321 tables | rejeu idempotent |
| Droits PostgREST | aucun `GRANT` dans le corpus ; exécution des fonctions ouverte à PUBLIC par défaut | rien pour `anon`, tables pour `authenticated` sous RLS, journal d'audit en lecture seule | privilèges contrôlés |
| Référentiels | devises et pays vides | XOF et XAF à exposant 0, quatre pays | chargés |
| Erreurs (A69, A96) | — | `error_codes` chargée du catalogue, `raise_error`, traduction côté interface | tests |

## À valider par Oss53pa
1. **Accès par module** (`scripts/schema/rls_modules.tsv`, 492 tables) : le gabarit A.0.5 suppose des permissions `<module>.read/create/update/delete`, or le catalogue (Admin partie 2) emploie d'autres verbes (`permit.request`, `permit.approve`…) et les écritures passent par des RPC SECURITY DEFINER (Index §5). Proposition : une seule politique permissive de LECTURE par table, `has_permission('<module>.read')` (ou la première permission du module), et aucune écriture directe. Confiance : 210 haute, 152 moyenne, 130 à définir. Tant que ce n'est pas validé, les tables restent fermées (refus par défaut).
2. **Exécution des fonctions** : `authenticated` peut exécuter toutes les fonctions de `keystone` (nécessaire aux politiques) ; les fonctions réservées au worker sont à retirer une à une.
3. **16 tables à identifiant non uuid** : hors audit chaîné (`tg_audit` attend un uuid) ; journaux et tables à `bigint`, à confirmer.
4. **`audit_verify`** (RPC asynchrone, Annexe A) non écrite : dépend de sa table de suivi.

## Ordre d'application (base de test ou branche)
Voir `supabase/candidates/README.md`.

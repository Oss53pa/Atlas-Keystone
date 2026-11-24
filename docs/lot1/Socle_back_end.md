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
1. **Accès par module : décidé (lecture seule, 21/11/2026)**. `scripts/schema/rls_lecture.sql` pose une politique de lecture sur 464 tables (seconde passe validée le 21/11/2026, `docs/lot1/Seconde_passe_modules.md`), données de santé réservées à `event.medical_read` ; les autres tables ont les politiques de leurs annexes ; seule `tenant_provisioning` reste fermée (plateforme). Recette `recette_permissions.sql` : sans rôle 0 ligne, avec rôle 1 ligne, autre tenant 0 ligne. Historique de la proposition (`scripts/schema/rls_modules.tsv`, 492 tables) : le gabarit A.0.5 suppose des permissions `<module>.read/create/update/delete`, or le catalogue (Admin partie 2) emploie d'autres verbes (`permit.request`, `permit.approve`…) et les écritures passent par des RPC SECURITY DEFINER (Index §5). Proposition : une seule politique permissive de LECTURE par table, `has_permission('<module>.read')` (ou la première permission du module), et aucune écriture directe. Confiance : 210 haute, 152 moyenne, 130 à définir. Tant que ce n'est pas validé, les tables restent fermées (refus par défaut).
2. **Exécution des fonctions** : `authenticated` exécute les fonctions de `keystone` (nécessaire aux politiques), sauf les fonctions de trigger et les fonctions internes d'audit et de pseudonymisation, retirées après l'octroi global (correction d'une régression : l'octroi global avait rendu `audit_pseudonymize` exécutable). Restent à trier : les RPC SECURITY DEFINER réservées au worker (une décision par fonction).
3. **16 tables à identifiant non uuid** : hors audit chaîné (`tg_audit` attend un uuid) ; journaux et tables à `bigint`, à confirmer.
4. **`audit_verify`** (RPC asynchrone, Annexe A) non écrite : dépend de sa table de suivi.

## Ordre d'application (base de test ou branche)
Voir `supabase/candidates/README.md`.

## Essai réel sur Supabase (24/11/2026)
Branche `keystone-v2-socle` (PostgreSQL 17.12), schéma appliqué par l'API de gestion Supabase (jeton temporaire, injecté par le proxy de la session, jamais lu) : extensions, `correctifs_corpus.sql`, schéma candidat, codes d'erreur, référentiels, `conventions_socle.sql`, `rls_lecture.sql` : 7 envois réussis.
Constaté : 572 tables, 515 politiques d'isolation, 464 politiques de lecture, 460 audits chaînés, 321 horodatages, 623 codes d'erreur, XOF et XAF à exposant 0 ; `anon` sans accès ; `audit_pseudonymize` non exécutable par `authenticated`.
Recette (`scripts/schema/recette_supabase.sql`, bloc annulé) : sans rôle 0 ligne, avec rôle 1 ligne, intrusion refusée, écriture du journal refusée, jeton d'un autre tenant 0 ligne, 8 lignes d'audit à chaîne et empreintes valides. Aucune donnée de test restante.

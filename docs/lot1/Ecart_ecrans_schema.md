# Écart entre les écrans actuels et le schéma v2 (24/11/2026)

Inventaire des appels `.from()` et `.rpc()` de `apps/web/src`, comparés au schéma candidat appliqué sur une base locale.
Résultat : **49 objets sur 58 sont absents du schéma v2**. Les écrans « vivants » ont été écrits pour l'ancien schéma, toujours en production ;
leurs RPC d'agrégation (`*_board`, `*_summary`) n'existent pas dans le corpus, qui définit ses propres RPC et vues par lot.
Rebrancher n'est donc pas une correction mécanique : chaque écran se reconstruit sur la fiche de son lot (cahier des charges, 04_Design_ecrans).

| Fichier | Objets absents / appelés |
|---|---|
| `data/agents.ts` | 2 / 2 |
| `data/assets.ts` | 6 / 6 |
| `data/budget.ts` | 1 / 1 |
| `data/cockpit.ts` | 4 / 4 |
| `data/contractors.ts` | 7 / 7 |
| `data/crp.ts` | 3 / 3 |
| `data/documents.ts` | 3 / 3 |
| `data/gmao.ts` | 3 / 4 |
| `data/governance.ts` | 3 / 4 |
| `data/leases.ts` | 1 / 2 |
| `data/notifications.ts` | 4 / 5 |
| `data/portal.ts` | 3 / 3 |
| `data/report.ts` | 3 / 3 |
| `data/search.ts` | 1 / 1 |
| `data/space.ts` | 2 / 2 |
| `data/tickets.ts` | 2 / 2 |
| `data/utilities.ts` | 2 / 2 |
| `features/wo-templates/WoTemplates.tsx` | 0 / 1 |
| `lib/profiles.ts` | 0 / 4 |

Objets absents : `accounting_accounts`, `approval_thresholds`, `center_news`, `company_profile`, `evaluation_weights`, `notification_channels`, `notification_events`, `notification_quiet_hours`, `notification_templates`, `service_requests`, `utility_tariff_bands`, `utility_tariffs`, `agent_journal`, `approve_invoice`, `assets_board`, `attention_feed`, `budget_overview`, `cockpit_summary`, `contractor_scorecards`, `contractors_board`, `convert_ticket_to_wo`, `create_ticket_public`, `crp_board`, `crp_summary`, `demo_kpi`, `demo_summary`, `evaluation_submit`, `failure_library_families`, `failure_pareto`, `fmea_board`, `fmea_create_action`, `fmea_from_library`, `global_search`, `invoices_board`, `live_presence`, `next_ref`, `pay_invoice`, `posture`, `predictions_board`, `publish_report`, `qr_context_public`, `record_crp_result`, `report_latest`, `run_agents_now`, `run_reporting_now`, `sla_measures`, `space_inventory`, `space_summary`, `track_ticket_public`.

Contrainte : aucune ressource payante (CLAUDE.md règle 5). Docker est installé dans la session mais sans démon : pas de pile Supabase locale. Seule la base Postgres locale sert aux essais.

# Préparation de la reconstruction des OT sur le schéma v2 (24/11/2026)

Relevé sur la base locale (`scripts/schema/base_locale.sh`). Décision d'Oss53pa du 24/11/2026 : **les OT d'abord, le
tableau de bord en dernier**, le tableau de bord n'étant qu'une projection des modules qui l'alimentent.

## 1. Le v2 n'agrège pas par RPC, il agrège par vues

[Confirmé] : le schéma v2 ne définit **aucune** fonction dont le nom contienne `board`, `summary`, `kpi` ou `feed`.
Il expose 41 vues, dont les vues d'agrégat `v_*` (`v_ticket_queue`, `v_assets_fleet`, `v_capa_list`,
`v_occupant_work_orders`, `v_vendor_work_orders`…). Les écrans actuels, eux, appellent 1 RPC d'agrégat par écran
(`demo_kpi`, `demo_summary`, `predictions_board`, `cockpit_summary`, `attention_feed`…).

Conséquence : l'écart relevé dans `Ecart_ecrans_schema.md` (49 objets sur 58 absents) n'est pas une liste d'objets à
créer, c'est **un changement de contrat**. Chaque écran se rebranche sur les vues et les tables de son lot, et ne
reçoit un RPC que là où la fiche en prévoit un (écriture, transition, calcul transactionnel).

## 2. Ce que le v2 fournit déjà pour les OT

| Objet | Rôle |
|---|---|
| `work_orders` | 130 colonnes : cycle de vie, diagnostic ISO 14224, SLA, coûts, visas, réception |
| `work_order_lines`, `work_order_team`, `worked_hours`, `wo_work_sessions` | exécution et temps passés |
| `wo_transitions_log`, `wo_reschedules`, `wo_scan_log` | traçabilité des changements d'état |
| `wo_instructions`, `wo_checkpoint_results`, `wo_reports` | contenu d'intervention et comptes rendus |
| `wo_required_competencies`, `wo_required_permits`, `wo_required_tools`, `work_permits` | prérequis et permis |
| `wo_templates`, `wo_template_tasks`, `wo_template_parts`, `v_wo_templates_for_site` | gammes |
| `work_centers`, `work_center_categories`, `work_units` | affectation |
| `v_occupant_work_orders`, `v_vendor_work_orders` | listes cloisonnées occupant et prestataire |
| `consume_part`, `wo_punch`, `pr_link_work_order`, `assert_regulatory_wo_closable`, `wo_stage_status_ok` | écritures et garde-fous (permissions arbitrées en C21 à C23) |

## 3. Écart exact de l'écran existant

`apps/web/src/data/gmao.ts` ligne 18 lit `work_orders` avec :
`id, ref, title, type, status, priority, requires_permit, sla_due, planned_start, cost_labor, cost_parts,
assets(tag,name), locations(name)`.

- **Compatible en v2** : toutes ces colonnes existent, et `assets(tag, name)` comme `locations(name)` aussi.
- **Seule colonne absente** : `sla_due`. Le v2 en distingue trois — `sla_response_due`, `sla_resolution_due`,
  `client_sla_due` — plus `sla_response_met`, `sla_resolution_met`, `client_sla_met` et `sla_paused`. Laquelle la
  liste affiche, et ce qu'elle affiche quand l'horloge est en pause, est une décision de fiche (04_Design_ecrans) :
  **à trancher avant d'écrire**, pas à deviner.
- **RPC absents** : `demo_kpi`, `demo_summary`, `predictions_board`. À remplacer par des vues, ou par les RPC que la
  fiche OT définit.

## 4. Ce qui manque pour aller plus loin

Les fiches `04_Design_ecrans` du cahier des charges. Sans elles, l'en-tête de liste, les filtres, les colonnes, les
états vides, les actions et les codes d'erreur affichés ne peuvent être qu'inventés — ce que la hiérarchie fixée par
Oss53pa interdit (la maquette fait foi pour le design, le cahier des charges pour les processus).

Deux écarts de schéma, relevés dans `Recette_base_locale.md`, touchent les OT indirectement :
les 31 tables filles sans RLS (dont `move_work_orders`, `qc_reworks`) et les 7 tables partitionnées sans partition
(dont `usage_events`, qui trace l'usage des écrans).

# Supabase — schéma `keystone` (Socle + GMAO + HSSE)

> **Statut : appliqué en live.** Les migrations ci-dessous sont **déjà appliquées** sur le projet Supabase
> **« ATLAS STUDIO — SCHEMA COMPLET »** (`vgtmljfayiysuvrcmunt`, région `eu-west-1`), dans un schéma
> **`keystone`** isolé (+ `atlas_core` minimal). Elles n'altèrent **aucune** des tables existantes
> (`public`, `atlas_people`, `atlasbanx`). Réversible : `DROP SCHEMA keystone CASCADE; DROP SCHEMA atlas_core CASCADE;`.

## Migrations appliquées (table `supabase_migrations.schema_migrations`)

| # | Nom | Contenu |
|---|-----|---------|
| 1 | `keystone_01_schemas_core_helpers` | schémas `atlas_core`/`keystone`, extension `pgcrypto`, `atlas_core` minimal, helpers (`current_tenant`, `next_ref`, `set_updated_at`, `has_permission`, `current_contractor`), énumérations (GMAO + HSSE) |
| 2 | `keystone_02_socle_rbac_rls` | Socle : sites→…→locations, actifs & composants & identifiants, personnes, compétences, prestataires, planning (shifts/on_call/time_off), RBAC, **RLS générique** d'isolation tenant |
| 3 | `keystone_03_audit_trail` | piste d'audit **chaînée SHA-256** (`audit_row()`) |
| 4 | `keystone_04_gmao` | **Annexe B** : OT, lignes, plans (calendaire/meter/predictive), pm_tasks, stocks, mouvements, compteurs, contrats. RPC `wo_transition` (interlock permis, séparation des tâches, affectation), `consume_part` (atomique), `record_meter_reading` (conditionnel anti-doublon), `person_assignable`. RLS prestataire scellée. |
| 5 | `keystone_05_hsse` | **Annexe C** : événements, investigations (5 Pourquoi/Ishikawa/Bowtie), CAPA + **porte d'efficacité** (`capa_transition`), permis + **interlock LOTO zéro énergie** (`permit_activate`, `gas_tests_valid`), `event_transition`, CRP (`create_capa_from_control`), audits/DUER |
| 6 | `keystone_06_api_exposure_demo_rpc` | RPC de démo `SECURITY DEFINER` lecture seule (`demo_work_orders`, `demo_summary`) + exposition du schéma `keystone` à PostgREST |

> Le seed (tenant démo + données Cosmos + cas de test interlocks) a été inséré via `execute_sql` (non versionné).

## Pour récupérer le SQL exact en local

```bash
supabase link --project-ref vgtmljfayiysuvrcmunt
supabase db pull --schema keystone,atlas_core   # régénère les fichiers .sql ici
```

## Interlocks de sécurité — vérifiés en base (Definition of Done)

Tous prouvés par tentative de contournement directe des RPC :

| Invariant | Code d'erreur |
|---|---|
| OT à risque sans permis actif | `PERMIT_REQUIRED` |
| Permis activé sans consignation zéro-énergie | `ISOLATION_NOT_VERIFIED` |
| Espace confiné sans tests d'atmosphère valides | `GAS_TEST_REQUIRED` |
| Exécutant vérifie son propre OT | `SEGREGATION_OF_DUTIES` |
| Stock insuffisant | `INSUFFICIENT_STOCK` |
| Clôture CAPA inefficace | `NOT_EFFECTIVE` |
| Compteur > seuil | OT conditionnel unique (anti-doublon) |
| Transition d'état illégale | `INVALID_TRANSITION` |

## Tenant démo

`a0000000-0000-4000-8000-000000000001` (New Heaven SA) — Cosmos Yopougon / Angré, actifs GF-02 & ASC-A3.

## Notes de fidélité aux annexes
- Les annexes appellent `auth.current_tenant()` → implémenté en `keystone.current_tenant()` (lit le claim JWT `tenant_id`, fallback GUC `keystone.tenant_id`) pour ne pas modifier le schéma `auth` géré par Supabase.
- `capa_status` / `permit_status` suivent la version de l'**Annexe C** (plus détaillée que le §6.2 du CDC).
- RLS = `keystone.current_tenant()`. GUC de test : `keystone.bypass_rbac`.

## Lot « Enrichissement WiseFM » (2026-10-02) — **fichiers prêts, NON appliqués**

Fonctionnalités portées depuis WiseFM (`C:\devs\wise_fm`), améliorées pour Keystone. À appliquer dans l'ordre (chaque `b` = seed démo idempotent) :

| Fichier | Contenu |
|---|---|
| `20261002_keystone_26_assets_amdec.sql` (+26b) | Fiche actif enrichie, **AMDEC IEC 60812** (RPN généré, RPN révisé, gravité ≥ 9 ⇒ critique), `assets_board()` avec **indice de santé** explicable, `fmea_create_action()` → OT préventif brouillon |
| `20261002_keystone_27_procurement_stock.sql` (+27b) | Stock (min/max/point de commande, couverture réelle 90 j), **DA à paliers FCFA** (500 k / 5 M), contrôle budgétaire OK/LIMIT/OVER → `INSUFFICIENT_BUDGET`, `SEGREGATION_OF_DUTIES`, BC TVA 18 %, réception QC → entrée stock, agent Réappro `pr_from_stock_alerts()` |
| `20261002_keystone_28_energy_carbon.sql` (+28b) | Relevés énergie/eau/fluides, **facteurs d'émission par pays** (indicatifs à remplacer), scopes 1-2-3, EnPI kWh/m², objectifs cible/alerte/critique |
| `20261002_keystone_29_inspections_nc.sql` (+29b) | Modèles de ronde typés, `inspection_submit()` (score pondéré, NC auto, OT si NC critique), `nc_transition()` avec `ACTION_REQUIRED` |
| `20261002_keystone_30_failure_library_pareto.sql` (+30b) | Bibliothèque 60 modes de défaillance (15 familles, G/O/D suggérés, code ISO 14224), `fmea_from_library()`, `failure_pareto()` 80/20 (fréquence/coût/arrêt) ; 30b = 12 mois d'OT correctifs |
| `20261002_keystone_31_contractor_sla.sql` (+31b) | SLA contractuels **mesurés sur les OT**, pénalités FCFA plafonnées, `contractor_scorecards()` (60 % SLA + 40 % grille pondérée, note A–D), préavis de renouvellement, `evaluation_submit()` |
| `20261002_keystone_32_preventive_afnor.sql` (+32b) | Gammes à **niveau AFNOR NF X60-000** (1–5) + garde-fou `LEVEL_COMPETENCY`, étapes avec points de contrôle, `pm_board()` échéancier/conformité, `pm_workload()` charge vs capacité, `pm_generate_horizon()` |
| `20261002_keystone_33_waste_register.sql` (+33b) | Registre déchets 8 flux, `BSD_REQUIRED` / `OPERATOR_NOT_APPROVED`, taux de valorisation, CO₂e déchets (indicatif), objectifs à statut calculé |
| `20261002_keystone_34_contractor_portal.sql` (+34b) | Portail prestataire : devis, avenants (escalade > 20 %), rapports photos avant/après + signature client, anomalies → OT de suivi, pauses SLA arbitrées ; **policy RLS restrictive par prestataire** |

Points à vérifier à l'application (schéma existant non relu) : valeurs de `maintenance_plans.trigger_type`/`interval_unit`, contraintes de `wo_transition` sur les OT insérés en seed, signature de `keystone.next_ref(text)`, valeurs de `stock_movements.direction` (`in`/`out`), colonnes NOT NULL éventuelles de `work_orders`, `keystone.budget_line_available(uuid)`.

## Espace prestataire (2026-10-03)

| Fichier | Contenu |
|---|---|
| `20261002_keystone_26c_sync_ref_counters.sql` | Recale `ref_counters` sur les références existantes (appliqué via APPLY v5) |
| `20261002_keystone_35_fixes.sql` | `next_ref` insensible à la casse, portail filtré, surfaces agrégées (appliqué) |
| `20261003_keystone_36_contractor_app.sql` | `portal_me()`, `portal_contractors()`, bucket privé `keystone-wo-photos` + policies (tenant + OT du prestataire) |

Procédure : le mode auto de Claude Code bloque les écritures sur ce projet partagé → coller le fichier dans le SQL Editor (projet `vgtmljfayiysuvrcmunt`, sans sélection active), puis vérification en lecture seule.

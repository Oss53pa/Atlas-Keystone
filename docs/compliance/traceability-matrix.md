# Atlas Keystone — Matrice de traçabilité normative (modules livrés)

> Norme → exigence → objet implémenté (table / RPC / écran) → **preuve vérifiable**.
> Portée de ce document : ce qui est **réellement construit et appliqué en live** (Socle + GMAO Annexe B + HSSE Annexe C + KPI EN 15341 + GED). Les modules non encore construits (Space, Soft FM, PROPH3T/agents) sont listés §X comme écarts ouverts.
> Backend : projet Supabase `vgtmljfayiysuvrcmunt`, schéma `keystone`. Tenant démo `a0000000-0000-4000-8000-000000000001`.

## A. Maintenance & actifs

| Norme | Exigence | Implémentation | Preuve |
|---|---|---|---|
| **EN 13306** | Vocabulaire normalisé des types de maintenance | enum `keystone.wo_type` (corrective, preventive, conditional, predictive, regulatory) | migration 1 |
| **ISO 55001** | Cycle de vie de l'actif | `keystone.assets` (acquisition/book value, criticité), `asset_components`, `maintenance_contracts` (EN 13269) | migration 2/4 |
| **ISO 14224** | Données de fiabilité (modes/mécanismes de défaillance) | `keystone.failure_modes` (code, mechanism, taxonomy_class) + `work_orders.failure_mode_id/failure_class/downtime_hours` | migration 7 |
| **EN 13460** | Documents de maintenance | GED `keystone.documents` + `document_versions` (rattachement entité, version, sha256) | migration 7 |
| **EN 15341** | KPI maintenance — formules normalisées | RPC `keystone.kpi_maintenance()` déterministe ; canon TS `@keystone/domain/kpi.ts` | `SELECT keystone.demo_kpi()` → MTBF 1946.7h, MTTR 3.22h, dispo 99.83%, %prév 57.7% |

## B. SST / Sécurité (ISO 45001, IEC 31010, ISO 14118)

| Norme | Exigence | Implémentation | Preuve (interlock testé) |
|---|---|---|---|
| **IEC 31010** | Techniques d'appréciation du risque | `investigation_method` (five_why, ishikawa, **bowtie**, fault_tree) + `root_causes`, `bowtie_nodes` | migration 5 |
| **ISO 14118** | Consignation des énergies (LOTO) — zéro énergie vérifié | `permit_isolations.zero_energy_verified` ; garde `permit_activate()` | `ISOLATION_NOT_VERIFIED` (test 2) |
| **ISO 45001 §8.1.2** | Hiérarchie des contrôles | enum `control_hierarchy` (elimination→ppe) sur `capa_actions` | migration 5 |
| **ISO 45001 §8 (PTW)** | Interlock permis de travail | garde `wo_transition` : OT à risque bloqué sans permis `active` | `PERMIT_REQUIRED` (test 1) |
| **OSHA confined space** | Tests d'atmosphère valides | `gas_tests_valid()` (O₂/LIE/H₂S/CO + fraîcheur 60 min) | `GAS_TEST_REQUIRED` |
| **ISO 45001 §10.2** | CAPA avec **vérification d'efficacité** | porte d'efficacité `capa_transition` (closed ⇐ verifying + effective) | `NOT_EFFECTIVE` (test 7) |
| **ISO 9001 (SoD)** | Séparation des tâches | vérificateur ≠ exécutant dans `wo_transition` | `SEGREGATION_OF_DUTIES` (test 6) |
| **ISO 31000** | DUER — risque brut/résiduel | `risk_register` (gross_risk, residual_risk, review_due) | migration 5 |

## C. Audit & conformité (ISO 19011)

| Norme | Exigence | Implémentation | Preuve |
|---|---|---|---|
| **ISO 19011** | Programme d'audit, écarts → action | `audits`, `audit_findings` (severity NC, `capa_id`), `compliance_requirements` | migration 5 |
| **CRP (EN 81 / EN 54 / local)** | Échéancier réglementaire, NC → CAPA | `regulatory_controls`, `create_capa_from_control()` (déclasse l'actif si ascenseur) | migration 5 |

## D. Produit logiciel (ISO/IEC 27001:2022)

| Norme | Exigence | Implémentation | Preuve |
|---|---|---|---|
| **27001 A.5.15-18** | Contrôle d'accès, moindre privilège | RLS 100 % par `tenant_id` ; anon n'a QUE les RPC démo (pas d'accès table) ; `service_role` jamais côté client | migrations 2/4/5/6 |
| **27001 (intégrité)** | Journal inaltérable | `audit_trail` chaîné **SHA-256** (`hash = sha256(before‖after‖prev_hash)`) sur work_orders / hsse_events / work_permits / capa_actions | migration 3 |
| **ISO 30301** | Records management (conservation) | `documents.retention_until` + versionnage `document_versions` | migration 7 |
| **WCAG 2.2 AA** | Accessibilité | design system Keystone UI (contrastes, focus ambre, cibles ≥44/56px, prefers-reduced-motion) | `@keystone/ui` |

## X. Écarts normatifs ouverts (modules non construits)
- **ISO 14224** : taxonomie complète (niveaux 1-9) + historique de défaillance par composant — *partiel* (modes de défaillance créés, pas l'arbre taxonomique complet).
- **EN 15341** : KPI live branchés sur l'écran GMAO ✅ ; reste à brancher l'onglet Maintenance de la Tour de contrôle (encore en démo).
- **ISO 45003** (psychosocial), **ISO 7010** (mapping signalétique) — non modélisés.
- **ISO/IEC 42001** (PROPH3T / agents) — `agent_actions` & garde-fous non construits (Annexe H).
- **EN 15221-6 / IPMS** (Space Management), **EN 13549 / INSTA 800 / EN 16636** (Soft FM) — annexes à venir.
- **Auth multi-tenant** (claim JWT `tenant_id` + RLS app) : lecture live via RPC démo pour l'instant.

*Version 1.0 — à étendre à chaque module livré. Éditions des normes à revérifier avant toute certification.*

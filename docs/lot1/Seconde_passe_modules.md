# Lot 1 : seconde passe des modules, à valider

130 tables auparavant « À DÉFINIR », donc fermées. Règle décidée : lecture seule, aucune écriture directe. Rattachement par clé étrangère vers une table déjà rattachée (61), par annexe propriétaire (61), par le sens du nom (7) ; `tenant_provisioning` reste fermée (plateforme).

Rien n'est appliqué avant validation. Après accord, `scripts/schema/rls_lecture.sql` est régénéré avec ces tables.

| Module | Permission de lecture | Tables (méthode) |
|---|---|---|
| settings | `settings.manage` | `account_access_review_items` (annexe), `account_access_reviews` (annexe), `bulk_operations` (sens du nom), `email_suppressions` (clé étrangère), `email_templates` (annexe), `mode_change_plans` (sens du nom), `object_comments` (annexe), `push_subscriptions` (annexe), `session_profiles` (annexe), `tenant_branding` (annexe), `tenant_domains` (annexe), `tenant_onboarding_steps` (annexe), `tenant_surfaces` (annexe), `undo_tokens` (annexe) |
| event | `event.read` | `investigation_members` (annexe), `investigation_timeline` (annexe), `investigations` (clé étrangère), `lessons_learned` (clé étrangère), `medical_visits` (annexe), `occupational_diseases` (clé étrangère), `root_causes` (annexe), `safety_alerts` (clé étrangère), `witness_statements` (clé étrangère) |
| wo | `wo.read` | `device_sessions` (annexe), `maintenance_plan_skips` (clé étrangère), `occupational_exposures` (clé étrangère), `pm_task_checkpoints` (annexe), `pm_task_parts` (annexe), `sla_pauses` (clé étrangère), `sla_policies` (annexe), `sync_conflicts` (annexe), `sync_mutations` (annexe) |
| asset | `asset.read` | `leak_alerts` (clé étrangère), `maintenance_contract_scope` (clé étrangère), `maintenance_plan_assets` (clé étrangère), `maintenance_plans` (clé étrangère), `refrigerant_check_rules` (annexe), `samp` (clé étrangère), `sectors` (clé étrangère), `video_requisitions` (clé étrangère) |
| person | `person.read` | `hsse_objective_measures` (annexe), `hsse_objectives` (annexe), `job_positions` (annexe), `maintenance_levels` (clé étrangère), `management_review_participants` (annexe), `management_reviews` (annexe), `pm_tasks` (clé étrangère) |
| site | `site.read` | `bait_stations` (clé étrangère), `business_calendar_days` (annexe), `business_calendars` (annexe), `checkpoints` (clé étrangère), `loading_docks` (clé étrangère), `pseudonym_map` (annexe), `public_report_points` (clé étrangère) |
| budget | `budget.read` | `approval_delegations` (annexe), `approval_steps` (annexe), `goods_receipt_lines` (annexe), `purchasing_category_thresholds` (clé étrangère), `purchasing_settings` (annexe), `shipment_notice_lines` (annexe) |
| report | `report.read` | `fm_context_issues` (annexe), `fm_management_reviews` (clé étrangère), `fm_objective_actions` (annexe), `fm_objectives` (annexe), `fm_policies` (annexe), `fm_review_inputs` (annexe) |
| space | `space.read` | `area_classes` (annexe), `atelier_drafts` (clé étrangère), `floor_measurements` (clé étrangère), `level_outlines` (clé étrangère), `measurement_surveys` (annexe), `tenant_lot_prefixes` (annexe) |
| ai | `ai.read` | `anomalies` (clé étrangère), `copilot_messages` (clé étrangère), `embeddings` (annexe), `predictions` (clé étrangère) |
| capa | `capa.assign` | `bowtie_nodes` (clé étrangère), `controls` (clé étrangère), `fm_review_outputs` (clé étrangère), `management_review_decisions` (clé étrangère) |
| client | `client.read` | `action_items` (clé étrangère), `billable_items` (clé étrangère), `data_exports` (clé étrangère), `fm_stakeholders` (clé étrangère) |
| purchase | `purchase.approve` | `goods_receipts` (clé étrangère), `po_change_proposals` (clé étrangère), `po_lines` (clé étrangère), `shipment_notices` (clé étrangère) |
| doc | `doc.read` | `disposal_records` (clé étrangère), `legal_hold_documents` (annexe), `legal_holds` (annexe) |
| fmea | `fmea.manage` | `am_decision_criteria` (annexe), `am_objectives` (annexe), `pm_task_failure_modes` (clé étrangère) |
| occupant | `occupant.manage` | `loading_dock_bookings` (clé étrangère), `mail_parcels` (clé étrangère), `public_report_attempts` (annexe) |
| permit | `permit.request` | `duer_versions` (annexe), `lockboxes` (annexe), `prevention_plan_risks` (annexe) |
| stock | `stock.read` | `cycle_count_lines` (clé étrangère), `cycle_counts` (clé étrangère), `supplier_catalog_items` (clé étrangère) |
| env | `env.manage` | `emission_factors` (sens du nom), `emissions` (sens du nom) |
| inspection | `inspection.manage` | `legal_obligations` (annexe), `obligation_control_map` (annexe) |
| planning | `planning.read` | `saved_views` (clé étrangère), `time_off` (annexe) |
| privacy | `privacy.manage` | `dpia_assessments` (annexe), `retention_runs` (annexe) |
| FERMÉE (plateforme) | `aucune` | `tenant_provisioning` (décision : service_role seulement) |
| access | `access.manage` | `visits` (clé étrangère) |
| audit | `audit.manage` | `auditees` (clé étrangère) |
| booking | `booking.approve` | `utilization_recommendation_dismissals` (clé étrangère) |
| calendar | `calendar.read` | `holiday_rules` (sens du nom) |
| compliance | `compliance.manage` | `fm_requirements` (clé étrangère) |
| cost | `cost.read` | `fm_cost_periods` (annexe) |
| crp | `crp.manage` | `control_reserves` (clé étrangère) |
| energy | `energy.manage` | `normalization_factors` (annexe) |
| fire | `fire.record` | `ssi_inhibitions` (clé étrangère) |
| fitout | `fitout.approve` | `prevention_plans` (clé étrangère) |
| iot | `iot.read` | `telemetry_dashboards` (annexe) |
| parking | `parking.manage` | `vehicles` (sens du nom) |
| permit | `permit.activate` | `confined_space_entries` (clé étrangère) |
| pest | `pest.manage` | `bait_station_checks` (clé étrangère) |
| risk | `risk.manage` | `hazards` (sens du nom) |
| role | `role.manage` | `approval_levels` (clé étrangère) |
| vendor | `vendor.read` | `maintenance_contracts` (clé étrangère) |
| visitor | `visitor.denylist_manage` | `physical_access_reviews` (annexe) |

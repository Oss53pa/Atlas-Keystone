# Lot 0 : écarts entre la base et les annexes back-end

Rapport du 21/11/2026, en lecture seule. Base : projet Supabase « Atlas Studio - Autres Applications », schémas `keystone`, `atlas_core`, `atlas_public`. Référence : 49 fichiers d’annexes du dossier « Atlas_Keystone_Claude_Code » (rang 2 de la hiérarchie de foi). Aucune écriture en base.

Méthode : extraction automatique des `CREATE TABLE`, `CREATE TYPE` et `CREATE FUNCTION` des annexes, comparée au catalogue Postgres (tables, énumérations, fonctions). Une table présente des deux côtés sous le même nom n’est pas vérifiée colonne par colonne dans ce rapport.

## 1. Chiffres

| Objet | Annexes | Base | Communs | Base seule | Annexes seules |
|---|---|---|---|---|---|
| Tables | 563 | 135 | 68 | 67 | 495 |
| Énumérations et domaines | 317 | 24 | 5 | 19 | 312 |

La base couvre 12 % des tables des annexes.

## 2. Invariants et arbitrages violés

| Règle | Constat en base | Gravité |
|---|---|---|
| I01, montants en `bigint` à l’unité de la devise, « aucun `numeric(18,2)` pour un montant » | 48 colonnes de montant en `numeric` (ex. `work_orders.cost_labor`, `budgets.amount`, `payments.amount`, `contractor_invoices.amount` en `numeric(18,2)`), 1 seule en entier | bloquant |
| I05, frontières : baux et lots chez Atlas Patrimoine, comptabilité chez Atlas FNA | tables `leases`, `lessees`, `lease_spaces`, `rent_schedules`, `rent_payments`, `charge_pools`, `accounting_accounts` et RPC `accounting_*`, `rent_*` dans `keystone` | bloquant |
| A96 et A69, erreurs levées par `keystone.raise_error(code, detail)` seule, table `keystone.error_codes` chargée du catalogue | ni la fonction ni la table n’existent | bloquant |
| Annexe CO, référentiel spatial dans `atlas_core` | sites, bâtiments et niveaux dans `keystone` | structurant |

## 3. Correspondances probables de noms

| Base | Annexes | Domaine |
|---|---|---|
| `keystone.sites`, `buildings`, `floors` | `atlas_core.sites`, `atlas_core.buildings`, `atlas_core.levels`, `atlas_core.spaces` | référentiel spatial dans `atlas_core` (Annexe CO) |
| `keystone.contractors` | `keystone.vendors` (et `vendor_*`) | tiers |
| `keystone.service_requests`, `ticket_messages` | `keystone.tickets`, `ticket_comments`, `ticket_status_history` | tickets (Annexe D) |
| `keystone.keystone_roles`, `keystone_permissions` | `keystone.roles`, `keystone.permissions` | RBAC (Annexe Admin) |
| `keystone.fmea_items`, `failure_modes`, `failure_mode_library` | `keystone.fmea_studies`, `fmea_modes`, `fmea_scales`, `fmea_reviews` | AMDEC (Annexe AM) |
| `keystone.documents`, `document_versions` | `keystone.ged_documents` | GED (Annexe G) |
| `keystone.leases`, `lessees`, `rent_*`, `charge_pools` | aucune : baux et lots relèvent d’Atlas Patrimoine (I05) | frontière |
| `keystone.accounting_accounts` et RPC `accounting_*` | aucune : la comptabilité relève d’Atlas FNA (I05) | frontière |

## 4. Données présentes

1 tenant, 63 ordres de travail, 8 baux et 8 preneurs : données de démonstration, d’après leur volume ; à confirmer par Oss53pa avant toute décision.

## 5. Décision à prendre

1. Reconstruire depuis les annexes (recommandé) : nouveau schéma conforme, chargé en un lot hors des heures d’utilisation (CLAUDE.md, règle 4) ; les écrans existants sont rebranchés domaine par domaine ; l’ancien schéma reste en lecture le temps de la bascule, puis est supprimé.
2. Adapter l’existant par migrations successives : plus de 400 tables à créer, des dizaines à renommer, 48 colonnes de montant à convertir ; risque élevé de garder des écarts invisibles.

Dans les deux cas : vérifier d’abord que le schéma des annexes s’exécute (Index, lot 0 : « jamais exécuté sur une base Supabase »), sur une branche Supabase ou un projet de test, jamais d’abord sur la base partagée.

## Annexe A. Tables en base absentes des annexes (67)

`keystone.accounting_accounts`, `keystone.agent_actions`, `keystone.agent_config`, `keystone.approval_thresholds`, `keystone.budget_lines`, `keystone.buildings`, `keystone.center_news`, `keystone.charge_pools`, `keystone.commitments`, `keystone.company_profile`, `keystone.contract_slas`, `keystone.contractor_certifications`, `keystone.contractor_invoices`, `keystone.contractors`, `keystone.document_versions`, `keystone.documents`, `keystone.energy_readings`, `keystone.evaluation_weights`, `keystone.failure_mode_library`, `keystone.failure_modes`, `keystone.floors`, `keystone.fmea_items`, `keystone.keystone_permissions`, `keystone.keystone_roles`, `keystone.lease_rent_history`, `keystone.lease_spaces`, `keystone.leases`, `keystone.lessees`, `keystone.non_conformities`, `keystone.notification_channels`, `keystone.notification_events`, `keystone.notification_outbox`, `keystone.notification_quiet_hours`, `keystone.notification_templates`, `keystone.payments`, `keystone.pest_control_logs`, `keystone.plan_steps`, `keystone.privacy_requests`, `keystone.purchase_order_lines`, `keystone.ref_counters`, `keystone.rent_payments`, `keystone.rent_schedules`, `keystone.reports`, `keystone.sensor_streams`, `keystone.service_plans`, `keystone.service_quality_checks`, `keystone.service_requests`, `keystone.service_visits`, `keystone.site_contacts`, `keystone.sites`, `keystone.space_units`, `keystone.supplier_invoice_lines`, `keystone.supplier_invoices`, `keystone.ticket_messages`, `keystone.user_prefs`, `keystone.utility_meter_readings`, `keystone.utility_meters`, `keystone.utility_rebills`, `keystone.utility_tariff_bands`, `keystone.utility_tariffs`, `keystone.waste_objectives`, `keystone.wo_anomalies`, `keystone.wo_quote_items`, `keystone.wo_quotes`, `keystone.wo_sla_pauses`, `keystone.wo_time_entries`, `keystone.wo_variations`

## Annexe B. Énumérations en base absentes des annexes (19)

`keystone.asset_criticality`, `keystone.budget_type`, `keystone.capa_status`, `keystone.capa_type`, `keystone.control_hierarchy`, `keystone.control_result`, `keystone.event_severity`, `keystone.event_status`, `keystone.event_type`, `keystone.identifier_type`, `keystone.investigation_method`, `keystone.invoice_status`, `keystone.permit_status`, `keystone.risk_level`, `keystone.service_visit_status`, `keystone.space_unit_type`, `keystone.ticket_status`, `keystone.wo_status`, `keystone.wo_type`

## Annexe C. Tables des annexes absentes de la base (495)

`atlas_core.buildings`, `atlas_core.currencies`, `atlas_core.identity_provider_domains`, `atlas_core.identity_providers`, `atlas_core.levels`, `atlas_core.operating_mode_changes`, `atlas_core.owner_transfers`, `atlas_core.platform_events`, `atlas_core.platform_maintenance_windows`, `atlas_core.sites`, `atlas_core.space_code_history`, `atlas_core.space_lineage`, `atlas_core.spaces`, `atlas_core.spatial_events`, `atlas_core.subscription_products`, `atlas_core.subscriptions`, `atlas_public.public_email_log`, `keystone.access_events`, `keystone.access_log`, `keystone.access_log_heads`, `keystone.access_rights`, `keystone.access_zones`, `keystone.account_access_review_items`, `keystone.account_access_reviews`, `keystone.action_items`, `keystone.agent_controls`, `keystone.agent_definitions`, `keystone.agent_runs`, `keystone.ai_data_routes`, `keystone.ai_models`, `keystone.am_decision_criteria`, `keystone.am_objectives`, `keystone.announcement_reads`, `keystone.announcement_targets`, `keystone.anomalies`, `keystone.api_events`, `keystone.api_scopes`, `keystone.api_tokens`, `keystone.api_usage_hourly`, `keystone.approval_delegations`, `keystone.approval_levels`, `keystone.approval_steps`, `keystone.area_class_bases`, `keystone.area_classes`, `keystone.asset_action_links`, `keystone.asset_category_attributes`, `keystone.asset_category_required_docs`, `keystone.asset_criticality_assessments`, `keystone.asset_data_requirements`, `keystone.asset_downtimes`, `keystone.asset_lifecycle_cost_items`, `keystone.asset_lifecycle_costs`, `keystone.asset_management_policy`, `keystone.asset_observations`, `keystone.asset_positions`, `keystone.asset_record_events`, `keystone.asset_served_spaces`, `keystone.asset_spare_parts`, `keystone.asset_status_history`, `keystone.asset_warranties`, `keystone.atelier_draft_spaces`, `keystone.atelier_drafts`, `keystone.atelier_operations`, `keystone.atelier_queue`, `keystone.audit_anchors`, `keystone.audit_criteria`, `keystone.audit_heads`, `keystone.audit_integrity_runs`, `keystone.audit_personal_fields`, `keystone.audit_programs`, `keystone.audit_schedule_slots`, `keystone.audit_team`, `keystone.auditees`, `keystone.bait_station_checks`, `keystone.bait_stations`, `keystone.billable_items`, `keystone.bookable_resources`, `keystone.booking_policies`, `keystone.booking_series`, `keystone.booking_services`, `keystone.budget_categories`, `keystone.budget_commitments`, `keystone.budget_period_closures`, `keystone.budget_revisions`, `keystone.bulk_action_catalog`, `keystone.bulk_operations`, `keystone.business_calendar_days`, `keystone.business_calendars`, `keystone.capex_plan_lines`, `keystone.capex_plans`, `keystone.capex_recommendations`, `keystone.checkpoints`, `keystone.client_acceptance_reserves`, `keystone.client_acceptances`, `keystone.client_disputes`, `keystone.client_invoices_cache`, `keystone.client_messages`, `keystone.client_portal_access_log`, `keystone.client_quote_approvals`, `keystone.client_quote_lines`, `keystone.client_quotes`, `keystone.client_user_sites`, `keystone.client_users`, `keystone.clients`, `keystone.competency_refusals`, `keystone.competency_requirements`, `keystone.compliance_evaluations`, `keystone.compliance_frameworks`, `keystone.confined_space_entries`, `keystone.consultation_participants`, `keystone.contractor_penalties`, `keystone.contractor_review_actions`, `keystone.contractor_review_scores`, `keystone.contractor_reviews`, `keystone.controls`, `keystone.copilot_messages`, `keystone.crisis_drill_findings`, `keystone.crisis_drills`, `keystone.cycle_count_lines`, `keystone.cycle_counts`, `keystone.dashboard_configs`, `keystone.data_exports`, `keystone.device_sessions`, `keystone.disposal_records`, `keystone.doc_access_log`, `keystone.doc_entity_types`, `keystone.doc_links`, `keystone.doc_qr_links`, `keystone.doc_versions`, `keystone.duer_versions`, `keystone.email_suppressions`, `keystone.email_template_versions`, `keystone.email_templates`, `keystone.embeddings`, `keystone.emissions`, `keystone.energy_action_plans`, `keystone.energy_actions`, `keystone.energy_anomalies`, `keystone.energy_baselines`, `keystone.energy_daily_values`, `keystone.energy_invoices`, `keystone.energy_opportunities`, `keystone.energy_rebilling_lines`, `keystone.energy_rebilling_runs`, `keystone.energy_reviews`, `keystone.energy_scopes`, `keystone.energy_tariff_tranches`, `keystone.energy_tariffs`, `keystone.energy_use_meters`, `keystone.energy_uses`, `keystone.env_aspects`, `keystone.env_indicators`, `keystone.env_permits`, `keystone.env_reports`, `keystone.env_targets`, `keystone.error_codes`, `keystone.event_containment_measures`, `keystone.event_declarations`, `keystone.event_person_health`, `keystone.expense_lines`, `keystone.expense_payments`, `keystone.fire_drill_assembly_results`, `keystone.fire_drill_plans`, `keystone.fire_drills`, `keystone.fire_registers`, `keystone.fire_system_sectors`, `keystone.fire_systems`, `keystone.fitout_condition_templates`, `keystone.fitout_conditions`, `keystone.fitout_contractors`, `keystone.fitout_deposits`, `keystone.fitout_documents`, `keystone.fitout_inspections`, `keystone.fitout_request_spaces`, `keystone.fitout_requests`, `keystone.fitout_reserves`, `keystone.fitout_status_history`, `keystone.fitout_visas`, `keystone.floor_measurements`, `keystone.fm_context_issues`, `keystone.fm_cost_periods`, `keystone.fm_management_reviews`, `keystone.fm_objective_actions`, `keystone.fm_objectives`, `keystone.fm_policies`, `keystone.fm_requirements`, `keystone.fm_review_inputs`, `keystone.fm_review_outputs`, `keystone.fm_stakeholders`, `keystone.fmea_modes`, `keystone.fmea_reviews`, `keystone.fmea_scales`, `keystone.fmea_studies`, `keystone.ged_classification`, `keystone.ged_documents`, `keystone.ged_retention_rules`, `keystone.goods_receipt_lines`, `keystone.governance_meetings`, `keystone.guided_tours`, `keystone.hazards`, `keystone.holiday_rules`, `keystone.hsse_objective_measures`, `keystone.hsse_objectives`, `keystone.i18n_missing_keys`, `keystone.import_batch_rows`, `keystone.import_batches`, `keystone.import_mappings`, `keystone.inspection_answers`, `keystone.inspection_bodies`, `keystone.inspection_plans`, `keystone.inspection_template_items`, `keystone.integration_connections`, `keystone.integration_endpoints`, `keystone.integration_inbox`, `keystone.integration_mappings`, `keystone.integration_outbox`, `keystone.investigation_members`, `keystone.investigation_timeline`, `keystone.iot_alerts`, `keystone.iot_device_status_log`, `keystone.iot_devices`, `keystone.iot_gateway_logs`, `keystone.iot_gateway_points`, `keystone.iot_gateways`, `keystone.iot_readings`, `keystone.iot_readings_daily`, `keystone.iot_readings_hourly`, `keystone.iot_thresholds`, `keystone.iso14224_class_modes`, `keystone.iso14224_codes`, `keystone.job_positions`, `keystone.leak_alerts`, `keystone.legal_hold_documents`, `keystone.legal_holds`, `keystone.legal_obligations`, `keystone.lessons_learned`, `keystone.level_outlines`, `keystone.loading_dock_bookings`, `keystone.loading_docks`, `keystone.lockboxes`, `keystone.lone_worker_alerts`, `keystone.lone_worker_sessions`, `keystone.mail_parcels`, `keystone.maintenance_contract_scope`, `keystone.maintenance_levels`, `keystone.maintenance_plan_assets`, `keystone.maintenance_plan_skips`, `keystone.management_review_decisions`, `keystone.management_review_participants`, `keystone.management_reviews`, `keystone.measurement_surveys`, `keystone.medical_visits`, `keystone.meter_reading_round_items`, `keystone.meter_reading_round_run_items`, `keystone.meter_reading_round_runs`, `keystone.meter_reading_rounds`, `keystone.mobilization_projects`, `keystone.mobilization_reserves`, `keystone.mobilization_staff_transfers`, `keystone.mobilization_tasks`, `keystone.mobilization_templates`, `keystone.mode_change_plans`, `keystone.move_items`, `keystone.move_lines`, `keystone.move_requests`, `keystone.move_task_templates`, `keystone.move_work_orders`, `keystone.normalization_factors`, `keystone.notification_digests`, `keystone.notification_event_catalog`, `keystone.notification_preferences`, `keystone.object_comments`, `keystone.obligation_control_map`, `keystone.occupant_headcount`, `keystone.occupant_organizations`, `keystone.occupant_site_codes`, `keystone.occupant_users`, `keystone.occupational_diseases`, `keystone.occupational_exposures`, `keystone.on_call_escalation_policies`, `keystone.on_call_pages`, `keystone.parking_access_logs`, `keystone.parking_reservations`, `keystone.parking_sessions`, `keystone.parking_spaces`, `keystone.parking_subscription_plans`, `keystone.parking_subscriptions`, `keystone.parking_tariff_bands`, `keystone.parking_tariffs`, `keystone.parking_violations`, `keystone.parking_zones`, `keystone.part_requests`, `keystone.patrol_anomalies`, `keystone.patrol_route_checkpoints`, `keystone.patrol_routes`, `keystone.patrol_scans`, `keystone.patrols`, `keystone.payment_handlers`, `keystone.payment_intents`, `keystone.payment_reconciliation_issues`, `keystone.payment_requests`, `keystone.permissions`, `keystone.permit_approvals`, `keystone.permit_extensions`, `keystone.permit_gas_tests`, `keystone.permit_personal_locks`, `keystone.permit_rubric_rules`, `keystone.permit_signatures`, `keystone.permit_watchers`, `keystone.permit_workers`, `keystone.pest_interventions`, `keystone.pest_quarterly_reports`, `keystone.physical_access_review_items`, `keystone.physical_access_reviews`, `keystone.plan_imports`, `keystone.planning_baseline_items`, `keystone.planning_baselines`, `keystone.planning_freezes`, `keystone.platform_event_offsets`, `keystone.pm_task_checkpoints`, `keystone.pm_task_failure_modes`, `keystone.pm_task_parts`, `keystone.po_change_proposals`, `keystone.po_lines`, `keystone.presence_access_log`, `keystone.prevention_plan_risks`, `keystone.prevention_plans`, `keystone.pseudonym_map`, `keystone.public_report_attempts`, `keystone.public_report_points`, `keystone.purchase_comments`, `keystone.purchasing_category_thresholds`, `keystone.purchasing_settings`, `keystone.push_subscriptions`, `keystone.qc_elements`, `keystone.qc_profiles`, `keystone.qc_reworks`, `keystone.qc_sample_findings`, `keystone.qc_samples`, `keystone.qc_scores`, `keystone.reception_log`, `keystone.refrigerant_check_rules`, `keystone.refrigerants`, `keystone.regulatory_control_results`, `keystone.regulatory_derogations`, `keystone.regulatory_regimes`, `keystone.regulatory_watch`, `keystone.report_publications`, `keystone.report_runs`, `keystone.report_schedules`, `keystone.report_templates`, `keystone.rfq_criteria`, `keystone.rfq_deadline_changes`, `keystone.rfq_invitations`, `keystone.rfq_response_lines`, `keystone.rfq_responses`, `keystone.rfqs`, `keystone.risk_assessment_lines`, `keystone.risk_assessments`, `keystone.risk_criteria`, `keystone.risk_links`, `keystone.risk_rating_history`, `keystone.risk_score_models`, `keystone.roles`, `keystone.safety_alerts`, `keystone.samp`, `keystone.saved_views`, `keystone.scenario_occupancies`, `keystone.scenario_space_units`, `keystone.scim_events`, `keystone.scim_groups`, `keystone.scim_tokens`, `keystone.sector_parts`, `keystone.sector_spaces`, `keystone.sectors`, `keystone.security_events`, `keystone.security_handover`, `keystone.security_log`, `keystone.security_log_persons`, `keystone.security_log_types`, `keystone.security_posts`, `keystone.service_contract_amendments`, `keystone.service_contract_scope`, `keystone.service_contracts`, `keystone.session_profiles`, `keystone.setting_definitions`, `keystone.settings`, `keystone.settings_history`, `keystone.shift_pattern_slots`, `keystone.shift_patterns`, `keystone.shipment_notice_lines`, `keystone.shipment_notices`, `keystone.site_announcements`, `keystone.site_blackouts`, `keystone.site_business_hours`, `keystone.site_directory`, `keystone.site_ext`, `keystone.site_fire_settings`, `keystone.site_regulatory_suspensions`, `keystone.sla_pauses`, `keystone.sla_policies`, `keystone.space_bookings`, `keystone.space_chargeback_lines`, `keystone.space_chargeback_rules`, `keystone.space_chargebacks`, `keystone.space_demand_forecasts`, `keystone.space_ext`, `keystone.space_measurements`, `keystone.space_occupancies`, `keystone.space_scenarios`, `keystone.space_utilization_hourly`, `keystone.ssi_inhibitions`, `keystone.sso_group_mappings`, `keystone.stock_issue_refusals`, `keystone.stock_reservations`, `keystone.stock_transfer_lines`, `keystone.stock_transfers`, `keystone.supplier_catalog_items`, `keystone.survey_followups`, `keystone.survey_invitations`, `keystone.survey_questions`, `keystone.survey_responses`, `keystone.surveys`, `keystone.sync_conflicts`, `keystone.sync_mutations`, `keystone.team_members`, `keystone.telemetry_dashboards`, `keystone.tenant_branding`, `keystone.tenant_domains`, `keystone.tenant_lot_prefixes`, `keystone.tenant_onboarding_steps`, `keystone.tenant_provisioning`, `keystone.tenant_surfaces`, `keystone.ticket_attachments`, `keystone.ticket_categories`, `keystone.ticket_comments`, `keystone.ticket_followers`, `keystone.ticket_status_history`, `keystone.ticket_templates`, `keystone.ticket_work_orders`, `keystone.tickets`, `keystone.training_media`, `keystone.training_records`, `keystone.training_sessions`, `keystone.undo_action_catalog`, `keystone.undo_tokens`, `keystone.usage_daily`, `keystone.usage_event_catalog`, `keystone.usage_events`, `keystone.user_preferences`, `keystone.user_profiles`, `keystone.user_quiet_hours`, `keystone.utilization_recommendation_dismissals`, `keystone.vehicles`, `keystone.vendor_bank_changes`, `keystone.vendor_change_requests`, `keystone.vendor_contacts`, `keystone.vendor_doc_daily_status`, `keystone.vendor_document_types`, `keystone.vendor_documents`, `keystone.vendor_messages`, `keystone.vendor_rate_lines`, `keystone.vendor_score_snapshots`, `keystone.vendor_site_restrictions`, `keystone.vendor_status_history`, `keystone.vendor_users`, `keystone.vendors`, `keystone.video_requisitions`, `keystone.visitor_denylist`, `keystone.visitors`, `keystone.visits`, `keystone.waste_streams`, `keystone.waste_tracking_slips`, `keystone.webhook_deliveries`, `keystone.webhook_endpoints`, `keystone.witness_statements`, `keystone.wo_checkpoint_results`, `keystone.wo_instructions`, `keystone.wo_required_competencies`, `keystone.wo_required_permits`, `keystone.wo_required_tools`, `keystone.wo_reschedules`, `keystone.wo_scan_log`, `keystone.wo_template_parts`, `keystone.wo_template_tasks`, `keystone.wo_transitions_log`, `keystone.wo_work_sessions`, `keystone.work_center_categories`, `keystone.work_centers`, `keystone.work_order_team`, `keystone.work_units`, `keystone.worked_hours`, `keystone.worker_consultations`, `keystone.zoning_types`, `keystone.zonings`


## 6. Essai d'exécution du schéma des annexes (Postgres 16 local, jetable)

Outils et mode d'emploi : `scripts/schema/README.md`. Le script assemble les blocs SQL des Référentiels transverses, des 49 annexes puis de la Protection des données, développe les conventions de colonnes communes, écarte 4 blocs de convention ou gabarits (en gardant leurs instructions sans jeton) et applique 3 substitutions tracées ; les correctifs C00 à C15 comblent les objets employés sans définition ; les échecs sont rejoués jusqu'à stabilité.

| Essai | Instructions réussies | Tables créées |
|---|---|---|
| corpus brut | 449 sur 1 445 | 67 sur 563 |
| avec conventions, correctifs et substitutions | 1458 sur 1503 | 565 (563 des annexes et 2 de la Protection des données) |

### 6.1 Correctifs et substitutions (à reporter au corpus et au Registre)

| Réf. | Constat | Traitement | Certitude |
|---|---|---|---|
| C00 | aucun `CREATE SCHEMA` | `atlas_core`, `atlas_public`, `keystone` | Confirmé |
| C01 | type de déclinaison jamais créé, deux noms | `atlas_core.operating_mode`, alias `keystone.operating_mode` | valeurs confirmées, nom à trancher |
| C02 | types des Annexes C, D, R sans `CREATE TYPE` | `capa_status`, `event_status`, `inspection_status`, `ticket_status` (9 valeurs, A53), `control_result` : valeurs écrites dans le corpus | Confirmé |
| C02 bis | idem, renvoi « valeurs de l'Annexe C » sans liste | `capa_type`, `control_hierarchy`, `identifier_type`, `investigation_method`, `permit_status`, `hsse_event_type` (avec `good_practice`, A25) : valeurs de l'ancienne base | Probable |
| C03 | `vendor_status`, `sla_clock`, `presence_source` écrits en texte | transcrits | Confirmé |
| C10 | `wo_stage_status_ok` jamais créée | tableau B.1.4 ; `cancelled` admis à toute étape avant la clôture | Confirmé, le point `cancelled` à valider |
| C11 | `new_qr_token()` jamais créée | 12 caractères base32 RFC 4648 | Interprétation |
| C12, S01 | `clients.sector_code` vers `client_sectors(code)`, unique seulement avec `tenant_id` | clé composite | Confirmé |
| C13 | `json_schemas`, `json_schema()` décrits en prose (Annexe M) | transcrits | Confirmé |
| C14, S02 | cycle `work_orders` et `purchase_requests` | clé posée après coup | Confirmé |
| C15 | rôle `proph3t_reader` décrit (Annexe C) sans création | rôle créé | Confirmé |
| S03 | `hsse_events.security_log_id uuid` vers `security_log.id bigint` | colonne en `bigint` | Interprétation |
| conventions | `-- colonnes A.0.2` (89 tables), `<communes>`, types non qualifiés | développées ; chemin de recherche `keystone` | Confirmé |
| extensions | PostGIS, pgvector, pg_trgm, btree_gist, unaccent, pg_jsonschema sans `CREATE EXTENSION` | bouchons ; `pg_jsonschema` simulé : validation JSON non éprouvée | Confirmé |

Correction d'un essai précédent : l'ancienne valeur `triaged` de `ticket_status` (base actuelle) contredit le corpus (`triage`, plus `cancelled`) ; l'ancienne base ne peut donc pas servir de référence de valeurs quand le corpus en donne.

### 6.2 Écarts restants (45 instructions)

| Nature | Nombre | Traitement attendu |
|---|---|---|
| conséquence d’un autre écart | 12 | disparaissent avec leur cause |
| fonction décrite en prose, à implémenter | 12 | à écrire au lot du domaine, d’après la description |
| objet jamais défini | 8 | définition par l’annexe propriétaire (Oss53pa) |
| fonction non IMMUTABLE (index ou colonne générée) | 5 | réécrire l’index ou la colonne |
| double définition | 4 | garder une seule définition |
| signature seule (description de RPC) | 2 | à écrire au lot du domaine |
| autre | 1 | relecture |
| valeur d’énumération incompatible | 1 | valeur à ajouter au type propriétaire |

Non éprouvable localement : `auth.current_tenant()` est créée dans le schéma `auth` (Annexe A §A.1, 109 emplois) ; Supabase réserve ce schéma [Probable : création refusée]. À déplacer, décision d'Oss53pa.

#### Objets jamais définis ou valeurs manquantes
| Bloc | Erreur |
|---|---|
| AnnexeA_Socle_Partie4#5 | function keystone.object_visible(text, uuid) does not exist |
| AnnexeB_GMAO#5 | type "keystone.wo_transition_rules" does not exist |
| AnnexeB_GMAO_Partie2#7 | type "sla_pause_reason" does not exist |
| AnnexeB_GMAO_Partie3#14 | function keystone.compute_meter_consumption_daily() does not exist |
| AnnexeEN_Energie#5 | relation "keystone.v_meter_consumption_daily" does not exist |
| AnnexeP_Prestataires_Mobile#14 | function keystone.vendor_docs_ok_rate(uuid, integer) does not exist |
| AnnexeS_Space_Management_Partie2#10 | column "site_id" does not exist |
| AnnexeS_Space_Management_Partie2#3 | function keystone.log_presence_access(uuid) does not exist |
| AnnexeB_GMAO_Partie4#3 | invalid input value for enum permit_type: "energized" |

Sont décrites en prose mais sans code : `keystone.object_visible(p_entity, p_id)` (Annexe A partie 4), `keystone.vendor_docs_ok_rate(p_vendor, p_days)` (Annexe P), `keystone.log_presence_access(site_id)` (Annexe S) ; `sla_pause_reason` n'a que 3 de ses 5 valeurs écrites (Annexe M) ; `permit_type` ne contient pas `energized`, employé par l'Annexe B partie 4.

#### Fonctions décrites en prose ou par leur seule signature (à écrire avec leur lot)
| Bloc | Erreur |
|---|---|
| AnnexeB_GMAO#8 | syntax error at end of input |
| AnnexeMO_Modeles_OT#3 | syntax error at end of input |
| AnnexeMO_Modeles_OT#3 | syntax error at end of input |
| AnnexePK_Parking#6 | syntax error at end of input |
| AnnexePK_Parking#6 | syntax error at end of input |
| AnnexePK_Parking#6 | syntax error at end of input |
| AnnexePL_Planning_Equipes#11 | syntax error at or near ".." |
| AnnexePL_Planning_Equipes#12 | syntax error at or near ".." |
| AnnexePL_Planning_Equipes#13 | syntax error at or near ".." |
| AnnexePL_Planning_Equipes#14 | syntax error at or near ".." |
| AnnexeP_Prestataires_Mobile#11 | syntax error at end of input |
| AnnexeP_Prestataires_Mobile_Partie2#2 | syntax error at end of input |
| AnnexeB_GMAO_Partie2#8 | syntax error at or near "keystone" |
| AnnexeB_GMAO_Partie4#4 | syntax error at or near "keystone" |
| AnnexeB_GMAO_Partie3#4 | no function body specified |

#### Défauts techniques du corpus
| Bloc | Erreur |
|---|---|
| AnnexeAdmin_RBAC_Notifications#10 | functions in index expression must be marked IMMUTABLE |
| AnnexeAdmin_RBAC_Notifications#10 | functions in index expression must be marked IMMUTABLE |
| AnnexeAdmin_RBAC_Notifications#6 | functions in index expression must be marked IMMUTABLE |
| AnnexeCO_Atlas_Core#5 | generation expression is not immutable |
| Protection_Donnees#2 | generation expression is not immutable |
| AnnexeCL_Portail_Client#1 | policy "tickets_client_select" for table "tickets" already exists |
| AnnexeCL_Portail_Client#1 | policy "tickets_client_insert" for table "tickets" already exists |
| AnnexeN_Satisfaction_Cout#5 | relation "v_expenses_without_site" already exists |
| AnnexeQ_Reporting#5 | relation "uq_review_ref" already exists |

### 6.3 Suite

1. Oss53pa tranche : nom du type de déclinaison (C01), emplacement de `current_tenant()`, interprétations C10, C11, S03 ; fournit les valeurs de C02 bis, de `sla_pause_reason`, l'ajout de `energized` à `permit_type`.
2. Les correctifs retenus sont reportés dans les annexes propriétaires et au Registre.
3. Essai relancé jusqu'à zéro échec hors fonctions à implémenter avec leur lot.
4. Ensuite seulement : migration initiale sur une branche Supabase, puis sur la base partagée hors des heures d'utilisation (CLAUDE.md, règle 4).

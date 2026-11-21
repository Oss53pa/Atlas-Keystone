-- Politiques de LECTURE par module (décisions d'Oss53pa du 21/11/2026 : lecture seule, aucune écriture directe ;
-- seconde passe validée). Les écritures passent par les RPC SECURITY DEFINER (Index §5). Générées depuis rls_modules.tsv,
-- pour les tables sans politique permissive propre. Données de santé : event.medical_read seulement (D26, A83, I04).
-- Se combine avec la politique RESTRICTIVE tenant_isolation (conventions_socle.sql). Idempotent : une politique
-- module_read existante est remplacée si sa permission a changé.
-- 464 tables.

DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.access_events;
  EXECUTE 'CREATE POLICY module_read ON keystone.access_events FOR SELECT TO authenticated USING (keystone.has_permission(''access.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.access_events'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.access_log;
  EXECUTE 'CREATE POLICY module_read ON keystone.access_log FOR SELECT TO authenticated USING (keystone.has_permission(''access.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.access_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.access_log_heads;
  EXECUTE 'CREATE POLICY module_read ON keystone.access_log_heads FOR SELECT TO authenticated USING (keystone.has_permission(''access.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.access_log_heads'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.access_rights;
  EXECUTE 'CREATE POLICY module_read ON keystone.access_rights FOR SELECT TO authenticated USING (keystone.has_permission(''access.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.access_rights'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.access_zones;
  EXECUTE 'CREATE POLICY module_read ON keystone.access_zones FOR SELECT TO authenticated USING (keystone.has_permission(''access.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.access_zones'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.account_access_review_items;
  EXECUTE 'CREATE POLICY module_read ON keystone.account_access_review_items FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.account_access_review_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.account_access_reviews;
  EXECUTE 'CREATE POLICY module_read ON keystone.account_access_reviews FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.account_access_reviews'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.action_items;
  EXECUTE 'CREATE POLICY module_read ON keystone.action_items FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.action_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.agent_controls;
  EXECUTE 'CREATE POLICY module_read ON keystone.agent_controls FOR SELECT TO authenticated USING (keystone.has_permission(''ai.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.agent_controls'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.agent_definitions;
  EXECUTE 'CREATE POLICY module_read ON keystone.agent_definitions FOR SELECT TO authenticated USING (keystone.has_permission(''ai.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.agent_definitions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.agent_runs;
  EXECUTE 'CREATE POLICY module_read ON keystone.agent_runs FOR SELECT TO authenticated USING (keystone.has_permission(''ai.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.agent_runs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.ai_data_routes;
  EXECUTE 'CREATE POLICY module_read ON keystone.ai_data_routes FOR SELECT TO authenticated USING (keystone.has_permission(''ai.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ai_data_routes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.am_decision_criteria;
  EXECUTE 'CREATE POLICY module_read ON keystone.am_decision_criteria FOR SELECT TO authenticated USING (keystone.has_permission(''fmea.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.am_decision_criteria'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.am_objectives;
  EXECUTE 'CREATE POLICY module_read ON keystone.am_objectives FOR SELECT TO authenticated USING (keystone.has_permission(''fmea.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.am_objectives'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.anomalies;
  EXECUTE 'CREATE POLICY module_read ON keystone.anomalies FOR SELECT TO authenticated USING (keystone.has_permission(''ai.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.anomalies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.api_events;
  EXECUTE 'CREATE POLICY module_read ON keystone.api_events FOR SELECT TO authenticated USING (keystone.has_permission(''api.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.api_events'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.api_usage_hourly;
  EXECUTE 'CREATE POLICY module_read ON keystone.api_usage_hourly FOR SELECT TO authenticated USING (keystone.has_permission(''api.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.api_usage_hourly'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.approval_delegations;
  EXECUTE 'CREATE POLICY module_read ON keystone.approval_delegations FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.approval_delegations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.approval_levels;
  EXECUTE 'CREATE POLICY module_read ON keystone.approval_levels FOR SELECT TO authenticated USING (keystone.has_permission(''role.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.approval_levels'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.approval_steps;
  EXECUTE 'CREATE POLICY module_read ON keystone.approval_steps FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.approval_steps'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.area_classes;
  EXECUTE 'CREATE POLICY module_read ON keystone.area_classes FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.area_classes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_action_links;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_action_links FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_action_links'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_categories;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_categories FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_categories'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_category_attributes;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_category_attributes FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_category_attributes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_category_required_docs;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_category_required_docs FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_category_required_docs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_components;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_components FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_components'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_criticality_assessments;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_criticality_assessments FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_criticality_assessments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_data_requirements;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_data_requirements FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_data_requirements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_downtimes;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_downtimes FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_downtimes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_identifiers;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_identifiers FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_identifiers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_lifecycle_cost_items;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_lifecycle_cost_items FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_lifecycle_cost_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_lifecycle_costs;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_lifecycle_costs FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_lifecycle_costs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_management_policy;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_management_policy FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_management_policy'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_meters;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_meters FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_meters'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_observations;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_observations FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_observations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_record_events;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_record_events FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_record_events'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_served_spaces;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_served_spaces FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_served_spaces'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_spare_parts;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_spare_parts FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_spare_parts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_status_history;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_status_history FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_status_history'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.asset_warranties;
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_warranties FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_warranties'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.assets;
  EXECUTE 'CREATE POLICY module_read ON keystone.assets FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.assets'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.atelier_drafts;
  EXECUTE 'CREATE POLICY module_read ON keystone.atelier_drafts FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.atelier_drafts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.audit_anchors;
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_anchors FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_anchors'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.audit_criteria;
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_criteria FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_criteria'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.audit_findings;
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_findings FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_findings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.audit_heads;
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_heads FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_heads'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.audit_integrity_runs;
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_integrity_runs FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_integrity_runs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.audit_programs;
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_programs FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_programs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.audit_schedule_slots;
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_schedule_slots FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_schedule_slots'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.audit_team;
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_team FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_team'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.audit_trail;
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_trail FOR SELECT TO authenticated USING (keystone.has_permission(''audit_trail.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_trail'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.auditees;
  EXECUTE 'CREATE POLICY module_read ON keystone.auditees FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.auditees'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.audits;
  EXECUTE 'CREATE POLICY module_read ON keystone.audits FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audits'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.bait_station_checks;
  EXECUTE 'CREATE POLICY module_read ON keystone.bait_station_checks FOR SELECT TO authenticated USING (keystone.has_permission(''pest.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.bait_station_checks'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.bait_stations;
  EXECUTE 'CREATE POLICY module_read ON keystone.bait_stations FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.bait_stations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.billable_items;
  EXECUTE 'CREATE POLICY module_read ON keystone.billable_items FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.billable_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.bookable_resources;
  EXECUTE 'CREATE POLICY module_read ON keystone.bookable_resources FOR SELECT TO authenticated USING (keystone.has_permission(''booking.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.bookable_resources'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.booking_policies;
  EXECUTE 'CREATE POLICY module_read ON keystone.booking_policies FOR SELECT TO authenticated USING (keystone.has_permission(''booking.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.booking_policies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.booking_series;
  EXECUTE 'CREATE POLICY module_read ON keystone.booking_series FOR SELECT TO authenticated USING (keystone.has_permission(''booking.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.booking_series'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.bowtie_nodes;
  EXECUTE 'CREATE POLICY module_read ON keystone.bowtie_nodes FOR SELECT TO authenticated USING (keystone.has_permission(''capa.assign'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.bowtie_nodes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.budget_categories;
  EXECUTE 'CREATE POLICY module_read ON keystone.budget_categories FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.budget_categories'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.budget_period_closures;
  EXECUTE 'CREATE POLICY module_read ON keystone.budget_period_closures FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.budget_period_closures'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.budget_revisions;
  EXECUTE 'CREATE POLICY module_read ON keystone.budget_revisions FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.budget_revisions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.budgets;
  EXECUTE 'CREATE POLICY module_read ON keystone.budgets FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.budgets'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.business_calendar_days;
  EXECUTE 'CREATE POLICY module_read ON keystone.business_calendar_days FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.business_calendar_days'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.business_calendars;
  EXECUTE 'CREATE POLICY module_read ON keystone.business_calendars FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.business_calendars'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.capa_actions;
  EXECUTE 'CREATE POLICY module_read ON keystone.capa_actions FOR SELECT TO authenticated USING (keystone.has_permission(''capa.assign'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.capa_actions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.capex_plan_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.capex_plan_lines FOR SELECT TO authenticated USING (keystone.has_permission(''capex.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.capex_plan_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.capex_plans;
  EXECUTE 'CREATE POLICY module_read ON keystone.capex_plans FOR SELECT TO authenticated USING (keystone.has_permission(''capex.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.capex_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.capex_recommendations;
  EXECUTE 'CREATE POLICY module_read ON keystone.capex_recommendations FOR SELECT TO authenticated USING (keystone.has_permission(''capex.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.capex_recommendations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.checkpoints;
  EXECUTE 'CREATE POLICY module_read ON keystone.checkpoints FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.checkpoints'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.client_acceptance_reserves;
  EXECUTE 'CREATE POLICY module_read ON keystone.client_acceptance_reserves FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_acceptance_reserves'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.client_acceptances;
  EXECUTE 'CREATE POLICY module_read ON keystone.client_acceptances FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_acceptances'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.client_disputes;
  EXECUTE 'CREATE POLICY module_read ON keystone.client_disputes FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_disputes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.client_invoices_cache;
  EXECUTE 'CREATE POLICY module_read ON keystone.client_invoices_cache FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_invoices_cache'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.client_messages;
  EXECUTE 'CREATE POLICY module_read ON keystone.client_messages FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_messages'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.client_portal_access_log;
  EXECUTE 'CREATE POLICY module_read ON keystone.client_portal_access_log FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_portal_access_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.client_quote_approvals;
  EXECUTE 'CREATE POLICY module_read ON keystone.client_quote_approvals FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_quote_approvals'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.client_quote_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.client_quote_lines FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_quote_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.client_sectors;
  EXECUTE 'CREATE POLICY module_read ON keystone.client_sectors FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_sectors'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.client_user_sites;
  EXECUTE 'CREATE POLICY module_read ON keystone.client_user_sites FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_user_sites'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.client_users;
  EXECUTE 'CREATE POLICY module_read ON keystone.client_users FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_users'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.clients;
  EXECUTE 'CREATE POLICY module_read ON keystone.clients FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.clients'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.competencies;
  EXECUTE 'CREATE POLICY module_read ON keystone.competencies FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.competencies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.competency_refusals;
  EXECUTE 'CREATE POLICY module_read ON keystone.competency_refusals FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.competency_refusals'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.competency_requirements;
  EXECUTE 'CREATE POLICY module_read ON keystone.competency_requirements FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.competency_requirements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.compliance_evaluations;
  EXECUTE 'CREATE POLICY module_read ON keystone.compliance_evaluations FOR SELECT TO authenticated USING (keystone.has_permission(''compliance.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.compliance_evaluations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.compliance_requirements;
  EXECUTE 'CREATE POLICY module_read ON keystone.compliance_requirements FOR SELECT TO authenticated USING (keystone.has_permission(''compliance.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.compliance_requirements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.confined_space_entries;
  EXECUTE 'CREATE POLICY module_read ON keystone.confined_space_entries FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.confined_space_entries'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.consultation_participants;
  EXECUTE 'CREATE POLICY module_read ON keystone.consultation_participants FOR SELECT TO authenticated USING (keystone.has_permission(''consultation.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.consultation_participants'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.contractor_evaluations;
  EXECUTE 'CREATE POLICY module_read ON keystone.contractor_evaluations FOR SELECT TO authenticated USING (keystone.has_permission(''contract.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.contractor_evaluations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.contractor_penalties;
  EXECUTE 'CREATE POLICY module_read ON keystone.contractor_penalties FOR SELECT TO authenticated USING (keystone.has_permission(''contract.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.contractor_penalties'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.contractor_review_actions;
  EXECUTE 'CREATE POLICY module_read ON keystone.contractor_review_actions FOR SELECT TO authenticated USING (keystone.has_permission(''contract.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.contractor_review_actions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.contractor_review_scores;
  EXECUTE 'CREATE POLICY module_read ON keystone.contractor_review_scores FOR SELECT TO authenticated USING (keystone.has_permission(''contract.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.contractor_review_scores'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.contractor_reviews;
  EXECUTE 'CREATE POLICY module_read ON keystone.contractor_reviews FOR SELECT TO authenticated USING (keystone.has_permission(''contract.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.contractor_reviews'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.control_reserves;
  EXECUTE 'CREATE POLICY module_read ON keystone.control_reserves FOR SELECT TO authenticated USING (keystone.has_permission(''crp.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.control_reserves'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.controls;
  EXECUTE 'CREATE POLICY module_read ON keystone.controls FOR SELECT TO authenticated USING (keystone.has_permission(''capa.assign'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.controls'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.copilot_messages;
  EXECUTE 'CREATE POLICY module_read ON keystone.copilot_messages FOR SELECT TO authenticated USING (keystone.has_permission(''ai.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.copilot_messages'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.cycle_count_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.cycle_count_lines FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.cycle_count_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.cycle_counts;
  EXECUTE 'CREATE POLICY module_read ON keystone.cycle_counts FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.cycle_counts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.dashboard_configs;
  EXECUTE 'CREATE POLICY module_read ON keystone.dashboard_configs FOR SELECT TO authenticated USING (keystone.has_permission(''dashboard.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.dashboard_configs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.data_exports;
  EXECUTE 'CREATE POLICY module_read ON keystone.data_exports FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.data_exports'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.device_sessions;
  EXECUTE 'CREATE POLICY module_read ON keystone.device_sessions FOR SELECT TO authenticated USING (keystone.has_permission(''admin.devices'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.device_sessions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.disposal_records;
  EXECUTE 'CREATE POLICY module_read ON keystone.disposal_records FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.disposal_records'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.doc_links;
  EXECUTE 'CREATE POLICY module_read ON keystone.doc_links FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.doc_links'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.doc_qr_links;
  EXECUTE 'CREATE POLICY module_read ON keystone.doc_qr_links FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.doc_qr_links'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.doc_versions;
  EXECUTE 'CREATE POLICY module_read ON keystone.doc_versions FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.doc_versions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.dpia_assessments;
  EXECUTE 'CREATE POLICY module_read ON keystone.dpia_assessments FOR SELECT TO authenticated USING (keystone.has_permission(''privacy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.dpia_assessments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.email_suppressions;
  EXECUTE 'CREATE POLICY module_read ON keystone.email_suppressions FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.email_suppressions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.email_templates;
  EXECUTE 'CREATE POLICY module_read ON keystone.email_templates FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.email_templates'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.embeddings;
  EXECUTE 'CREATE POLICY module_read ON keystone.embeddings FOR SELECT TO authenticated USING (keystone.has_permission(''ai.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.embeddings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.emission_factors;
  EXECUTE 'CREATE POLICY module_read ON keystone.emission_factors FOR SELECT TO authenticated USING (keystone.has_permission(''env.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.emission_factors'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.emissions;
  EXECUTE 'CREATE POLICY module_read ON keystone.emissions FOR SELECT TO authenticated USING (keystone.has_permission(''env.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.emissions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_action_plans;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_action_plans FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_action_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_actions;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_actions FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_actions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_anomalies;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_anomalies FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_anomalies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_baselines;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_baselines FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_baselines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_invoices;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_invoices FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_invoices'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_opportunities;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_opportunities FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_opportunities'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_rebilling_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_rebilling_lines FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_rebilling_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_rebilling_runs;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_rebilling_runs FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_rebilling_runs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_reviews;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_reviews FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_reviews'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_scopes;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_scopes FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_scopes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_targets;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_targets FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_targets'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_tariff_tranches;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_tariff_tranches FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_tariff_tranches'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_tariffs;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_tariffs FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_tariffs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_use_meters;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_use_meters FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_use_meters'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.energy_uses;
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_uses FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_uses'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.env_aspects;
  EXECUTE 'CREATE POLICY module_read ON keystone.env_aspects FOR SELECT TO authenticated USING (keystone.has_permission(''env.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.env_aspects'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.env_indicators;
  EXECUTE 'CREATE POLICY module_read ON keystone.env_indicators FOR SELECT TO authenticated USING (keystone.has_permission(''env.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.env_indicators'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.env_permits;
  EXECUTE 'CREATE POLICY module_read ON keystone.env_permits FOR SELECT TO authenticated USING (keystone.has_permission(''env.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.env_permits'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.env_reports;
  EXECUTE 'CREATE POLICY module_read ON keystone.env_reports FOR SELECT TO authenticated USING (keystone.has_permission(''env.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.env_reports'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.env_targets;
  EXECUTE 'CREATE POLICY module_read ON keystone.env_targets FOR SELECT TO authenticated USING (keystone.has_permission(''env.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.env_targets'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.event_attachments;
  EXECUTE 'CREATE POLICY module_read ON keystone.event_attachments FOR SELECT TO authenticated USING (keystone.has_permission(''event.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.event_attachments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.event_declarations;
  EXECUTE 'CREATE POLICY module_read ON keystone.event_declarations FOR SELECT TO authenticated USING (keystone.has_permission(''event.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.event_declarations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.event_persons;
  EXECUTE 'CREATE POLICY module_read ON keystone.event_persons FOR SELECT TO authenticated USING (keystone.has_permission(''event.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.event_persons'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.expense_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.expense_lines FOR SELECT TO authenticated USING (keystone.has_permission(''expense.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.expense_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.expense_payments;
  EXECUTE 'CREATE POLICY module_read ON keystone.expense_payments FOR SELECT TO authenticated USING (keystone.has_permission(''expense.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.expense_payments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.expenses;
  EXECUTE 'CREATE POLICY module_read ON keystone.expenses FOR SELECT TO authenticated USING (keystone.has_permission(''expense.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.expenses'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fire_drill_assembly_results;
  EXECUTE 'CREATE POLICY module_read ON keystone.fire_drill_assembly_results FOR SELECT TO authenticated USING (keystone.has_permission(''fire.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fire_drill_assembly_results'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fire_drill_plans;
  EXECUTE 'CREATE POLICY module_read ON keystone.fire_drill_plans FOR SELECT TO authenticated USING (keystone.has_permission(''fire.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fire_drill_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fire_drills;
  EXECUTE 'CREATE POLICY module_read ON keystone.fire_drills FOR SELECT TO authenticated USING (keystone.has_permission(''fire.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fire_drills'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fire_registers;
  EXECUTE 'CREATE POLICY module_read ON keystone.fire_registers FOR SELECT TO authenticated USING (keystone.has_permission(''fire.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fire_registers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fire_system_sectors;
  EXECUTE 'CREATE POLICY module_read ON keystone.fire_system_sectors FOR SELECT TO authenticated USING (keystone.has_permission(''fire.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fire_system_sectors'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fire_systems;
  EXECUTE 'CREATE POLICY module_read ON keystone.fire_systems FOR SELECT TO authenticated USING (keystone.has_permission(''fire.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fire_systems'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fitout_condition_templates;
  EXECUTE 'CREATE POLICY module_read ON keystone.fitout_condition_templates FOR SELECT TO authenticated USING (keystone.has_permission(''fitout.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fitout_condition_templates'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fitout_deposits;
  EXECUTE 'CREATE POLICY module_read ON keystone.fitout_deposits FOR SELECT TO authenticated USING (keystone.has_permission(''fitout.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fitout_deposits'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fitout_requests;
  EXECUTE 'CREATE POLICY module_read ON keystone.fitout_requests FOR SELECT TO authenticated USING (keystone.has_permission(''fitout.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fitout_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.floor_measurements;
  EXECUTE 'CREATE POLICY module_read ON keystone.floor_measurements FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.floor_measurements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fm_context_issues;
  EXECUTE 'CREATE POLICY module_read ON keystone.fm_context_issues FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fm_context_issues'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fm_cost_periods;
  EXECUTE 'CREATE POLICY module_read ON keystone.fm_cost_periods FOR SELECT TO authenticated USING (keystone.has_permission(''cost.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fm_cost_periods'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fm_management_reviews;
  EXECUTE 'CREATE POLICY module_read ON keystone.fm_management_reviews FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fm_management_reviews'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fm_objective_actions;
  EXECUTE 'CREATE POLICY module_read ON keystone.fm_objective_actions FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fm_objective_actions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fm_objectives;
  EXECUTE 'CREATE POLICY module_read ON keystone.fm_objectives FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fm_objectives'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fm_policies;
  EXECUTE 'CREATE POLICY module_read ON keystone.fm_policies FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fm_policies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fm_requirements;
  EXECUTE 'CREATE POLICY module_read ON keystone.fm_requirements FOR SELECT TO authenticated USING (keystone.has_permission(''compliance.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fm_requirements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fm_review_inputs;
  EXECUTE 'CREATE POLICY module_read ON keystone.fm_review_inputs FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fm_review_inputs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fm_review_outputs;
  EXECUTE 'CREATE POLICY module_read ON keystone.fm_review_outputs FOR SELECT TO authenticated USING (keystone.has_permission(''capa.assign'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fm_review_outputs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fm_stakeholders;
  EXECUTE 'CREATE POLICY module_read ON keystone.fm_stakeholders FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fm_stakeholders'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fmea_modes;
  EXECUTE 'CREATE POLICY module_read ON keystone.fmea_modes FOR SELECT TO authenticated USING (keystone.has_permission(''fmea.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fmea_modes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fmea_reviews;
  EXECUTE 'CREATE POLICY module_read ON keystone.fmea_reviews FOR SELECT TO authenticated USING (keystone.has_permission(''fmea.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fmea_reviews'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fmea_scales;
  EXECUTE 'CREATE POLICY module_read ON keystone.fmea_scales FOR SELECT TO authenticated USING (keystone.has_permission(''fmea.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fmea_scales'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.fmea_studies;
  EXECUTE 'CREATE POLICY module_read ON keystone.fmea_studies FOR SELECT TO authenticated USING (keystone.has_permission(''fmea.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fmea_studies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.ged_classification;
  EXECUTE 'CREATE POLICY module_read ON keystone.ged_classification FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ged_classification'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.ged_documents;
  EXECUTE 'CREATE POLICY module_read ON keystone.ged_documents FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ged_documents'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.ged_retention_rules;
  EXECUTE 'CREATE POLICY module_read ON keystone.ged_retention_rules FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ged_retention_rules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.goods_receipt_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.goods_receipt_lines FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.goods_receipt_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.goods_receipts;
  EXECUTE 'CREATE POLICY module_read ON keystone.goods_receipts FOR SELECT TO authenticated USING (keystone.has_permission(''purchase.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.goods_receipts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.governance_meetings;
  EXECUTE 'CREATE POLICY module_read ON keystone.governance_meetings FOR SELECT TO authenticated USING (keystone.has_permission(''governance.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.governance_meetings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.hazards;
  EXECUTE 'CREATE POLICY module_read ON keystone.hazards FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.hazards'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.holiday_rules;
  EXECUTE 'CREATE POLICY module_read ON keystone.holiday_rules FOR SELECT TO authenticated USING (keystone.has_permission(''calendar.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.holiday_rules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.hsse_objective_measures;
  EXECUTE 'CREATE POLICY module_read ON keystone.hsse_objective_measures FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.hsse_objective_measures'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.hsse_objectives;
  EXECUTE 'CREATE POLICY module_read ON keystone.hsse_objectives FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.hsse_objectives'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.import_batch_rows;
  EXECUTE 'CREATE POLICY module_read ON keystone.import_batch_rows FOR SELECT TO authenticated USING (keystone.has_permission(''import.run'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.import_batch_rows'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.import_batches;
  EXECUTE 'CREATE POLICY module_read ON keystone.import_batches FOR SELECT TO authenticated USING (keystone.has_permission(''import.run'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.import_batches'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.import_mappings;
  EXECUTE 'CREATE POLICY module_read ON keystone.import_mappings FOR SELECT TO authenticated USING (keystone.has_permission(''import.run'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.import_mappings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.inspection_answers;
  EXECUTE 'CREATE POLICY module_read ON keystone.inspection_answers FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.inspection_answers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.inspection_bodies;
  EXECUTE 'CREATE POLICY module_read ON keystone.inspection_bodies FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.inspection_bodies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.inspection_plans;
  EXECUTE 'CREATE POLICY module_read ON keystone.inspection_plans FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.inspection_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.inspection_template_items;
  EXECUTE 'CREATE POLICY module_read ON keystone.inspection_template_items FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.inspection_template_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.inspection_templates;
  EXECUTE 'CREATE POLICY module_read ON keystone.inspection_templates FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.inspection_templates'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.inspections;
  EXECUTE 'CREATE POLICY module_read ON keystone.inspections FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.inspections'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.integration_connections;
  EXECUTE 'CREATE POLICY module_read ON keystone.integration_connections FOR SELECT TO authenticated USING (keystone.has_permission(''integration.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.integration_connections'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.integration_endpoints;
  EXECUTE 'CREATE POLICY module_read ON keystone.integration_endpoints FOR SELECT TO authenticated USING (keystone.has_permission(''integration.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.integration_endpoints'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.integration_inbox;
  EXECUTE 'CREATE POLICY module_read ON keystone.integration_inbox FOR SELECT TO authenticated USING (keystone.has_permission(''integration.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.integration_inbox'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.integration_mappings;
  EXECUTE 'CREATE POLICY module_read ON keystone.integration_mappings FOR SELECT TO authenticated USING (keystone.has_permission(''integration.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.integration_mappings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.integration_outbox;
  EXECUTE 'CREATE POLICY module_read ON keystone.integration_outbox FOR SELECT TO authenticated USING (keystone.has_permission(''integration.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.integration_outbox'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.investigation_members;
  EXECUTE 'CREATE POLICY module_read ON keystone.investigation_members FOR SELECT TO authenticated USING (keystone.has_permission(''event.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.investigation_members'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.investigation_timeline;
  EXECUTE 'CREATE POLICY module_read ON keystone.investigation_timeline FOR SELECT TO authenticated USING (keystone.has_permission(''event.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.investigation_timeline'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.investigations;
  EXECUTE 'CREATE POLICY module_read ON keystone.investigations FOR SELECT TO authenticated USING (keystone.has_permission(''event.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.investigations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.iot_alerts;
  EXECUTE 'CREATE POLICY module_read ON keystone.iot_alerts FOR SELECT TO authenticated USING (keystone.has_permission(''iot.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.iot_alerts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.iot_device_status_log;
  EXECUTE 'CREATE POLICY module_read ON keystone.iot_device_status_log FOR SELECT TO authenticated USING (keystone.has_permission(''iot.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.iot_device_status_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.iot_devices;
  EXECUTE 'CREATE POLICY module_read ON keystone.iot_devices FOR SELECT TO authenticated USING (keystone.has_permission(''iot.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.iot_devices'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.iot_gateway_points;
  EXECUTE 'CREATE POLICY module_read ON keystone.iot_gateway_points FOR SELECT TO authenticated USING (keystone.has_permission(''iot.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.iot_gateway_points'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.iot_gateways;
  EXECUTE 'CREATE POLICY module_read ON keystone.iot_gateways FOR SELECT TO authenticated USING (keystone.has_permission(''iot.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.iot_gateways'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.iot_thresholds;
  EXECUTE 'CREATE POLICY module_read ON keystone.iot_thresholds FOR SELECT TO authenticated USING (keystone.has_permission(''iot.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.iot_thresholds'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.job_positions;
  EXECUTE 'CREATE POLICY module_read ON keystone.job_positions FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.job_positions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.leak_alerts;
  EXECUTE 'CREATE POLICY module_read ON keystone.leak_alerts FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.leak_alerts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.legal_hold_documents;
  EXECUTE 'CREATE POLICY module_read ON keystone.legal_hold_documents FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.legal_hold_documents'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.legal_holds;
  EXECUTE 'CREATE POLICY module_read ON keystone.legal_holds FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.legal_holds'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.legal_obligations;
  EXECUTE 'CREATE POLICY module_read ON keystone.legal_obligations FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.legal_obligations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.lessons_learned;
  EXECUTE 'CREATE POLICY module_read ON keystone.lessons_learned FOR SELECT TO authenticated USING (keystone.has_permission(''event.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.lessons_learned'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.level_outlines;
  EXECUTE 'CREATE POLICY module_read ON keystone.level_outlines FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.level_outlines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.loading_dock_bookings;
  EXECUTE 'CREATE POLICY module_read ON keystone.loading_dock_bookings FOR SELECT TO authenticated USING (keystone.has_permission(''occupant.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.loading_dock_bookings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.loading_docks;
  EXECUTE 'CREATE POLICY module_read ON keystone.loading_docks FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.loading_docks'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.locations;
  EXECUTE 'CREATE POLICY module_read ON keystone.locations FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.locations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.lockboxes;
  EXECUTE 'CREATE POLICY module_read ON keystone.lockboxes FOR SELECT TO authenticated USING (keystone.has_permission(''permit.request'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.lockboxes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.lone_worker_alerts;
  EXECUTE 'CREATE POLICY module_read ON keystone.lone_worker_alerts FOR SELECT TO authenticated USING (keystone.has_permission(''lone_worker.respond'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.lone_worker_alerts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.lone_worker_sessions;
  EXECUTE 'CREATE POLICY module_read ON keystone.lone_worker_sessions FOR SELECT TO authenticated USING (keystone.has_permission(''lone_worker.respond'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.lone_worker_sessions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.mail_parcels;
  EXECUTE 'CREATE POLICY module_read ON keystone.mail_parcels FOR SELECT TO authenticated USING (keystone.has_permission(''occupant.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.mail_parcels'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.maintenance_contract_scope;
  EXECUTE 'CREATE POLICY module_read ON keystone.maintenance_contract_scope FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.maintenance_contract_scope'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.maintenance_contracts;
  EXECUTE 'CREATE POLICY module_read ON keystone.maintenance_contracts FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.maintenance_contracts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.maintenance_levels;
  EXECUTE 'CREATE POLICY module_read ON keystone.maintenance_levels FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.maintenance_levels'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.maintenance_plan_assets;
  EXECUTE 'CREATE POLICY module_read ON keystone.maintenance_plan_assets FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.maintenance_plan_assets'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.maintenance_plan_skips;
  EXECUTE 'CREATE POLICY module_read ON keystone.maintenance_plan_skips FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.maintenance_plan_skips'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.maintenance_plans;
  EXECUTE 'CREATE POLICY module_read ON keystone.maintenance_plans FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.maintenance_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.management_review_decisions;
  EXECUTE 'CREATE POLICY module_read ON keystone.management_review_decisions FOR SELECT TO authenticated USING (keystone.has_permission(''capa.assign'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.management_review_decisions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.management_review_participants;
  EXECUTE 'CREATE POLICY module_read ON keystone.management_review_participants FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.management_review_participants'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.management_reviews;
  EXECUTE 'CREATE POLICY module_read ON keystone.management_reviews FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.management_reviews'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.measurement_surveys;
  EXECUTE 'CREATE POLICY module_read ON keystone.measurement_surveys FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.measurement_surveys'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.meter_reading_round_items;
  EXECUTE 'CREATE POLICY module_read ON keystone.meter_reading_round_items FOR SELECT TO authenticated USING (keystone.has_permission(''meter.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.meter_reading_round_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.meter_reading_round_run_items;
  EXECUTE 'CREATE POLICY module_read ON keystone.meter_reading_round_run_items FOR SELECT TO authenticated USING (keystone.has_permission(''meter.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.meter_reading_round_run_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.meter_reading_round_runs;
  EXECUTE 'CREATE POLICY module_read ON keystone.meter_reading_round_runs FOR SELECT TO authenticated USING (keystone.has_permission(''meter.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.meter_reading_round_runs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.meter_reading_rounds;
  EXECUTE 'CREATE POLICY module_read ON keystone.meter_reading_rounds FOR SELECT TO authenticated USING (keystone.has_permission(''meter.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.meter_reading_rounds'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.meter_readings;
  EXECUTE 'CREATE POLICY module_read ON keystone.meter_readings FOR SELECT TO authenticated USING (keystone.has_permission(''meter.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.meter_readings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.mobilization_projects;
  EXECUTE 'CREATE POLICY module_read ON keystone.mobilization_projects FOR SELECT TO authenticated USING (keystone.has_permission(''mobilization.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.mobilization_projects'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.mobilization_reserves;
  EXECUTE 'CREATE POLICY module_read ON keystone.mobilization_reserves FOR SELECT TO authenticated USING (keystone.has_permission(''mobilization.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.mobilization_reserves'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.mobilization_staff_transfers;
  EXECUTE 'CREATE POLICY module_read ON keystone.mobilization_staff_transfers FOR SELECT TO authenticated USING (keystone.has_permission(''mobilization.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.mobilization_staff_transfers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.mobilization_tasks;
  EXECUTE 'CREATE POLICY module_read ON keystone.mobilization_tasks FOR SELECT TO authenticated USING (keystone.has_permission(''mobilization.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.mobilization_tasks'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.mobilization_templates;
  EXECUTE 'CREATE POLICY module_read ON keystone.mobilization_templates FOR SELECT TO authenticated USING (keystone.has_permission(''mobilization.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.mobilization_templates'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.mode_change_plans;
  EXECUTE 'CREATE POLICY module_read ON keystone.mode_change_plans FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.mode_change_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.move_requests;
  EXECUTE 'CREATE POLICY module_read ON keystone.move_requests FOR SELECT TO authenticated USING (keystone.has_permission(''move.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.move_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.move_task_templates;
  EXECUTE 'CREATE POLICY module_read ON keystone.move_task_templates FOR SELECT TO authenticated USING (keystone.has_permission(''move.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.move_task_templates'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.normalization_factors;
  EXECUTE 'CREATE POLICY module_read ON keystone.normalization_factors FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.normalization_factors'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.notification_digests;
  EXECUTE 'CREATE POLICY module_read ON keystone.notification_digests FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.notification_digests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.notification_preferences;
  EXECUTE 'CREATE POLICY module_read ON keystone.notification_preferences FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.notification_preferences'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.notification_rules;
  EXECUTE 'CREATE POLICY module_read ON keystone.notification_rules FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.notification_rules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.notifications;
  EXECUTE 'CREATE POLICY module_read ON keystone.notifications FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.notifications'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.obligation_control_map;
  EXECUTE 'CREATE POLICY module_read ON keystone.obligation_control_map FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.obligation_control_map'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.occupant_headcount;
  EXECUTE 'CREATE POLICY module_read ON keystone.occupant_headcount FOR SELECT TO authenticated USING (keystone.has_permission(''occupant.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.occupant_headcount'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.occupant_organizations;
  EXECUTE 'CREATE POLICY module_read ON keystone.occupant_organizations FOR SELECT TO authenticated USING (keystone.has_permission(''occupant.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.occupant_organizations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.occupant_site_codes;
  EXECUTE 'CREATE POLICY module_read ON keystone.occupant_site_codes FOR SELECT TO authenticated USING (keystone.has_permission(''occupant.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.occupant_site_codes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.occupant_users;
  EXECUTE 'CREATE POLICY module_read ON keystone.occupant_users FOR SELECT TO authenticated USING (keystone.has_permission(''occupant.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.occupant_users'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.occupational_diseases;
  EXECUTE 'CREATE POLICY module_read ON keystone.occupational_diseases FOR SELECT TO authenticated USING (keystone.has_permission(''event.medical_read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.occupational_diseases'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.occupational_exposures;
  EXECUTE 'CREATE POLICY module_read ON keystone.occupational_exposures FOR SELECT TO authenticated USING (keystone.has_permission(''event.medical_read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.occupational_exposures'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.on_call;
  EXECUTE 'CREATE POLICY module_read ON keystone.on_call FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.on_call'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.on_call_escalation_policies;
  EXECUTE 'CREATE POLICY module_read ON keystone.on_call_escalation_policies FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.on_call_escalation_policies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.on_call_pages;
  EXECUTE 'CREATE POLICY module_read ON keystone.on_call_pages FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.on_call_pages'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.parking_access_logs;
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_access_logs FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_access_logs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.parking_reservations;
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_reservations FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_reservations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.parking_sessions;
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_sessions FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_sessions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.parking_spaces;
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_spaces FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_spaces'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.parking_subscription_plans;
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_subscription_plans FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_subscription_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.parking_subscriptions;
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_subscriptions FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_subscriptions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.parking_tariffs;
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_tariffs FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_tariffs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.parking_violations;
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_violations FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_violations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.parking_zones;
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_zones FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_zones'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.part_requests;
  EXECUTE 'CREATE POLICY module_read ON keystone.part_requests FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.part_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.patrol_anomalies;
  EXECUTE 'CREATE POLICY module_read ON keystone.patrol_anomalies FOR SELECT TO authenticated USING (keystone.has_permission(''patrol.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.patrol_anomalies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.patrol_routes;
  EXECUTE 'CREATE POLICY module_read ON keystone.patrol_routes FOR SELECT TO authenticated USING (keystone.has_permission(''patrol.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.patrol_routes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.patrol_scans;
  EXECUTE 'CREATE POLICY module_read ON keystone.patrol_scans FOR SELECT TO authenticated USING (keystone.has_permission(''patrol.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.patrol_scans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.patrols;
  EXECUTE 'CREATE POLICY module_read ON keystone.patrols FOR SELECT TO authenticated USING (keystone.has_permission(''patrol.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.patrols'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.payment_intents;
  EXECUTE 'CREATE POLICY module_read ON keystone.payment_intents FOR SELECT TO authenticated USING (keystone.has_permission(''payment.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.payment_intents'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.payment_reconciliation_issues;
  EXECUTE 'CREATE POLICY module_read ON keystone.payment_reconciliation_issues FOR SELECT TO authenticated USING (keystone.has_permission(''payment.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.payment_reconciliation_issues'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.payment_requests;
  EXECUTE 'CREATE POLICY module_read ON keystone.payment_requests FOR SELECT TO authenticated USING (keystone.has_permission(''payment.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.payment_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.permit_approvals;
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_approvals FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_approvals'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.permit_extensions;
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_extensions FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_extensions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.permit_gas_tests;
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_gas_tests FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_gas_tests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.permit_isolations;
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_isolations FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_isolations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.permit_personal_locks;
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_personal_locks FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_personal_locks'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.permit_rubric_rules;
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_rubric_rules FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_rubric_rules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.permit_signatures;
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_signatures FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_signatures'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.permit_watchers;
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_watchers FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_watchers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.permit_workers;
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_workers FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_workers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.person_competencies;
  EXECUTE 'CREATE POLICY module_read ON keystone.person_competencies FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.person_competencies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.persons;
  EXECUTE 'CREATE POLICY module_read ON keystone.persons FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.persons'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.pest_interventions;
  EXECUTE 'CREATE POLICY module_read ON keystone.pest_interventions FOR SELECT TO authenticated USING (keystone.has_permission(''pest.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.pest_interventions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.pest_quarterly_reports;
  EXECUTE 'CREATE POLICY module_read ON keystone.pest_quarterly_reports FOR SELECT TO authenticated USING (keystone.has_permission(''pest.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.pest_quarterly_reports'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.physical_access_reviews;
  EXECUTE 'CREATE POLICY module_read ON keystone.physical_access_reviews FOR SELECT TO authenticated USING (keystone.has_permission(''visitor.denylist_manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.physical_access_reviews'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.plan_imports;
  EXECUTE 'CREATE POLICY module_read ON keystone.plan_imports FOR SELECT TO authenticated USING (keystone.has_permission(''plan.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.plan_imports'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.planning_baseline_items;
  EXECUTE 'CREATE POLICY module_read ON keystone.planning_baseline_items FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.planning_baseline_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.planning_baselines;
  EXECUTE 'CREATE POLICY module_read ON keystone.planning_baselines FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.planning_baselines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.planning_freezes;
  EXECUTE 'CREATE POLICY module_read ON keystone.planning_freezes FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.planning_freezes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.pm_task_checkpoints;
  EXECUTE 'CREATE POLICY module_read ON keystone.pm_task_checkpoints FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.pm_task_checkpoints'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.pm_task_failure_modes;
  EXECUTE 'CREATE POLICY module_read ON keystone.pm_task_failure_modes FOR SELECT TO authenticated USING (keystone.has_permission(''fmea.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.pm_task_failure_modes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.pm_task_parts;
  EXECUTE 'CREATE POLICY module_read ON keystone.pm_task_parts FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.pm_task_parts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.pm_tasks;
  EXECUTE 'CREATE POLICY module_read ON keystone.pm_tasks FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.pm_tasks'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.po_change_proposals;
  EXECUTE 'CREATE POLICY module_read ON keystone.po_change_proposals FOR SELECT TO authenticated USING (keystone.has_permission(''purchase.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.po_change_proposals'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.po_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.po_lines FOR SELECT TO authenticated USING (keystone.has_permission(''purchase.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.po_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.predictions;
  EXECUTE 'CREATE POLICY module_read ON keystone.predictions FOR SELECT TO authenticated USING (keystone.has_permission(''ai.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.predictions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.presence;
  EXECUTE 'CREATE POLICY module_read ON keystone.presence FOR SELECT TO authenticated USING (keystone.has_permission(''presence.view'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.presence'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.presence_access_log;
  EXECUTE 'CREATE POLICY module_read ON keystone.presence_access_log FOR SELECT TO authenticated USING (keystone.has_permission(''presence.view'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.presence_access_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.prevention_plan_risks;
  EXECUTE 'CREATE POLICY module_read ON keystone.prevention_plan_risks FOR SELECT TO authenticated USING (keystone.has_permission(''permit.request'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.prevention_plan_risks'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.prevention_plans;
  EXECUTE 'CREATE POLICY module_read ON keystone.prevention_plans FOR SELECT TO authenticated USING (keystone.has_permission(''fitout.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.prevention_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.privacy_breaches;
  EXECUTE 'CREATE POLICY module_read ON keystone.privacy_breaches FOR SELECT TO authenticated USING (keystone.has_permission(''privacy.erase'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.privacy_breaches'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.privacy_formalities;
  EXECUTE 'CREATE POLICY module_read ON keystone.privacy_formalities FOR SELECT TO authenticated USING (keystone.has_permission(''privacy.erase'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.privacy_formalities'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.privacy_request_events;
  EXECUTE 'CREATE POLICY module_read ON keystone.privacy_request_events FOR SELECT TO authenticated USING (keystone.has_permission(''privacy.erase'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.privacy_request_events'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.privacy_requests;
  EXECUTE 'CREATE POLICY module_read ON keystone.privacy_requests FOR SELECT TO authenticated USING (keystone.has_permission(''privacy.erase'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.privacy_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.processing_activities;
  EXECUTE 'CREATE POLICY module_read ON keystone.processing_activities FOR SELECT TO authenticated USING (keystone.has_permission(''privacy.erase'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.processing_activities'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.pseudonym_map;
  EXECUTE 'CREATE POLICY module_read ON keystone.pseudonym_map FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.pseudonym_map'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.public_report_attempts;
  EXECUTE 'CREATE POLICY module_read ON keystone.public_report_attempts FOR SELECT TO authenticated USING (keystone.has_permission(''occupant.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.public_report_attempts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.public_report_points;
  EXECUTE 'CREATE POLICY module_read ON keystone.public_report_points FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.public_report_points'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.purchase_comments;
  EXECUTE 'CREATE POLICY module_read ON keystone.purchase_comments FOR SELECT TO authenticated USING (keystone.has_permission(''purchase.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.purchase_comments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.purchase_orders;
  EXECUTE 'CREATE POLICY module_read ON keystone.purchase_orders FOR SELECT TO authenticated USING (keystone.has_permission(''purchase.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.purchase_orders'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.purchase_request_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.purchase_request_lines FOR SELECT TO authenticated USING (keystone.has_permission(''purchase.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.purchase_request_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.purchase_requests;
  EXECUTE 'CREATE POLICY module_read ON keystone.purchase_requests FOR SELECT TO authenticated USING (keystone.has_permission(''purchase.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.purchase_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.purchasing_category_thresholds;
  EXECUTE 'CREATE POLICY module_read ON keystone.purchasing_category_thresholds FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.purchasing_category_thresholds'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.purchasing_settings;
  EXECUTE 'CREATE POLICY module_read ON keystone.purchasing_settings FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.purchasing_settings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.push_subscriptions;
  EXECUTE 'CREATE POLICY module_read ON keystone.push_subscriptions FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.push_subscriptions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.qc_elements;
  EXECUTE 'CREATE POLICY module_read ON keystone.qc_elements FOR SELECT TO authenticated USING (keystone.has_permission(''qc.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.qc_elements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.qc_profiles;
  EXECUTE 'CREATE POLICY module_read ON keystone.qc_profiles FOR SELECT TO authenticated USING (keystone.has_permission(''qc.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.qc_profiles'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.qc_scores;
  EXECUTE 'CREATE POLICY module_read ON keystone.qc_scores FOR SELECT TO authenticated USING (keystone.has_permission(''qc.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.qc_scores'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.reception_log;
  EXECUTE 'CREATE POLICY module_read ON keystone.reception_log FOR SELECT TO authenticated USING (keystone.has_permission(''reception.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.reception_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.refrigerant_check_rules;
  EXECUTE 'CREATE POLICY module_read ON keystone.refrigerant_check_rules FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.refrigerant_check_rules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.regulatory_control_results;
  EXECUTE 'CREATE POLICY module_read ON keystone.regulatory_control_results FOR SELECT TO authenticated USING (keystone.has_permission(''crp.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.regulatory_control_results'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.regulatory_controls;
  EXECUTE 'CREATE POLICY module_read ON keystone.regulatory_controls FOR SELECT TO authenticated USING (keystone.has_permission(''crp.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.regulatory_controls'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.regulatory_derogations;
  EXECUTE 'CREATE POLICY module_read ON keystone.regulatory_derogations FOR SELECT TO authenticated USING (keystone.has_permission(''crp.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.regulatory_derogations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.regulatory_regimes;
  EXECUTE 'CREATE POLICY module_read ON keystone.regulatory_regimes FOR SELECT TO authenticated USING (keystone.has_permission(''crp.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.regulatory_regimes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.regulatory_watch;
  EXECUTE 'CREATE POLICY module_read ON keystone.regulatory_watch FOR SELECT TO authenticated USING (keystone.has_permission(''crp.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.regulatory_watch'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.report_publications;
  EXECUTE 'CREATE POLICY module_read ON keystone.report_publications FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.report_publications'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.report_runs;
  EXECUTE 'CREATE POLICY module_read ON keystone.report_runs FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.report_runs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.report_schedules;
  EXECUTE 'CREATE POLICY module_read ON keystone.report_schedules FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.report_schedules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.report_templates;
  EXECUTE 'CREATE POLICY module_read ON keystone.report_templates FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.report_templates'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.retention_runs;
  EXECUTE 'CREATE POLICY module_read ON keystone.retention_runs FOR SELECT TO authenticated USING (keystone.has_permission(''privacy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.retention_runs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.rfq_criteria;
  EXECUTE 'CREATE POLICY module_read ON keystone.rfq_criteria FOR SELECT TO authenticated USING (keystone.has_permission(''rfq.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.rfq_criteria'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.rfq_deadline_changes;
  EXECUTE 'CREATE POLICY module_read ON keystone.rfq_deadline_changes FOR SELECT TO authenticated USING (keystone.has_permission(''rfq.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.rfq_deadline_changes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.rfq_invitations;
  EXECUTE 'CREATE POLICY module_read ON keystone.rfq_invitations FOR SELECT TO authenticated USING (keystone.has_permission(''rfq.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.rfq_invitations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.rfq_response_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.rfq_response_lines FOR SELECT TO authenticated USING (keystone.has_permission(''rfq.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.rfq_response_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.rfq_responses;
  EXECUTE 'CREATE POLICY module_read ON keystone.rfq_responses FOR SELECT TO authenticated USING (keystone.has_permission(''rfq.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.rfq_responses'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.rfqs;
  EXECUTE 'CREATE POLICY module_read ON keystone.rfqs FOR SELECT TO authenticated USING (keystone.has_permission(''rfq.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.rfqs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.risk_assessment_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_assessment_lines FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_assessment_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.risk_assessments;
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_assessments FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_assessments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.risk_criteria;
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_criteria FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_criteria'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.risk_links;
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_links FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_links'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.risk_rating_history;
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_rating_history FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_rating_history'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.risk_score_models;
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_score_models FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_score_models'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.risk_scores;
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_scores FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_scores'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.role_permissions;
  EXECUTE 'CREATE POLICY module_read ON keystone.role_permissions FOR SELECT TO authenticated USING (keystone.has_permission(''role.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.role_permissions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.roles;
  EXECUTE 'CREATE POLICY module_read ON keystone.roles FOR SELECT TO authenticated USING (keystone.has_permission(''role.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.roles'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.root_causes;
  EXECUTE 'CREATE POLICY module_read ON keystone.root_causes FOR SELECT TO authenticated USING (keystone.has_permission(''event.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.root_causes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.safety_alerts;
  EXECUTE 'CREATE POLICY module_read ON keystone.safety_alerts FOR SELECT TO authenticated USING (keystone.has_permission(''event.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.safety_alerts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.samp;
  EXECUTE 'CREATE POLICY module_read ON keystone.samp FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.samp'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.scim_events;
  EXECUTE 'CREATE POLICY module_read ON keystone.scim_events FOR SELECT TO authenticated USING (keystone.has_permission(''scim.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.scim_events'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.scim_groups;
  EXECUTE 'CREATE POLICY module_read ON keystone.scim_groups FOR SELECT TO authenticated USING (keystone.has_permission(''scim.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.scim_groups'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.scim_tokens;
  EXECUTE 'CREATE POLICY module_read ON keystone.scim_tokens FOR SELECT TO authenticated USING (keystone.has_permission(''scim.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.scim_tokens'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.sectors;
  EXECUTE 'CREATE POLICY module_read ON keystone.sectors FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.sectors'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.security_handover;
  EXECUTE 'CREATE POLICY module_read ON keystone.security_handover FOR SELECT TO authenticated USING (keystone.has_permission(''security.kpi_read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.security_handover'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.security_log;
  EXECUTE 'CREATE POLICY module_read ON keystone.security_log FOR SELECT TO authenticated USING (keystone.has_permission(''security.kpi_read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.security_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.security_log_types;
  EXECUTE 'CREATE POLICY module_read ON keystone.security_log_types FOR SELECT TO authenticated USING (keystone.has_permission(''security.kpi_read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.security_log_types'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.security_posts;
  EXECUTE 'CREATE POLICY module_read ON keystone.security_posts FOR SELECT TO authenticated USING (keystone.has_permission(''security.kpi_read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.security_posts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.service_contract_amendments;
  EXECUTE 'CREATE POLICY module_read ON keystone.service_contract_amendments FOR SELECT TO authenticated USING (keystone.has_permission(''service_contract.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.service_contract_amendments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.service_contract_scope;
  EXECUTE 'CREATE POLICY module_read ON keystone.service_contract_scope FOR SELECT TO authenticated USING (keystone.has_permission(''service_contract.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.service_contract_scope'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.service_contracts;
  EXECUTE 'CREATE POLICY module_read ON keystone.service_contracts FOR SELECT TO authenticated USING (keystone.has_permission(''service_contract.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.service_contracts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.service_types;
  EXECUTE 'CREATE POLICY module_read ON keystone.service_types FOR SELECT TO authenticated USING (keystone.has_permission(''service.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.service_types'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.session_profiles;
  EXECUTE 'CREATE POLICY module_read ON keystone.session_profiles FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.session_profiles'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.settings;
  EXECUTE 'CREATE POLICY module_read ON keystone.settings FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.settings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.settings_history;
  EXECUTE 'CREATE POLICY module_read ON keystone.settings_history FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.settings_history'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.shift_pattern_slots;
  EXECUTE 'CREATE POLICY module_read ON keystone.shift_pattern_slots FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.shift_pattern_slots'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.shift_patterns;
  EXECUTE 'CREATE POLICY module_read ON keystone.shift_patterns FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.shift_patterns'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.shifts;
  EXECUTE 'CREATE POLICY module_read ON keystone.shifts FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.shifts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.shipment_notice_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.shipment_notice_lines FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.shipment_notice_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.shipment_notices;
  EXECUTE 'CREATE POLICY module_read ON keystone.shipment_notices FOR SELECT TO authenticated USING (keystone.has_permission(''purchase.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.shipment_notices'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.site_announcements;
  EXECUTE 'CREATE POLICY module_read ON keystone.site_announcements FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_announcements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.site_blackouts;
  EXECUTE 'CREATE POLICY module_read ON keystone.site_blackouts FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_blackouts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.site_business_hours;
  EXECUTE 'CREATE POLICY module_read ON keystone.site_business_hours FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_business_hours'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.site_directory;
  EXECUTE 'CREATE POLICY module_read ON keystone.site_directory FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_directory'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.site_ext;
  EXECUTE 'CREATE POLICY module_read ON keystone.site_ext FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_ext'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.site_fire_settings;
  EXECUTE 'CREATE POLICY module_read ON keystone.site_fire_settings FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_fire_settings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.site_regulatory_suspensions;
  EXECUTE 'CREATE POLICY module_read ON keystone.site_regulatory_suspensions FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_regulatory_suspensions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.sla_pauses;
  EXECUTE 'CREATE POLICY module_read ON keystone.sla_pauses FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.sla_pauses'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.sla_policies;
  EXECUTE 'CREATE POLICY module_read ON keystone.sla_policies FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.sla_policies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.space_bookings;
  EXECUTE 'CREATE POLICY module_read ON keystone.space_bookings FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_bookings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.space_chargeback_rules;
  EXECUTE 'CREATE POLICY module_read ON keystone.space_chargeback_rules FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_chargeback_rules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.space_chargebacks;
  EXECUTE 'CREATE POLICY module_read ON keystone.space_chargebacks FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_chargebacks'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.space_ext;
  EXECUTE 'CREATE POLICY module_read ON keystone.space_ext FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_ext'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.space_measurements;
  EXECUTE 'CREATE POLICY module_read ON keystone.space_measurements FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_measurements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.space_occupancies;
  EXECUTE 'CREATE POLICY module_read ON keystone.space_occupancies FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_occupancies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.space_plans;
  EXECUTE 'CREATE POLICY module_read ON keystone.space_plans FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.space_scenarios;
  EXECUTE 'CREATE POLICY module_read ON keystone.space_scenarios FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_scenarios'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.space_utilization_hourly;
  EXECUTE 'CREATE POLICY module_read ON keystone.space_utilization_hourly FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_utilization_hourly'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.spare_parts;
  EXECUTE 'CREATE POLICY module_read ON keystone.spare_parts FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.spare_parts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.ssi_inhibitions;
  EXECUTE 'CREATE POLICY module_read ON keystone.ssi_inhibitions FOR SELECT TO authenticated USING (keystone.has_permission(''fire.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ssi_inhibitions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.stock_issue_refusals;
  EXECUTE 'CREATE POLICY module_read ON keystone.stock_issue_refusals FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.stock_issue_refusals'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.stock_movements;
  EXECUTE 'CREATE POLICY module_read ON keystone.stock_movements FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.stock_movements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.stock_reservations;
  EXECUTE 'CREATE POLICY module_read ON keystone.stock_reservations FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.stock_reservations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.stock_transfer_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.stock_transfer_lines FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.stock_transfer_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.stock_transfers;
  EXECUTE 'CREATE POLICY module_read ON keystone.stock_transfers FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.stock_transfers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.supplier_catalog_items;
  EXECUTE 'CREATE POLICY module_read ON keystone.supplier_catalog_items FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.supplier_catalog_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.survey_followups;
  EXECUTE 'CREATE POLICY module_read ON keystone.survey_followups FOR SELECT TO authenticated USING (keystone.has_permission(''survey.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.survey_followups'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.survey_invitations;
  EXECUTE 'CREATE POLICY module_read ON keystone.survey_invitations FOR SELECT TO authenticated USING (keystone.has_permission(''survey.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.survey_invitations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.survey_questions;
  EXECUTE 'CREATE POLICY module_read ON keystone.survey_questions FOR SELECT TO authenticated USING (keystone.has_permission(''survey.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.survey_questions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.survey_responses;
  EXECUTE 'CREATE POLICY module_read ON keystone.survey_responses FOR SELECT TO authenticated USING (keystone.has_permission(''survey.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.survey_responses'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.surveys;
  EXECUTE 'CREATE POLICY module_read ON keystone.surveys FOR SELECT TO authenticated USING (keystone.has_permission(''survey.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.surveys'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.sync_conflicts;
  EXECUTE 'CREATE POLICY module_read ON keystone.sync_conflicts FOR SELECT TO authenticated USING (keystone.has_permission(''admin.devices'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.sync_conflicts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.sync_mutations;
  EXECUTE 'CREATE POLICY module_read ON keystone.sync_mutations FOR SELECT TO authenticated USING (keystone.has_permission(''admin.devices'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.sync_mutations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.team_members;
  EXECUTE 'CREATE POLICY module_read ON keystone.team_members FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.team_members'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.teams;
  EXECUTE 'CREATE POLICY module_read ON keystone.teams FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.teams'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.telemetry_dashboards;
  EXECUTE 'CREATE POLICY module_read ON keystone.telemetry_dashboards FOR SELECT TO authenticated USING (keystone.has_permission(''iot.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.telemetry_dashboards'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.tenant_branding;
  EXECUTE 'CREATE POLICY module_read ON keystone.tenant_branding FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.tenant_branding'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.tenant_domains;
  EXECUTE 'CREATE POLICY module_read ON keystone.tenant_domains FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.tenant_domains'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.tenant_lot_prefixes;
  EXECUTE 'CREATE POLICY module_read ON keystone.tenant_lot_prefixes FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.tenant_lot_prefixes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.tenant_onboarding_steps;
  EXECUTE 'CREATE POLICY module_read ON keystone.tenant_onboarding_steps FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.tenant_onboarding_steps'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.tenant_surfaces;
  EXECUTE 'CREATE POLICY module_read ON keystone.tenant_surfaces FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.tenant_surfaces'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.ticket_attachments;
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_attachments FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_attachments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.ticket_categories;
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_categories FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_categories'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.ticket_comments;
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_comments FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_comments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.ticket_followers;
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_followers FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_followers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.ticket_status_history;
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_status_history FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_status_history'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.ticket_templates;
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_templates FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_templates'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.ticket_work_orders;
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_work_orders FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_work_orders'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.time_off;
  EXECUTE 'CREATE POLICY module_read ON keystone.time_off FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.time_off'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.training_media;
  EXECUTE 'CREATE POLICY module_read ON keystone.training_media FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.training_media'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.training_records;
  EXECUTE 'CREATE POLICY module_read ON keystone.training_records FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.training_records'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.training_sessions;
  EXECUTE 'CREATE POLICY module_read ON keystone.training_sessions FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.training_sessions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.user_quiet_hours;
  EXECUTE 'CREATE POLICY module_read ON keystone.user_quiet_hours FOR SELECT TO authenticated USING (keystone.has_permission(''user.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.user_quiet_hours'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.user_roles;
  EXECUTE 'CREATE POLICY module_read ON keystone.user_roles FOR SELECT TO authenticated USING (keystone.has_permission(''user.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.user_roles'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.user_scope;
  EXECUTE 'CREATE POLICY module_read ON keystone.user_scope FOR SELECT TO authenticated USING (keystone.has_permission(''user.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.user_scope'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.users;
  EXECUTE 'CREATE POLICY module_read ON keystone.users FOR SELECT TO authenticated USING (keystone.has_permission(''user.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.users'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.utilization_recommendation_dismissals;
  EXECUTE 'CREATE POLICY module_read ON keystone.utilization_recommendation_dismissals FOR SELECT TO authenticated USING (keystone.has_permission(''booking.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.utilization_recommendation_dismissals'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.vehicles;
  EXECUTE 'CREATE POLICY module_read ON keystone.vehicles FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vehicles'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.vendor_bank_changes;
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_bank_changes FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_bank_changes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.vendor_change_requests;
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_change_requests FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_change_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.vendor_contacts;
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_contacts FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_contacts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.vendor_doc_daily_status;
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_doc_daily_status FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_doc_daily_status'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.vendor_document_types;
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_document_types FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_document_types'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.vendor_messages;
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_messages FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_messages'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.vendor_rate_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_rate_lines FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_rate_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.vendor_score_snapshots;
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_score_snapshots FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_score_snapshots'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.vendor_site_restrictions;
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_site_restrictions FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_site_restrictions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.vendor_status_history;
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_status_history FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_status_history'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.vendor_users;
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_users FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_users'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.vendors;
  EXECUTE 'CREATE POLICY module_read ON keystone.vendors FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendors'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.video_requisitions;
  EXECUTE 'CREATE POLICY module_read ON keystone.video_requisitions FOR SELECT TO authenticated USING (keystone.has_permission(''security.video_requisition'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.video_requisitions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.visitor_denylist;
  EXECUTE 'CREATE POLICY module_read ON keystone.visitor_denylist FOR SELECT TO authenticated USING (keystone.has_permission(''visitor.denylist_manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.visitor_denylist'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.visitors;
  EXECUTE 'CREATE POLICY module_read ON keystone.visitors FOR SELECT TO authenticated USING (keystone.has_permission(''visitor.denylist_manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.visitors'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.visits;
  EXECUTE 'CREATE POLICY module_read ON keystone.visits FOR SELECT TO authenticated USING (keystone.has_permission(''access.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.visits'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.warehouses;
  EXECUTE 'CREATE POLICY module_read ON keystone.warehouses FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.warehouses'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.waste_records;
  EXECUTE 'CREATE POLICY module_read ON keystone.waste_records FOR SELECT TO authenticated USING (keystone.has_permission(''waste.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.waste_records'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.waste_streams;
  EXECUTE 'CREATE POLICY module_read ON keystone.waste_streams FOR SELECT TO authenticated USING (keystone.has_permission(''waste.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.waste_streams'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.waste_tracking_slips;
  EXECUTE 'CREATE POLICY module_read ON keystone.waste_tracking_slips FOR SELECT TO authenticated USING (keystone.has_permission(''waste.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.waste_tracking_slips'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.wo_checkpoint_results;
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_checkpoint_results FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_checkpoint_results'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.wo_instructions;
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_instructions FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_instructions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.wo_reports;
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_reports FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_reports'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.wo_required_competencies;
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_required_competencies FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_required_competencies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.wo_required_permits;
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_required_permits FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_required_permits'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.wo_required_tools;
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_required_tools FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_required_tools'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.wo_reschedules;
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_reschedules FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_reschedules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.wo_scan_log;
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_scan_log FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_scan_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.wo_template_parts;
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_template_parts FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_template_parts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.wo_template_tasks;
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_template_tasks FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_template_tasks'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.wo_transitions_log;
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_transitions_log FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_transitions_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.wo_work_sessions;
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_work_sessions FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_work_sessions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.work_center_categories;
  EXECUTE 'CREATE POLICY module_read ON keystone.work_center_categories FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_center_categories'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.work_centers;
  EXECUTE 'CREATE POLICY module_read ON keystone.work_centers FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_centers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.work_order_lines;
  EXECUTE 'CREATE POLICY module_read ON keystone.work_order_lines FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_order_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.work_order_team;
  EXECUTE 'CREATE POLICY module_read ON keystone.work_order_team FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_order_team'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.work_orders;
  EXECUTE 'CREATE POLICY module_read ON keystone.work_orders FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_orders'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.work_permits;
  EXECUTE 'CREATE POLICY module_read ON keystone.work_permits FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_permits'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.work_units;
  EXECUTE 'CREATE POLICY module_read ON keystone.work_units FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_units'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.worked_hours;
  EXECUTE 'CREATE POLICY module_read ON keystone.worked_hours FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.worked_hours'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.worker_consultations;
  EXECUTE 'CREATE POLICY module_read ON keystone.worker_consultations FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.worker_consultations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.zones;
  EXECUTE 'CREATE POLICY module_read ON keystone.zones FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.zones'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.zoning_types;
  EXECUTE 'CREATE POLICY module_read ON keystone.zoning_types FOR SELECT TO authenticated USING (keystone.has_permission(''zoning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.zoning_types'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS module_read ON keystone.zonings;
  EXECUTE 'CREATE POLICY module_read ON keystone.zonings FOR SELECT TO authenticated USING (keystone.has_permission(''zoning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.zonings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END $$;

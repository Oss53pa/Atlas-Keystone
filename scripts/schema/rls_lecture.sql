-- Politiques de LECTURE par module (décision d'Oss53pa du 21/11/2026 : lecture seule, aucune écriture directe ;
-- les écritures passent par les RPC SECURITY DEFINER, Index §5). Générées depuis rls_modules.tsv (confiance haute et
-- moyenne, tables sans politique permissive propre). Les tables « À DÉFINIR » restent fermées. Idempotent.
-- Se combine avec la politique RESTRICTIVE tenant_isolation (conventions_socle.sql) : tenant ET permission.
-- 342 tables ; 150 écartées (à définir, ou politiques déjà fournies par les annexes).

DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.access_events'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.access_events FOR SELECT TO authenticated USING (keystone.has_permission(''access.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.access_events'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.access_log'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.access_log FOR SELECT TO authenticated USING (keystone.has_permission(''access.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.access_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.access_log_heads'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.access_log_heads FOR SELECT TO authenticated USING (keystone.has_permission(''access.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.access_log_heads'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.access_rights'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.access_rights FOR SELECT TO authenticated USING (keystone.has_permission(''access.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.access_rights'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.access_zones'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.access_zones FOR SELECT TO authenticated USING (keystone.has_permission(''access.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.access_zones'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.agent_controls'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.agent_controls FOR SELECT TO authenticated USING (keystone.has_permission(''ai.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.agent_controls'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.agent_definitions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.agent_definitions FOR SELECT TO authenticated USING (keystone.has_permission(''ai.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.agent_definitions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.agent_runs'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.agent_runs FOR SELECT TO authenticated USING (keystone.has_permission(''ai.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.agent_runs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.ai_data_routes'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.ai_data_routes FOR SELECT TO authenticated USING (keystone.has_permission(''ai.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ai_data_routes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.api_events'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.api_events FOR SELECT TO authenticated USING (keystone.has_permission(''api.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.api_events'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.api_usage_hourly'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.api_usage_hourly FOR SELECT TO authenticated USING (keystone.has_permission(''api.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.api_usage_hourly'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_action_links'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_action_links FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_action_links'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_categories'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_categories FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_categories'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_category_attributes'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_category_attributes FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_category_attributes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_category_required_docs'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_category_required_docs FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_category_required_docs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_components'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_components FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_components'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_criticality_assessments'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_criticality_assessments FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_criticality_assessments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_data_requirements'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_data_requirements FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_data_requirements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_downtimes'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_downtimes FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_downtimes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_identifiers'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_identifiers FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_identifiers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_lifecycle_cost_items'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_lifecycle_cost_items FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_lifecycle_cost_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_lifecycle_costs'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_lifecycle_costs FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_lifecycle_costs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_management_policy'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_management_policy FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_management_policy'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_meters'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_meters FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_meters'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_observations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_observations FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_observations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_record_events'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_record_events FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_record_events'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_served_spaces'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_served_spaces FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_served_spaces'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_spare_parts'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_spare_parts FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_spare_parts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_status_history'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_status_history FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_status_history'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.asset_warranties'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.asset_warranties FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.asset_warranties'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.assets'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.assets FOR SELECT TO authenticated USING (keystone.has_permission(''asset.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.assets'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.audit_anchors'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_anchors FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_anchors'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.audit_criteria'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_criteria FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_criteria'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.audit_findings'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_findings FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_findings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.audit_heads'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_heads FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_heads'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.audit_integrity_runs'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_integrity_runs FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_integrity_runs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.audit_programs'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_programs FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_programs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.audit_schedule_slots'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_schedule_slots FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_schedule_slots'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.audit_team'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_team FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_team'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.audit_trail'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.audit_trail FOR SELECT TO authenticated USING (keystone.has_permission(''audit_trail.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audit_trail'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.audits'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.audits FOR SELECT TO authenticated USING (keystone.has_permission(''audit.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.audits'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.bookable_resources'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.bookable_resources FOR SELECT TO authenticated USING (keystone.has_permission(''booking.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.bookable_resources'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.booking_policies'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.booking_policies FOR SELECT TO authenticated USING (keystone.has_permission(''booking.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.booking_policies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.booking_series'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.booking_series FOR SELECT TO authenticated USING (keystone.has_permission(''booking.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.booking_series'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.budget_categories'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.budget_categories FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.budget_categories'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.budget_period_closures'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.budget_period_closures FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.budget_period_closures'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.budget_revisions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.budget_revisions FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.budget_revisions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.budgets'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.budgets FOR SELECT TO authenticated USING (keystone.has_permission(''budget.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.budgets'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.capa_actions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.capa_actions FOR SELECT TO authenticated USING (keystone.has_permission(''capa.assign'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.capa_actions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.capex_plan_lines'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.capex_plan_lines FOR SELECT TO authenticated USING (keystone.has_permission(''capex.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.capex_plan_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.capex_plans'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.capex_plans FOR SELECT TO authenticated USING (keystone.has_permission(''capex.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.capex_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.capex_recommendations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.capex_recommendations FOR SELECT TO authenticated USING (keystone.has_permission(''capex.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.capex_recommendations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.client_acceptance_reserves'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.client_acceptance_reserves FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_acceptance_reserves'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.client_acceptances'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.client_acceptances FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_acceptances'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.client_disputes'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.client_disputes FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_disputes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.client_invoices_cache'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.client_invoices_cache FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_invoices_cache'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.client_messages'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.client_messages FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_messages'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.client_portal_access_log'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.client_portal_access_log FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_portal_access_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.client_quote_approvals'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.client_quote_approvals FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_quote_approvals'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.client_quote_lines'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.client_quote_lines FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_quote_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.client_sectors'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.client_sectors FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_sectors'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.client_user_sites'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.client_user_sites FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_user_sites'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.client_users'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.client_users FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.client_users'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.clients'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.clients FOR SELECT TO authenticated USING (keystone.has_permission(''client.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.clients'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.competencies'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.competencies FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.competencies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.competency_refusals'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.competency_refusals FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.competency_refusals'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.competency_requirements'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.competency_requirements FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.competency_requirements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.compliance_evaluations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.compliance_evaluations FOR SELECT TO authenticated USING (keystone.has_permission(''compliance.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.compliance_evaluations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.compliance_requirements'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.compliance_requirements FOR SELECT TO authenticated USING (keystone.has_permission(''compliance.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.compliance_requirements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.consultation_participants'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.consultation_participants FOR SELECT TO authenticated USING (keystone.has_permission(''consultation.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.consultation_participants'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.contractor_evaluations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.contractor_evaluations FOR SELECT TO authenticated USING (keystone.has_permission(''contract.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.contractor_evaluations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.contractor_penalties'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.contractor_penalties FOR SELECT TO authenticated USING (keystone.has_permission(''contract.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.contractor_penalties'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.contractor_review_actions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.contractor_review_actions FOR SELECT TO authenticated USING (keystone.has_permission(''contract.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.contractor_review_actions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.contractor_review_scores'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.contractor_review_scores FOR SELECT TO authenticated USING (keystone.has_permission(''contract.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.contractor_review_scores'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.contractor_reviews'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.contractor_reviews FOR SELECT TO authenticated USING (keystone.has_permission(''contract.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.contractor_reviews'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.dashboard_configs'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.dashboard_configs FOR SELECT TO authenticated USING (keystone.has_permission(''dashboard.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.dashboard_configs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.doc_links'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.doc_links FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.doc_links'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.doc_qr_links'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.doc_qr_links FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.doc_qr_links'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.doc_versions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.doc_versions FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.doc_versions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_action_plans'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_action_plans FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_action_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_actions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_actions FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_actions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_anomalies'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_anomalies FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_anomalies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_baselines'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_baselines FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_baselines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_invoices'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_invoices FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_invoices'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_opportunities'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_opportunities FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_opportunities'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_rebilling_lines'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_rebilling_lines FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_rebilling_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_rebilling_runs'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_rebilling_runs FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_rebilling_runs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_reviews'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_reviews FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_reviews'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_scopes'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_scopes FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_scopes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_targets'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_targets FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_targets'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_tariff_tranches'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_tariff_tranches FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_tariff_tranches'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_tariffs'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_tariffs FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_tariffs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_use_meters'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_use_meters FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_use_meters'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.energy_uses'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.energy_uses FOR SELECT TO authenticated USING (keystone.has_permission(''energy.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.energy_uses'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.env_aspects'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.env_aspects FOR SELECT TO authenticated USING (keystone.has_permission(''env.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.env_aspects'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.env_indicators'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.env_indicators FOR SELECT TO authenticated USING (keystone.has_permission(''env.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.env_indicators'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.env_permits'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.env_permits FOR SELECT TO authenticated USING (keystone.has_permission(''env.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.env_permits'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.env_reports'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.env_reports FOR SELECT TO authenticated USING (keystone.has_permission(''env.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.env_reports'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.env_targets'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.env_targets FOR SELECT TO authenticated USING (keystone.has_permission(''env.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.env_targets'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.event_attachments'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.event_attachments FOR SELECT TO authenticated USING (keystone.has_permission(''event.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.event_attachments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.event_declarations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.event_declarations FOR SELECT TO authenticated USING (keystone.has_permission(''event.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.event_declarations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.event_persons'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.event_persons FOR SELECT TO authenticated USING (keystone.has_permission(''event.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.event_persons'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.expense_lines'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.expense_lines FOR SELECT TO authenticated USING (keystone.has_permission(''expense.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.expense_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.expense_payments'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.expense_payments FOR SELECT TO authenticated USING (keystone.has_permission(''expense.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.expense_payments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.expenses'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.expenses FOR SELECT TO authenticated USING (keystone.has_permission(''expense.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.expenses'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.fire_drill_assembly_results'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.fire_drill_assembly_results FOR SELECT TO authenticated USING (keystone.has_permission(''fire.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fire_drill_assembly_results'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.fire_drill_plans'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.fire_drill_plans FOR SELECT TO authenticated USING (keystone.has_permission(''fire.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fire_drill_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.fire_drills'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.fire_drills FOR SELECT TO authenticated USING (keystone.has_permission(''fire.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fire_drills'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.fire_registers'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.fire_registers FOR SELECT TO authenticated USING (keystone.has_permission(''fire.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fire_registers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.fire_system_sectors'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.fire_system_sectors FOR SELECT TO authenticated USING (keystone.has_permission(''fire.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fire_system_sectors'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.fire_systems'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.fire_systems FOR SELECT TO authenticated USING (keystone.has_permission(''fire.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fire_systems'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.fitout_condition_templates'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.fitout_condition_templates FOR SELECT TO authenticated USING (keystone.has_permission(''fitout.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fitout_condition_templates'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.fitout_deposits'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.fitout_deposits FOR SELECT TO authenticated USING (keystone.has_permission(''fitout.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fitout_deposits'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.fitout_requests'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.fitout_requests FOR SELECT TO authenticated USING (keystone.has_permission(''fitout.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fitout_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.fmea_modes'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.fmea_modes FOR SELECT TO authenticated USING (keystone.has_permission(''fmea.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fmea_modes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.fmea_reviews'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.fmea_reviews FOR SELECT TO authenticated USING (keystone.has_permission(''fmea.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fmea_reviews'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.fmea_scales'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.fmea_scales FOR SELECT TO authenticated USING (keystone.has_permission(''fmea.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fmea_scales'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.fmea_studies'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.fmea_studies FOR SELECT TO authenticated USING (keystone.has_permission(''fmea.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.fmea_studies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.ged_classification'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.ged_classification FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ged_classification'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.ged_documents'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.ged_documents FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ged_documents'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.ged_retention_rules'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.ged_retention_rules FOR SELECT TO authenticated USING (keystone.has_permission(''doc.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ged_retention_rules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.governance_meetings'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.governance_meetings FOR SELECT TO authenticated USING (keystone.has_permission(''governance.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.governance_meetings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.import_batch_rows'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.import_batch_rows FOR SELECT TO authenticated USING (keystone.has_permission(''import.run'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.import_batch_rows'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.import_batches'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.import_batches FOR SELECT TO authenticated USING (keystone.has_permission(''import.run'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.import_batches'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.import_mappings'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.import_mappings FOR SELECT TO authenticated USING (keystone.has_permission(''import.run'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.import_mappings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.inspection_answers'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.inspection_answers FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.inspection_answers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.inspection_bodies'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.inspection_bodies FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.inspection_bodies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.inspection_plans'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.inspection_plans FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.inspection_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.inspection_template_items'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.inspection_template_items FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.inspection_template_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.inspection_templates'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.inspection_templates FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.inspection_templates'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.inspections'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.inspections FOR SELECT TO authenticated USING (keystone.has_permission(''inspection.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.inspections'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.integration_connections'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.integration_connections FOR SELECT TO authenticated USING (keystone.has_permission(''integration.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.integration_connections'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.integration_endpoints'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.integration_endpoints FOR SELECT TO authenticated USING (keystone.has_permission(''integration.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.integration_endpoints'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.integration_inbox'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.integration_inbox FOR SELECT TO authenticated USING (keystone.has_permission(''integration.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.integration_inbox'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.integration_mappings'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.integration_mappings FOR SELECT TO authenticated USING (keystone.has_permission(''integration.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.integration_mappings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.integration_outbox'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.integration_outbox FOR SELECT TO authenticated USING (keystone.has_permission(''integration.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.integration_outbox'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.iot_alerts'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.iot_alerts FOR SELECT TO authenticated USING (keystone.has_permission(''iot.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.iot_alerts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.iot_device_status_log'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.iot_device_status_log FOR SELECT TO authenticated USING (keystone.has_permission(''iot.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.iot_device_status_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.iot_devices'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.iot_devices FOR SELECT TO authenticated USING (keystone.has_permission(''iot.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.iot_devices'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.iot_gateway_points'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.iot_gateway_points FOR SELECT TO authenticated USING (keystone.has_permission(''iot.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.iot_gateway_points'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.iot_gateways'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.iot_gateways FOR SELECT TO authenticated USING (keystone.has_permission(''iot.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.iot_gateways'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.iot_thresholds'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.iot_thresholds FOR SELECT TO authenticated USING (keystone.has_permission(''iot.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.iot_thresholds'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.locations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.locations FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.locations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.lone_worker_alerts'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.lone_worker_alerts FOR SELECT TO authenticated USING (keystone.has_permission(''lone_worker.respond'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.lone_worker_alerts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.lone_worker_sessions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.lone_worker_sessions FOR SELECT TO authenticated USING (keystone.has_permission(''lone_worker.respond'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.lone_worker_sessions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.meter_reading_round_items'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.meter_reading_round_items FOR SELECT TO authenticated USING (keystone.has_permission(''meter.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.meter_reading_round_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.meter_reading_round_run_items'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.meter_reading_round_run_items FOR SELECT TO authenticated USING (keystone.has_permission(''meter.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.meter_reading_round_run_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.meter_reading_round_runs'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.meter_reading_round_runs FOR SELECT TO authenticated USING (keystone.has_permission(''meter.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.meter_reading_round_runs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.meter_reading_rounds'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.meter_reading_rounds FOR SELECT TO authenticated USING (keystone.has_permission(''meter.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.meter_reading_rounds'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.meter_readings'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.meter_readings FOR SELECT TO authenticated USING (keystone.has_permission(''meter.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.meter_readings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.mobilization_projects'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.mobilization_projects FOR SELECT TO authenticated USING (keystone.has_permission(''mobilization.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.mobilization_projects'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.mobilization_reserves'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.mobilization_reserves FOR SELECT TO authenticated USING (keystone.has_permission(''mobilization.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.mobilization_reserves'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.mobilization_staff_transfers'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.mobilization_staff_transfers FOR SELECT TO authenticated USING (keystone.has_permission(''mobilization.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.mobilization_staff_transfers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.mobilization_tasks'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.mobilization_tasks FOR SELECT TO authenticated USING (keystone.has_permission(''mobilization.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.mobilization_tasks'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.mobilization_templates'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.mobilization_templates FOR SELECT TO authenticated USING (keystone.has_permission(''mobilization.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.mobilization_templates'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.move_requests'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.move_requests FOR SELECT TO authenticated USING (keystone.has_permission(''move.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.move_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.move_task_templates'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.move_task_templates FOR SELECT TO authenticated USING (keystone.has_permission(''move.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.move_task_templates'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.notification_digests'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.notification_digests FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.notification_digests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.notification_preferences'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.notification_preferences FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.notification_preferences'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.notification_rules'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.notification_rules FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.notification_rules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.notifications'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.notifications FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.notifications'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.occupant_headcount'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.occupant_headcount FOR SELECT TO authenticated USING (keystone.has_permission(''occupant.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.occupant_headcount'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.occupant_organizations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.occupant_organizations FOR SELECT TO authenticated USING (keystone.has_permission(''occupant.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.occupant_organizations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.occupant_site_codes'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.occupant_site_codes FOR SELECT TO authenticated USING (keystone.has_permission(''occupant.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.occupant_site_codes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.occupant_users'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.occupant_users FOR SELECT TO authenticated USING (keystone.has_permission(''occupant.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.occupant_users'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.on_call'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.on_call FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.on_call'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.on_call_escalation_policies'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.on_call_escalation_policies FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.on_call_escalation_policies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.on_call_pages'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.on_call_pages FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.on_call_pages'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.parking_access_logs'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_access_logs FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_access_logs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.parking_reservations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_reservations FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_reservations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.parking_sessions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_sessions FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_sessions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.parking_spaces'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_spaces FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_spaces'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.parking_subscription_plans'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_subscription_plans FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_subscription_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.parking_subscriptions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_subscriptions FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_subscriptions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.parking_tariffs'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_tariffs FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_tariffs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.parking_violations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_violations FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_violations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.parking_zones'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.parking_zones FOR SELECT TO authenticated USING (keystone.has_permission(''parking.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.parking_zones'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.part_requests'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.part_requests FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.part_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.patrol_anomalies'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.patrol_anomalies FOR SELECT TO authenticated USING (keystone.has_permission(''patrol.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.patrol_anomalies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.patrol_routes'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.patrol_routes FOR SELECT TO authenticated USING (keystone.has_permission(''patrol.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.patrol_routes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.patrol_scans'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.patrol_scans FOR SELECT TO authenticated USING (keystone.has_permission(''patrol.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.patrol_scans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.patrols'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.patrols FOR SELECT TO authenticated USING (keystone.has_permission(''patrol.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.patrols'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.payment_intents'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.payment_intents FOR SELECT TO authenticated USING (keystone.has_permission(''payment.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.payment_intents'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.payment_reconciliation_issues'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.payment_reconciliation_issues FOR SELECT TO authenticated USING (keystone.has_permission(''payment.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.payment_reconciliation_issues'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.payment_requests'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.payment_requests FOR SELECT TO authenticated USING (keystone.has_permission(''payment.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.payment_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.permit_approvals'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_approvals FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_approvals'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.permit_extensions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_extensions FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_extensions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.permit_gas_tests'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_gas_tests FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_gas_tests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.permit_isolations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_isolations FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_isolations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.permit_personal_locks'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_personal_locks FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_personal_locks'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.permit_rubric_rules'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_rubric_rules FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_rubric_rules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.permit_signatures'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_signatures FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_signatures'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.permit_watchers'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_watchers FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_watchers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.permit_workers'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.permit_workers FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.permit_workers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.person_competencies'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.person_competencies FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.person_competencies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.persons'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.persons FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.persons'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.pest_interventions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.pest_interventions FOR SELECT TO authenticated USING (keystone.has_permission(''pest.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.pest_interventions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.pest_quarterly_reports'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.pest_quarterly_reports FOR SELECT TO authenticated USING (keystone.has_permission(''pest.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.pest_quarterly_reports'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.plan_imports'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.plan_imports FOR SELECT TO authenticated USING (keystone.has_permission(''plan.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.plan_imports'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.planning_baseline_items'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.planning_baseline_items FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.planning_baseline_items'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.planning_baselines'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.planning_baselines FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.planning_baselines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.planning_freezes'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.planning_freezes FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.planning_freezes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.presence'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.presence FOR SELECT TO authenticated USING (keystone.has_permission(''presence.view'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.presence'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.presence_access_log'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.presence_access_log FOR SELECT TO authenticated USING (keystone.has_permission(''presence.view'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.presence_access_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.privacy_breaches'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.privacy_breaches FOR SELECT TO authenticated USING (keystone.has_permission(''privacy.erase'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.privacy_breaches'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.privacy_formalities'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.privacy_formalities FOR SELECT TO authenticated USING (keystone.has_permission(''privacy.erase'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.privacy_formalities'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.privacy_request_events'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.privacy_request_events FOR SELECT TO authenticated USING (keystone.has_permission(''privacy.erase'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.privacy_request_events'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.privacy_requests'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.privacy_requests FOR SELECT TO authenticated USING (keystone.has_permission(''privacy.erase'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.privacy_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.processing_activities'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.processing_activities FOR SELECT TO authenticated USING (keystone.has_permission(''privacy.erase'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.processing_activities'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.purchase_comments'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.purchase_comments FOR SELECT TO authenticated USING (keystone.has_permission(''purchase.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.purchase_comments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.purchase_orders'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.purchase_orders FOR SELECT TO authenticated USING (keystone.has_permission(''purchase.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.purchase_orders'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.purchase_request_lines'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.purchase_request_lines FOR SELECT TO authenticated USING (keystone.has_permission(''purchase.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.purchase_request_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.purchase_requests'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.purchase_requests FOR SELECT TO authenticated USING (keystone.has_permission(''purchase.approve'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.purchase_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.qc_elements'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.qc_elements FOR SELECT TO authenticated USING (keystone.has_permission(''qc.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.qc_elements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.qc_profiles'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.qc_profiles FOR SELECT TO authenticated USING (keystone.has_permission(''qc.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.qc_profiles'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.qc_scores'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.qc_scores FOR SELECT TO authenticated USING (keystone.has_permission(''qc.record'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.qc_scores'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.reception_log'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.reception_log FOR SELECT TO authenticated USING (keystone.has_permission(''reception.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.reception_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.regulatory_control_results'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.regulatory_control_results FOR SELECT TO authenticated USING (keystone.has_permission(''crp.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.regulatory_control_results'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.regulatory_controls'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.regulatory_controls FOR SELECT TO authenticated USING (keystone.has_permission(''crp.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.regulatory_controls'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.regulatory_derogations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.regulatory_derogations FOR SELECT TO authenticated USING (keystone.has_permission(''crp.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.regulatory_derogations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.regulatory_regimes'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.regulatory_regimes FOR SELECT TO authenticated USING (keystone.has_permission(''crp.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.regulatory_regimes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.regulatory_watch'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.regulatory_watch FOR SELECT TO authenticated USING (keystone.has_permission(''crp.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.regulatory_watch'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.report_publications'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.report_publications FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.report_publications'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.report_runs'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.report_runs FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.report_runs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.report_schedules'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.report_schedules FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.report_schedules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.report_templates'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.report_templates FOR SELECT TO authenticated USING (keystone.has_permission(''report.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.report_templates'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.rfq_criteria'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.rfq_criteria FOR SELECT TO authenticated USING (keystone.has_permission(''rfq.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.rfq_criteria'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.rfq_deadline_changes'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.rfq_deadline_changes FOR SELECT TO authenticated USING (keystone.has_permission(''rfq.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.rfq_deadline_changes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.rfq_invitations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.rfq_invitations FOR SELECT TO authenticated USING (keystone.has_permission(''rfq.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.rfq_invitations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.rfq_response_lines'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.rfq_response_lines FOR SELECT TO authenticated USING (keystone.has_permission(''rfq.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.rfq_response_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.rfq_responses'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.rfq_responses FOR SELECT TO authenticated USING (keystone.has_permission(''rfq.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.rfq_responses'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.rfqs'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.rfqs FOR SELECT TO authenticated USING (keystone.has_permission(''rfq.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.rfqs'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.risk_assessment_lines'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_assessment_lines FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_assessment_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.risk_assessments'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_assessments FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_assessments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.risk_criteria'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_criteria FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_criteria'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.risk_links'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_links FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_links'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.risk_rating_history'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_rating_history FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_rating_history'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.risk_score_models'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_score_models FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_score_models'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.risk_scores'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.risk_scores FOR SELECT TO authenticated USING (keystone.has_permission(''risk.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.risk_scores'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.role_permissions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.role_permissions FOR SELECT TO authenticated USING (keystone.has_permission(''role.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.role_permissions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.roles'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.roles FOR SELECT TO authenticated USING (keystone.has_permission(''role.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.roles'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.scim_events'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.scim_events FOR SELECT TO authenticated USING (keystone.has_permission(''scim.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.scim_events'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.scim_groups'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.scim_groups FOR SELECT TO authenticated USING (keystone.has_permission(''scim.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.scim_groups'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.scim_tokens'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.scim_tokens FOR SELECT TO authenticated USING (keystone.has_permission(''scim.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.scim_tokens'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.security_handover'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.security_handover FOR SELECT TO authenticated USING (keystone.has_permission(''security.kpi_read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.security_handover'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.security_log'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.security_log FOR SELECT TO authenticated USING (keystone.has_permission(''security.kpi_read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.security_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.security_log_types'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.security_log_types FOR SELECT TO authenticated USING (keystone.has_permission(''security.kpi_read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.security_log_types'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.security_posts'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.security_posts FOR SELECT TO authenticated USING (keystone.has_permission(''security.kpi_read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.security_posts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.service_contract_amendments'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.service_contract_amendments FOR SELECT TO authenticated USING (keystone.has_permission(''service_contract.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.service_contract_amendments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.service_contract_scope'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.service_contract_scope FOR SELECT TO authenticated USING (keystone.has_permission(''service_contract.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.service_contract_scope'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.service_contracts'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.service_contracts FOR SELECT TO authenticated USING (keystone.has_permission(''service_contract.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.service_contracts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.service_types'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.service_types FOR SELECT TO authenticated USING (keystone.has_permission(''service.execute'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.service_types'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.settings'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.settings FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.settings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.settings_history'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.settings_history FOR SELECT TO authenticated USING (keystone.has_permission(''settings.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.settings_history'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.shift_pattern_slots'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.shift_pattern_slots FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.shift_pattern_slots'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.shift_patterns'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.shift_patterns FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.shift_patterns'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.shifts'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.shifts FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.shifts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.site_announcements'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.site_announcements FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_announcements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.site_blackouts'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.site_blackouts FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_blackouts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.site_business_hours'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.site_business_hours FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_business_hours'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.site_directory'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.site_directory FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_directory'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.site_ext'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.site_ext FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_ext'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.site_fire_settings'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.site_fire_settings FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_fire_settings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.site_regulatory_suspensions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.site_regulatory_suspensions FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.site_regulatory_suspensions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.space_bookings'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.space_bookings FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_bookings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.space_chargeback_rules'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.space_chargeback_rules FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_chargeback_rules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.space_chargebacks'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.space_chargebacks FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_chargebacks'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.space_ext'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.space_ext FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_ext'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.space_measurements'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.space_measurements FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_measurements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.space_occupancies'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.space_occupancies FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_occupancies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.space_plans'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.space_plans FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_plans'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.space_scenarios'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.space_scenarios FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_scenarios'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.space_utilization_hourly'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.space_utilization_hourly FOR SELECT TO authenticated USING (keystone.has_permission(''space.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.space_utilization_hourly'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.spare_parts'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.spare_parts FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.spare_parts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.stock_issue_refusals'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.stock_issue_refusals FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.stock_issue_refusals'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.stock_movements'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.stock_movements FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.stock_movements'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.stock_reservations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.stock_reservations FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.stock_reservations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.stock_transfer_lines'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.stock_transfer_lines FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.stock_transfer_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.stock_transfers'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.stock_transfers FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.stock_transfers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.survey_followups'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.survey_followups FOR SELECT TO authenticated USING (keystone.has_permission(''survey.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.survey_followups'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.survey_invitations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.survey_invitations FOR SELECT TO authenticated USING (keystone.has_permission(''survey.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.survey_invitations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.survey_questions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.survey_questions FOR SELECT TO authenticated USING (keystone.has_permission(''survey.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.survey_questions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.survey_responses'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.survey_responses FOR SELECT TO authenticated USING (keystone.has_permission(''survey.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.survey_responses'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.surveys'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.surveys FOR SELECT TO authenticated USING (keystone.has_permission(''survey.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.surveys'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.team_members'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.team_members FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.team_members'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.teams'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.teams FOR SELECT TO authenticated USING (keystone.has_permission(''planning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.teams'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.ticket_attachments'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_attachments FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_attachments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.ticket_categories'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_categories FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_categories'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.ticket_comments'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_comments FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_comments'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.ticket_followers'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_followers FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_followers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.ticket_status_history'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_status_history FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_status_history'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.ticket_templates'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_templates FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_templates'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.ticket_work_orders'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.ticket_work_orders FOR SELECT TO authenticated USING (keystone.has_permission(''ticket.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.ticket_work_orders'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.training_media'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.training_media FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.training_media'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.training_records'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.training_records FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.training_records'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.training_sessions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.training_sessions FOR SELECT TO authenticated USING (keystone.has_permission(''person.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.training_sessions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.user_quiet_hours'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.user_quiet_hours FOR SELECT TO authenticated USING (keystone.has_permission(''user.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.user_quiet_hours'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.user_roles'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.user_roles FOR SELECT TO authenticated USING (keystone.has_permission(''user.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.user_roles'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.user_scope'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.user_scope FOR SELECT TO authenticated USING (keystone.has_permission(''user.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.user_scope'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.users'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.users FOR SELECT TO authenticated USING (keystone.has_permission(''user.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.users'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.vendor_bank_changes'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_bank_changes FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_bank_changes'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.vendor_change_requests'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_change_requests FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_change_requests'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.vendor_contacts'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_contacts FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_contacts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.vendor_doc_daily_status'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_doc_daily_status FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_doc_daily_status'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.vendor_document_types'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_document_types FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_document_types'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.vendor_messages'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_messages FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_messages'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.vendor_rate_lines'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_rate_lines FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_rate_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.vendor_score_snapshots'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_score_snapshots FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_score_snapshots'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.vendor_site_restrictions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_site_restrictions FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_site_restrictions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.vendor_status_history'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_status_history FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_status_history'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.vendor_users'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.vendor_users FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendor_users'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.vendors'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.vendors FOR SELECT TO authenticated USING (keystone.has_permission(''vendor.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.vendors'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.visitor_denylist'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.visitor_denylist FOR SELECT TO authenticated USING (keystone.has_permission(''visitor.denylist_manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.visitor_denylist'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.visitors'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.visitors FOR SELECT TO authenticated USING (keystone.has_permission(''visitor.denylist_manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.visitors'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.warehouses'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.warehouses FOR SELECT TO authenticated USING (keystone.has_permission(''stock.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.warehouses'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.waste_records'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.waste_records FOR SELECT TO authenticated USING (keystone.has_permission(''waste.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.waste_records'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.waste_streams'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.waste_streams FOR SELECT TO authenticated USING (keystone.has_permission(''waste.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.waste_streams'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.waste_tracking_slips'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.waste_tracking_slips FOR SELECT TO authenticated USING (keystone.has_permission(''waste.manage'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.waste_tracking_slips'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.wo_checkpoint_results'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_checkpoint_results FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_checkpoint_results'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.wo_instructions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_instructions FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_instructions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.wo_reports'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_reports FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_reports'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.wo_required_competencies'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_required_competencies FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_required_competencies'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.wo_required_permits'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_required_permits FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_required_permits'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.wo_required_tools'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_required_tools FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_required_tools'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.wo_reschedules'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_reschedules FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_reschedules'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.wo_scan_log'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_scan_log FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_scan_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.wo_template_parts'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_template_parts FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_template_parts'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.wo_template_tasks'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_template_tasks FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_template_tasks'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.wo_transitions_log'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_transitions_log FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_transitions_log'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.wo_work_sessions'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.wo_work_sessions FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.wo_work_sessions'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.work_center_categories'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.work_center_categories FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_center_categories'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.work_centers'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.work_centers FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_centers'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.work_order_lines'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.work_order_lines FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_order_lines'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.work_order_team'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.work_order_team FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_order_team'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.work_orders'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.work_orders FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_orders'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.work_permits'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.work_permits FOR SELECT TO authenticated USING (keystone.has_permission(''permit.activate'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_permits'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.work_units'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.work_units FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.work_units'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.worked_hours'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.worked_hours FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.worked_hours'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.worker_consultations'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.worker_consultations FOR SELECT TO authenticated USING (keystone.has_permission(''wo.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.worker_consultations'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.zones'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.zones FOR SELECT TO authenticated USING (keystone.has_permission(''site.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.zones'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.zoning_types'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.zoning_types FOR SELECT TO authenticated USING (keystone.has_permission(''zoning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.zoning_types'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'keystone.zonings'::regclass AND polname = 'module_read') THEN
  EXECUTE 'CREATE POLICY module_read ON keystone.zonings FOR SELECT TO authenticated USING (keystone.has_permission(''zoning.read'')' ||
    CASE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'keystone.zonings'::regclass AND attname = 'deleted_at' AND NOT attisdropped) THEN ' AND deleted_at IS NULL' ELSE '' END || ')';
END IF; END $$;

-- keystone_26c_sync_ref_counters — recale ref_counters sur les références déjà présentes
-- Les OT/tickets de démo d'origine portent des refs saisies en dur (WO-2026-000001…) sans incrément du compteur :
-- next_ref('WO') renvoyait alors une ref existante → violation uq_wo_ref. Idempotent (GREATEST).
INSERT INTO keystone.ref_counters(tenant_id, prefix, year, n)
SELECT tenant_id, split_part(ref, '-', 1), split_part(ref, '-', 2)::int, max(split_part(ref, '-', 3)::int)
FROM (
  SELECT tenant_id, ref FROM keystone.work_orders
  UNION ALL SELECT tenant_id, ref FROM keystone.service_requests
  UNION ALL SELECT tenant_id, ref FROM keystone.hsse_events
  UNION ALL SELECT tenant_id, ref FROM keystone.capa_actions
  UNION ALL SELECT tenant_id, ref FROM keystone.work_permits
) x
WHERE ref ~ '^[A-Z]+-[0-9]{4}-[0-9]+$'
GROUP BY 1, 2, 3
ON CONFLICT (tenant_id, prefix, year) DO UPDATE SET n = GREATEST(keystone.ref_counters.n, EXCLUDED.n);

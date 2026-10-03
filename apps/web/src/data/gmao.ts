import { supabase } from '../lib/supabase.ts';
import type { WorkOrderRow, DemoSummary, MaintKpi, PredictionRow } from '@keystone/domain/db/keystone';

interface RawWo {
  id: string; ref: string; title: string; type: WorkOrderRow['type']; status: WorkOrderRow['status'];
  priority: number; requires_permit: boolean; sla_due: string | null; planned_start: string | null;
  cost_labor: number; cost_parts: number;
  assets: { tag: string | null; name: string | null } | null;
  locations: { name: string | null } | null;
}

/** Lecture des OT — table directe protégée par RLS (le tenant est résolu via l'utilisateur connecté). */
export async function fetchWorkOrders(): Promise<WorkOrderRow[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase
    .schema('keystone')
    .from('work_orders')
    .select('id,ref,title,type,status,priority,requires_permit,sla_due,planned_start,cost_labor,cost_parts,assets(tag,name),locations(name)')
    .is('deleted_at', null)
    .order('status')
    .order('sla_due', { nullsFirst: false });
  if (error) throw new Error(error.message);
  return ((data ?? []) as unknown as RawWo[]).map((r) => ({
    id: r.id, ref: r.ref, title: r.title, type: r.type, status: r.status, priority: r.priority,
    requires_permit: r.requires_permit, sla_due: r.sla_due, planned_start: r.planned_start,
    cost_labor: r.cost_labor, cost_parts: r.cost_parts,
    asset_tag: r.assets?.tag ?? null, asset_name: r.assets?.name ?? null, location_name: r.locations?.name ?? null,
  }));
}

export async function fetchSummary(): Promise<DemoSummary> {
  if (!supabase) throw new Error('Supabase non configuré (mode démo).');
  const { data, error } = await supabase.schema('keystone').rpc('demo_summary');
  if (error) throw new Error(error.message);
  return data as DemoSummary;
}

export async function fetchKpi(): Promise<MaintKpi> {
  if (!supabase) throw new Error('Supabase non configuré (mode démo).');
  const { data, error } = await supabase.schema('keystone').rpc('demo_kpi');
  if (error) throw new Error(error.message);
  return data as MaintKpi;
}

/** Prédictions ouvertes (Sentinelle / PROPH3T), RLS-scopé. */
export async function fetchPredictions(): Promise<PredictionRow[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('predictions_board');
  if (error) throw new Error(error.message);
  return ((data ?? []) as PredictionRow[]).map((p) => ({
    ...p, rul_days: p.rul_days == null ? null : Number(p.rul_days),
    confidence: p.confidence == null ? null : Number(p.confidence), drift_pct: p.drift_pct == null ? null : Number(p.drift_pct),
  }));
}

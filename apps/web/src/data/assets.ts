import { supabase } from '../lib/supabase.ts';
import type { AssetRow, FmeaRow, FailureFamily, ParetoCriterion, ParetoRow } from '@keystone/domain/db/keystone';

const num = (v: unknown) => (v == null ? null : Number(v));

export async function fetchAssets(): Promise<AssetRow[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('assets_board');
  if (error) throw new Error(error.message);
  return ((data ?? []) as AssetRow[]).map((a) => ({
    ...a,
    age_years: num(a.age_years), replacement_value: num(a.replacement_value), mtbf_h: num(a.mtbf_h), mttr_h: num(a.mttr_h),
    prediction_rul_days: num(a.prediction_rul_days), max_rpn: num(a.max_rpn),
    wo_open: Number(a.wo_open), wo_corrective_12m: Number(a.wo_corrective_12m), downtime_12m_h: Number(a.downtime_12m_h),
    cost_12m: Number(a.cost_12m), fmea_count: Number(a.fmea_count), health: Number(a.health),
  }));
}

export async function fetchFmea(): Promise<FmeaRow[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('fmea_board');
  if (error) throw new Error(error.message);
  return (data ?? []) as FmeaRow[];
}

export async function createFmeaAction(id: string): Promise<{ wo_id: string; ref: string }> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('fmea_create_action', { p_item: id });
  if (error) throw new Error(error.message);
  return data as { wo_id: string; ref: string };
}

export async function fetchFailureFamilies(): Promise<FailureFamily[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('failure_library_families');
  if (error) throw new Error(error.message);
  return (data ?? []) as FailureFamily[];
}

export async function fmeaFromLibrary(assetId: string, family: string): Promise<{ created: number }> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('fmea_from_library', { p_asset: assetId, p_family: family });
  if (error) throw new Error(error.message);
  return data as { created: number };
}

export async function fetchPareto(criterion: ParetoCriterion, months = 12): Promise<ParetoRow[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('failure_pareto', { p_criterion: criterion, p_months: months });
  if (error) throw new Error(error.message);
  return ((data ?? []) as ParetoRow[]).map((r) => ({
    ...r, cost: Number(r.cost), downtime_h: Number(r.downtime_h), value: Number(r.value), pct: Number(r.pct),
    cumulative_pct: Number(r.cumulative_pct), mtbf_h: num(r.mtbf_h), mttr_h: num(r.mttr_h), availability_pct: num(r.availability_pct),
  }));
}

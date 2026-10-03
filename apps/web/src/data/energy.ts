import { supabase } from '../lib/supabase.ts';
import type { EnergyMonthly, EnergySummary, EnergyTargetRow } from '@keystone/domain/db/keystone';

async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc(fn, args);
  if (error) throw new Error(error.message);
  return data as T;
}
const n = (v: unknown) => (v == null ? null : Number(v));

export async function fetchEnergyMonthly(months = 12): Promise<EnergyMonthly[]> {
  const rows = await rpc<EnergyMonthly[]>('energy_monthly', { p_months: months });
  return (rows ?? []).map((r) => ({ ...r, quantity: Number(r.quantity), kwh: Number(r.kwh), kg_co2e: Number(r.kg_co2e), cost: Number(r.cost) }));
}
export async function fetchEnergySummary(): Promise<EnergySummary> {
  const s = await rpc<Record<string, unknown>>('energy_summary');
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(s)) out[k] = typeof v === 'boolean' ? v : k === 'intensity_kwh_m2' ? n(v) : Number(v ?? 0);
  return out as unknown as EnergySummary;
}
export async function fetchEnergyTargets(): Promise<EnergyTargetRow[]> {
  const rows = await rpc<EnergyTargetRow[]>('energy_targets_status');
  return (rows ?? []).map((r) => ({ ...r, actual: n(r.actual), target: Number(r.target), alert: Number(r.alert), critical: Number(r.critical), gap_pct: n(r.gap_pct) }));
}

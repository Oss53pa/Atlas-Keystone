import { supabase } from '../lib/supabase.ts';
import type { WasteRow, WasteMonthly, WasteSummary, WasteObjective } from '@keystone/domain/db/keystone';

async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc(fn, args);
  if (error) throw new Error(error.message);
  return data as T;
}
const n = (v: unknown) => (v == null ? null : Number(v));

export async function fetchWaste(): Promise<WasteRow[]> {
  const rows = await rpc<WasteRow[]>('waste_board', { p_months: 12 });
  return (rows ?? []).map((r) => ({ ...r, quantity_kg: Number(r.quantity_kg), cost: n(r.cost), kg_co2e: Number(r.kg_co2e) }));
}
export async function fetchWasteMonthly(): Promise<WasteMonthly[]> {
  const rows = await rpc<WasteMonthly[]>('waste_monthly', { p_months: 12 });
  return (rows ?? []).map((r) => ({
    period: r.period, total_kg: Number(r.total_kg), valorized_kg: Number(r.valorized_kg), eliminated_kg: Number(r.eliminated_kg),
    dangerous_kg: Number(r.dangerous_kg), valorization_pct: n(r.valorization_pct),
  }));
}
export async function fetchWasteSummary(): Promise<WasteSummary> {
  const s = await rpc<Record<string, unknown>>('waste_summary');
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(s)) out[k] = k === 'valorization_pct' ? n(v) : Number(v ?? 0);
  return out as unknown as WasteSummary;
}
export async function fetchWasteObjectives(): Promise<WasteObjective[]> {
  const rows = await rpc<WasteObjective[]>('waste_objectives_board');
  return (rows ?? []).map((r) => ({ ...r, target: Number(r.target), actual: n(r.actual) }));
}

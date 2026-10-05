import { supabase } from '../lib/supabase.ts';
import type { MeterRow, BalanceRow, BillCheckRow, RebillRow, Tariff, TariffBreakdown, UtilitiesSummary } from '@keystone/domain/db/keystone';

function db() {
  if (!supabase) throw new Error('Supabase non configuré.');
  return supabase.schema('keystone');
}
async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await db().rpc(fn, args);
  if (error) throw new Error(error.details ? `${error.message} — ${error.details}` : error.message);
  return data as T;
}
const N = (v: unknown) => (v == null ? null : Number(v));

export async function fetchMeters(): Promise<MeterRow[]> {
  const rows = await rpc<MeterRow[]>('meters_board');
  return (rows ?? []).map((r) => ({
    ...r, subscribed_kva: N(r.subscribed_kva), last_index: N(r.last_index), last_qty: N(r.last_qty), avg_qty: N(r.avg_qty),
    variation_pct: N(r.variation_pct), series: (r.series ?? []).map(Number),
  }));
}
export async function fetchBalance(months = 6): Promise<BalanceRow[]> {
  const rows = await rpc<BalanceRow[]>('submeter_balance', { p_months: months });
  return (rows ?? []).map((r) => ({
    ...r, main_qty: Number(r.main_qty), sub_qty: Number(r.sub_qty), leased_qty: Number(r.leased_qty), common_qty: Number(r.common_qty),
    unmetered_qty: Number(r.unmetered_qty), loss_pct: N(r.loss_pct),
  }));
}
export async function fetchBillCheck(months = 12): Promise<BillCheckRow[]> {
  const rows = await rpc<BillCheckRow[]>('utility_bill_check', { p_months: months });
  return (rows ?? []).map((r) => ({
    ...r, invoiced_qty: Number(r.invoiced_qty), invoiced_ht: N(r.invoiced_ht), computed_ht: Number(r.computed_ht),
    variance: N(r.variance), variance_pct: N(r.variance_pct),
  }));
}
export async function fetchRebill(period: string): Promise<RebillRow[]> {
  const rows = await rpc<RebillRow[]>('rebill_preview', { p_period: period });
  return (rows ?? []).map((r) => ({ ...r, qty: Number(r.qty), unit_cost: N(r.unit_cost), amount_ht: N(r.amount_ht), vat_amount: N(r.vat_amount) }));
}
export const rebillPost = (period: string) => rpc<{ posted: number; amount_ht: number; skipped: number }>('rebill_post', { p_period: period });
export const fetchTariffs = async () => ((await rpc<Tariff[]>('tariffs_board')) ?? []);
export const tariffCompute = (tariff: string, qty: number, kva?: number | null, profile?: Record<string, number> | null) =>
  rpc<TariffBreakdown>('tariff_compute', { p_tariff: tariff, p_qty: qty, p_kva: kva ?? null, p_profile: profile ?? null });
export const recordReading = (meter: string, date: string, index: number, reset: boolean, note?: string) =>
  rpc<{ qty: number | null; avg: number | null; flag: 'SPIKE' | 'DROP' | null }>('meter_record_reading', {
    p_meter: meter, p_date: date, p_index: index, p_reset: reset, p_note: note ?? null, p_source: 'manual',
  });
export async function fetchUtilitiesSummary(): Promise<UtilitiesSummary> {
  const s = await rpc<Record<string, unknown>>('utilities_summary');
  return Object.fromEntries(Object.entries(s).map(([k, v]) => [k, v == null ? null : k === 'last_period' ? v : Number(v)])) as unknown as UtilitiesSummary;
}
export async function saveBand(id: string, unit_price: number) {
  const { error } = await db().from('utility_tariff_bands').update({ unit_price }).eq('id', id);
  if (error) throw new Error(error.message);
}
export async function saveTariff(id: string, patch: { fixed_monthly?: number; demand_charge?: number }) {
  const { error } = await db().from('utility_tariffs').update(patch).eq('id', id);
  if (error) throw new Error(error.message);
}

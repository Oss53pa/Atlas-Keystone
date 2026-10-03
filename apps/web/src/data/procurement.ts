import { supabase } from '../lib/supabase.ts';
import type { StockRow, PurchaseRequestRow, PurchaseOrderRow, ProcurementSummary } from '@keystone/domain/db/keystone';

async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc(fn, args);
  if (error) throw new Error(error.details ? `${error.message} — ${error.details}` : error.message);
  return data as T;
}
const n = (v: unknown) => (v == null ? null : Number(v));

export async function fetchStock(): Promise<StockRow[]> {
  const rows = await rpc<StockRow[]>('stock_board');
  return (rows ?? []).map((r) => ({
    ...r, qty: Number(r.qty), min_qty: Number(r.min_qty), max_qty: Number(r.max_qty), reorder_point: Number(r.reorder_point),
    unit_cost: n(r.unit_cost), stock_value: Number(r.stock_value), daily_use: Number(r.daily_use), days_cover: n(r.days_cover),
    suggested_qty: Number(r.suggested_qty), on_order: Number(r.on_order),
  }));
}
export async function fetchPurchaseRequests(): Promise<PurchaseRequestRow[]> {
  const rows = await rpc<PurchaseRequestRow[]>('pr_board');
  return (rows ?? []).map((r) => ({ ...r, total: Number(r.total), budget_available: n(r.budget_available) }));
}
export async function fetchPurchaseOrders(): Promise<PurchaseOrderRow[]> {
  const rows = await rpc<PurchaseOrderRow[]>('po_board');
  return (rows ?? []).map((r) => ({ ...r, amount_ht: Number(r.amount_ht), amount_ttc: Number(r.amount_ttc) }));
}
export async function fetchProcurementSummary(): Promise<ProcurementSummary> {
  const s = await rpc<Record<keyof ProcurementSummary, unknown>>('procurement_summary');
  return Object.fromEntries(Object.entries(s).map(([k, v]) => [k, Number(v)])) as unknown as ProcurementSummary;
}

export type PrAction = 'submit' | 'approve_tech' | 'approve_budget' | 'approve_direction' | 'reject';
export const prTransition = (id: string, action: PrAction, comment?: string) =>
  rpc<{ status: string }>('pr_transition', { p_pr: id, p_action: action, p_comment: comment ?? null });
export const prToPo = (id: string) => rpc<{ po_id: string; ref: string }>('pr_to_po', { p_pr: id });
export const poReceive = (id: string, qc: 'accepted' | 'accepted_with_reserves' | 'refused') =>
  rpc<{ status: string; stock_in: number }>('po_receive', { p_po: id, p_qc: qc, p_notes: null });
export const prFromStockAlerts = () => rpc<{ created: number }>('pr_from_stock_alerts');

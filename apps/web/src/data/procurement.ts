import { supabase } from '../lib/supabase.ts';
import type {
  StockRow, PurchaseRequestRow, PurchaseOrderRow, ProcurementSummary, SupplierInvoiceRow, SupplierInvoiceDetail, PoLineStatus, ApSummary,
} from '@keystone/domain/db/keystone';

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

/* ---------- Rapprochement BC / réception / facture (migration 42) ---------- */
const nums = <T extends object>(o: T, keys: (keyof T)[]): T => {
  const out = { ...o } as Record<keyof T, unknown>;
  for (const k of keys) if (out[k] != null) out[k] = Number(out[k]);
  return out as T;
};
export async function fetchSupplierInvoices(): Promise<SupplierInvoiceRow[]> {
  const rows = await rpc<SupplierInvoiceRow[]>('supplier_invoices_board');
  return (rows ?? []).map((r) => nums({ ...r, issues: r.issues ?? [], issue_labels: r.issue_labels ?? [] }, ['amount_ht', 'amount_ttc', 'expected_ht', 'variance_ht']));
}
export const fetchSupplierInvoice = (id: string) => rpc<SupplierInvoiceDetail>('invoice_detail', { p_inv: id });
export async function fetchPoLines(po: string): Promise<PoLineStatus[]> {
  const rows = await rpc<PoLineStatus[]>('po_lines_status', { p_po: po });
  return (rows ?? []).map((r) => nums(r, ['qty_ordered', 'qty_received', 'qty_refused', 'qty_to_receive', 'qty_invoiced', 'qty_to_invoice', 'unit_price']));
}
export async function fetchApSummary(): Promise<ApSummary> {
  const s = await rpc<Record<string, unknown>>('ap_summary');
  return Object.fromEntries(Object.entries(s).map(([k, v]) => [k, v == null ? null : Number(v)])) as unknown as ApSummary;
}
export type InvoiceLineInput = { po_line_id: string | null; label?: string; qty: number; unit_price: number };
export const invoiceRegister = (po: string, supplierRef: string, date: string, lines: InvoiceLineInput[] | null, amountHt?: number | null) =>
  rpc<{ id: string; ref: string; status: string; variance_ht: number }>('invoice_register', {
    p_po: po, p_supplier_ref: supplierRef, p_invoice_date: date, p_lines: lines, p_amount_ht: amountHt ?? null, p_tax_rate: 18, p_due_days: null,
  });
export type InvoiceAction = 'approve' | 'force_approve' | 'reject' | 'pay' | 'rematch';
export const invoiceTransition = (id: string, action: InvoiceAction, comment?: string) =>
  rpc<{ status: string }>('invoice_transition', { p_inv: id, p_action: action, p_comment: comment ?? null });
export const poReceiveLines = (po: string, lines: { line_id: string; qty: number; refused: number }[], qc: 'accepted' | 'accepted_with_reserves' | 'refused', notes?: string) =>
  rpc<{ status: string; stock_in: number }>('po_receive_lines', { p_po: po, p_lines: lines, p_qc: qc, p_notes: notes ?? null });

import { supabase } from '../lib/supabase.ts';
import type {
  RentRollRow, RentSummary, ArrearsRow, ScheduleRow, ChargeRegRow, RentReceipt, NewsItem, LesseeHome,
} from '@keystone/domain/db/keystone';

async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc(fn, args);
  if (error) throw new Error(error.details ? `${error.message} — ${error.details}` : error.message);
  return data as T;
}
const n = (v: unknown) => (v == null ? null : Number(v));
const nn = (v: unknown) => Number(v ?? 0);

/* ---------- Back-office ---------- */
export async function fetchRentRoll(): Promise<RentRollRow[]> {
  const rows = await rpc<RentRollRow[]>('rent_roll');
  return (rows ?? []).map((r) => ({
    ...r, area_m2: nn(r.area_m2), monthly_rent: nn(r.monthly_rent), rent_m2_month: n(r.rent_m2_month), charges_provision: nn(r.charges_provision),
    months_left: n(r.months_left), arrears: nn(r.arrears), arrears_days: n(r.arrears_days), open_tickets: nn(r.open_tickets),
  }));
}
export async function fetchRentSummary(): Promise<RentSummary> {
  const s = await rpc<Record<string, unknown>>('rent_summary');
  const nullable = new Set(['occupancy_pct', 'avg_rent_m2', 'walt_years', 'collection_pct']);
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(s)) out[k] = nullable.has(k) ? n(v) : nn(v);
  return out as unknown as RentSummary;
}
export async function fetchArrears(): Promise<ArrearsRow[]> {
  const rows = await rpc<ArrearsRow[]>('arrears_board');
  return (rows ?? []).map((r) => ({ ...r, total_due: nn(r.total_due), paid: nn(r.paid), balance: nn(r.balance) }));
}
export async function fetchSchedules(lessee?: string, months = 2): Promise<ScheduleRow[]> {
  const rows = await rpc<ScheduleRow[]>('rent_schedule_board', { p_lessee: lessee ?? null, p_months: months });
  return (rows ?? []).map((r) => ({
    ...r, rent: nn(r.rent), charges: nn(r.charges), vat: nn(r.vat), total_due: nn(r.total_due), paid: nn(r.paid),
  }));
}
export async function fetchChargesRegularization(year: number): Promise<ChargeRegRow[]> {
  const rows = await rpc<ChargeRegRow[]>('charges_regularization', { p_year: year });
  return (rows ?? []).map((r) => ({
    ...r, weighted_m2: nn(r.weighted_m2), share_pct: nn(r.share_pct), real_charges: nn(r.real_charges),
    provisions_billed: nn(r.provisions_billed), balance: nn(r.balance),
  }));
}
export async function fetchChargePools(year: number): Promise<{ site: string; category: string; amount: number }[]> {
  const rows = await rpc<{ site: string; category: string; amount: number }[]>('charge_pools_board', { p_year: year });
  return (rows ?? []).map((r) => ({ ...r, amount: nn(r.amount) }));
}
export const fetchNews = () => rpc<NewsItem[]>('news_board');
export type PayMethod = 'mobile_money' | 'transfer' | 'cheque' | 'cash' | 'card';
export const recordRentPayment = (schedule: string, amount: number, method: PayMethod) =>
  rpc<{ provider_ref: string | null; balance: number }>('rent_record_payment', { p_schedule: schedule, p_amount: amount, p_method: method });
export const sendRentReminder = (schedule: string) => rpc<{ reminders_sent: number }>('rent_send_reminder', { p_schedule: schedule });
export const applyIndexation = (lease: string, indexValue?: number) =>
  rpc<{ old_rent: number; new_rent: number; variation_pct: number }>('lease_apply_indexation', { p_lease: lease, p_index_value: indexValue ?? null });
export const generateAllSchedules = (ahead = 2) => rpc<{ created: number }>('rent_generate_all', { p_ahead: ahead });
export async function fetchReceipt(schedule: string): Promise<RentReceipt> {
  const r = await rpc<RentReceipt>('rent_receipt', { p_schedule: schedule });
  return { ...r, rent: nn(r.rent), charges: nn(r.charges), vat: nn(r.vat), vat_rate: nn(r.vat_rate), total: nn(r.total) };
}
export async function publishNews(siteId: string, kind: NewsItem['kind'], title: string, body: string, eventDate?: string) {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { error } = await supabase.schema('keystone').from('center_news')
    .insert({ site_id: siteId, kind, title, body, event_date: eventDate || null });
  if (error) throw new Error(error.message);
}
export async function fetchSites(): Promise<{ id: string; name: string }[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').from('sites').select('id, name').is('deleted_at', null).order('name');
  if (error) throw new Error(error.message);
  return (data ?? []) as { id: string; name: string }[];
}

/* ---------- Portail locataire ---------- */
export const fetchPortalLessees = () => rpc<{ id: string; name: string; trade_name: string | null; open_tickets: number }[]>('portal_lessees');
export async function fetchLesseeHome(lessee?: string): Promise<LesseeHome> {
  const h = await rpc<LesseeHome>('lessee_home', { p_lessee: lessee ?? null });
  return { ...h, balance: nn(h.balance) };
}
export const lesseeCreateTicket = (lessee: string | undefined, category: string, description: string, spaceCode?: string) =>
  rpc<{ id: string; ref: string; priority: number }>('lessee_create_ticket', {
    p_lessee: lessee ?? null, p_category: category, p_description: description, p_space_code: spaceCode ?? null,
  });
export const lesseeComment = (ticket: string, body: string) => rpc<void>('lessee_ticket_comment', { p_ticket: ticket, p_body: body });
export const lesseeRate = (ticket: string, score: number) => rpc<void>('lessee_rate_ticket', { p_ticket: ticket, p_score: score });

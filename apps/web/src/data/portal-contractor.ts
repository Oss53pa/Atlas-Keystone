import { supabase } from '../lib/supabase.ts';
import type { PortalRow, PortalDetail } from '@keystone/domain/db/keystone';

async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc(fn, args);
  if (error) throw new Error(error.details ? `${error.message} — ${error.details}` : error.message);
  return data as T;
}
const n = (v: unknown) => (v == null ? null : Number(v));

export async function fetchPortalBoard(contractor?: string): Promise<PortalRow[]> {
  const rows = await rpc<PortalRow[]>('portal_board', { p_contractor: contractor ?? null });
  return (rows ?? []).map((r) => ({
    ...r, quote_total: n(r.quote_total), variations_total: Number(r.variations_total), elapsed_h: Number(r.elapsed_h),
    paused_h: Number(r.paused_h), pending_pause_h: Number(r.pending_pause_h),
  }));
}
export const fetchPortalDetail = (wo: string) => rpc<PortalDetail>('portal_detail', { p_wo: wo });

export const quoteDecide = (quote: string, approve: boolean, reason?: string) =>
  rpc<{ status: string }>('quote_decide', { p_quote: quote, p_approve: approve, p_reason: reason ?? null });
export const variationDecide = (v: string, approve: boolean) => rpc<{ status: string }>('variation_decide', { p_var: v, p_approve: approve });
export const reportValidate = (report: string, signer: string, approve: boolean, reason?: string) =>
  rpc<{ status: string; follow_ups: number }>('report_validate', { p_report: report, p_signer: signer, p_approve: approve, p_reason: reason ?? null });
export const pauseArbitrate = (pause: string, justified: boolean) => rpc<void>('pause_arbitrate', { p_pause: pause, p_justified: justified });

/* ---------- Côté prestataire (?prestataire) ---------- */
export interface PortalMe { contractor_id: string | null; contractor_name: string | null; is_contractor: boolean; tenant_id: string; full_name: string | null }
export const fetchPortalMe = () => rpc<PortalMe>('portal_me');
export const fetchPortalContractors = () => rpc<{ id: string; name: string; open_wo: number }[]>('portal_contractors');

export type QuoteItemInput = { kind: 'labor' | 'material' | 'travel' | 'other'; label: string; qty: number; unit_price: number };
export const quoteSubmit = (wo: string, items: QuoteItemInput[], notes?: string) =>
  rpc<{ ref: string; total: number }>('quote_submit', { p_wo: wo, p_items: items, p_notes: notes ?? null });
export const variationSubmit = (wo: string, reason: string, cost: number, hours: number) =>
  rpc<{ variation_id: string }>('variation_submit', { p_wo: wo, p_reason: reason, p_cost: cost, p_hours: hours });
export const slaPause = (wo: string, reason: string) => rpc<{ pause_id: string }>('sla_pause', { p_wo: wo, p_reason: reason });
export const slaResume = (wo: string) => rpc<void>('sla_resume', { p_wo: wo });
export type AnomalyInput = { severity: 'minor' | 'major' | 'critical'; description: string };
export const reportSubmit = (wo: string, summary: string, technician: string, before: string[], after: string[], anomalies: AnomalyInput[]) =>
  rpc<{ report_id: string }>('report_submit', {
    p_wo: wo, p_summary: summary, p_technician: technician, p_before: before, p_after: after, p_anomalies: anomalies,
  });

/* ---------- Photos d'intervention (Storage privé, chemin <tenant>/<wo>/<phase>-<ts>.<ext>) ---------- */
const BUCKET = 'keystone-wo-photos';
export const isStoredPhoto = (path: string) => path.split('/').length === 3;

export async function uploadWoPhoto(tenantId: string, woId: string, phase: string, file: File): Promise<string> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const ext = (file.name.split('.').pop() || 'jpg').toLowerCase();
  const path = `${tenantId}/${woId}/${phase}-${Date.now()}.${ext}`;
  const { error } = await supabase.storage.from(BUCKET).upload(path, file, { contentType: file.type || 'image/jpeg', upsert: false });
  if (error) throw new Error(error.message);
  return path;
}

export async function signedPhotoUrls(paths: string[]): Promise<Record<string, string>> {
  if (!supabase) return {};
  const stored = paths.filter(isStoredPhoto);
  if (stored.length === 0) return {};
  const { data, error } = await supabase.storage.from(BUCKET).createSignedUrls(stored, 3600);
  if (error || !data) return {};
  const out: Record<string, string> = {};
  for (const d of data) if (d.path && d.signedUrl) out[d.path] = d.signedUrl;
  return out;
}

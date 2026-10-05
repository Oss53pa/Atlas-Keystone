import { supabase } from '../lib/supabase.ts';

function db() {
  if (!supabase) throw new Error('Supabase non configuré.');
  return supabase.schema('keystone');
}
async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await db().rpc(fn, args);
  if (error) throw new Error(error.details ? `${error.message} — ${error.details}` : error.message);
  return data as T;
}

/* ---------- Politique de double authentification ---------- */
export async function fetchMfaPolicy(): Promise<boolean> {
  const { data, error } = await db().from('company_profile').select('mfa_required_for_finance').maybeSingle();
  if (error) throw new Error(error.message);
  return Boolean((data as { mfa_required_for_finance?: boolean } | null)?.mfa_required_for_finance);
}
export async function saveMfaPolicy(on: boolean) {
  const { data: cp } = await db().from('company_profile').select('tenant_id').maybeSingle();
  if (!cp) throw new Error('Renseignez d’abord l’identité de la société (onglet Société & documents).');
  const { error } = await db().from('company_profile').update({ mfa_required_for_finance: on }).eq('tenant_id', (cp as { tenant_id: string }).tenant_id);
  if (error) throw new Error(error.details ? `${error.message} — ${error.details}` : error.message);
}

/* ---------- Données personnelles ---------- */
export type SubjectKind = 'person' | 'user' | 'lessee_contact' | 'requester' | 'contractor_contact';
export interface Subject { kind: SubjectKind; id: string | null; key: string | null; label: string; detail: string; records: number }
export interface PrivacyRequest {
  id: string; ref: string; subject_kind: SubjectKind; subject_label: string; request_type: 'access' | 'rectification' | 'erasure' | 'opposition' | 'portability';
  channel: string; received_at: string; due_date: string; status: 'open' | 'done' | 'rejected'; outcome: string | null; overdue: boolean; days_left: number;
}
export const searchSubjects = (q: string) => rpc<Subject[]>('personal_data_subjects', { p_q: q }).then((r) => r ?? []);
export const exportSubject = (s: Subject) => rpc<unknown>('personal_data_export', { p_kind: s.kind, p_id: s.id, p_key: s.key });
export const anonymizeSubject = (s: Subject, reason: string, request?: string) =>
  rpc<{ rows: number; tag: string }>('personal_data_anonymize', { p_kind: s.kind, p_id: s.id, p_key: s.key, p_reason: reason, p_request: request ?? null });
export const myData = () => rpc<unknown>('my_personal_data');
export const fetchPrivacyRequests = () => rpc<PrivacyRequest[]>('privacy_board').then((r) => r ?? []);
export async function createPrivacyRequest(r: { subject: Subject; type: PrivacyRequest['request_type']; channel: string; received_at: string; due_days: number }) {
  const { data: ref, error: e1 } = await db().rpc('next_ref', { p_prefix: 'RGPD' });
  if (e1) throw new Error(e1.message);
  const due = new Date(r.received_at); due.setDate(due.getDate() + r.due_days);
  const { error } = await db().from('privacy_requests').insert({
    ref, subject_kind: r.subject.kind, subject_id: r.subject.id, subject_key: r.subject.key, subject_label: r.subject.label,
    request_type: r.type, channel: r.channel, received_at: r.received_at, due_date: due.toISOString().slice(0, 10),
  });
  if (error) throw new Error(error.message);
}
export async function closePrivacyRequest(id: string, status: 'done' | 'rejected', outcome: string) {
  const { error } = await db().from('privacy_requests').update({ status, outcome, handled_at: new Date().toISOString() }).eq('id', id);
  if (error) throw new Error(error.message);
}

/* ---------- Comptabilité SYSCOHADA ---------- */
export interface PlanRow { key: string; account: string; label: string; is_default: boolean }
export interface Entry { journal: 'AC' | 'VT' | 'BQ'; entry_date: string; piece: string; account: string; aux: string | null; label: string; debit: number; credit: number; source: string }
export interface JournalSummary { journal: string; entries: number; pieces: number; debit: number; credit: number; unbalanced_pieces: number }
export const fetchPlan = () => rpc<PlanRow[]>('accounting_plan').then((r) => r ?? []);
export async function savePlanRow(key: string, account: string, label: string) {
  const { error } = await db().from('accounting_accounts').upsert({ key, account, label });
  if (error) throw new Error(error.message);
}
export async function fetchEntries(from: string, to: string): Promise<Entry[]> {
  const rows = await rpc<Entry[]>('accounting_entries', { p_from: from, p_to: to });
  return (rows ?? []).map((r) => ({ ...r, debit: Number(r.debit), credit: Number(r.credit) }));
}
export async function fetchJournalSummary(from: string, to: string): Promise<JournalSummary[]> {
  const rows = await rpc<JournalSummary[]>('accounting_summary', { p_from: from, p_to: to });
  return (rows ?? []).map((r) => ({ ...r, debit: Number(r.debit), credit: Number(r.credit) }));
}

/** Téléchargement local d'un fichier généré dans le navigateur (aucun envoi réseau). */
export function downloadFile(name: string, content: string, type: string) {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = name; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

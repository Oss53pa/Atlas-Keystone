import { supabase } from '../lib/supabase.ts';
import type { CompanyProfile, ApprovalThreshold, PoDocument, WoDocument } from '@keystone/domain/db/keystone';

function db() {
  if (!supabase) throw new Error('Supabase non configuré.');
  return supabase.schema('keystone');
}
async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await db().rpc(fn, args);
  if (error) throw new Error(error.details ? `${error.message} — ${error.details}` : error.message);
  return data as T;
}

export const fetchPoDocument = (po: string) => rpc<PoDocument>('po_document', { p_po: po });
export const fetchWoDocument = (wo: string) => rpc<WoDocument>('wo_document', { p_wo: wo });

export async function fetchCompany(): Promise<CompanyProfile | null> {
  const { data, error } = await db().from('company_profile').select('*').maybeSingle();
  if (error) throw new Error(error.message);
  return data as CompanyProfile | null;
}
export async function saveCompany(c: CompanyProfile) {
  const { tenant_id: _t, ...patch } = c;
  const { error } = await db().from('company_profile').upsert({ ...patch, updated_at: new Date().toISOString() });
  if (error) throw new Error(error.message);
}
export async function fetchThresholds(): Promise<ApprovalThreshold[]> {
  const { data, error } = await db().from('approval_thresholds').select('doc_type, step, min_amount, approver_label').eq('doc_type', 'purchase_request');
  if (error) throw new Error(error.message);
  return ((data ?? []) as ApprovalThreshold[]).map((t) => ({ ...t, min_amount: Number(t.min_amount) }));
}
export async function saveThreshold(step: 'budget' | 'direction', min_amount: number, approver_label: string) {
  const { error } = await db().from('approval_thresholds').update({ min_amount, approver_label }).eq('doc_type', 'purchase_request').eq('step', step);
  if (error) throw new Error(error.details ?? error.message);
}
export async function fetchWeights(): Promise<Record<string, number>> {
  const { data, error } = await db().from('evaluation_weights').select('criterion, weight');
  if (error) throw new Error(error.message);
  return Object.fromEntries((data ?? []).map((w: { criterion: string; weight: number }) => [w.criterion, Number(w.weight)]));
}
export const saveWeights = (w: Record<string, number>) => rpc<void>('save_evaluation_weights', { p_weights: w });

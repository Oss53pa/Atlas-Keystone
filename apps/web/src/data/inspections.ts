import { supabase } from '../lib/supabase.ts';
import type { InspectionRound, InspectionHistoryRow, NcRow, QualitySummary, InspectionResult } from '@keystone/domain/db/keystone';

async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc(fn, args);
  if (error) throw new Error(error.details ? `${error.message} — ${error.details}` : error.message);
  return data as T;
}
const n = (v: unknown) => (v == null ? null : Number(v));

export async function fetchRounds(): Promise<InspectionRound[]> {
  const rows = await rpc<InspectionRound[]>('inspection_rounds');
  return (rows ?? []).map((r) => ({ ...r, last_score: n(r.last_score), days_to_due: Number(r.days_to_due) }));
}
export async function fetchInspectionHistory(): Promise<InspectionHistoryRow[]> {
  const rows = await rpc<InspectionHistoryRow[]>('inspections_history', { p_limit: 30 });
  return (rows ?? []).map((r) => ({ ...r, score: n(r.score) }));
}
export const fetchNcs = () => rpc<NcRow[]>('nc_board');
export async function fetchQualitySummary(): Promise<QualitySummary> {
  const s = await rpc<Record<string, unknown>>('quality_summary');
  return {
    score_30d: n(s.score_30d), rounds_30d: Number(s.rounds_30d), rounds_overdue: Number(s.rounds_overdue), nc_open: Number(s.nc_open),
    nc_critical: Number(s.nc_critical), nc_overdue: Number(s.nc_overdue), nc_closed_on_time_pct: n(s.nc_closed_on_time_pct),
  };
}
export const submitInspection = (template: string, answers: Record<string, unknown>, inspector: string, signed: boolean) =>
  rpc<InspectionResult>('inspection_submit', { p_template: template, p_answers: answers, p_inspector: inspector, p_signed: signed });
export const ncTransition = (id: string, action: 'start' | 'submit' | 'close' | 'reject', rootCause?: string, corrective?: string) =>
  rpc<{ status: string }>('nc_transition', { p_nc: id, p_action: action, p_root_cause: rootCause ?? null, p_corrective: corrective ?? null });

import { supabase } from '../lib/supabase.ts';
import type { PmPlanRow, PmStep, PmWorkloadRow, PmSummary } from '@keystone/domain/db/keystone';

async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc(fn, args);
  if (error) throw new Error(error.details ? `${error.message} — ${error.details}` : error.message);
  return data as T;
}

export async function fetchPmBoard(): Promise<PmPlanRow[]> {
  const rows = await rpc<PmPlanRow[]>('pm_board');
  return (rows ?? []).map((r) => ({ ...r, estimated_hours: Number(r.estimated_hours), days_to_due: Number(r.days_to_due) }));
}
export const fetchPmSteps = (plan: string) => rpc<PmStep[]>('pm_steps', { p_plan: plan });
export async function fetchPmWorkload(weeks = 8): Promise<PmWorkloadRow[]> {
  const rows = await rpc<PmWorkloadRow[]>('pm_workload', { p_weeks: weeks });
  return (rows ?? []).map((r) => ({
    week: r.week, internal_h: Number(r.internal_h), contractor_h: Number(r.contractor_h), operator_h: Number(r.operator_h), capacity_h: Number(r.capacity_h),
  }));
}
export async function fetchPmSummary(): Promise<PmSummary> {
  const s = await rpc<Record<string, unknown>>('pm_summary');
  return {
    plans: Number(s.plans), overdue: Number(s.overdue), due: Number(s.due), scheduled: Number(s.scheduled),
    compliance_pct: s.compliance_pct == null ? null : Number(s.compliance_pct), hours_per_year: Number(s.hours_per_year ?? 0),
  };
}
export const pmGenerate = (days = 14) => rpc<{ created: number; refs: string[] }>('pm_generate_horizon', { p_days: days });

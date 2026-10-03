import { supabase } from '../lib/supabase.ts';
import type { CrpRow, CrpSummary } from '@keystone/domain/db/keystone';

export async function fetchCrp(): Promise<CrpRow[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('crp_board');
  if (error) throw new Error(error.message);
  return ((data ?? []) as CrpRow[]).map((r) => ({
    ...r, frequency_months: Number(r.frequency_months), days_to_due: r.days_to_due == null ? null : Number(r.days_to_due),
  }));
}

export async function fetchCrpSummary(): Promise<CrpSummary> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('crp_summary');
  if (error) throw new Error(error.message);
  const s = data as CrpSummary;
  return {
    total: Number(s.total), compliant: Number(s.compliant), due: Number(s.due), overdue: Number(s.overdue),
    conformity_pct: Number(s.conformity_pct), reserves_open: Number(s.reserves_open),
  };
}

export async function recordCrpResult(id: string, result: 'conform' | 'non_conform'): Promise<{ capa_created?: string }> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('record_crp_result', { p_control: id, p_result: result });
  if (error) throw new Error(error.message);
  return data as { capa_created?: string };
}

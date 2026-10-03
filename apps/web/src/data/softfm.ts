import { supabase } from '../lib/supabase.ts';
import type { SoftVisit, PestLog, SoftFmSummary } from '@keystone/domain/db/keystone';

async function rpc<T>(fn: string): Promise<T> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc(fn);
  if (error) throw new Error(error.message);
  return data as T;
}

export const fetchSoftVisits = () => rpc<SoftVisit[]>('soft_visits');
export const fetchPestLogs = () => rpc<PestLog[]>('pest_logs');
export async function fetchSoftFmSummary(): Promise<SoftFmSummary> {
  const s = await rpc<SoftFmSummary>('soft_fm_summary');
  return {
    visits_total: Number(s.visits_total), realisation_pct: Number(s.realisation_pct), qc_avg: Number(s.qc_avg),
    missed: Number(s.missed), qc_failed: Number(s.qc_failed), pest_logs: Number(s.pest_logs),
  };
}

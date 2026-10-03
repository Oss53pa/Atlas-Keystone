import { supabase } from '../lib/supabase.ts';
import type { MonthlyReport } from '@keystone/domain/db/keystone';

export async function fetchLatestReport(): Promise<MonthlyReport | null> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('report_latest');
  if (error) throw new Error(error.message);
  return (data ?? null) as MonthlyReport | null;
}

export async function generateReport(): Promise<string> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('run_reporting_now');
  if (error) throw new Error(error.message);
  return data as string;
}

export async function publishReport(id: string): Promise<void> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { error } = await supabase.schema('keystone').rpc('publish_report', { p_id: id });
  if (error) throw new Error(error.message);
}

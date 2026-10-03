import { supabase } from '../lib/supabase.ts';
import type { HsseEventRow, CapaRow, PermitRow, HsseSummary } from '@keystone/domain/db/keystone';

async function rpc<T>(fn: string): Promise<T> {
  if (!supabase) throw new Error('Supabase non configuré (mode démo).');
  const { data, error } = await supabase.schema('keystone').rpc(fn);
  if (error) throw new Error(error.message);
  return data as T;
}

export const fetchEvents = () => rpc<HsseEventRow[]>('demo_events');
export const fetchCapa = () => rpc<CapaRow[]>('demo_capa');
export const fetchPermits = () => rpc<PermitRow[]>('demo_permits');
export const fetchHsseSummary = () => rpc<HsseSummary>('demo_hsse_summary');

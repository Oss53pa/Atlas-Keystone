import { supabase } from '../lib/supabase.ts';
import type { AgentAction, AgentRunResult } from '@keystone/domain/db/keystone';

export async function fetchAgentJournal(): Promise<AgentAction[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('agent_journal');
  if (error) throw new Error(error.message);
  return (data ?? []) as AgentAction[];
}

export async function runAgents(): Promise<AgentRunResult> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('run_agents_now');
  if (error) throw new Error(error.message);
  const r = data as AgentRunResult;
  return { relanceur_capa: Number(r.relanceur_capa), echeancier_crp: Number(r.echeancier_crp), habilitations: Number(r.habilitations) };
}

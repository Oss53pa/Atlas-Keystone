import { supabase } from '../lib/supabase.ts';
import type { AttentionLive, CockpitSummary, Posture, LivePresence } from '@keystone/domain/db/keystone';

/** Feed d'attention consolidé (OT/CRP/CAPA/événements/permis), RLS-scopé au tenant connecté. */
export async function fetchAttention(): Promise<AttentionLive[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('attention_feed');
  if (error) throw new Error(error.message);
  return (data ?? []) as AttentionLive[];
}

export async function fetchCockpitSummary(): Promise<CockpitSummary> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('cockpit_summary');
  if (error) throw new Error(error.message);
  return data as CockpitSummary;
}

/** Posture 4 axes + score de risque dynamique (§10.4), déterministe et RLS-scopé. */
export async function fetchPosture(): Promise<Posture> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('posture');
  if (error) throw new Error(error.message);
  return data as Posture;
}

/** Position courante des intervenants (§6.27), RLS-scopé. */
export async function fetchPresence(): Promise<LivePresence[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('live_presence');
  if (error) throw new Error(error.message);
  return ((data ?? []) as LivePresence[]).map((p) => ({ ...p, x: Number(p.x), y: Number(p.y) }));
}

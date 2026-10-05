import { supabase } from '../lib/supabase.ts';

export interface SearchHit { kind: string; id: string; ref: string | null; title: string; subtitle: string | null; module: string; score: number }

/** Recherche globale (OT, équipements, tickets, HSSE, baux, achats, pièces, lots, compteurs…) — sous RLS, insensible aux accents. */
export async function globalSearch(q: string, limit = 24): Promise<SearchHit[]> {
  if (!supabase || q.trim().length < 2) return [];
  const { data, error } = await supabase.schema('keystone').rpc('global_search', { p_q: q, p_limit: limit });
  if (error) throw new Error(error.message);
  return ((data ?? []) as SearchHit[]).map((h) => ({ ...h, score: Number(h.score) }));
}

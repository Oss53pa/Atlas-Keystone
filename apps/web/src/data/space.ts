import { supabase } from '../lib/supabase.ts';
import type { SpaceUnit, SpaceSummary } from '@keystone/domain/db/keystone';

export async function fetchSpaceInventory(): Promise<SpaceUnit[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('space_inventory');
  if (error) throw new Error(error.message);
  return ((data ?? []) as SpaceUnit[]).map((u) => ({ ...u, surface_m2: u.surface_m2 == null ? null : Number(u.surface_m2) }));
}

export async function fetchSpaceSummary(): Promise<SpaceSummary> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('space_summary');
  if (error) throw new Error(error.message);
  const s = data as SpaceSummary;
  return {
    units: Number(s.units), surface_total: Number(s.surface_total), surface_occupee: Number(s.surface_occupee),
    vacants: Number(s.vacants), occupation_pct: Number(s.occupation_pct),
  };
}

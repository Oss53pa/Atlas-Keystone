import { supabase } from '../lib/supabase.ts';
import type { BudgetOverview, BudgetSide } from '@keystone/domain/db/keystone';

const num = (s?: BudgetSide): BudgetSide | undefined =>
  s ? { budget: Number(s.budget), committed: Number(s.committed), spent: Number(s.spent), available: Number(s.available), execution_pct: Number(s.execution_pct) } : undefined;

/** Vue OPEX/CAPEX consolidée (budget/engagé/réalisé/disponible), RLS-scopée. */
export async function fetchBudgetOverview(): Promise<BudgetOverview> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('budget_overview');
  if (error) throw new Error(error.message);
  const d = (data ?? {}) as BudgetOverview;
  return { opex: num(d.opex), capex: num(d.capex) };
}

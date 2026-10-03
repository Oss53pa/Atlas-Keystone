import { supabase } from '../lib/supabase.ts';
import type { ContractorRow, InvoiceRow, SlaMeasure, ContractorScorecard, EvalCriterion } from '@keystone/domain/db/keystone';

export async function fetchContractors(): Promise<ContractorRow[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('contractors_board');
  if (error) throw new Error(error.message);
  return ((data ?? []) as ContractorRow[]).map((c) => ({
    ...c, rating: c.rating == null ? null : Number(c.rating),
    certs_total: Number(c.certs_total), certs_expiring: Number(c.certs_expiring),
    open_invoices: Number(c.open_invoices), paid_amount: Number(c.paid_amount),
  }));
}

export async function fetchInvoices(): Promise<InvoiceRow[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('invoices_board');
  if (error) throw new Error(error.message);
  return ((data ?? []) as InvoiceRow[]).map((i) => ({ ...i, amount: Number(i.amount) }));
}

export async function approveInvoice(id: string): Promise<void> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { error } = await supabase.schema('keystone').rpc('approve_invoice', { p_inv: id });
  if (error) throw new Error(error.message);
}

export async function payInvoice(id: string): Promise<{ provider_ref: string; method: string }> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('pay_invoice', { p_inv: id });
  if (error) throw new Error(error.message);
  return data as { provider_ref: string; method: string };
}

const nn = (v: unknown) => (v == null ? null : Number(v));

export async function fetchSlaMeasures(days = 90): Promise<SlaMeasure[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('sla_measures', { p_days: days });
  if (error) throw new Error(error.message);
  return ((data ?? []) as SlaMeasure[]).map((m) => ({
    ...m, target: Number(m.target), achieved: nn(m.achieved), attainment: nn(m.attainment), weight: Number(m.weight),
    overrun: Number(m.overrun), penalty: Number(m.penalty),
  }));
}

export async function fetchScorecards(days = 90): Promise<ContractorScorecard[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('contractor_scorecards', { p_days: days });
  if (error) throw new Error(error.message);
  return ((data ?? []) as ContractorScorecard[]).map((c) => ({
    ...c, sla_score: nn(c.sla_score), qualitative: nn(c.qualitative), global_score: nn(c.global_score),
    penalty_raw: Number(c.penalty_raw), penalty_cap: Number(c.penalty_cap), penalty: Number(c.penalty),
  }));
}

export async function submitEvaluation(contractorId: string, scores: Record<EvalCriterion, number>, comment?: string) {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('evaluation_submit', { p_contractor: contractorId, p_scores: scores, p_comment: comment ?? null });
  if (error) throw new Error(error.message);
  return data as { period: string; qualitative: number };
}

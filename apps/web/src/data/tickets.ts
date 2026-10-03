import { supabase } from '../lib/supabase.ts';
import type { TicketRow } from '@keystone/domain/db/keystone';

interface RawTk {
  id: string; ref: string; channel: string | null; requester_kind: string | null; requester_name: string | null;
  category: string | null; description: string | null; priority: number; status: TicketRow['status'];
  sla_due: string | null; satisfaction: number | null; work_order_id: string | null; created_at: string;
  assets: { tag: string | null } | null; locations: { name: string | null } | null;
}

/** Liste des tickets — table directe protégée par RLS. */
export async function fetchTickets(): Promise<TicketRow[]> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase
    .schema('keystone')
    .from('service_requests')
    .select('id,ref,channel,requester_kind,requester_name,category,description,priority,status,sla_due,satisfaction,work_order_id,created_at,assets(tag),locations(name)')
    .is('deleted_at', null)
    .order('created_at', { ascending: false });
  if (error) throw new Error(error.message);
  return ((data ?? []) as unknown as RawTk[]).map((r) => ({
    id: r.id, ref: r.ref, channel: r.channel, requester_kind: r.requester_kind, requester_name: r.requester_name,
    category: r.category, description: r.description, priority: r.priority, status: r.status, sla_due: r.sla_due,
    satisfaction: r.satisfaction, work_order_id: r.work_order_id, created_at: r.created_at,
    asset_tag: r.assets?.tag ?? null, location_name: r.locations?.name ?? null,
  }));
}

/** Convertit un ticket en ordre de travail (RPC). Renvoie la réf de l'OT. */
export async function convertTicketToWo(ticketId: string): Promise<string> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc('convert_ticket_to_wo', { p_ticket: ticketId });
  if (error) throw new Error(error.message);
  return data as string;
}

import { supabase } from '../lib/supabase.ts';
import type { TicketStatus } from '@keystone/domain/db/keystone';

export interface QrContext {
  found: boolean;
  kind?: 'location' | 'asset';
  asset_name?: string | null;
  location_name?: string | null;
  site_name?: string | null;
}
export interface TicketTrack {
  found: boolean;
  ref?: string;
  category?: string;
  status?: TicketStatus;
  created_at?: string;
  resolved_at?: string | null;
  has_work_order?: boolean;
  satisfaction?: number | null;
}

export async function qrContext(qr: string): Promise<QrContext> {
  if (!supabase) throw new Error('Hors ligne.');
  const { data, error } = await supabase.schema('keystone').rpc('qr_context_public', { p_qr: qr });
  if (error) throw new Error(error.message);
  return data as QrContext;
}

export async function createPublicTicket(input: {
  qr: string; category: string; description: string; name?: string; contact?: string;
}): Promise<string> {
  if (!supabase) throw new Error('Hors ligne.');
  const { data, error } = await supabase.schema('keystone').rpc('create_ticket_public', {
    p_qr: input.qr, p_category: input.category, p_description: input.description,
    p_name: input.name || null, p_contact: input.contact || null,
  });
  if (error) throw new Error(error.message);
  return data as string;
}

export async function trackTicket(ref: string): Promise<TicketTrack> {
  if (!supabase) throw new Error('Hors ligne.');
  const { data, error } = await supabase.schema('keystone').rpc('track_ticket_public', { p_ref: ref });
  if (error) throw new Error(error.message);
  return data as TicketTrack;
}

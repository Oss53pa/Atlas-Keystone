import { supabase } from '../lib/supabase.ts';
import type {
  NotifJournalRow, NotifStats, NotifMatrixRow, NotifChannelConfig, NotifTemplate, QuietHours, MyNotification, NotifChannel,
} from '@keystone/domain/db/keystone';

function db() {
  if (!supabase) throw new Error('Supabase non configuré.');
  return supabase.schema('keystone');
}
async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await db().rpc(fn, args);
  if (error) throw new Error(error.details ? `${error.message} — ${error.details}` : error.message);
  return data as T;
}

export const fetchJournal = (limit = 80) => rpc<NotifJournalRow[]>('notification_journal', { p_limit: limit });
export async function fetchNotifStats(): Promise<NotifStats> {
  const s = await rpc<NotifStats>('notification_stats');
  return { ...s, sent_24h: Number(s.sent_24h), queued: Number(s.queued), deferred: Number(s.deferred), suppressed_24h: Number(s.suppressed_24h), failed_24h: Number(s.failed_24h), live_channels: Number(s.live_channels) };
}
export const fetchMatrix = () => rpc<NotifMatrixRow[]>('notification_matrix');
export const sendTest = (channel: NotifChannel) => rpc<{ status: string; provider_ref: string | null; reason: string | null }>('notification_test', { p_channel: channel });

export async function toggleRule(id: string, enabled: boolean) {
  const { error } = await db().from('notification_rules').update({ is_enabled: enabled }).eq('id', id);
  if (error) throw new Error(error.message);
}
export async function fetchChannels(): Promise<NotifChannelConfig[]> {
  const { data, error } = await db().from('notification_channels').select('channel, is_enabled, mode, provider, sender').order('channel');
  if (error) throw new Error(error.message);
  return (data ?? []) as NotifChannelConfig[];
}
export async function updateChannel(channel: NotifChannel, patch: Partial<Pick<NotifChannelConfig, 'is_enabled' | 'mode' | 'sender'>>) {
  const { error } = await db().from('notification_channels').update(patch).eq('channel', channel);
  if (error) throw new Error(error.message);
}
export async function fetchTemplates(): Promise<NotifTemplate[]> {
  const { data, error } = await db().from('notification_templates').select('id, event_type, channel, locale, subject, body, wa_template_name').order('event_type');
  if (error) throw new Error(error.message);
  return (data ?? []) as NotifTemplate[];
}
export async function saveTemplate(id: string, subject: string | null, body: string) {
  const { error } = await db().from('notification_templates').update({ subject, body, updated_at: new Date().toISOString() }).eq('id', id);
  if (error) throw new Error(error.message);
}
export async function fetchEventPlaceholders(): Promise<Record<string, string[]>> {
  const { data, error } = await db().from('notification_events').select('event_type, placeholders');
  if (error) throw new Error(error.message);
  return Object.fromEntries((data ?? []).map((e: { event_type: string; placeholders: string[] }) => [e.event_type, e.placeholders]));
}
export async function fetchQuietHours(): Promise<QuietHours | null> {
  const { data, error } = await db().from('notification_quiet_hours').select('start_local, end_local, timezone, applies_to').maybeSingle();
  if (error) throw new Error(error.message);
  return data as QuietHours | null;
}
export async function saveQuietHours(q: Pick<QuietHours, 'start_local' | 'end_local' | 'applies_to'>) {
  const { error } = await db().from('notification_quiet_hours').update(q).not('tenant_id', 'is', null);
  if (error) throw new Error(error.message);
}

/* ---------- Cloche in-app ---------- */
export const fetchMyNotifications = (limit = 20) => rpc<MyNotification[]>('my_notifications', { p_limit: limit });
export const markAllRead = () => rpc<number>('my_notifications_read');

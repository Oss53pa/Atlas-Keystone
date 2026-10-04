// Edge Function « notify-dispatch » — envoi RÉEL des notifications des canaux passés en mode « live ».
// Le mode simulation est traité en base (keystone.notification_dispatch, pg_cron toutes les 2 min).
//
// Déploiement :   supabase functions deploy notify-dispatch --no-verify-jwt=false
// Planification : pg_cron → net.http_post vers cette fonction toutes les minutes, ou Scheduled Function.
// Secrets (jamais en base) :
//   WA_PHONE_ID, WA_ACCESS_TOKEN                        WhatsApp Cloud API (Meta)
//   SMS_API_URL, SMS_API_TOKEN, SMS_SENDER              passerelle SMS HTTP (ex. Orange SMS API CI, Twilio…)
//   RESEND_API_KEY                                      email (Resend)
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY             fournis par la plateforme
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type Outbox = {
  id: string; tenant_id: string; event_type: string; channel: 'whatsapp' | 'sms' | 'email'; address: string;
  subject: string | null; body: string; attempts: number;
};
const MAX_ATTEMPTS = 5;
const e164 = (p: string) => '+' + p.replace(/[^\d]/g, '').replace(/^00/, '');

async function sendWhatsApp(o: Outbox): Promise<string> {
  // Texte libre : valable dans la fenêtre de 24 h ouverte par le destinataire. Hors fenêtre, Meta exige un modèle
  // pré-approuvé (notification_templates.wa_template_name) — à brancher lors de l'homologation des modèles.
  const res = await fetch(`https://graph.facebook.com/v20.0/${Deno.env.get('WA_PHONE_ID')}/messages`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${Deno.env.get('WA_ACCESS_TOKEN')}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ messaging_product: 'whatsapp', to: e164(o.address).slice(1), type: 'text', text: { body: o.body } }),
  });
  const j = await res.json();
  if (!res.ok) throw new Error(j?.error?.message ?? `WhatsApp HTTP ${res.status}`);
  return j?.messages?.[0]?.id ?? 'wa-ok';
}

async function sendSms(o: Outbox): Promise<string> {
  const res = await fetch(Deno.env.get('SMS_API_URL')!, {
    method: 'POST',
    headers: { Authorization: `Bearer ${Deno.env.get('SMS_API_TOKEN')}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ to: e164(o.address), from: Deno.env.get('SMS_SENDER'), text: o.body.slice(0, 459) }),
  });
  if (!res.ok) throw new Error(`SMS HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const j = await res.json().catch(() => ({}));
  return (j as { id?: string }).id ?? 'sms-ok';
}

async function sendEmail(o: Outbox, from: string): Promise<string> {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${Deno.env.get('RESEND_API_KEY')}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from, to: o.address, subject: o.subject ?? 'Atlas Keystone', text: o.body }),
  });
  const j = await res.json();
  if (!res.ok) throw new Error(j?.message ?? `Email HTTP ${res.status}`);
  return j?.id ?? 'email-ok';
}

Deno.serve(async () => {
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { db: { schema: 'keystone' } });

  const { data: channels } = await db.from('notification_channels').select('tenant_id, channel, sender').eq('mode', 'live').eq('is_enabled', true).neq('channel', 'in_app');
  if (!channels?.length) return Response.json({ sent: 0, failed: 0, note: 'aucun canal live' });
  const senderOf = new Map(channels.map((c) => [`${c.tenant_id}:${c.channel}`, c.sender as string | null]));

  const { data: due } = await db.from('notification_outbox')
    .select('id, tenant_id, event_type, channel, address, subject, body, attempts')
    .in('status', ['queued', 'deferred']).lte('scheduled_for', new Date().toISOString())
    .in('channel', [...new Set(channels.map((c) => c.channel))]).order('scheduled_for').limit(100);

  let sent = 0, failed = 0;
  for (const o of (due ?? []) as Outbox[]) {
    if (!senderOf.has(`${o.tenant_id}:${o.channel}`)) continue;   // canal live pour un autre tenant uniquement
    try {
      const ref = o.channel === 'whatsapp' ? await sendWhatsApp(o)
        : o.channel === 'sms' ? await sendSms(o)
        : await sendEmail(o, senderOf.get(`${o.tenant_id}:email`) ?? 'Atlas Keystone <noreply@example.com>');
      await db.from('notification_outbox').update({ status: 'sent', sent_at: new Date().toISOString(), provider_ref: ref, attempts: o.attempts + 1 }).eq('id', o.id);
      sent++;
    } catch (e) {
      const attempts = o.attempts + 1;
      const retryAt = new Date(Date.now() + 2 ** attempts * 60_000).toISOString();   // 2, 4, 8, 16 min…
      await db.from('notification_outbox').update({
        attempts, status: attempts >= MAX_ATTEMPTS ? 'failed' : 'queued', scheduled_for: retryAt,
        status_reason: String((e as Error).message ?? e).slice(0, 300),
      }).eq('id', o.id);
      failed++;
    }
  }
  return Response.json({ sent, failed });
});

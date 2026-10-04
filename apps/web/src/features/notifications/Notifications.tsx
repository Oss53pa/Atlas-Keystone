import { Fragment, useEffect, useMemo, useState } from 'react';
import {
  MessageCircle, MessageSquare, Mail, Bell, Send, Clock, ShieldOff, AlertTriangle, CheckCircle2, X, RefreshCw, Moon, Radio, FlaskConical, Save,
} from 'lucide-react';
import { Card, StatBig, TabBar } from '@keystone/ui';
import type { NotifJournalRow, NotifStats, NotifMatrixRow, NotifChannelConfig, NotifTemplate, QuietHours, NotifChannel, NotifAudience } from '@keystone/domain/db/keystone';
import { supabase } from '../../lib/supabase.ts';
import {
  fetchJournal, fetchNotifStats, fetchMatrix, toggleRule, fetchChannels, updateChannel, fetchTemplates, saveTemplate, fetchEventPlaceholders,
  fetchQuietHours, saveQuietHours, sendTest,
} from '../../data/notifications.ts';

const CH: Record<NotifChannel, { label: string; icon: React.ReactNode; color: string }> = {
  whatsapp: { label: 'WhatsApp', icon: <MessageCircle size={15} />, color: '#1F8F4E' },
  sms: { label: 'SMS', icon: <MessageSquare size={15} />, color: 'var(--ks-info)' },
  email: { label: 'Email', icon: <Mail size={15} />, color: 'var(--ks-amber-700)' },
  in_app: { label: 'In-app', icon: <Bell size={15} />, color: 'var(--ks-ink-2)' },
};
const AUD: Record<NotifAudience, string> = { lessee: 'Locataire', contractor: 'Prestataire', staff: 'Équipe FM', requester: 'Demandeur (QR)' };
const STATUS: Record<string, { label: string; risk: 'low' | 'info' | 'medium' | 'high' | 'critical' }> = {
  sent: { label: 'Envoyé', risk: 'low' }, queued: { label: 'En file', risk: 'info' }, deferred: { label: 'Différé', risk: 'medium' },
  suppressed: { label: 'Non envoyé', risk: 'high' }, failed: { label: 'Échec', risk: 'critical' },
};
const dt = (s: string | null) => (s ? new Date(s).toLocaleString('fr-FR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—');

export function Notifications() {
  const [tab, setTab] = useState('journal');
  const [stats, setStats] = useState<NotifStats | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const flash = (m: string) => { setToast(m); setTimeout(() => setToast(null), 4500); };
  const loadStats = () => fetchNotifStats().then(setStats).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
  useEffect(() => { void loadStats(); }, []);

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Système · Communication</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Notifications</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">WhatsApp · SMS · email · in-app — règles événement × canal × destinataire, non-dérangement</span>
          </div>
        </div>
      </header>

      {toast && <div className="ka-toast"><CheckCircle2 size={16} /> {toast}</div>}
      {err && (
        <div className="ka-toast" style={{ background: 'var(--ks-critical-100)', color: '#8E1E22' }}>
          <AlertTriangle size={16} /> <span className="ks-mono" style={{ fontSize: 12.5 }}>{err}</span>
          <button className="ks-icon-btn" style={{ marginLeft: 'auto' }} aria-label="Fermer" onClick={() => setErr(null)}><X size={14} /></button>
        </div>
      )}

      {stats && (
        <>
          {stats.live_channels === 0 && (
            <div className="kn-banner"><FlaskConical size={16} /> <span><b>Mode simulation.</b> Les messages sont composés, horodatés et journalisés comme en réel, mais rien ne part encore vers les opérateurs. Le passage en réel se fait canal par canal (onglet Canaux), une fois les comptes WhatsApp Business / SMS / email configurés.</span></div>
          )}
          <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
            <Card><StatBig label="Envoyés 24 h" icon={<Send size={15} />} accent="var(--ks-low)" value={stats.sent_24h} sub={Object.entries(stats.by_channel ?? {}).map(([k, v]) => `${CH[k as NotifChannel]?.label ?? k} ${v}`).join(' · ') || '—'} /></Card>
            <Card><StatBig label="Différés" icon={<Moon size={15} />} accent={stats.deferred ? 'var(--ks-amber)' : undefined} value={stats.deferred} sub="plage de non-dérangement" /></Card>
            <Card><StatBig label="Non envoyés 24 h" icon={<ShieldOff size={15} />} accent={stats.suppressed_24h ? 'var(--ks-high)' : undefined} value={stats.suppressed_24h} sub="coordonnée manquante ou doublon" /></Card>
            <Card><StatBig label="Échecs 24 h" icon={<AlertTriangle size={15} />} accent={stats.failed_24h ? 'var(--ks-critical)' : 'var(--ks-low)'} value={stats.failed_24h} sub={`${stats.queued} en file d’attente`} /></Card>
          </div>
        </>
      )}

      <div style={{ marginBottom: 16 }}>
        <TabBar tabs={[
          { id: 'journal', label: 'Journal d’envoi', icon: <Send size={15} /> },
          { id: 'rules', label: 'Règles', icon: <Radio size={15} /> },
          { id: 'templates', label: 'Modèles de messages', icon: <MessageSquare size={15} /> },
          { id: 'channels', label: 'Canaux & non-dérangement', icon: <Moon size={15} /> },
        ]} active={tab} onChange={setTab} />
      </div>

      {tab === 'journal' && <Journal onError={setErr} />}
      {tab === 'rules' && <Rules onError={setErr} />}
      {tab === 'templates' && <Templates onToast={flash} onError={setErr} />}
      {tab === 'channels' && <Channels onToast={(m) => { flash(m); void loadStats(); }} onError={setErr} />}
    </div>
  );
}

function Journal({ onError }: { onError: (m: string) => void }) {
  const [rows, setRows] = useState<NotifJournalRow[] | null>(null);
  const [open, setOpen] = useState<string | null>(null);
  function load() { fetchJournal(100).then(setRows).catch((e) => onError(String(e))); }
  useEffect(() => {
    load();
    if (!supabase) return;
    const ch = supabase.channel('notif-outbox').on('postgres_changes', { event: '*', schema: 'keystone', table: 'notification_outbox' }, () => load()).subscribe();
    return () => { void supabase?.removeChannel(ch); };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps
  return (
    <Card pad={false} className="ks-reveal">
      <div style={{ display: 'flex', justifyContent: 'flex-end', padding: '10px 14px 0' }}><button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={load}><RefreshCw size={13} /> Actualiser</button></div>
      <div style={{ overflowX: 'auto' }}>
        <table className="ks-table">
          <thead><tr><th>Quand</th><th>Événement</th><th>Canal</th><th>Destinataire</th><th>Statut</th></tr></thead>
          <tbody>
            {(rows ?? []).map((r) => (
              <Fragment key={r.id}>
                <tr style={{ cursor: 'pointer' }} onClick={() => setOpen(open === r.id ? null : r.id)}>
                  <td className="ks-mono ks-faint" style={{ fontSize: 11.5, whiteSpace: 'nowrap' }}>{dt(r.created_at)}</td>
                  <td><div style={{ fontWeight: 600 }}>{r.event_label ?? r.event_type}</div><div className="ks-mono ks-faint" style={{ fontSize: 11 }}>{r.entity_ref ?? ''}</div></td>
                  <td><span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: CH[r.channel].color, fontWeight: 600, fontSize: 12.5 }}>{CH[r.channel].icon} {CH[r.channel].label}</span></td>
                  <td style={{ fontSize: 12.5 }}>{r.recipient_label ?? '—'}<div className="ks-faint ks-mono" style={{ fontSize: 11 }}>{AUD[r.audience]} · {r.address ?? 'sans coordonnée'}</div></td>
                  <td>
                    <span className={`ks-risk ks-risk--${STATUS[r.status].risk}`}>{STATUS[r.status].label}</span>
                    <div className="ks-faint" style={{ fontSize: 11, marginTop: 3 }}>{r.status === 'deferred' ? `→ ${dt(r.scheduled_for)}` : r.status === 'sent' ? r.provider_ref : r.status_reason ?? ''}</div>
                  </td>
                </tr>
                {open === r.id && (
                  <tr><td colSpan={5} style={{ background: 'var(--ks-surface-2)' }}>
                    <div className={`kn-bubble kn-bubble--${r.channel}`}>
                      {r.subject && <div style={{ fontWeight: 700, marginBottom: 4 }}>{r.subject}</div>}
                      <div style={{ whiteSpace: 'pre-wrap' }}>{r.body}</div>
                    </div>
                  </td></tr>
                )}
              </Fragment>
            ))}
            {rows && rows.length === 0 && <tr><td colSpan={5} className="ks-dim" style={{ textAlign: 'center', padding: 30 }}>Aucun message pour le moment. Les envois apparaissent ici en temps réel.</td></tr>}
          </tbody>
        </table>
      </div>
    </Card>
  );
}

function Rules({ onError }: { onError: (m: string) => void }) {
  const [rows, setRows] = useState<NotifMatrixRow[] | null>(null);
  useEffect(() => { fetchMatrix().then(setRows).catch((e) => onError(String(e))); }, []); // eslint-disable-line react-hooks/exhaustive-deps
  const events = useMemo(() => {
    const m = new Map<string, { label: string; domain: string; sev: string; rules: NotifMatrixRow[] }>();
    for (const r of rows ?? []) {
      const e = m.get(r.event_type) ?? { label: r.label, domain: r.domain, sev: r.default_severity, rules: [] };
      e.rules.push(r); m.set(r.event_type, e);
    }
    return [...m.entries()];
  }, [rows]);
  async function flip(r: NotifMatrixRow) {
    setRows((xs) => (xs ?? []).map((x) => (x.rule_id === r.rule_id ? { ...x, is_enabled: !x.is_enabled } : x)));
    try { await toggleRule(r.rule_id, !r.is_enabled); } catch (e) { onError(String(e)); setRows((xs) => (xs ?? []).map((x) => (x.rule_id === r.rule_id ? r : x))); }
  }
  return (
    <div className="kn-rules ks-reveal">
      {events.map(([id, e]) => (
        <Card key={id}>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, alignItems: 'baseline' }}>
            <div><div className="ks-eyebrow">{e.domain}</div><div style={{ fontWeight: 700, fontSize: 15, marginTop: 2 }}>{e.label}</div></div>
            {e.sev === 'critical' && <span className="ks-risk ks-risk--critical" title="Ignore la plage de non-dérangement">critique</span>}
          </div>
          <div style={{ marginTop: 10 }}>
            {e.rules.map((r) => (
              <label key={r.rule_id} className="kn-rule">
                <span style={{ color: CH[r.channel].color, display: 'inline-flex' }}>{CH[r.channel].icon}</span>
                <span style={{ flex: 1 }}>{CH[r.channel].label} → {AUD[r.audience]}{!r.has_template && <span className="ks-faint" style={{ fontSize: 11 }}> · modèle manquant</span>}</span>
                <span className={`kn-switch${r.is_enabled ? ' kn-switch--on' : ''}`} role="switch" aria-checked={r.is_enabled} tabIndex={0}
                  onClick={() => void flip(r)} onKeyDown={(k) => (k.key === ' ' || k.key === 'Enter') && void flip(r)}><i /></span>
              </label>
            ))}
          </div>
        </Card>
      ))}
    </div>
  );
}

function Templates({ onToast, onError }: { onToast: (m: string) => void; onError: (m: string) => void }) {
  const [tpls, setTpls] = useState<NotifTemplate[] | null>(null);
  const [ph, setPh] = useState<Record<string, string[]>>({});
  const [sel, setSel] = useState<NotifTemplate | null>(null);
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  useEffect(() => {
    fetchTemplates().then((t) => { setTpls(t); if (t[0]) pick(t[0]); }).catch((e) => onError(String(e)));
    fetchEventPlaceholders().then(setPh).catch(() => {});
  }, []); // eslint-disable-line react-hooks/exhaustive-deps
  function pick(t: NotifTemplate) { setSel(t); setSubject(t.subject ?? ''); setBody(t.body); }
  const sample: Record<string, string> = { ref: 'TK-2026-000042', category: 'plomberie', description: 'Fuite sous l’évier de la réserve', status_label: 'en cours d’intervention',
    title: 'Groupe froid à l’arrêt', asset: 'GF-02', location: 'Galerie marchande', due_date: '12/10/2026', contractor: 'Frigo Services CI',
    lessee: 'Mode Ivoire', amount: '9 959 280 FCFA', period: '09/2026', reminder_no: '2', payment_ref: 'CP-8F2A1C90B3' };
  const render = (s: string) => s.replace(/\{\{([a-z_]+)\}\}/g, (_, k: string) => sample[k] ?? '');
  async function save() {
    if (!sel) return;
    try { await saveTemplate(sel.id, sel.channel === 'email' || sel.channel === 'in_app' ? subject : null, body); onToast('Modèle enregistré'); setTpls((xs) => (xs ?? []).map((x) => (x.id === sel.id ? { ...x, subject, body } : x))); }
    catch (e) { onError(String(e)); }
  }
  const smsLen = sel?.channel === 'sms' ? render(body).length : 0;
  return (
    <div className="kt-dash kt-dash--12 ks-reveal">
      <Card pad={false}>
        <div className="kn-tpl-list">
          {(tpls ?? []).map((t) => (
            <button key={t.id} className={`kn-tpl${sel?.id === t.id ? ' kn-tpl--on' : ''}`} onClick={() => pick(t)}>
              <span style={{ color: CH[t.channel].color, display: 'inline-flex' }}>{CH[t.channel].icon}</span>
              <span style={{ flex: 1, minWidth: 0 }}><span className="ks-mono" style={{ fontSize: 11.5 }}>{t.event_type}</span></span>
              <span className="ks-pill" style={{ fontSize: 10.5 }}>{t.locale.toUpperCase()}</span>
            </button>
          ))}
        </div>
      </Card>
      {sel && (
        <Card>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, alignItems: 'center' }}>
            <div><div className="ks-eyebrow">{CH[sel.channel].label} · {sel.locale.toUpperCase()}</div><div className="ks-mono" style={{ fontWeight: 700 }}>{sel.event_type}</div></div>
            <button className="ks-btn ks-btn--primary ks-btn--sm" onClick={save}><Save size={13} /> Enregistrer</button>
          </div>
          {(sel.channel === 'email' || sel.channel === 'in_app') && (
            <input className="kx-in" style={{ width: '100%', marginTop: 12 }} placeholder="Objet" value={subject} onChange={(e) => setSubject(e.target.value)} />
          )}
          <textarea className="kt-field ki-input ks-mono" rows={sel.channel === 'email' ? 9 : 4} style={{ width: '100%', marginTop: 8, fontSize: 13 }} value={body} onChange={(e) => setBody(e.target.value)} />
          <div className="kx-chips" style={{ marginTop: 8 }}>
            {(ph[sel.event_type] ?? []).map((p) => <button key={p} className="kx-chip" onClick={() => setBody((b) => `${b}{{${p}}}`)}>{`{{${p}}}`}</button>)}
          </div>
          {sel.channel === 'sms' && <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 6, color: smsLen > 160 ? 'var(--ks-high)' : undefined }}>{smsLen} caractères · {Math.ceil(smsLen / 153) || 1} SMS</div>}
          {sel.channel === 'whatsapp' && sel.wa_template_name && <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 6 }}>Modèle Meta associé : <span className="ks-mono">{sel.wa_template_name}</span> (à faire approuver avant l’envoi réel hors fenêtre de 24 h)</div>}
          <div className="ks-eyebrow" style={{ margin: '16px 0 6px' }}>Aperçu</div>
          <div className={`kn-bubble kn-bubble--${sel.channel}`}>
            {(sel.channel === 'email' || sel.channel === 'in_app') && subject && <div style={{ fontWeight: 700, marginBottom: 4 }}>{render(subject)}</div>}
            <div style={{ whiteSpace: 'pre-wrap' }}>{render(body)}</div>
          </div>
        </Card>
      )}
    </div>
  );
}

function Channels({ onToast, onError }: { onToast: (m: string) => void; onError: (m: string) => void }) {
  const [chs, setChs] = useState<NotifChannelConfig[] | null>(null);
  const [q, setQ] = useState<QuietHours | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  function load() { fetchChannels().then(setChs).catch((e) => onError(String(e))); fetchQuietHours().then(setQ).catch(() => {}); }
  useEffect(load, []); // eslint-disable-line react-hooks/exhaustive-deps
  async function patch(c: NotifChannel, p: Partial<NotifChannelConfig>) {
    try { await updateChannel(c, p); load(); onToast(`${CH[c].label} mis à jour`); } catch (e) { onError(String(e)); }
  }
  async function test(c: NotifChannel) {
    setBusy(c);
    try {
      const r = await sendTest(c);
      if (r.status === 'sent') onToast(`Test ${CH[c].label} envoyé · ${r.provider_ref}`);
      else if (r.status === 'queued') onToast(`Test ${CH[c].label} mis en file (canal en réel : envoyé par la fonction d’envoi)`);
      else onError(`Test ${CH[c].label} non envoyé : ${r.reason ?? r.status}`);
    } catch (e) { onError(String(e)); } finally { setBusy(null); }
  }
  async function saveQ() {
    if (!q) return;
    try { await saveQuietHours({ start_local: q.start_local, end_local: q.end_local, applies_to: q.applies_to }); onToast('Plage de non-dérangement enregistrée'); }
    catch (e) { onError(String(e)); }
  }
  return (
    <div className="kt-dash kt-dash--21 ks-reveal">
      <div className="kn-channels">
        {(chs ?? []).map((c) => (
          <Card key={c.channel}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <span className="kn-chico" style={{ color: CH[c.channel].color }}>{CH[c.channel].icon}</span>
              <div style={{ flex: 1 }}><div style={{ fontWeight: 700 }}>{CH[c.channel].label}</div><div className="ks-faint" style={{ fontSize: 12 }}>{c.provider ?? '—'}</div></div>
              <span className={`kn-switch${c.is_enabled ? ' kn-switch--on' : ''}`} role="switch" aria-checked={c.is_enabled} aria-label={`Activer ${CH[c.channel].label}`} tabIndex={0}
                onClick={() => void patch(c.channel, { is_enabled: !c.is_enabled })} onKeyDown={(k) => (k.key === ' ' || k.key === 'Enter') && void patch(c.channel, { is_enabled: !c.is_enabled })}><i /></span>
            </div>
            {c.channel !== 'in_app' && (
              <div className="ks-segment" role="group" aria-label="Mode" style={{ marginTop: 12 }}>
                <button aria-pressed={c.mode === 'simulation'} onClick={() => void patch(c.channel, { mode: 'simulation' })}>Simulation</button>
                <button aria-pressed={c.mode === 'live'} onClick={() => void patch(c.channel, { mode: 'live' })}>Réel</button>
              </div>
            )}
            {c.sender && <div className="ks-faint ks-mono" style={{ fontSize: 11.5, marginTop: 8 }}>Expéditeur : {c.sender}</div>}
            {c.mode === 'live' && c.channel !== 'in_app' && <div style={{ fontSize: 11.5, marginTop: 6, color: 'var(--ks-high)' }}>Réel : nécessite la fonction d’envoi déployée et ses clés (secrets Supabase).</div>}
            <button className="ks-btn ks-btn--ghost ks-btn--sm" style={{ marginTop: 12 }} disabled={busy === c.channel || !c.is_enabled} onClick={() => void test(c.channel)}><FlaskConical size={13} /> {busy === c.channel ? '…' : 'Envoyer un test'}</button>
          </Card>
        ))}
      </div>
      {q && (
        <Card>
          <div className="kt-cardtitle" style={{ display: 'flex', gap: 8, alignItems: 'center' }}><Moon size={16} /> Non-dérangement</div>
          <div className="kt-cardsub">les messages SMS / WhatsApp sont différés pendant cette plage — sauf urgences critiques</div>
          <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
            <label className="kx-lbl">De<input className="kx-in" type="time" value={q.start_local.slice(0, 5)} onChange={(e) => setQ({ ...q, start_local: e.target.value })} /></label>
            <label className="kx-lbl">À<input className="kx-in" type="time" value={q.end_local.slice(0, 5)} onChange={(e) => setQ({ ...q, end_local: e.target.value })} /></label>
          </div>
          <div className="kx-chips" style={{ marginTop: 12 }}>
            {(['sms', 'whatsapp', 'email'] as NotifChannel[]).map((c) => {
              const on = q.applies_to.includes(c);
              return <button key={c} className={`kx-chip${on ? ' kx-chip--on' : ''}`} onClick={() => setQ({ ...q, applies_to: on ? q.applies_to.filter((x) => x !== c) : [...q.applies_to, c] })}>{CH[c].label}</button>;
            })}
          </div>
          <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 10 }}><Clock size={12} style={{ verticalAlign: -2 }} /> Fuseau : {q.timezone}</div>
          <button className="ks-btn ks-btn--primary kx-wide" onClick={() => void saveQ()}><Save size={15} /> Enregistrer</button>
        </Card>
      )}
    </div>
  );
}

import { useCallback, useEffect, useState } from 'react';
import { Ticket, QrCode, Globe, Phone, Mail, Smartphone, ArrowRight, RefreshCw, Star, AlertTriangle, Wrench } from 'lucide-react';
import { Card, StatBig } from '@keystone/ui';
import type { TicketRow, TicketStatus } from '@keystone/domain/db/keystone';
import { fetchTickets, convertTicketToWo } from '../../data/tickets.ts';
import { supabase } from '../../lib/supabase.ts';

const STATUS: Record<TicketStatus, { label: string; color: string; bg: string }> = {
  new: { label: 'Nouveau', color: '#2A47A0', bg: 'var(--ks-info-100)' },
  triaged: { label: 'Trié', color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' },
  assigned: { label: 'Assigné', color: '#4B3FA0', bg: '#ECEAFB' },
  in_progress: { label: 'En cours', color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' },
  resolved: { label: 'Résolu', color: '#0F6E56', bg: '#E1F5EE' },
  closed: { label: 'Clôturé', color: '#2C6230', bg: 'var(--ks-low-100)' },
  rejected: { label: 'Rejeté', color: 'var(--ks-ink-3)', bg: 'var(--ks-surface-3)' },
  reopened: { label: 'Rouvert', color: '#8A3A07', bg: 'var(--ks-high-100)' },
};
const CHANNEL: Record<string, { label: string; icon: typeof QrCode }> = {
  qr_scan: { label: 'Scan QR', icon: QrCode },
  portal: { label: 'Portail', icon: Globe },
  phone: { label: 'Téléphone', icon: Phone },
  email: { label: 'Email', icon: Mail },
  mobile: { label: 'Mobile', icon: Smartphone },
};

export function Tickets() {
  const [rows, setRows] = useState<TicketRow[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [flash, setFlash] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);

  const load = useCallback(() => { fetchTickets().then(setRows).catch((e) => setErr(e instanceof Error ? e.message : String(e))); }, []);
  useEffect(() => { load(); }, [load]);

  useEffect(() => {
    const sb = supabase;
    if (!sb) return;
    const ch = sb.channel('tickets-live').on('postgres_changes', { event: '*', schema: 'keystone', table: 'service_requests' },
      () => { setFlash(true); load(); setTimeout(() => setFlash(false), 1800); });
    ch.subscribe();
    return () => { void sb.removeChannel(ch); };
  }, [load]);

  async function convert(id: string) {
    setBusy(id);
    try { await convertTicketToWo(id); load(); }
    catch (e) { setErr(e instanceof Error ? e.message : String(e)); }
    finally { setBusy(null); }
  }

  const list = rows ?? [];
  const open = list.filter((t) => !['closed', 'rejected'].includes(t.status)).length;
  const byQr = list.filter((t) => t.channel === 'qr_scan').length;
  const overdue = list.filter((t) => t.sla_due && new Date(t.sla_due) < new Date() && !['closed', 'rejected', 'resolved'].includes(t.status)).length;
  const sat = list.filter((t) => t.satisfaction != null);
  const satAvg = sat.length ? (sat.reduce((s, t) => s + (t.satisfaction ?? 0), 0) / sat.length).toFixed(1) : '—';

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Pilotage · Helpdesk</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Tickets &amp; demandes</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync" style={{ color: flash ? 'var(--ks-amber-700)' : undefined }}>
              <span className="ks-sync__dot" style={flash ? { background: 'var(--ks-amber)' } : undefined} />
              {flash ? 'nouveau ticket' : 'LIVE'}
            </span>
            <span className="ks-faint">portail occupant · scan QR sans compte · conversion en OT (§5.9 / §7.12)</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={load} style={{ alignSelf: 'end' }}><RefreshCw size={15} /> Rafraîchir</button>
      </header>

      <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
        <Card><StatBig label="Tickets ouverts" icon={<Ticket size={15} />} value={open} sub={`${list.length} au total`} /></Card>
        <Card><StatBig label="Via scan QR" icon={<QrCode size={15} />} accent="var(--ks-info)" value={byQr} sub="occupant sans compte" /></Card>
        <Card><StatBig label="Hors SLA" icon={<AlertTriangle size={15} />} accent={overdue ? 'var(--ks-critical)' : 'var(--ks-low)'} value={overdue} sub="prise en charge" /></Card>
        <Card><StatBig label="Satisfaction" icon={<Star size={15} />} accent="var(--ks-amber)" value={satAvg} unit="/5" sub={`${sat.length} notes`} /></Card>
      </div>

      {err && <Card><div style={{ textAlign: 'center', padding: 20 }}><AlertTriangle color="var(--ks-high)" /><div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 8 }}>{err}</div></div></Card>}

      {rows && !err && (
        <Card pad={false} className="ks-reveal" style={{ animationDelay: '120ms' }}>
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Réf.</th><th>Canal</th><th>Demande</th><th>Demandeur</th><th>Statut</th><th>SLA</th><th></th></tr></thead>
              <tbody>
                {list.map((t) => {
                  const st = STATUS[t.status]; const C = CHANNEL[t.channel ?? ''] ?? { label: t.channel ?? '—', icon: Globe }; const Ci = C.icon;
                  const overdueT = t.sla_due && new Date(t.sla_due) < new Date() && !['closed', 'rejected', 'resolved'].includes(t.status);
                  const convertible = ['new', 'triaged'].includes(t.status) && !t.work_order_id;
                  return (
                    <tr key={t.id}>
                      <td className="ks-mono ks-faint" style={{ fontSize: 11.5, whiteSpace: 'nowrap' }}>{t.ref}</td>
                      <td><span className="ks-pill" style={{ color: t.channel === 'qr_scan' ? 'var(--ks-info)' : undefined }}><Ci size={12} /> {C.label}</span></td>
                      <td>
                        <div style={{ fontWeight: 600 }}>{t.category}{t.asset_tag && <span className="ks-mono ks-faint" style={{ fontSize: 11, marginLeft: 6 }}>{t.asset_tag}</span>}</div>
                        <div className="ks-faint" style={{ fontSize: 11.5, maxWidth: 320, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{t.description}</div>
                      </td>
                      <td style={{ fontSize: 12.5 }}>{t.requester_name ?? '—'}</td>
                      <td><span className="ks-wo-pill" style={{ color: st.color, background: st.bg }}>{st.label}</span></td>
                      <td><span className="ks-mono" style={{ fontSize: 12, fontWeight: 600, color: overdueT ? 'var(--ks-critical)' : 'var(--ks-ink-2)' }}>{t.sla_due ? new Date(t.sla_due).toLocaleString('fr-FR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—'}{overdueT ? ' ⚠' : ''}</span></td>
                      <td style={{ textAlign: 'right' }}>
                        {t.work_order_id ? (
                          <span className="ks-pill" style={{ color: 'var(--ks-low)' }}><Wrench size={12} /> OT lié</span>
                        ) : convertible ? (
                          <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={busy === t.id} onClick={() => convert(t.id)}>
                            {busy === t.id ? '…' : <>Convertir en OT <ArrowRight size={14} /></>}
                          </button>
                        ) : null}
                      </td>
                    </tr>
                  );
                })}
                {list.length === 0 && <tr><td colSpan={7} style={{ textAlign: 'center', padding: 40 }} className="ks-dim">Aucun ticket.</td></tr>}
              </tbody>
            </table>
          </div>
        </Card>
      )}
    </div>
  );
}

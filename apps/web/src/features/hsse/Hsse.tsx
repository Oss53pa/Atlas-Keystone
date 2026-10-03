import { useEffect, useState } from 'react';
import { AlertTriangle, ShieldAlert, ClipboardList, Search, EyeOff, RefreshCw, Activity } from 'lucide-react';
import { Card, StatBig, RiskBadge, type RiskLevel } from '@keystone/ui';
import type { HsseEventRow, CapaRow, HsseSummary, EventType, EventStatus, EventSeverity, CapaStatus, ControlLevel } from '@keystone/domain/db/keystone';
import { fetchEvents, fetchCapa, fetchHsseSummary } from '../../data/hsse.ts';

const EV_TYPE: Record<EventType, string> = {
  near_miss: 'Presque-accident', incident: 'Incident', accident: 'Accident',
  dangerous_situation: 'Situation dangereuse', env_spill: 'Épanchement', security_event: 'Sûreté',
};
const EV_STATUS: Record<EventStatus, string> = {
  reported: 'Déclaré', triage: 'Triage', under_investigation: 'Investigation', capa_defined: 'CAPA définie', closed: 'Clôturé', rejected: 'Rejeté',
};
const SEV_RISK: Record<EventSeverity, RiskLevel> = {
  minor: 'low', moderate: 'medium', serious: 'high', major: 'critical', catastrophic: 'critical',
};
const CAPA_STATUS: Record<CapaStatus, { label: string; color: string; bg: string }> = {
  open: { label: 'Ouverte', color: '#2A47A0', bg: 'var(--ks-info-100)' },
  in_progress: { label: 'En cours', color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' },
  done: { label: 'Faite', color: '#0F6E56', bg: '#E1F5EE' },
  verifying: { label: 'Vérif. efficacité', color: '#4B3FA0', bg: '#ECEAFB' },
  closed: { label: 'Clôturée', color: '#2C6230', bg: 'var(--ks-low-100)' },
  reopened: { label: 'Rouverte', color: '#8A3A07', bg: 'var(--ks-high-100)' },
  cancelled: { label: 'Annulée', color: 'var(--ks-ink-3)', bg: 'var(--ks-surface-3)' },
};
const CTRL: Record<ControlLevel, string> = {
  elimination: 'Élimination', substitution: 'Substitution', engineering: 'Ingénierie', administrative: 'Administratif', ppe: 'EPI',
};

export function Hsse() {
  const [events, setEvents] = useState<HsseEventRow[] | null>(null);
  const [capa, setCapa] = useState<CapaRow[] | null>(null);
  const [summary, setSummary] = useState<HsseSummary | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true); setErr(null);
    try {
      const [e, c, s] = await Promise.all([fetchEvents(), fetchCapa(), fetchHsseSummary()]);
      setEvents(e); setCapa(c); setSummary(s);
    } catch (x) { setErr(x instanceof Error ? x.message : String(x)); }
    finally { setLoading(false); }
  }
  useEffect(() => { load(); }, []);

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">HSSE · Sécurité au travail</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Incidents &amp; CAPA</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">ISO 45001 · IEC 31010 · investigation &amp; vérification d'efficacité</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={load} style={{ alignSelf: 'end' }}><RefreshCw size={15} /> Rafraîchir</button>
      </header>

      {summary && (
        <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
          <Card><StatBig label="Événements ouverts" icon={<AlertTriangle size={15} />} value={summary.events_open} sub={`${summary.near_miss} presque-accidents`} /></Card>
          <Card><StatBig label="Accidents" icon={<ShieldAlert size={15} />} accent={summary.accidents ? 'var(--ks-critical)' : 'var(--ks-low)'} value={summary.accidents} sub="enregistrables" /></Card>
          <Card><StatBig label="CAPA ouvertes" icon={<ClipboardList size={15} />} accent="var(--ks-amber)" value={summary.capa_open} sub="actions correctives" /></Card>
          <Card><StatBig label="CAPA en retard" icon={<Activity size={15} />} accent={summary.capa_overdue ? 'var(--ks-critical)' : 'var(--ks-low)'} value={summary.capa_overdue} sub="relance auto" /></Card>
        </div>
      )}

      {err && <Card><div style={{ textAlign: 'center', padding: 20 }}><AlertTriangle color="var(--ks-high)" /><div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 8 }}>{err}</div></div></Card>}
      {loading && !err && <Card><div className="ks-dim" style={{ textAlign: 'center', padding: 30 }}>Chargement live…</div></Card>}

      {!loading && !err && (
        <div className="kt-dash kt-dash--2" style={{ alignItems: 'start' }}>
          {/* Événements */}
          <Card pad={false} className="ks-reveal" style={{ animationDelay: '100ms' }}>
            <div className="ks-card__head" style={{ padding: '16px 20px' }}>
              <div className="ks-card__title" style={{ fontSize: 14, fontWeight: 700, display: 'flex', gap: 8, alignItems: 'center' }}>
                <Search size={16} /> Événements <span className="ks-faint ks-mono" style={{ fontWeight: 500 }}>· tri risque</span>
              </div>
            </div>
            <div style={{ overflowX: 'auto' }}>
              <table className="ks-table">
                <thead><tr><th>Réf.</th><th>Type</th><th>Événement</th><th>Risque</th><th>Statut</th></tr></thead>
                <tbody>
                  {events?.map((e) => (
                    <tr key={e.id}>
                      <td className="ks-mono ks-faint" style={{ fontSize: 11.5, whiteSpace: 'nowrap' }}>{e.ref}</td>
                      <td><span className="ks-pill">{EV_TYPE[e.type]}</span></td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                          {e.is_anonymous && <EyeOff size={13} className="ks-faint" />}
                          <span style={{ fontWeight: 600 }}>{e.title}</span>
                          {e.has_investigation && <span className="ks-pill" style={{ height: 19, color: 'var(--ks-low)' }}>investigué</span>}
                        </div>
                      </td>
                      <td>{e.severity_potential && <RiskBadge level={SEV_RISK[e.severity_potential]} label={String(e.risk_score ?? '')} />}</td>
                      <td><span className="ks-mono" style={{ fontSize: 12, color: 'var(--ks-ink-2)' }}>{EV_STATUS[e.status]}</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>

          {/* CAPA */}
          <Card pad={false} className="ks-reveal" style={{ animationDelay: '180ms' }}>
            <div className="ks-card__head" style={{ padding: '16px 20px' }}>
              <div className="ks-card__title" style={{ fontSize: 14, fontWeight: 700, display: 'flex', gap: 8, alignItems: 'center' }}>
                <ClipboardList size={16} /> Actions correctives (CAPA)
              </div>
            </div>
            <div style={{ overflowX: 'auto' }}>
              <table className="ks-table">
                <thead><tr><th>Réf.</th><th>Action</th><th>Maîtrise</th><th>Échéance</th><th>Statut</th></tr></thead>
                <tbody>
                  {capa?.map((c) => {
                    const st = CAPA_STATUS[c.status];
                    return (
                      <tr key={c.id}>
                        <td className="ks-mono ks-faint" style={{ fontSize: 11.5, whiteSpace: 'nowrap' }}>{c.ref}</td>
                        <td><span style={{ fontWeight: 600 }}>{c.title}</span></td>
                        <td>{c.control_level && <span className="ks-pill" style={{ color: c.control_level === 'ppe' ? 'var(--ks-high)' : 'var(--ks-ink-2)' }}>{CTRL[c.control_level]}</span>}</td>
                        <td><span className="ks-mono" style={{ fontSize: 12, fontWeight: 600, color: c.is_overdue ? 'var(--ks-critical)' : 'var(--ks-ink-2)' }}>{c.due_date ? new Date(c.due_date).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' }) : '—'}{c.is_overdue ? ' ⚠' : ''}</span></td>
                        <td><span className="ks-wo-pill" style={{ color: st.color, background: st.bg }}>{st.label}</span></td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}

import { useEffect, useState } from 'react';
import { ShieldCheck, CalendarClock, ClipboardX, FileWarning, RefreshCw, AlertTriangle, CheckCircle2, X } from 'lucide-react';
import { Card, StatBig, RingGauge } from '@keystone/ui';
import type { CrpRow, CrpSummary, CrpStatus } from '@keystone/domain/db/keystone';
import { fetchCrp, fetchCrpSummary, recordCrpResult } from '../../data/crp.ts';

const STATUS: Record<CrpStatus, { label: string; color: string; bg: string }> = {
  compliant: { label: 'Conforme', color: '#2C6230', bg: 'var(--ks-low-100)' },
  due: { label: 'À échéance', color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' },
  overdue: { label: 'En dépassement', color: '#8E1E22', bg: 'var(--ks-critical-100)' },
  non_conform: { label: 'Non conforme', color: '#8E1E22', bg: 'var(--ks-critical-100)' },
};
const dueText = (d: number | null) => (d == null ? '—' : d < 0 ? `+${-d} j de retard` : `J-${d}`);
const fmtDate = (s: string | null) => (s ? new Date(s).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: '2-digit' }) : '—');

export function Crp() {
  const [rows, setRows] = useState<CrpRow[] | null>(null);
  const [summary, setSummary] = useState<CrpSummary | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  function load() {
    fetchCrp().then(setRows).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
    fetchCrpSummary().then(setSummary).catch(() => {});
  }
  useEffect(load, []);

  async function record(id: string, result: 'conform' | 'non_conform') {
    setBusy(id);
    try {
      const r = await recordCrpResult(id, result);
      setToast(result === 'non_conform' ? `Non-conformité enregistrée → CAPA créée${r.capa_created ? '' : ''}` : 'Contrôle conforme — échéance reportée');
      load(); setTimeout(() => setToast(null), 4000);
    } catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(null); }
  }

  const list = rows ?? [];

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">HSSE · Conformité réglementaire</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Contrôles réglementaires</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">ascenseurs EN 81 · SSI EN 54 · organismes agréés · non-conformité → CAPA (§7.15)</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={load} style={{ alignSelf: 'end' }}><RefreshCw size={15} /> Rafraîchir</button>
      </header>

      {toast && <div style={{ marginBottom: 14, padding: '11px 16px', borderRadius: 'var(--ks-r-md)', background: 'var(--ks-amber-50)', color: 'var(--ks-amber-700)', fontSize: 13.5, display: 'flex', alignItems: 'center', gap: 8 }}><CheckCircle2 size={16} /> {toast}</div>}
      {err && <Card><div style={{ textAlign: 'center', padding: 20 }}><AlertTriangle color="var(--ks-high)" /><div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 8 }}>{err}</div></div></Card>}

      {summary && (
        <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
          <Card>
            <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
              <RingGauge value={summary.conformity_pct} size={74} stroke={7} color={summary.conformity_pct >= 90 ? 'var(--ks-low)' : 'var(--ks-high)'} />
              <div><div className="ks-stat__label">Conformité CRP</div><div className="ks-faint" style={{ fontSize: 12, marginTop: 4 }}>{summary.total} contrôles suivis</div></div>
            </div>
          </Card>
          <Card><StatBig label="À échéance" icon={<CalendarClock size={15} />} accent="var(--ks-amber)" value={summary.due} sub="dans les 60 jours" /></Card>
          <Card><StatBig label="En dépassement" icon={<ClipboardX size={15} />} accent={summary.overdue ? 'var(--ks-critical)' : 'var(--ks-low)'} value={summary.overdue} sub="action immédiate" /></Card>
          <Card><StatBig label="Réserves ouvertes" icon={<FileWarning size={15} />} accent={summary.reserves_open ? 'var(--ks-high)' : 'var(--ks-low)'} value={summary.reserves_open} sub="liées à des CAPA" /></Card>
        </div>
      )}

      <div className="kt-section-h"><h2>Échéancier réglementaire</h2></div>
      {rows && (
        <Card pad={false} className="ks-reveal">
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Régime</th><th>Actif</th><th>Organisme</th><th>Périodicité</th><th>Prochaine échéance</th><th>Statut</th><th></th></tr></thead>
              <tbody>
                {list.map((r) => {
                  const st = STATUS[r.status];
                  return (
                    <tr key={r.id}>
                      <td style={{ fontWeight: 600 }}>{r.regime}</td>
                      <td>{r.asset_tag ? <span className="ks-mono" style={{ fontSize: 12 }}>{r.asset_tag}</span> : <span className="ks-faint">site</span>}</td>
                      <td style={{ fontSize: 12.5 }}>{r.controller_org ?? '—'}</td>
                      <td className="ks-mono ks-faint" style={{ fontSize: 12 }}>{r.frequency_months} mois</td>
                      <td>
                        <span className="ks-mono" style={{ fontSize: 12.5, fontWeight: 600, color: (r.days_to_due ?? 0) < 0 ? 'var(--ks-critical)' : (r.days_to_due ?? 99) < 60 ? 'var(--ks-amber-700)' : 'var(--ks-ink-2)' }}>{dueText(r.days_to_due)}</span>
                        <span className="ks-faint" style={{ fontSize: 11, marginLeft: 6 }}>{fmtDate(r.next_due_date)}</span>
                      </td>
                      <td><span className="ks-wo-pill" style={{ color: st.color, background: st.bg }}>{st.label}</span></td>
                      <td style={{ textAlign: 'right', whiteSpace: 'nowrap' }}>
                        <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={busy === r.id} onClick={() => record(r.id, 'conform')} title="Marquer conforme"><CheckCircle2 size={13} /></button>
                        <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={busy === r.id} onClick={() => record(r.id, 'non_conform')} title="Non conforme → CAPA" style={{ marginLeft: 6, color: 'var(--ks-critical)' }}><X size={13} /></button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <div style={{ padding: '12px 20px', borderTop: '1px solid var(--ks-line)', fontSize: 12 }} className="ks-faint">
            <ShieldCheck size={13} style={{ verticalAlign: -2 }} /> Un résultat <b>non conforme</b> crée automatiquement une CAPA corrective et, pour un ascenseur, déclasse l'actif (status « down »). Relances J-60/J-30 par l'agent Échéancier.
          </div>
        </Card>
      )}
    </div>
  );
}

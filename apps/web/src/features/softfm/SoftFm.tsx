import { useEffect, useState } from 'react';
import { Sparkles, Gauge, CalendarX, Bug, RefreshCw, AlertTriangle, ShieldCheck } from 'lucide-react';
import { Card, StatBig } from '@keystone/ui';
import type { SoftVisit, PestLog, SoftFmSummary, ServiceVisitStatus } from '@keystone/domain/db/keystone';
import { fetchSoftVisits, fetchPestLogs, fetchSoftFmSummary } from '../../data/softfm.ts';

const STATUS: Record<ServiceVisitStatus, { label: string; color: string; bg: string }> = {
  planned: { label: 'Planifiée', color: '#2A47A0', bg: 'var(--ks-info-100)' },
  in_progress: { label: 'En cours', color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' },
  done: { label: 'Réalisée', color: '#0F6E56', bg: '#E1F5EE' },
  qc_passed: { label: 'QC validé', color: '#2C6230', bg: 'var(--ks-low-100)' },
  qc_failed: { label: 'QC échec', color: '#8E1E22', bg: 'var(--ks-critical-100)' },
  missed: { label: 'Manquée', color: '#8A3A07', bg: 'var(--ks-high-100)' },
};
const qcColor = (n: number | null) => (n == null ? 'var(--ks-ink-3)' : n >= 80 ? 'var(--ks-low)' : n >= 60 ? 'var(--ks-amber-700)' : 'var(--ks-critical)');
const dt = (s: string | null) => (s ? new Date(s).toLocaleString('fr-FR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—');

export function SoftFm() {
  const [visits, setVisits] = useState<SoftVisit[] | null>(null);
  const [pests, setPests] = useState<PestLog[] | null>(null);
  const [summary, setSummary] = useState<SoftFmSummary | null>(null);
  const [err, setErr] = useState<string | null>(null);

  function load() {
    fetchSoftVisits().then(setVisits).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
    fetchPestLogs().then(setPests).catch(() => {});
    fetchSoftFmSummary().then(setSummary).catch(() => {});
  }
  useEffect(load, []);

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Soft FM · Services généraux</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Services généraux</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">propreté EN 13549 · lutte antinuisibles 3D EN 16636 · contrôle qualité noté</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={load} style={{ alignSelf: 'end' }}><RefreshCw size={15} /> Rafraîchir</button>
      </header>

      {err && <Card><div style={{ textAlign: 'center', padding: 20 }}><AlertTriangle color="var(--ks-high)" /><div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 8 }}>{err}</div></div></Card>}

      {summary && (
        <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
          <Card><StatBig label="Taux de réalisation" icon={<Sparkles size={15} />} accent="var(--ks-low)" value={summary.realisation_pct} unit="%" sub={`${summary.visits_total} prestations`} /></Card>
          <Card><StatBig label="Score qualité moyen" icon={<Gauge size={15} />} accent="var(--ks-amber)" value={summary.qc_avg} unit="/100" sub="norme EN 13549" /></Card>
          <Card><StatBig label="Prestations manquées" icon={<CalendarX size={15} />} accent={summary.missed ? 'var(--ks-critical)' : 'var(--ks-low)'} value={summary.missed} sub={`${summary.qc_failed} échecs QC`} /></Card>
          <Card><StatBig label="Interventions 3D" icon={<Bug size={15} />} accent="var(--ks-info)" value={summary.pest_logs} sub="traçabilité EN 16636" /></Card>
        </div>
      )}

      <div className="kt-section-h"><h2>Prestations &amp; contrôle qualité</h2></div>
      {visits && (
        <Card pad={false} className="ks-reveal">
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Service</th><th>Lieu</th><th>Statut</th><th>Score QC</th><th>Réalisée</th></tr></thead>
              <tbody>
                {visits.map((v) => {
                  const st = STATUS[v.status];
                  return (
                    <tr key={v.id}>
                      <td style={{ fontWeight: 600 }}>{v.service_label ?? '—'}</td>
                      <td style={{ fontSize: 12.5 }}>{v.location_name ?? '—'}</td>
                      <td><span className="ks-wo-pill" style={{ color: st.color, background: st.bg }}>{st.label}</span></td>
                      <td><span className="ks-mono" style={{ fontWeight: 600, color: qcColor(v.qc_score) }}>{v.qc_score != null ? `${v.qc_score}/100` : '—'}</span></td>
                      <td><span className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{dt(v.completed_at ?? v.scheduled_for)}</span></td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      <div className="kt-section-h"><h2>Journal de lutte antinuisibles (3D)</h2><span className="kt-count">EN 16636 · produits réglementés</span></div>
      {pests && (
        <Card pad={false} className="ks-reveal">
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Intervention</th><th>Produit</th><th>Dose</th><th>Opérateur</th><th>Date</th></tr></thead>
              <tbody>
                {pests.map((p) => (
                  <tr key={p.id}>
                    <td style={{ fontWeight: 600 }}>{p.intervention_type}</td>
                    <td className="ks-mono" style={{ fontSize: 12.5 }}>{p.product_used}</td>
                    <td style={{ fontSize: 12.5 }}>{p.dose}</td>
                    <td style={{ fontSize: 12.5 }}>{p.operator_name}</td>
                    <td><span className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{dt(p.at)}</span></td>
                  </tr>
                ))}
                {pests.length === 0 && <tr><td colSpan={5} className="ks-dim" style={{ textAlign: 'center', padding: 30 }}>Aucune intervention 3D.</td></tr>}
              </tbody>
            </table>
          </div>
          <div style={{ padding: '12px 20px', borderTop: '1px solid var(--ks-line)', fontSize: 12 }} className="ks-faint">
            <ShieldCheck size={13} style={{ verticalAlign: -2 }} /> Traçabilité réglementaire (EN 16636 / label CEPA) : produit, dose, opérateur et relevé de pièges conservés pour chaque intervention 3D.
          </div>
        </Card>
      )}
    </div>
  );
}

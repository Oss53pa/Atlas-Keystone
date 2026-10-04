import { useEffect, useState } from 'react';
import { Wrench, Lock, RefreshCw, AlertTriangle, AlertCircle, Database, Boxes, ShieldCheck, ClipboardList, Radar, TrendingUp, FileText } from 'lucide-react';
import { WorkOrderDoc } from '../documents/Documents.tsx';
import { Card, StatBig } from '@keystone/ui';
import type { WorkOrderRow, WoStatus, WoType, DemoSummary, MaintKpi, PredictionRow } from '@keystone/domain/db/keystone';
import { fetchWorkOrders, fetchSummary, fetchKpi, fetchPredictions } from '../../data/gmao.ts';

const STATUS: Record<WoStatus, { label: string; color: string; bg: string }> = {
  draft: { label: 'Brouillon', color: 'var(--ks-ink-2)', bg: 'var(--ks-surface-3)' },
  planned: { label: 'Planifié', color: '#2A47A0', bg: 'var(--ks-info-100)' },
  assigned: { label: 'Assigné', color: '#4B3FA0', bg: '#ECEAFB' },
  in_progress: { label: 'En cours', color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' },
  on_hold: { label: 'En pause', color: 'var(--ks-ink-2)', bg: 'var(--ks-surface-3)' },
  done: { label: 'Terminé', color: '#0F6E56', bg: '#E1F5EE' },
  verified: { label: 'Vérifié', color: '#2C6230', bg: 'var(--ks-low-100)' },
  cancelled: { label: 'Annulé', color: 'var(--ks-ink-3)', bg: 'var(--ks-surface-3)' },
};
const TYPE: Record<WoType, string> = {
  corrective: 'Correctif', preventive: 'Préventif', conditional: 'Conditionnel', predictive: 'Prédictif', regulatory: 'Réglementaire',
};

function slaText(due: string | null, open: boolean): { txt: string; over: boolean } {
  if (!due) return { txt: '—', over: false };
  const d = new Date(due).getTime();
  const now = Date.now();
  const diffH = Math.round((d - now) / 3_600_000);
  if (open && diffH < 0) return { txt: `SLA +${Math.abs(diffH)} h`, over: true };
  if (diffH < 0) return { txt: 'échu', over: false };
  if (diffH < 48) return { txt: `dans ${diffH} h`, over: false };
  return { txt: `dans ${Math.round(diffH / 24)} j`, over: false };
}

export function WorkOrders() {
  const [rows, setRows] = useState<WorkOrderRow[] | null>(null);
  const [doc, setDoc] = useState<string | null>(null);
  const [summary, setSummary] = useState<DemoSummary | null>(null);
  const [kpi, setKpi] = useState<MaintKpi | null>(null);
  const [preds, setPreds] = useState<PredictionRow[]>([]);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true); setErr(null);
    fetchPredictions().then(setPreds).catch(() => {});
    try {
      const [wo, sum, k] = await Promise.all([fetchWorkOrders(), fetchSummary(), fetchKpi()]);
      setRows(wo); setSummary(sum); setKpi(k);
    } catch (e) {
      setErr(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }
  useEffect(() => { load(); }, []);

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Hard FM · GMAO</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Ordres de travail</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint" style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
              <Database size={13} /> projet ATLAS STUDIO · schéma <span className="ks-mono">keystone</span>
            </span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={load} style={{ alignSelf: 'end' }}>
          <RefreshCw size={15} /> Rafraîchir
        </button>
      </header>

      {summary && (
        <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
          <Card><StatBig label="Ordres de travail" icon={<Wrench size={15} />} value={summary.wo_total} sub={`${summary.wo_open} ouverts`} /></Card>
          <Card><StatBig label="Hors SLA" icon={<AlertCircle size={15} />} accent={summary.wo_overdue ? 'var(--ks-critical)' : 'var(--ks-low)'} value={summary.wo_overdue} sub="à escalader" /></Card>
          <Card><StatBig label="CRP en dépassement" icon={<ShieldCheck size={15} />} accent={summary.crp_overdue ? 'var(--ks-high)' : 'var(--ks-low)'} value={summary.crp_overdue} sub="contrôles réglementaires" /></Card>
          <Card><StatBig label="CAPA ouvertes" icon={<ClipboardList size={15} />} accent="var(--ks-amber)" value={summary.capa_open} sub={`${summary.events_open} événements HSSE`} /></Card>
        </div>
      )}

      {kpi && (
        <div style={{ marginBottom: 18 }}>
          <div className="ks-eyebrow" style={{ marginBottom: 10, display: 'flex', alignItems: 'center', gap: 8 }}>
            <ShieldCheck size={13} /> Indicateurs de maintenance · norme EN 15341 · calcul live
          </div>
          <div className="kt-dash kt-dash--4 ks-reveal">
            <Card><StatBig label="MTBF" value={kpi.mtbf_hours.toLocaleString('fr-FR')} unit="h" sub="temps moyen entre défaillances" /></Card>
            <Card><StatBig label="MTTR" value={kpi.mttr_hours.toFixed(2)} unit="h" sub="temps moyen de réparation" /></Card>
            <Card><StatBig label="Disponibilité" accent="var(--ks-low)" value={kpi.availability_pct.toFixed(2)} unit="%" sub="MTBF / (MTBF + MTTR)" /></Card>
            <Card><StatBig label="Part de préventif" accent="var(--ks-amber)" value={kpi.preventive_share_pct.toFixed(1)} unit="%" sub={`respect SLA ${kpi.sla_compliance_pct}%`} /></Card>
          </div>
        </div>
      )}

      {preds.length > 0 && (
        <Card className="ks-reveal" style={{ marginBottom: 18, borderColor: 'var(--ks-amber-100)', background: 'linear-gradient(180deg, var(--ks-amber-50), var(--ks-surface) 60%)' }}>
          <div className="ks-card__title" style={{ fontSize: 14, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
            <Radar size={16} color="var(--ks-amber-600)" /> Maintenance prédictive · PROPH3T
            <span className="ks-pill" style={{ height: 20 }}>{preds.length}</span>
          </div>
          <div className="ks-faint" style={{ fontSize: 12, marginBottom: 14 }}>Dérive de signature détectée par l'agent Sentinelle · OT prédictif à valider (§10.1)</div>
          {preds.map((p) => {
            const urgent = (p.rul_days ?? 99) <= 10;
            return (
              <div key={p.id} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '12px 0', borderTop: '1px solid var(--ks-line)' }}>
                <span style={{ width: 40, height: 40, borderRadius: 11, flex: 'none', display: 'grid', placeItems: 'center', background: urgent ? 'var(--ks-critical-100)' : 'var(--ks-amber-100)', color: urgent ? 'var(--ks-critical)' : 'var(--ks-amber-700)' }}><TrendingUp size={19} /></span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13.5, fontWeight: 600 }}>{p.asset_name} <span className="ks-mono ks-faint" style={{ fontSize: 11 }}>{p.asset_tag}</span></div>
                  <div className="ks-faint" style={{ fontSize: 12 }}>{p.recommended_action}</div>
                </div>
                <div style={{ textAlign: 'center' }}><div className="ks-mono" style={{ fontSize: 15, fontWeight: 600, color: urgent ? 'var(--ks-critical)' : 'var(--ks-amber-700)' }}>+{p.drift_pct}%</div><div className="ks-faint" style={{ fontSize: 10 }}>DÉRIVE</div></div>
                <div style={{ textAlign: 'center' }}><div className="ks-mono" style={{ fontSize: 15, fontWeight: 600 }}>{p.rul_days} j</div><div className="ks-faint" style={{ fontSize: 10 }}>RUL</div></div>
                <div style={{ textAlign: 'center' }}><div className="ks-mono" style={{ fontSize: 15, fontWeight: 600 }}>{Math.round((p.confidence ?? 0) * 100)}%</div><div className="ks-faint" style={{ fontSize: 10 }}>CONFIANCE</div></div>
                <span className="ks-wo-pill" style={{ color: 'var(--ks-ink-2)', background: 'var(--ks-surface-3)' }}>{p.wo_ref} · brouillon</span>
              </div>
            );
          })}
        </Card>
      )}

      <Card pad={false} className="ks-reveal" style={{ animationDelay: '120ms' }}>
        <div className="ks-card__head" style={{ padding: '16px 20px' }}>
          <div className="ks-card__title" style={{ fontSize: 14, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
            <Boxes size={16} /> Pipeline GMAO {rows && <span className="ks-faint ks-mono" style={{ fontWeight: 500 }}>· {rows.length}</span>}
          </div>
        </div>

        {loading && <div style={{ padding: '40px', textAlign: 'center' }} className="ks-dim">Chargement live…</div>}

        {err && (
          <div style={{ padding: '40px 24px', textAlign: 'center' }}>
            <AlertTriangle size={28} color="var(--ks-high)" />
            <div style={{ fontWeight: 700, marginTop: 10 }}>Erreur de lecture</div>
            <div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 6 }}>{err}</div>
          </div>
        )}

        {rows && !loading && !err && (
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead>
                <tr>
                  <th>Réf.</th><th>Intervention</th><th>Type</th><th>Statut</th><th>P.</th><th>Actif</th><th>SLA</th><th></th>
                </tr>
              </thead>
              <tbody>
                {rows.map((w) => {
                  const open = !['verified', 'cancelled'].includes(w.status);
                  const sla = slaText(w.sla_due, open);
                  const st = STATUS[w.status];
                  return (
                    <tr key={w.id}>
                      <td className="ks-mono" style={{ color: 'var(--ks-ink-2)', whiteSpace: 'nowrap' }}>{w.ref}</td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          {w.requires_permit && <Lock size={13} color="var(--ks-high)" />}
                          <span style={{ fontWeight: 600 }}>{w.title}</span>
                        </div>
                      </td>
                      <td><span className="ks-pill">{TYPE[w.type]}</span></td>
                      <td><span className="ks-wo-pill" style={{ color: st.color, background: st.bg }}>{st.label}</span></td>
                      <td><span className="ks-mono ks-prio" data-p={w.priority}>P{w.priority}</span></td>
                      <td>
                        {w.asset_tag ? (
                          <div style={{ lineHeight: 1.25 }}>
                            <span className="ks-mono" style={{ fontSize: 12 }}>{w.asset_tag}</span>
                            <div className="ks-faint" style={{ fontSize: 11.5 }}>{w.asset_name}</div>
                          </div>
                        ) : <span className="ks-faint">—</span>}
                      </td>
                      <td><span className="ks-mono" style={{ fontWeight: 600, color: sla.over ? 'var(--ks-critical)' : 'var(--ks-ink-2)' }}>{sla.txt}</span></td>
                      <td style={{ textAlign: 'right' }}><button className="ks-icon-btn" aria-label={`Fiche d’intervention ${w.ref}`} title="Fiche d’intervention (PDF)" onClick={() => setDoc(w.id)}><FileText size={15} /></button></td>
                    </tr>
                  );
                })}
                {rows.length === 0 && (
                  <tr><td colSpan={8} style={{ textAlign: 'center', padding: 40 }} className="ks-dim">Aucun ordre de travail.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </Card>
      {doc && <WorkOrderDoc woId={doc} onClose={() => setDoc(null)} />}
    </div>
  );
}

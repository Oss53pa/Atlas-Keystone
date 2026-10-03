import { useEffect, useState } from 'react';
import { BarChart3 } from 'lucide-react';
import { Card, TabBar } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import type { ParetoCriterion, ParetoRow } from '@keystone/domain/db/keystone';
import { fetchPareto } from '../../data/assets.ts';

const fcfa = (n: number) => format(money(n, 'XOF'));
const CRIT: Record<ParetoCriterion, { label: string; unit: (r: ParetoRow) => string }> = {
  frequency: { label: 'Fréquence', unit: (r) => `${r.failures} panne(s)` },
  cost: { label: 'Coût', unit: (r) => fcfa(r.cost) },
  downtime: { label: 'Durée d’arrêt', unit: (r) => `${r.downtime_h} h` },
};
const CLASS = { critical: 'critical', major: 'high', minor: 'medium' } as const;
const CLASS_LBL = { critical: 'Critique', major: 'Majeure', minor: 'Mineure' } as const;

/** Pareto 80/20 : barres (valeur) + courbe cumulée + seuil 80 %. Les « vital few » sont en ambre. */
function ParetoChart({ rows }: { rows: ParetoRow[] }) {
  const W = 640, H = 220, pad = { t: 16, r: 40, b: 34, l: 12 };
  const w = W - pad.l - pad.r, h = H - pad.t - pad.b;
  const max = Math.max(...rows.map((r) => r.value), 1);
  const bw = w / rows.length;
  const y80 = pad.t + h * 0.2;
  const pts = rows.map((r, i) => [pad.l + bw * i + bw / 2, pad.t + h - (r.cumulative_pct / 100) * h] as const);
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label="Diagramme de Pareto des pannes" style={{ display: 'block' }}>
      <line x1={pad.l} x2={W - pad.r} y1={y80} y2={y80} stroke="var(--ks-critical)" strokeDasharray="4 4" strokeWidth={1} opacity={0.6} />
      <text x={W - pad.r + 6} y={y80 + 4} fontSize={10.5} fill="var(--ks-critical)" fontFamily="var(--ks-font-mono)">80 %</text>
      {rows.map((r, i) => {
        const bh = (r.value / max) * h;
        return (
          <g key={r.asset_id}>
            <rect className="ks-grow" x={pad.l + bw * i + bw * 0.18} y={pad.t + h - bh} width={bw * 0.64} height={bh} rx={4}
              fill={r.in_vital_few ? 'var(--ks-amber)' : 'var(--ks-line-strong)'} style={{ animationDelay: `${i * 60}ms`, transformOrigin: 'bottom' }} />
            <text x={pad.l + bw * i + bw / 2} y={H - 14} textAnchor="middle" fontSize={10.5} fill="var(--ks-ink-2)" fontFamily="var(--ks-font-mono)">{r.asset_tag}</text>
          </g>
        );
      })}
      <path d={pts.map((p, i) => `${i ? 'L' : 'M'}${p[0].toFixed(1)},${p[1].toFixed(1)}`).join(' ')} fill="none" stroke="var(--ks-ink)" strokeWidth={1.75}
        pathLength={1} className="ks-draw" style={{ ['--len' as string]: 1 }} />
      {pts.map((p, i) => <circle key={i} cx={p[0]} cy={p[1]} r={3} fill="var(--ks-surface)" stroke="var(--ks-ink)" strokeWidth={1.5} />)}
      {[0, 50, 100].map((v) => (
        <text key={v} x={W - pad.r + 6} y={pad.t + h - (v / 100) * h + 4} fontSize={10} fill="var(--ks-ink-3)" fontFamily="var(--ks-font-mono)">{v}</text>
      ))}
    </svg>
  );
}

export function ParetoPanel() {
  const [crit, setCrit] = useState<ParetoCriterion>('frequency');
  const [rows, setRows] = useState<ParetoRow[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => { setRows(null); fetchPareto(crit).then(setRows).catch((e) => setErr(e instanceof Error ? e.message : String(e))); }, [crit]);
  const vital = (rows ?? []).filter((r) => r.in_vital_few);

  return (
    <div className="ks-reveal">
      <Card>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12, flexWrap: 'wrap', marginBottom: 12 }}>
          <div>
            <div className="kt-cardtitle">Pareto des pannes · 12 mois</div>
            <div className="kt-cardsub">OT correctifs réels · en ambre, les équipements qui concentrent 80 % du problème</div>
          </div>
          <TabBar tabs={(Object.keys(CRIT) as ParetoCriterion[]).map((k) => ({ id: k, label: CRIT[k].label }))} active={crit} onChange={(v) => setCrit(v as ParetoCriterion)} />
        </div>
        {err && <div className="ks-mono ks-faint" style={{ fontSize: 12 }}>{err}</div>}
        {rows && rows.length === 0 && <div className="ks-dim" style={{ textAlign: 'center', padding: 30 }}><BarChart3 size={20} /><div style={{ marginTop: 8 }}>Aucune panne corrective sur la période.</div></div>}
        {rows && rows.length > 0 && <ParetoChart rows={rows} />}
        {vital.length > 0 && (
          <div className="ka-insight">
            <b>{vital.length}</b> équipement{vital.length > 1 ? 's' : ''} sur {rows!.length} ({Math.round((vital.length / rows!.length) * 100)} %) concentre{vital.length > 1 ? 'nt' : ''} {vital[vital.length - 1].cumulative_pct} % {crit === 'frequency' ? 'des pannes' : crit === 'cost' ? 'du coût correctif' : 'des heures d’arrêt'} : {vital.map((v) => v.asset_tag).join(', ')}. C’est là que l’AMDEC et le préventif rapportent le plus.
          </div>
        )}
      </Card>

      {rows && rows.length > 0 && (
        <Card pad={false} style={{ marginTop: 14 }}>
          <div style={{ overflowX: 'auto' }}>
            <table className="ks-table">
              <thead><tr><th>Équipement</th><th>{CRIT[crit].label}</th><th>Part · cumul</th><th>MTBF</th><th>MTTR</th><th>Disponibilité</th><th>Classe</th></tr></thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.asset_id}>
                    <td><div className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{r.asset_tag}</div><div style={{ fontWeight: 600 }}>{r.asset_name}</div></td>
                    <td className="ks-mono" style={{ fontSize: 12.5, fontWeight: 600 }}>{CRIT[crit].unit(r)}</td>
                    <td className="ks-mono" style={{ fontSize: 12.5 }}>{r.pct} % <span className="ks-faint">· {r.cumulative_pct} %</span></td>
                    <td className="ks-mono" style={{ fontSize: 12.5 }}>{r.mtbf_h != null ? `${r.mtbf_h} h` : '—'}</td>
                    <td className="ks-mono" style={{ fontSize: 12.5 }}>{r.mttr_h != null ? `${r.mttr_h} h` : '—'}</td>
                    <td className="ks-mono" style={{ fontSize: 12.5 }}>{r.availability_pct != null ? `${r.availability_pct} %` : '—'}</td>
                    <td><span className={`ks-risk ks-risk--${CLASS[r.class]}`}>{CLASS_LBL[r.class]}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}
    </div>
  );
}

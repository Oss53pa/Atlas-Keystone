import { ShieldCheck, TrendingDown, AlertTriangle, ClipboardList } from 'lucide-react';
import { Card, StatBig, BarChart, Donut, Legend, ProgressRows, TrendChart, CountUp } from '@keystone/ui';
import { HSSE } from '../../../data/dashboards.ts';
import { CardTitle, type PanelProps } from '../shared.tsx';

export function Hsse(_: PanelProps) {
  const pyrMax = Math.max(...HSSE.pyramid.map((p) => p.value));
  return (
    <>
      <div className="kt-dash kt-dash--4 ks-reveal">
        <Card><StatBig label="Jours sans accident avec arrêt" icon={<ShieldCheck size={15} />} accent="var(--ks-low)" value={<CountUp value={HSSE.daysWithoutLTI} />} sub="record période : 92 j" /></Card>
        <Card><StatBig label="TRIR (12 mois)" icon={<TrendingDown size={15} />} value="1,82" sub="−14 % vs T-1" /></Card>
        <Card><StatBig label="LTIFR (12 mois)" icon={<TrendingDown size={15} />} value="3,10" sub="tendance baissière" /></Card>
        <Card><StatBig label="CAPA en retard" icon={<AlertTriangle size={15} />} accent="var(--ks-critical)" value={<CountUp value={6} />} sub="relance auto activée" /></Card>
      </div>

      <div className="kt-dash kt-dash--21" style={{ marginTop: 18 }}>
        <Card className="ks-reveal" style={{ animationDelay: '120ms' }}>
          <CardTitle title="TRIR — 12 mois glissants" sub="Indicateur retardé · objectif < 2,0" right={<Legend items={[{ label: 'TRIR', color: 'var(--ks-low)' }, { label: 'LTIFR', color: 'var(--ks-high)' }]} />} />
          <div style={{ marginTop: 14 }}>
            <TrendChart series={HSSE.trir} labels={HSSE.months} height={150} color="var(--ks-low)" />
            <div style={{ marginTop: -8 }}><TrendChart series={HSSE.ltifr} labels={HSSE.months} height={120} color="var(--ks-high)" /></div>
          </div>
        </Card>
        <Card className="ks-reveal" style={{ animationDelay: '200ms' }}>
          <CardTitle title="Pyramide de sécurité" sub="Modèle de Heinrich" />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 16, alignItems: 'center' }}>
            {HSSE.pyramid.map((p) => (
              <div key={p.label} style={{ width: `${40 + (p.value / pyrMax) * 60}%`, minWidth: 120 }}>
                <div style={{ height: 38, borderRadius: 7, background: p.color, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', gap: 8 }} className="ks-grow-x">
                  <b className="ks-mono" style={{ fontSize: 15 }}>{p.value}</b>
                </div>
                <div className="ks-faint" style={{ fontSize: 11, textAlign: 'center', marginTop: 3 }}>{p.label}</div>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <div className="kt-dash kt-dash--3" style={{ marginTop: 18 }}>
        <Card className="ks-reveal" style={{ animationDelay: '260ms' }}>
          <CardTitle title="Incidents par type" sub="12 mois" />
          <div style={{ marginTop: 16 }}><BarChart data={HSSE.incidentsByType} height={150} /></div>
        </Card>
        <Card className="ks-reveal" style={{ animationDelay: '320ms' }}>
          <CardTitle title="CAPA par statut" right={<ClipboardList size={16} className="ks-faint" />} />
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14, marginTop: 10 }}>
            <Donut data={HSSE.capaByStatus} size={130} stroke={18} center={<><b className="ks-mono" style={{ fontSize: 20 }}>{HSSE.capaByStatus.reduce((s, d) => s + d.value, 0)}</b><br /><span className="ks-faint" style={{ fontSize: 10 }}>CAPA</span></>} />
            <Legend items={HSSE.capaByStatus.map((c) => ({ label: c.label, color: c.color, value: String(c.value) }))} />
          </div>
        </Card>
        <Card className="ks-reveal" style={{ animationDelay: '380ms' }}>
          <CardTitle title="Score de risque dynamique" sub="par zone · CDC §10.4" />
          <div style={{ marginTop: 18 }}>
            <ProgressRows max={100} rows={HSSE.riskByScope.map((r) => ({ label: r.label, value: r.value, color: r.color, right: <span className="ks-mono" style={{ color: r.color }}>{r.value}</span> }))} />
          </div>
        </Card>
      </div>
    </>
  );
}

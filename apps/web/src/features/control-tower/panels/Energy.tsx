import { Zap, Gauge, Recycle, Droplets } from 'lucide-react';
import { Card, StatBig, TrendChart, Donut, Legend, BarChart, Sparkline, CountUp } from '@keystone/ui';
import { ENV } from '../../../data/dashboards.ts';
import { ENERGY } from '../../../data/demo.ts';
import { CardTitle, levelColor, type PanelProps } from '../shared.tsx';

export function Energy(_: PanelProps) {
  return (
    <>
      <div className="kt-dash kt-dash--4 ks-reveal">
        <Card><StatBig label="Consommation YTD" icon={<Zap size={15} />} accent="var(--ks-amber)" value={<CountUp value={ENV.ytdMwh} />} unit="MWh" sub="cumul exercice" /></Card>
        <Card><StatBig label="Intensité énergétique" icon={<Gauge size={15} />} value={<CountUp value={ENV.intensity} />} unit="kWh/m²" sub="par an · benchmark 160" /></Card>
        <Card><StatBig label="Valorisation déchets" icon={<Recycle size={15} />} accent="var(--ks-low)" value={<CountUp value={ENV.recoveryRate} />} unit="%" sub="objectif ESG : 70 %" /></Card>
        <Card><StatBig label="Consommation d’eau" icon={<Droplets size={15} />} accent="var(--ks-info)" value={<CountUp value={ENV.waterM3} />} unit="m³" sub="cumul exercice" /></Card>
      </div>

      <div className="kt-dash kt-dash--21" style={{ marginTop: 18 }}>
        <Card className="ks-reveal" style={{ animationDelay: '120ms' }}>
          <CardTitle title="Consommation énergétique" sub="12 mois · MWh" right={<span className="ks-pill" style={{ color: 'var(--ks-amber-700)' }}>pic en juillet</span>} />
          <div style={{ marginTop: 14 }}><TrendChart series={ENV.energyTrend} labels={ENV.months} height={170} color="var(--ks-amber)" /></div>
        </Card>
        <Card className="ks-reveal" style={{ animationDelay: '200ms' }}>
          <CardTitle title="Émissions GES par scope" sub="tCO₂e · reporting ESG" />
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16, marginTop: 12 }}>
            <Donut data={ENV.emissions} size={140} stroke={20} center={<><b className="ks-mono" style={{ fontSize: 20 }}>{ENV.emissions.reduce((s, e) => s + e.value, 0)}</b><br /><span className="ks-faint" style={{ fontSize: 10 }}>tCO₂e</span></>} />
            <Legend items={ENV.emissions.map((e) => ({ label: e.label, color: e.color, value: `${e.value} t` }))} />
          </div>
        </Card>
      </div>

      <div className="kt-dash kt-dash--2" style={{ marginTop: 18 }}>
        <Card pad={false} className="ks-reveal" style={{ animationDelay: '260ms' }}>
          <div style={{ padding: '20px 22px 6px' }}>
            <CardTitle title="Anomalies par zone (sous-comptage)" sub="détection PROPH3T · 7 jours" />
          </div>
          <div style={{ padding: '0 20px 14px' }}>
            {ENERGY.map((e) => (
              <div className="kt-energy-row" key={e.zone}>
                <span style={{ width: 8, height: 8, borderRadius: 9, background: levelColor(e.level) }} />
                <div style={{ flex: 1, minWidth: 0, fontSize: 13, fontWeight: 600 }}>{e.zone}</div>
                <Sparkline data={e.series} width={80} height={26} color={levelColor(e.level)} />
                <span className="ks-mono" style={{ fontSize: 13, fontWeight: 600, width: 52, textAlign: 'right', color: e.deviation > 0 ? 'var(--ks-high)' : 'var(--ks-low)' }}>
                  {e.deviation > 0 ? '+' : ''}{e.deviation}%
                </span>
              </div>
            ))}
          </div>
        </Card>
        <Card className="ks-reveal" style={{ animationDelay: '320ms' }}>
          <CardTitle title="Gestion des déchets" sub="valorisation vs enfouissement" />
          <div style={{ marginTop: 16 }}><BarChart data={ENV.waste.map((w) => ({ ...w, display: `${w.value}%` }))} max={100} height={150} /></div>
          <div className="ks-faint" style={{ fontSize: 12, marginTop: 4 }}>
            Bordereaux de suivi générés pour 100 % des déchets dangereux (CDC §6.8).
          </div>
        </Card>
      </div>
    </>
  );
}

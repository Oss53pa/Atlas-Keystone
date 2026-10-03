import { Gauge, Timer, Activity, ShieldAlert, ChevronRight } from 'lucide-react';
import { Card, StatBig, BarChart, Donut, Legend, ProgressRows, TrendChart, CountUp } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import { MAINT } from '../../../data/dashboards.ts';
import { CardTitle, type PanelProps } from '../shared.tsx';

export function Maintenance(_: PanelProps) {
  const fcfa = (n: number) => format(money(n, 'XOF'));
  return (
    <>
      <div className="kt-dash kt-dash--4 ks-reveal">
        <Card><StatBig label="MTBF" icon={<Activity size={15} />} value={<CountUp value={MAINT.mtbf} />} unit="h" sub="temps moyen entre pannes" /></Card>
        <Card><StatBig label="MTTR" icon={<Timer size={15} />} value={<CountUp value={MAINT.mttr} decimals={1} />} unit="h" sub="temps moyen de réparation" /></Card>
        <Card><StatBig label="Disponibilité" icon={<Gauge size={15} />} accent="var(--ks-low)" value={<CountUp value={MAINT.availabilityPct} decimals={1} />} unit="%" sub="parc équipements critiques" /></Card>
        <Card><StatBig label="Part de préventif" icon={<Activity size={15} />} accent="var(--ks-amber)" value={<CountUp value={MAINT.preventiveShare} />} unit="%" sub={`${MAINT.woTotal} OT au total`} /></Card>
      </div>

      <div className="kt-dash kt-dash--21" style={{ marginTop: 18 }}>
        <Card className="ks-reveal" style={{ animationDelay: '120ms' }}>
          <CardTitle title="Ordres de travail par statut" sub="Pipeline GMAO en cours" right={<span className="ks-mono ks-faint" style={{ fontSize: 12 }}>{MAINT.woTotal} OT</span>} />
          <div style={{ marginTop: 18 }}><BarChart data={MAINT.woByStatus} height={170} /></div>
        </Card>
        <Card className="ks-reveal" style={{ animationDelay: '200ms' }}>
          <CardTitle title="Répartition par type" />
          <div style={{ display: 'flex', alignItems: 'center', gap: 22, marginTop: 14 }}>
            <Donut data={MAINT.mix} size={140} stroke={20} center={<><b className="ks-mono" style={{ fontSize: 22 }}>{MAINT.mix.reduce((s, d) => s + d.value, 0)}</b><br /><span className="ks-faint" style={{ fontSize: 11 }}>OT 30 j</span></>} />
            <Legend items={MAINT.mix.map((m) => ({ label: m.label, color: m.color!, value: String(m.value) }))} />
          </div>
        </Card>
      </div>

      <div className="kt-dash kt-dash--21" style={{ marginTop: 18 }}>
        <Card className="ks-reveal" style={{ animationDelay: '280ms' }}>
          <CardTitle title="Top actifs par coût de maintenance" sub="90 derniers jours · Money.ts (XOF)" />
          <div style={{ marginTop: 18 }}>
            <ProgressRows
              rows={MAINT.topAssetsCost.map((a) => ({
                label: a.label, sub: a.sub, value: a.value, color: 'var(--ks-amber)', right: <span style={{ color: 'var(--ks-ink)' }}>{fcfa(a.value)}</span>,
              }))}
            />
          </div>
        </Card>
        <Card pad={false} className="ks-reveal" style={{ animationDelay: '360ms' }}>
          <div style={{ padding: '20px 22px 0' }}>
            <CardTitle title="Backlog OT" sub="8 dernières semaines" right={<span className="ks-pill" style={{ color: 'var(--ks-critical)' }}><ShieldAlert size={13} /> {MAINT.slaBreaches} hors SLA</span>} />
            <div style={{ marginTop: 10 }}><TrendChart series={MAINT.backlogTrend} height={120} color="var(--ks-info)" /></div>
          </div>
          <div style={{ borderTop: '1px solid var(--ks-line)', padding: '6px 8px 8px' }}>
            {MAINT.slaList.map((s) => (
              <div className="ks-attn__row" key={s.ref} style={{ gridTemplateColumns: '1fr auto' }}>
                <div style={{ display: 'flex', flexDirection: 'column' }}>
                  <span style={{ fontSize: 13, fontWeight: 600 }}>{s.title}</span>
                  <span className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{s.ref}</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span className="ks-risk ks-risk--high">{s.over}</span>
                  <ChevronRight size={16} className="ks-faint" />
                </div>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </>
  );
}

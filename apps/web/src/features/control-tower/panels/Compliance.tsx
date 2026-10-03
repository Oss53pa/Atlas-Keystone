import { ShieldCheck, CalendarClock, FileWarning, ClipboardX } from 'lucide-react';
import { Card, StatBig, RingGauge, ProgressRows, CountUp, Legend } from '@keystone/ui';
import { COMPLIANCE } from '../../../data/dashboards.ts';
import { CardTitle, type PanelProps } from '../shared.tsx';

export function Compliance(_: PanelProps) {
  const reservesTotal = COMPLIANCE.reserves.reduce((s, r) => s + r.value, 0);
  return (
    <>
      <div className="kt-dash kt-dash--4 ks-reveal">
        <Card>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <RingGauge value={COMPLIANCE.crpRate} size={74} stroke={7} color="var(--ks-high)" />
            <div>
              <div className="ks-stat__label">Conformité CRP</div>
              <div className="ks-faint" style={{ fontSize: 12, marginTop: 4 }}>contrôles à jour / dus</div>
            </div>
          </div>
        </Card>
        <Card><StatBig label="Contrôles dus" icon={<CalendarClock size={15} />} accent="var(--ks-amber)" value={<CountUp value={COMPLIANCE.due} />} sub="échéance < 60 j" /></Card>
        <Card><StatBig label="En dépassement" icon={<ClipboardX size={15} />} accent="var(--ks-critical)" value={<CountUp value={COMPLIANCE.overdue} />} sub="action immédiate" /></Card>
        <Card><StatBig label="Réserves à lever" icon={<FileWarning size={15} />} accent="var(--ks-high)" value={<CountUp value={reservesTotal} />} sub="liées à des CAPA" /></Card>
      </div>

      <div className="kt-dash kt-dash--21" style={{ marginTop: 18 }}>
        <Card className="ks-reveal" style={{ animationDelay: '120ms' }}>
          <CardTitle title="Conformité réglementaire par type d’équipement" sub="Organismes agréés : Veritas · SOCOTEC · APAVE" />
          <div style={{ marginTop: 18 }}>
            <ProgressRows
              max={100}
              rows={COMPLIANCE.crpByType.map((t) => {
                const ratio = t.conform / t.total;
                const color = ratio === 1 ? 'var(--ks-low)' : ratio >= 0.85 ? 'var(--ks-amber)' : 'var(--ks-high)';
                return { label: t.label, value: Math.round(ratio * 100), color, right: <span className="ks-mono">{t.conform}/{t.total}</span> };
              })}
            />
          </div>
        </Card>
        <Card pad={false} className="ks-reveal" style={{ animationDelay: '200ms' }}>
          <div style={{ padding: '20px 22px 0' }}>
            <CardTitle title="Réserves" sub="par sévérité" />
            <div style={{ marginTop: 12 }}>
              <Legend items={COMPLIANCE.reserves.map((r) => ({ label: r.label, color: r.color, value: String(r.value) }))} />
            </div>
          </div>
          <div style={{ borderTop: '1px solid var(--ks-line)', marginTop: 16, padding: '6px 8px 8px' }}>
            <div className="ks-eyebrow" style={{ padding: '12px 12px 4px' }}>GED · documents à expiration</div>
            {COMPLIANCE.gedExpiring.map((d) => (
              <div className="ks-attn__row" key={d.title} style={{ gridTemplateColumns: '1fr auto' }}>
                <span style={{ fontSize: 13, fontWeight: 600 }}>{d.title}</span>
                <span className={`ks-risk ks-risk--${d.days === 0 ? 'critical' : d.days <= 15 ? 'high' : 'medium'}`}>
                  {d.days === 0 ? 'Expiré' : `J-${d.days}`}
                </span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <div className="kt-dash kt-dash--2" style={{ marginTop: 18 }}>
        {COMPLIANCE.iso.map((f, i) => (
          <Card key={f.label} className="ks-reveal" style={{ animationDelay: `${260 + i * 70}ms` }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
              <RingGauge value={f.value} size={70} stroke={6} color="var(--ks-info)" />
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 15, fontWeight: 700 }}>
                  <ShieldCheck size={16} color="var(--ks-info)" /> {f.label}
                </div>
                <div className="ks-faint" style={{ fontSize: 12.5, marginTop: 4 }}>{f.clauses}</div>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </>
  );
}

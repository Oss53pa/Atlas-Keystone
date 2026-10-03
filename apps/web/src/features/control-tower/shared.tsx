import { useEffect, useState, type ReactNode } from 'react';
import { ChevronRight, MapPin } from 'lucide-react';
import { RiskBadge, type RiskLevel } from '@keystone/ui';
import type { AttentionItem } from '../../data/demo.ts';

export interface PanelProps {
  site: string;
}

export function useClock() {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(t);
  }, []);
  return now;
}

export const postureColor = (v: number) =>
  v >= 85 ? 'var(--ks-low)' : v >= 75 ? 'var(--ks-amber)' : 'var(--ks-high)';

export const levelColor = (l: RiskLevel) =>
  ({ critical: 'var(--ks-critical)', high: 'var(--ks-high)', medium: 'var(--ks-amber)', low: 'var(--ks-low)', info: 'var(--ks-info)' }[l]);

export const techColor = (s: 'on_wo' | 'on_duty' | 'break') =>
  ({ on_wo: 'var(--ks-info)', on_duty: 'var(--ks-low)', break: 'var(--ks-ink-3)' }[s]);

export const scoreColor = (n: number) =>
  n >= 80 ? 'var(--ks-critical)' : n >= 60 ? 'var(--ks-high)' : 'var(--ks-amber-700)';

/** En-tête de carte dashboard. */
export function CardTitle({ title, sub, right }: { title: string; sub?: string; right?: ReactNode }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
      <div>
        <div className="kt-cardtitle">{title}</div>
        {sub && <div className="kt-cardsub" style={{ marginBottom: 0 }}>{sub}</div>}
      </div>
      {right}
    </div>
  );
}

export function AttnRow({ item }: { item: AttentionItem }) {
  return (
    <div className="ks-attn__row">
      <span className={`ks-attn__rail ks-attn__rail--${item.level}`} />
      <div style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 2 }}>
          <RiskBadge level={item.level} />
          <span className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{item.id}</span>
          <span className="ks-faint" style={{ fontSize: 11.5 }}>· {item.domain}</span>
        </div>
        <div className="ks-attn__title">{item.title}</div>
        <div className="ks-attn__meta">
          <span><MapPin size={12} style={{ verticalAlign: -1 }} /> {item.site}</span>
          {item.asset && <span className="ks-mono">{item.asset}</span>}
          <span>{item.age}</span>
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
        <div style={{ textAlign: 'right' }}>
          <div className="ks-mono" style={{ fontSize: 18, fontWeight: 600, color: scoreColor(item.riskScore) }}>{item.riskScore}</div>
          <div className="ks-faint" style={{ fontSize: 10.5, letterSpacing: '.04em' }}>RISQUE</div>
        </div>
        <ChevronRight size={18} className="ks-faint" />
      </div>
    </div>
  );
}

export function HealthCell({ label, v }: { label: string; v: number }) {
  return (
    <div className="kt-health__cell">
      <div className="kt-health__lbl">{label}</div>
      <div className="ks-mono" style={{ fontSize: 16, fontWeight: 600, color: 'var(--ks-ink)' }}>
        {v}<span style={{ fontSize: 11, color: 'var(--ks-ink-3)' }}>%</span>
      </div>
      <div className="kt-bar"><span style={{ width: `${v}%`, background: postureColor(v) }} /></div>
    </div>
  );
}

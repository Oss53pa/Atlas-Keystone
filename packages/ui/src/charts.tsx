import type { ReactNode } from 'react';

const cx = (...c: (string | false | undefined)[]) => c.filter(Boolean).join(' ');

/* ============================ Tab bar ============================ */
export interface TabDef {
  id: string;
  label: string;
  icon?: ReactNode;
}
export function TabBar({ tabs, active, onChange }: { tabs: TabDef[]; active: string; onChange: (id: string) => void }) {
  return (
    <div className="ks-tabs" role="tablist">
      {tabs.map((t) => (
        <button
          key={t.id}
          role="tab"
          aria-selected={t.id === active}
          className={cx('ks-tab', t.id === active && 'ks-tab--active')}
          onClick={() => onChange(t.id)}
        >
          {t.icon && <span className="ks-tab__icon">{t.icon}</span>}
          {t.label}
        </button>
      ))}
    </div>
  );
}

/* ============================ Stat ============================ */
export function StatBig({
  label,
  value,
  unit,
  sub,
  accent,
  icon,
}: {
  label: string;
  value: ReactNode;
  unit?: string;
  sub?: ReactNode;
  accent?: string;
  icon?: ReactNode;
}) {
  return (
    <div className="ks-stat">
      <div className="ks-stat__label">
        {icon && <span style={{ color: accent ?? 'var(--ks-ink-3)' }}>{icon}</span>}
        {label}
      </div>
      <div className="ks-stat__value" style={accent ? { color: accent } : undefined}>
        {value}
        {unit && <span className="ks-stat__unit">{unit}</span>}
      </div>
      {sub && <div className="ks-stat__sub">{sub}</div>}
    </div>
  );
}

/* ============================ Legend ============================ */
export function Legend({ items }: { items: { label: string; color: string; value?: string }[] }) {
  return (
    <div className="ks-legend2">
      {items.map((i) => (
        <span key={i.label} className="ks-legend2__item">
          <i style={{ background: i.color }} />
          {i.label}
          {i.value && <b className="ks-mono">{i.value}</b>}
        </span>
      ))}
    </div>
  );
}

/* ============================ Bar chart (vertical) ============================ */
export interface Bar {
  label: string;
  value: number;
  color?: string;
  display?: string;
}
export function BarChart({ data, height = 150, max }: { data: Bar[]; height?: number; max?: number }) {
  const top = max ?? Math.max(...data.map((d) => d.value), 1);
  return (
    <div className="ks-bars" style={{ height }}>
      {data.map((d, i) => (
        <div className="ks-bars__col" key={d.label + i}>
          <div className="ks-bars__val ks-mono">{d.display ?? d.value}</div>
          <div className="ks-bars__track">
            <div
              className="ks-bars__bar ks-grow"
              style={{
                height: `${(d.value / top) * 100}%`,
                background: d.color ?? 'var(--ks-amber)',
                animationDelay: `${i * 70}ms`,
              }}
            />
          </div>
          <div className="ks-bars__lbl">{d.label}</div>
        </div>
      ))}
    </div>
  );
}

/* ============================ Progress rows (ranking / cascade) ============================ */
export interface ProgRow {
  label: string;
  value: number;
  max?: number;
  color?: string;
  right?: ReactNode;
  sub?: string;
}
export function ProgressRows({ rows, max }: { rows: ProgRow[]; max?: number }) {
  const top = max ?? Math.max(...rows.map((r) => r.max ?? r.value), 1);
  return (
    <div className="ks-prog">
      {rows.map((r, i) => (
        <div className="ks-prog__row" key={r.label + i}>
          <div className="ks-prog__head">
            <span className="ks-prog__label">{r.label}{r.sub && <em className="ks-faint"> · {r.sub}</em>}</span>
            <span className="ks-prog__right ks-mono">{r.right ?? r.value}</span>
          </div>
          <div className="ks-prog__track">
            <span className="ks-grow-x" style={{ width: `${Math.min(100, (r.value / top) * 100)}%`, background: r.color ?? 'var(--ks-amber)', animationDelay: `${i * 60}ms` }} />
          </div>
        </div>
      ))}
    </div>
  );
}

/* ============================ Trend chart (area + line, optional projection) ============================ */
export function TrendChart({
  series,
  width = 520,
  height = 170,
  color = 'var(--ks-amber)',
  labels,
  projectionFrom,
}: {
  series: number[];
  width?: number;
  height?: number;
  color?: string;
  labels?: string[];
  projectionFrom?: number; // index where dashed projection starts
}) {
  const pad = { t: 14, r: 12, b: 22, l: 30 };
  const w = width - pad.l - pad.r;
  const h = height - pad.t - pad.b;
  const min = Math.min(...series);
  const max = Math.max(...series);
  const span = max - min || 1;
  const step = w / (series.length - 1);
  const x = (i: number) => pad.l + i * step;
  const y = (v: number) => pad.t + h - ((v - min) / span) * h;
  const pts = series.map((v, i) => [x(i), y(v)] as const);

  const solidEnd = projectionFrom != null ? projectionFrom : series.length - 1;
  const line = (a: number, b: number) =>
    pts.slice(a, b + 1).map((p, i) => `${i === 0 ? 'M' : 'L'}${p[0].toFixed(1)},${p[1].toFixed(1)}`).join(' ');
  const areaPath = `${line(0, solidEnd)} L${pts[solidEnd][0]},${pad.t + h} L${pad.l},${pad.t + h} Z`;

  const grid = [0, 0.5, 1].map((g) => pad.t + h - g * h);

  return (
    <svg width="100%" viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Tendance" style={{ display: 'block' }}>
      {grid.map((gy, i) => (
        <line key={i} x1={pad.l} x2={width - pad.r} y1={gy} y2={gy} stroke="var(--ks-line)" strokeWidth={1} />
      ))}
      {[max, (max + min) / 2, min].map((v, i) => (
        <text key={i} x={pad.l - 6} y={grid[i] + 3} textAnchor="end" fontSize="10" fill="var(--ks-ink-3)" className="ks-mono">
          {Math.round(v)}
        </text>
      ))}
      <path d={areaPath} fill={color} opacity={0.1} />
      <path d={line(0, solidEnd)} fill="none" stroke={color} strokeWidth={2.25} strokeLinecap="round" strokeLinejoin="round" pathLength={1} className="ks-draw" style={{ ['--len' as string]: 1 }} />
      {projectionFrom != null && (
        <path d={line(solidEnd, series.length - 1)} fill="none" stroke={color} strokeWidth={2} strokeDasharray="5 5" opacity={0.6} strokeLinecap="round" />
      )}
      <circle cx={pts[solidEnd][0]} cy={pts[solidEnd][1]} r={3.5} fill={color} stroke="var(--ks-surface)" strokeWidth={2} />
      {labels &&
        labels.map((l, i) => (
          <text key={i} x={x(i)} y={height - 6} textAnchor="middle" fontSize="10" fill="var(--ks-ink-3)">
            {l}
          </text>
        ))}
    </svg>
  );
}

/* ============================ Donut ============================ */
export interface Slice {
  label: string;
  value: number;
  color: string;
}
export function Donut({ data, size = 150, stroke = 20, center }: { data: Slice[]; size?: number; stroke?: number; center?: ReactNode }) {
  const total = data.reduce((s, d) => s + d.value, 0) || 1;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  let acc = 0;
  return (
    <span className="ks-ring" style={{ width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }} aria-hidden>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--ks-surface-3)" strokeWidth={stroke} />
        {data.map((d, i) => {
          const frac = d.value / total;
          const dash = frac * c;
          const off = -acc * c;
          acc += frac;
          return (
            <circle
              key={i}
              cx={size / 2}
              cy={size / 2}
              r={r}
              fill="none"
              stroke={d.color}
              strokeWidth={stroke}
              strokeDasharray={`${dash} ${c - dash}`}
              strokeDashoffset={off}
            />
          );
        })}
      </svg>
      {center && <span className="ks-ring__val" style={{ fontSize: size * 0.16, textAlign: 'center', lineHeight: 1.1 }}>{center}</span>}
    </span>
  );
}

import { useEffect, useRef, useState, type ButtonHTMLAttributes, type ReactNode } from 'react';

export type RiskLevel = 'critical' | 'high' | 'medium' | 'low' | 'info';

const cx = (...c: (string | false | undefined)[]) => c.filter(Boolean).join(' ');

const prefersReduced = () =>
  typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

/** Anime une valeur 0 → target via requestAnimationFrame (easing out-cubic). */
export function useCountUp(target: number, duration = 900): number {
  const [v, setV] = useState(prefersReduced() ? target : 0);
  const ref = useRef<number>(0);
  useEffect(() => {
    if (prefersReduced()) {
      setV(target);
      return;
    }
    let raf = 0;
    const start = performance.now();
    const from = ref.current;
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / duration);
      const eased = 1 - Math.pow(1 - t, 3);
      const next = from + (target - from) * eased;
      ref.current = next;
      setV(next);
      if (t < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    // Filet de sécurité : garantit la valeur finale même si rAF est throttlé (onglet en arrière-plan / headless)
    const settle = setTimeout(() => { ref.current = target; setV(target); }, duration + 120);
    return () => { cancelAnimationFrame(raf); clearTimeout(settle); };
  }, [target, duration]);
  return v;
}

export function CountUp({ value, decimals = 0, suffix = '' }: { value: number; decimals?: number; suffix?: string }) {
  const v = useCountUp(value);
  return <>{v.toFixed(decimals)}{suffix}</>;
}

/* ---------------- Button ---------------- */
type BtnVariant = 'primary' | 'ghost' | 'quiet' | 'danger';
export function Button({
  variant = 'ghost',
  sm,
  className,
  children,
  ...rest
}: { variant?: BtnVariant; sm?: boolean } & ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button className={cx('ks-btn', `ks-btn--${variant}`, sm && 'ks-btn--sm', className)} {...rest}>
      {children}
    </button>
  );
}

export function IconButton({
  label,
  children,
  className,
  ...rest
}: { label: string } & ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button className={cx('ks-icon-btn', className)} aria-label={label} {...rest}>
      {children}
    </button>
  );
}

/* ---------------- Card ---------------- */
export function Card({
  pad = true,
  hover,
  className,
  children,
  ...rest
}: { pad?: boolean; hover?: boolean; className?: string; children: ReactNode } & React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cx('ks-card', pad && 'ks-card--pad', hover && 'ks-card--hover', className)} {...rest}>
      {children}
    </div>
  );
}

/* ---------------- Risk badge ---------------- */
const RISK_LABEL: Record<RiskLevel, string> = {
  critical: 'Critique',
  high: 'Élevé',
  medium: 'Moyen',
  low: 'Faible',
  info: 'Info',
};
export function RiskBadge({ level, label }: { level: RiskLevel; label?: string }) {
  return <span className={cx('ks-risk', `ks-risk--${level}`)}>{label ?? RISK_LABEL[level]}</span>;
}

/* ---------------- Status dot ---------------- */
const STATUS_COLOR: Record<RiskLevel, string> = {
  critical: 'var(--ks-critical)',
  high: 'var(--ks-high)',
  medium: 'var(--ks-medium)',
  low: 'var(--ks-low)',
  info: 'var(--ks-info)',
};
export function StatusDot({ level, children }: { level: RiskLevel; children?: ReactNode }) {
  return (
    <span className="ks-status" style={{ color: STATUS_COLOR[level] }}>
      <span className="ks-status__dot" />
      {children && <span style={{ color: 'var(--ks-ink)' }}>{children}</span>}
    </span>
  );
}

export function Pill({ children, color }: { children: ReactNode; color?: string }) {
  return (
    <span className="ks-pill" style={color ? { color } : undefined}>
      {color && <span className="ks-pill__dot" />}
      {children}
    </span>
  );
}

/* ---------------- Ring gauge ---------------- */
export function RingGauge({
  value,
  size = 72,
  stroke = 7,
  color = 'var(--ks-amber)',
  label,
}: {
  value: number; // 0..100
  size?: number;
  stroke?: number;
  color?: string;
  label?: string;
}) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const animated = useCountUp(Math.max(0, Math.min(100, value)), 1000);
  const dash = (animated / 100) * c;
  return (
    <span className="ks-ring" style={{ width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }} aria-hidden>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--ks-line-2)" strokeWidth={stroke} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={color}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={`${dash} ${c - dash}`}
        />
      </svg>
      <span className="ks-ring__val" style={{ fontSize: size * 0.26 }}>
        {label != null ? label : Math.round(animated)}
      </span>
    </span>
  );
}

/* ---------------- Sparkline ---------------- */
export function Sparkline({
  data,
  width = 96,
  height = 30,
  color = 'var(--ks-amber)',
}: {
  data: number[];
  width?: number;
  height?: number;
  color?: string;
}) {
  if (data.length < 2) return null;
  const min = Math.min(...data);
  const max = Math.max(...data);
  const span = max - min || 1;
  const step = width / (data.length - 1);
  const pts = data.map((d, i) => [i * step, height - ((d - min) / span) * (height - 4) - 2]);
  const path = pts.map((p, i) => `${i === 0 ? 'M' : 'L'}${p[0].toFixed(1)},${p[1].toFixed(1)}`).join(' ');
  const area = `${path} L${width},${height} L0,${height} Z`;
  return (
    <svg width={width} height={height} aria-hidden style={{ display: 'block', overflow: 'visible' }}>
      <path d={area} fill={color} opacity={0.1} />
      <path
        d={path}
        fill="none"
        stroke={color}
        strokeWidth={1.75}
        strokeLinecap="round"
        strokeLinejoin="round"
        pathLength={1}
        className="ks-draw"
        style={{ ['--len' as string]: 1 }}
      />
      <circle cx={pts[pts.length - 1][0]} cy={pts[pts.length - 1][1]} r={2.5} fill={color} />
    </svg>
  );
}

/* ---------------- Avatar ---------------- */
export function Avatar({ initials }: { initials: string }) {
  return <span className="ks-avatar">{initials}</span>;
}

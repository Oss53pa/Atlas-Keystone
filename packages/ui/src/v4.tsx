import type { ReactNode } from 'react';

/** Tons de statut de la refonte v4 : [fond, texte, pastille]. */
export const AK_TONE = {
  n: ['#F0EBE5', '#6C6761', '#7D7469'],
  t: ['#D5F8F8', '#037475', '#149494'],
  b: ['#E7F1FE', '#3569AA', '#4C87D2'],
  v: ['#F1EEFE', '#715AAC', '#9075D4'],
  a: ['#FFEDDA', '#925C01', '#BA7605'],
  g: ['#E0F7E4', '#26763E', '#3C9655'],
  r: ['#FFEBE9', '#B5403D', '#E05854'],
  c: ['#D33949', '#FFFFFF', '#FFFFFF'],
} as const;
export type AkTone = keyof typeof AK_TONE;

export function isTone(x: string): x is AkTone {
  return Object.prototype.hasOwnProperty.call(AK_TONE, x);
}

/** Décode « Libellé|ton ». */
export function parseStatus(v: string): { label: string; tone: AkTone } {
  const i = v.lastIndexOf('|');
  if (i < 0) return { label: v, tone: 'n' };
  const t = v.slice(i + 1);
  return { label: v.slice(0, i), tone: isTone(t) ? t : 'n' };
}

export function StatusChip({ label, tone = 'n' }: { label: string; tone?: AkTone }) {
  const [bg, fg, dot] = AK_TONE[tone];
  return (
    <span className="ak-st" style={{ background: bg, color: fg }}>
      <i style={{ background: dot }} aria-hidden />
      {label}
    </span>
  );
}

/** Couleur d'accent d'un indicateur selon son ton (vide = marque). */
export function toneAccent(tone: string): string {
  return isTone(tone) ? AK_TONE[tone][2] : 'var(--brand)';
}

export function Eyebrow({ children }: { children: ReactNode }) {
  return <div className="ak-eyebrow">{children}</div>;
}

export function ViewTabs<K extends string>({
  views, value, onChange, note, soft,
}: {
  views: { k: K; label: string; n?: number | string; icon?: ReactNode }[];
  value: K;
  onChange: (k: K) => void;
  note?: ReactNode;
  soft?: boolean;
}) {
  return (
    <div className={`ak-views${soft ? ' ak-views--soft' : ''} ak-noprint`} role="tablist">
      {views.map((v) => (
        <button key={v.k} role="tab" aria-selected={v.k === value} className="ak-view" onClick={() => onChange(v.k)}>
          {v.icon}
          {v.label}
          {v.n !== undefined && v.n !== '' && <span className="ak-view__n">{v.n}</span>}
        </button>
      ))}
      {note && <span className="ak-views__note">{note}</span>}
    </div>
  );
}

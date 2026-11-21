import { useEffect, useMemo, useRef, useState } from 'react';
import { Calendar, Home, Search, X, LayoutGrid } from 'lucide-react';
import type { NavChapter } from '../data/nav.ts';
import { Icon } from './Icon.tsx';

/** Sommaire plein écran « Mosaïque » : 10 chapitres, recherche par code transaction ou libellé. */
export function Sommaire({
  chapters, current, onGo, onClose, user, siteSub, today,
}: {
  chapters: NavChapter[];
  current: string;
  onGo: (id: string) => void;
  onClose: () => void;
  user: { name: string; initials: string; space: string };
  siteSub: string;
  today: string;
}) {
  const [q, setQ] = useState('');
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => { input.current?.focus(); }, []);

  const hq = q.trim().toUpperCase();
  const toc = useMemo(
    () =>
      chapters
        .map((ch) => ({
          ...ch,
          items: ch.items.filter((it) => !hq || it.code.startsWith(hq) || it.label.toUpperCase().includes(hq)),
        }))
        .filter((ch) => ch.items.length > 0),
    [chapters, hq],
  );
  const first = hq ? toc[0]?.items[0] : undefined;

  return (
    <div className="ak-toc" role="dialog" aria-modal="true" aria-label="Sommaire">
      <div className="ak-toc__top">
        <div className="ak-toc__brand">
          <img src="/brand/keystone_hn.svg" alt="Atlas Keystone, an Atlas Studio company" />
          <div>{siteSub}</div>
        </div>
        <button className="ak-chip-btn" onClick={() => onGo('my-space')} style={{ marginLeft: 6 }}>
          <Home size={14} aria-hidden /> Mon espace
        </button>
        <label className="ak-toc__search">
          <Search size={15} aria-hidden />
          <input
            ref={input}
            value={q}
            maxLength={60}
            onChange={(e) => setQ(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && first) onGo(first.id);
            }}
            placeholder="Code, écran, OT, actif, tiers"
            aria-label="Rechercher un écran ou un code transaction"
          />
        </label>
        <div className="ak-chip-info">
          <Calendar size={13} aria-hidden /> Situation au
          <span className="ak-mono" style={{ fontSize: 13, color: 'var(--ink)', fontWeight: 500 }}>{today}</span>
        </div>
        <div style={{ flex: 'none', display: 'flex', alignItems: 'center', gap: 10 }}>
          <span className="ak-eyebrow" style={{ fontSize: 10 }}>Échap</span>
          <span style={{ fontSize: 13, fontWeight: 500 }}>Fermer</span>
          <button className="ak-close" onClick={onClose} title="Fermer" aria-label="Fermer">
            <X size={15} aria-hidden />
          </button>
        </div>
      </div>

      <div className="ak-toc__body" style={{ borderTop: '1px solid var(--line)' }}>
        <div className="ak-toc__grid">
          {toc.map((ch) => {
            const here = ch.items.some((it) => it.id === current);
            const alerts = ch.items.reduce((n, it) => n + (it.badge ?? 0), 0);
            return (
              <section className="ak-ch" key={ch.no} aria-label={ch.title}>
                <span
                  className="ak-ch__seg"
                  style={{ width: here ? '100%' : 28, background: here ? 'var(--brand)' : 'var(--ink)' }}
                />
                <div className="ak-ch__head">
                  <span className="ak-ch__no">{ch.no}</span>
                  <span style={{ color: here ? 'var(--brand)' : 'var(--ink-2)', display: 'inline-flex' }}>
                    <Icon name={ch.icon} />
                  </span>
                  <span className="ak-ch__cnt">{ch.items.length}</span>
                  {alerts > 0 && <span className="ak-ch__alerts" title="Alertes">{alerts}</span>}
                </div>
                <div className="ak-ch__title">{ch.title}</div>
                <div className="ak-ch__items">
                  {ch.items.map((it) => (
                    <button
                      key={it.id}
                      className="ak-ch__item"
                      aria-current={it.id === current ? 'page' : undefined}
                      data-kbd={first?.id === it.id}
                      onClick={() => onGo(it.id)}
                    >
                      <span style={{ flex: 1, minWidth: 0 }}>{it.label}</span>
                      {hq && <code>{it.code}</code>}
                      {it.badge ? <span className="ak-ch__badge">{it.badge}</span> : null}
                    </button>
                  ))}
                </div>
              </section>
            );
          })}
          {toc.length === 0 && (
            <div className="ak-empty" style={{ gridColumn: '1 / -1' }}>
              <strong>Aucun écran ne correspond</strong>
              <span>Essayez un code transaction (OT, PTW, CRP) ou un libellé.</span>
            </div>
          )}
        </div>
      </div>

      <div className="ak-toc__foot">
        <span className="ak-dot-av">{user.initials}</span>
        <span>
          <strong style={{ fontWeight: 600 }}>{user.name}</strong>, espace{' '}
          <button className="ak-link" style={{ fontSize: 13 }} onClick={() => onGo('my-space')}>{user.space}</button>
        </span>
        <div className="ak-keys"><span>Ctrl K Sommaire</span><span>Entrée Ouvrir</span><span>Échap Fermer</span></div>
        <button className="ak-btn-text" style={{ marginLeft: 14, color: 'var(--brand-ink)', fontWeight: 500 }} onClick={onClose}>
          <LayoutGrid size={13} aria-hidden /> Applications
        </button>
      </div>
    </div>
  );
}

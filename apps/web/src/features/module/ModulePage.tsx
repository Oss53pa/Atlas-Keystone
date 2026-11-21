import { useMemo, useState, type ReactNode } from 'react';
import { Download, LayoutDashboard, MonitorDot, Search, Sparkles, Table2 } from 'lucide-react';
import { StatusChip, ViewTabs, parseStatus, toneAccent, AK_TONE, isTone, type AkTone } from '@keystone/ui';
import type { ColType, ModuleDef } from '../../data/modules.ts';

type View = 'live' | 'dash' | 'data';

interface Col { label: string; type: ColType }

function parseCols(c: string[]): Col[] {
  return c.map((s) => {
    const i = s.lastIndexOf(':');
    return { label: s.slice(0, i), type: s.slice(i + 1) as ColType };
  });
}

/** Neutralise une cellule pour l'export CSV (injection de formule). */
function csvCell(v: string): string {
  const safe = /^[=+\-@\t\r]/.test(v) ? `'${v}` : v;
  return `"${safe.replace(/"/g, '""')}"`;
}

export function exportCsv(name: string, cols: Col[], rows: string[][]) {
  const lines = [cols.map((c) => csvCell(c.label)).join(';'), ...rows.map((r) => r.map((v, i) => csvCell(cols[i]?.type === 'st' ? parseStatus(v).label : v)).join(';'))];
  const blob = new Blob(['﻿' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `${name.replace(/[^a-z0-9-]+/gi, '-')}.csv`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

/**
 * Page module générique de la refonte v4 : vue « Tableau de bord » (indicateurs, synthèse, proposition PROPH3T)
 * et vue « Données » (onglets de statut, recherche, tableau typé, panneau de sélection).
 * Si un écran opérationnel existant (données Supabase) est fourni, il est proposé en vue « Exploitation ».
 */
export function ModulePage({
  id, def, live, liveFirst = true, onPrimary, onToast,
}: {
  id: string;
  def: ModuleDef;
  live?: ReactNode;
  /** Ouvrir d'abord la vue Exploitation (vrai si le serveur est configuré). */
  liveFirst?: boolean;
  onPrimary: () => void;
  onToast: (m: string) => void;
}) {
  const cols = useMemo(() => parseCols(def.c), [def]);
  const stCol = cols.findIndex((c) => c.type === 'st');
  const mainCol = cols.findIndex((c) => c.type === 'main');
  const [view, setView] = useState<View>(live && liveFirst ? 'live' : 'dash');
  const [tab, setTab] = useState('all');
  const [q, setQ] = useState('');
  const [sel, setSel] = useState<number | null>(0);
  const [propHidden, setPropHidden] = useState(false);

  const stats = useMemo(() => {
    const m = new Map<string, { n: number; tone: AkTone }>();
    if (stCol >= 0) for (const r of def.r) {
      const s = parseStatus(r[stCol]);
      const cur = m.get(s.label);
      m.set(s.label, { n: (cur?.n ?? 0) + 1, tone: s.tone });
    }
    return [...m.entries()].map(([l, v]) => ({ l, ...v }));
  }, [def, stCol]);

  const needle = q.trim().toLowerCase();
  const vis = def.r
    .map((r, i) => ({ r, i }))
    .filter(({ r }) => tab === 'all' || (stCol >= 0 && parseStatus(r[stCol]).label === tab))
    .filter(({ r }) => !needle || r.some((v) => v.toLowerCase().includes(needle)));
  const selRow = sel !== null ? def.r[sel] : undefined;

  const views: { k: View; label: string; n?: number; icon: ReactNode }[] = [
    ...(live ? [{ k: 'live' as const, label: 'Exploitation', icon: <MonitorDot size={15} aria-hidden /> }] : []),
    { k: 'dash', label: 'Tableau de bord', icon: <LayoutDashboard size={15} aria-hidden /> },
    { k: 'data', label: 'Données', n: def.r.length, icon: <Table2 size={15} aria-hidden /> },
  ];
  const note = view === 'live' ? 'Données en temps réel' : view === 'dash' ? 'Situation consolidée, données de démonstration' : `${vis.length} enregistrements affichés sur ${def.r.length}`;

  return (
    <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column', gap: 14 }}>
      <ViewTabs views={views} value={view} onChange={setView} note={note} />

      {view === 'live' && <div className="ak-scroll ak-live" style={{ flex: 1, minHeight: 0, paddingRight: 4 }}>{live}</div>}

      {view === 'dash' && (
        <div className="ak-scroll" style={{ flex: 1, minHeight: 0, paddingRight: 4, display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div className="ak-kpis">
            {def.k.map(([label, value, unit, cmp, tone]) => {
              const t = isTone(tone) ? AK_TONE[tone] : null;
              return (
                <div className="ak-card ak-kpi" key={label}>
                  <span className="ak-kpi__accent" style={{ background: tone ? toneAccent(tone) : 'transparent' }} />
                  <span className="ak-kpi__label">{label}</span>
                  <div><span className="ak-kpi__value" style={{ fontSize: value.length > 9 ? 22 : 30 }}>{value}</span>{unit && <span className="ak-kpi__unit">{unit}</span>}</div>
                  <div style={{ minHeight: 20 }}>
                    {cmp && <span className="ak-kpi__cmp" style={{ background: t ? t[0] : 'var(--line-soft)', color: t ? t[1] : 'var(--ink-2)' }}>{cmp}</span>}
                  </div>
                </div>
              );
            })}
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0,2fr) minmax(0,1fr)', gap: 14 }}>
            <div className="ak-card" style={{ padding: '16px 18px' }}>
              <div style={{ fontSize: 14, fontWeight: 600, letterSpacing: '-.01em' }}>Répartition par statut</div>
              <div style={{ marginTop: 2, fontSize: 12, color: 'var(--ink-3)' }}>{def.r.length} enregistrements suivis</div>
              <div style={{ display: 'flex', height: 8, marginTop: 14, background: 'var(--line-soft)' }} aria-hidden>
                {stats.map((s) => <span key={s.l} style={{ width: `${(s.n / Math.max(1, def.r.length)) * 100}%`, background: AK_TONE[s.tone][2] }} />)}
              </div>
              <div style={{ marginTop: 12, display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {stats.map((s) => (
                  <button key={s.l} className="ak-btn-text" style={{ padding: 0, height: 'auto' }} onClick={() => { setTab(s.l); setView('data'); }}>
                    <StatusChip label={`${s.l} · ${s.n}`} tone={s.tone} />
                  </button>
                ))}
              </div>
            </div>
            {!propHidden && (
              <div className="ak-banner" style={{ flexDirection: 'column', gap: 0 }}>
                <div className="ak-eyebrow" style={{ color: 'var(--brand-ink)', display: 'flex', alignItems: 'center', gap: 8, letterSpacing: '.14em' }}>
                  <Sparkles size={12} aria-hidden /> Proposition de PROPH3T
                </div>
                <p style={{ marginTop: 8 }}>{def.p}</p>
                <p style={{ marginTop: 6, fontSize: 12, color: 'var(--ink-3)' }}>Proposition uniquement : la décision reste humaine.</p>
                <div style={{ marginTop: 10, display: 'flex', gap: 12 }}>
                  <button className="ak-link" onClick={onPrimary}>Appliquer</button>
                  <button className="ak-link" style={{ color: 'var(--ink-3)' }} onClick={() => setPropHidden(true)}>Ignorer</button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {view === 'data' && (
        <>
          <ViewTabs
            soft
            views={[{ k: 'all', label: 'Tous', n: def.r.length }, ...stats.map((s) => ({ k: s.l, label: s.l, n: s.n }))]}
            value={tab}
            onChange={(k) => { setTab(k); setSel(null); }}
          />
          <div className="ak-split">
            <div className="ak-scroll" style={{ minHeight: 0, paddingRight: 4 }}>
              <div className="ak-card">
                <div className="ak-toolbar ak-noprint">
                  <label className="ak-field">
                    <Search size={14} aria-hidden />
                    <input value={q} maxLength={80} onChange={(e) => setQ(e.target.value)} placeholder="Rechercher une référence, un site, un libellé" aria-label="Rechercher dans le tableau" />
                  </label>
                  <span style={{ marginLeft: 'auto', fontSize: 12, color: 'var(--ink-3)' }}>
                    <span className="ak-mono" style={{ color: 'var(--ink)' }}>{vis.length}</span> sur <span className="ak-mono">{def.r.length}</span>
                  </span>
                  <button className="ak-sq" title="Exporter" aria-label="Exporter en CSV" onClick={() => { exportCsv(id, cols, vis.map((v) => v.r)); onToast('Export CSV généré'); }}>
                    <Download size={15} aria-hidden />
                  </button>
                </div>
                <div style={{ overflowX: 'auto' }}>
                  <table className="ak-table">
                    <thead>
                      <tr>{cols.map((c) => <th key={c.label} style={{ textAlign: c.type === 'num' ? 'right' : 'left' }}>{c.label}</th>)}</tr>
                    </thead>
                    <tbody>
                      {vis.map(({ r, i }) => (
                        <tr key={i} aria-selected={sel === i} onClick={() => setSel(i)} tabIndex={0} onKeyDown={(e) => e.key === 'Enter' && setSel(i)}>
                          {r.map((v, j) => {
                            const t = cols[j]?.type ?? 'txt';
                            if (t === 'st') { const s = parseStatus(v); return <td key={j}><StatusChip label={s.label} tone={s.tone} /></td>; }
                            return <td key={j} className={`is-${t}`}>{v}</td>;
                          })}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {vis.length === 0 && (
                  <div className="ak-empty"><strong>Aucun élément ne correspond</strong><span>Modifiez la recherche ou l’onglet de statut.</span></div>
                )}
              </div>
            </div>

            <aside className="ak-card ak-aside" aria-label="Sélection">
              {selRow ? (
                <>
                  <div className="ak-aside__head">
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10 }}>
                      <span className="ak-eyebrow" style={{ letterSpacing: '.14em' }}>Sélection</span>
                      <span className="ak-mono" style={{ fontSize: 12 }}>{selRow[0]}</span>
                    </div>
                    <div className="ak-aside__title">{mainCol >= 0 ? selRow[mainCol] : selRow[1]}</div>
                    {stCol >= 0 && (() => { const s = parseStatus(selRow[stCol]); return <div style={{ marginTop: 10 }}><StatusChip label={s.label} tone={s.tone} /></div>; })()}
                  </div>
                  <div className="ak-facts">
                    {cols.map((c, j) => ({ c, v: selRow[j] }))
                      .filter((x) => x.c.type !== 'ref' && x.c.type !== 'main' && x.c.type !== 'st')
                      .map((x) => (
                        <div className="ak-fact" key={x.c.label}>
                          <div>{x.c.label}</div>
                          <div className={x.c.type === 'num' || x.c.type === 'date' ? 'ak-mono' : undefined}>{x.v}</div>
                        </div>
                      ))}
                  </div>
                  <div className="ak-aside__actions">
                    <button className="ak-btn-brand ak-btn-brand--lg" onClick={onPrimary}>{def.a}</button>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                      <button className="ak-btn-line ak-btn-line--lg" style={{ justifyContent: 'center' }} onClick={() => onToast(`Fiche ${selRow[0]} : disponible au prochain lot`)}>Ouvrir la fiche</button>
                      <button className="ak-btn-line ak-btn-line--lg" style={{ justifyContent: 'center', borderColor: 'var(--line-strong)' }} onClick={() => onToast(`Affectation de ${selRow[0]} : disponible au prochain lot`)}>Affecter</button>
                    </div>
                  </div>
                </>
              ) : (
                <div className="ak-empty" style={{ margin: 'auto' }}><strong>Aucune sélection</strong><span>Choisissez une ligne du tableau.</span></div>
              )}
            </aside>
          </div>
        </>
      )}
    </div>
  );
}

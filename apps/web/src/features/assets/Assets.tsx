import { useEffect, useMemo, useState } from 'react';
import {
  Boxes, HeartPulse, ShieldAlert, Wallet, RefreshCw, AlertTriangle, CheckCircle2, Wrench, X, Gauge, Timer, Factory, CalendarClock, Sparkles, BarChart3, Library,
} from 'lucide-react';
import { Card, StatBig, RingGauge, TabBar, ProgressRows } from '@keystone/ui';
import { money, format } from '@keystone/domain';
import type { AssetRow, AssetCriticality, FmeaRow, FmeaClass, FailureFamily } from '@keystone/domain/db/keystone';
import { fetchAssets, fetchFmea, createFmeaAction, fetchFailureFamilies, fmeaFromLibrary } from '../../data/assets.ts';
import { ParetoPanel } from './ParetoPanel.tsx';

const fcfa = (n: number) => format(money(n, 'XOF'));
const CRIT: Record<AssetCriticality, { label: string; level: 'critical' | 'high' | 'medium' | 'low' }> = {
  safety_critical: { label: 'Sécurité', level: 'critical' },
  high: { label: 'Haute', level: 'high' },
  medium: { label: 'Moyenne', level: 'medium' },
  low: { label: 'Basse', level: 'low' },
};
const CLASS: Record<FmeaClass, { label: string; color: string; bg: string }> = {
  critical: { label: 'Critique', color: '#8E1E22', bg: 'var(--ks-critical-100)' },
  high: { label: 'Élevée', color: '#8A3A07', bg: 'var(--ks-high-100)' },
  medium: { label: 'Modérée', color: 'var(--ks-amber-700)', bg: 'var(--ks-amber-100)' },
  low: { label: 'Acceptable', color: '#2C6230', bg: 'var(--ks-low-100)' },
};
const ACTION: Record<string, string> = { none: 'À définir', planned: 'Planifiée', in_progress: 'En cours', done: 'Réalisée' };
const DRIVER: Record<string, string> = { age: 'Vieillissement', pannes: 'Pannes 12 mois', amdec: 'Risque AMDEC ouvert', prediction: 'RUL prédite', ot_ouverts: 'OT ouverts' };
const healthColor = (h: number) => (h >= 75 ? 'var(--ks-low)' : h >= 55 ? 'var(--ks-amber)' : h >= 35 ? 'var(--ks-high)' : 'var(--ks-critical)');
const year = (s: string | null) => (s ? new Date(s).getFullYear() : '—');

export function Assets() {
  const [assets, setAssets] = useState<AssetRow[] | null>(null);
  const [fmea, setFmea] = useState<FmeaRow[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [tab, setTab] = useState('parc');
  const [sel, setSel] = useState<AssetRow | null>(null);
  const [cell, setCell] = useState<[number, number] | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  function load() {
    fetchAssets().then(setAssets).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
    fetchFmea().then(setFmea).catch(() => {});
  }
  useEffect(load, []);

  async function planAction(id: string) {
    setBusy(id);
    try {
      const r = await createFmeaAction(id);
      setToast(`OT préventif ${r.ref} créé en brouillon — à planifier dans la GMAO`);
      setTimeout(() => setToast(null), 4500);
      load();
    } catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(null); }
  }

  const list = assets ?? [];
  const items = fmea ?? [];
  const avgHealth = list.length ? Math.round(list.reduce((s, a) => s + a.health, 0) / list.length) : 0;
  const critical = items.filter((f) => f.class === 'critical' && f.action_status !== 'done').length;
  const replacement = list.reduce((s, a) => s + (a.replacement_value ?? 0), 0);
  const endOfLife = list.filter((a) => a.age_years != null && a.design_life_years && a.age_years / a.design_life_years >= 0.8).length;

  // Matrice G × O par tranches de 2 (5×5)
  const matrix = useMemo(() => {
    const m: FmeaRow[][][] = Array.from({ length: 5 }, () => Array.from({ length: 5 }, () => []));
    for (const f of items) m[Math.min(4, Math.floor((f.severity - 1) / 2))][Math.min(4, Math.floor((f.occurrence - 1) / 2))].push(f);
    return m;
  }, [items]);
  const shown = cell ? matrix[cell[0]][cell[1]] : items;

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Hard FM · Patrimoine technique</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Actifs &amp; composants</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">indice de santé explicable · AMDEC IEC 60812 · fiabilité ISO 14224</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={load} style={{ alignSelf: 'end' }}><RefreshCw size={15} /> Rafraîchir</button>
      </header>

      {toast && <div className="ka-toast"><CheckCircle2 size={16} /> {toast}</div>}
      {err && <Card><div style={{ textAlign: 'center', padding: 20 }}><AlertTriangle color="var(--ks-high)" /><div className="ks-mono ks-faint" style={{ fontSize: 12, marginTop: 8 }}>{err}</div></div></Card>}

      {assets && (
        <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
          <Card><StatBig label="Parc suivi" icon={<Boxes size={15} />} value={list.length} sub={`${list.filter((a) => a.criticality === 'safety_critical').length} équipements de sécurité`} /></Card>
          <Card><StatBig label="Santé moyenne du parc" icon={<HeartPulse size={15} />} accent={healthColor(avgHealth)} value={avgHealth} unit="/100" sub={`${endOfLife} actif(s) > 80 % de durée de vie`} /></Card>
          <Card><StatBig label="Risques AMDEC critiques" icon={<ShieldAlert size={15} />} accent={critical ? 'var(--ks-critical)' : 'var(--ks-low)'} value={critical} sub={`${items.length} modes analysés`} /></Card>
          <Card><StatBig label="Valeur de remplacement" icon={<Wallet size={15} />} value={fcfa(replacement)} sub="base plan CAPEX" /></Card>
        </div>
      )}

      <div style={{ marginBottom: 16 }}>
        <TabBar
          tabs={[
            { id: 'parc', label: 'Parc & santé', icon: <HeartPulse size={15} /> },
            { id: 'amdec', label: `AMDEC · ${items.length}`, icon: <ShieldAlert size={15} /> },
            { id: 'pareto', label: 'Pareto des pannes', icon: <BarChart3 size={15} /> },
          ]}
          active={tab}
          onChange={setTab}
        />
      </div>

      {tab === 'parc' && assets && (
        <div className="ka-grid ks-reveal">
          {list.map((a) => {
            const c = CRIT[a.criticality];
            const lifePct = a.age_years != null && a.design_life_years ? Math.min(100, (a.age_years / a.design_life_years) * 100) : null;
            return (
              <button key={a.id} className="ka-asset" onClick={() => setSel(a)}>
                <div className="ka-asset__top">
                  <div style={{ minWidth: 0 }}>
                    <div className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{a.tag} · {a.workcenter ?? a.category}</div>
                    <div className="ka-asset__name">{a.name}</div>
                    <div className="ks-faint" style={{ fontSize: 12 }}>{a.location ?? '—'}{a.site ? ` · ${a.site}` : ''}</div>
                  </div>
                  <RingGauge value={a.health} size={58} stroke={6} color={healthColor(a.health)} />
                </div>
                <div className="ka-asset__meta">
                  <span className={`ks-risk ks-risk--${c.level}`}>{c.label}</span>
                  {a.status !== 'operational' && <span className="ks-risk ks-risk--high">{a.status === 'degraded' ? 'Dégradé' : a.status}</span>}
                  {a.max_rpn != null && <span className="ks-pill">RPN {a.max_rpn}</span>}
                  {a.prediction_rul_days != null && <span className="ks-pill" style={{ color: 'var(--ks-critical)' }}><Sparkles size={11} /> RUL {Math.round(a.prediction_rul_days)} j</span>}
                </div>
                {lifePct != null && (
                  <div className="ka-life">
                    <div className="ka-life__head"><span>Cycle de vie</span><span className="ks-mono">{a.age_years} / {a.design_life_years} ans</span></div>
                    <div className="ka-life__track"><div style={{ width: `${lifePct}%`, background: lifePct >= 80 ? 'var(--ks-high)' : 'var(--ks-ink-2)' }} /></div>
                  </div>
                )}
              </button>
            );
          })}
        </div>
      )}

      {tab === 'amdec' && fmea && (
        <div className="kt-dash kt-dash--12 ks-reveal">
          <Card>
            <div className="kt-cardtitle">Matrice de criticité</div>
            <div className="kt-cardsub">Gravité × Occurrence · cliquez une case pour filtrer</div>
            <div className="ka-matrix">
              <div className="ka-matrix__ylab">Gravité →</div>
              <div className="ka-matrix__grid">
                {[4, 3, 2, 1, 0].map((g) =>
                  [0, 1, 2, 3, 4].map((o) => {
                    const n = matrix[g][o].length;
                    const score = (g + 1) * (o + 1);
                    const tone = g >= 4 || score >= 15 ? 'critical' : score >= 9 ? 'high' : score >= 4 ? 'medium' : 'low';
                    const active = cell?.[0] === g && cell?.[1] === o;
                    return (
                      <button key={`${g}-${o}`} className={`ka-cell ka-cell--${tone}${active ? ' ka-cell--on' : ''}`}
                        onClick={() => setCell(active ? null : [g, o])} aria-label={`Gravité ${g * 2 + 1}-${g * 2 + 2}, occurrence ${o * 2 + 1}-${o * 2 + 2}`}>
                        {n > 0 && <span className="ka-cell__n">{n}</span>}
                      </button>
                    );
                  }),
                )}
              </div>
              <div className="ka-matrix__xlab">Occurrence →</div>
            </div>
            <div className="ks-faint" style={{ fontSize: 12, marginTop: 14, lineHeight: 1.55 }}>
              RPN = G × O × D. Critique si RPN ≥ 200 <b>ou gravité ≥ 9</b> (sécurité des personnes), élevée ≥ 120, modérée ≥ 60.
            </div>
          </Card>

          <Card pad={false}>
            <div style={{ padding: '16px 20px 6px', display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
              <div className="kt-cardtitle">Modes de défaillance {cell && <span className="ks-faint" style={{ fontWeight: 500 }}>· filtre actif</span>}</div>
              {cell && <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => setCell(null)}>Tout afficher</button>}
            </div>
            <div style={{ overflowX: 'auto' }}>
              <table className="ks-table">
                <thead><tr><th>Actif · composant</th><th>Effet / cause</th><th>G·O·D</th><th>RPN</th><th>Action</th><th></th></tr></thead>
                <tbody>
                  {shown.map((f) => {
                    const k = CLASS[f.class];
                    return (
                      <tr key={f.id}>
                        <td><div className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{f.asset_tag}{f.failure_code ? ` · ${f.failure_code}` : ''}</div><div style={{ fontWeight: 600 }}>{f.component}</div></td>
                        <td style={{ fontSize: 12.5, maxWidth: 300 }}><div>{f.effect}</div><div className="ks-faint">{f.cause}</div></td>
                        <td className="ks-mono" style={{ fontSize: 12.5, whiteSpace: 'nowrap' }}>{f.severity}·{f.occurrence}·{f.detection}</td>
                        <td>
                          <span className="ks-wo-pill" style={{ color: k.color, background: k.bg }}>{f.rpn} · {k.label}</span>
                          {f.rev_rpn != null && <div className="ks-mono ks-faint" style={{ fontSize: 11, marginTop: 4 }}>→ {f.rev_rpn} après action</div>}
                        </td>
                        <td style={{ fontSize: 12.5, maxWidth: 240 }}>
                          <div>{f.action ?? <span className="ks-faint">Aucune action</span>}</div>
                          <div className="ks-faint" style={{ fontSize: 11.5 }}>{ACTION[f.action_status]}{f.action_wo_ref ? ` · ${f.action_wo_ref}` : ''}</div>
                        </td>
                        <td style={{ textAlign: 'right' }}>
                          {!f.action_wo_ref && f.action_status !== 'done' && f.class !== 'low' && (
                            <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={busy === f.id} onClick={() => planAction(f.id)}>
                              {busy === f.id ? '…' : <><Wrench size={13} /> Créer l’OT</>}
                            </button>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                  {shown.length === 0 && <tr><td colSpan={6} className="ks-dim" style={{ textAlign: 'center', padding: 30 }}>Aucun mode dans cette case.</td></tr>}
                </tbody>
              </table>
            </div>
          </Card>
        </div>
      )}

      {tab === 'pareto' && <ParetoPanel />}

      {sel && (
        <AssetDrawer
          a={sel}
          fmea={items.filter((f) => f.asset_id === sel.id)}
          onClose={() => setSel(null)}
          onSeeded={(n) => { setToast(n ? `${n} mode(s) de défaillance ajoutés depuis la bibliothèque — cotations à confirmer` : 'Tous les modes de cette famille sont déjà analysés.'); setTimeout(() => setToast(null), 4500); load(); }}
        />
      )}
    </div>
  );
}

function AssetDrawer({ a, fmea, onClose, onSeeded }: { a: AssetRow; fmea: FmeaRow[]; onClose: () => void; onSeeded: (n: number) => void }) {
  const [families, setFamilies] = useState<FailureFamily[]>([]);
  const [family, setFamily] = useState('');
  const [seeding, setSeeding] = useState(false);
  const [seedErr, setSeedErr] = useState<string | null>(null);
  useEffect(() => { fetchFailureFamilies().then((f) => { setFamilies(f); setFamily(f[0]?.family ?? ''); }).catch(() => {}); }, []);
  async function seed() {
    setSeeding(true); setSeedErr(null);
    try { const r = await fmeaFromLibrary(a.id, family); onSeeded(r.created); } catch (e) { setSeedErr(e instanceof Error ? e.message : String(e)); } finally { setSeeding(false); }
  }
  useEffect(() => {
    const k = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', k);
    return () => window.removeEventListener('keydown', k);
  }, [onClose]);
  const drivers = Object.entries(a.health_drivers ?? {}).filter(([, v]) => v > 0).sort((x, y) => y[1] - x[1]);
  const warrantyOk = a.warranty_until ? new Date(a.warranty_until) > new Date() : false;
  return (
    <div className="ka-overlay" onClick={onClose}>
      <aside className="ka-drawer" onClick={(e) => e.stopPropagation()} role="dialog" aria-label={a.name}>
        <div className="ka-drawer__head">
          <div>
            <div className="ks-mono ks-faint" style={{ fontSize: 12 }}>{a.tag} · {a.category}</div>
            <h2 style={{ fontSize: 22, fontWeight: 800, letterSpacing: '-.02em', margin: '4px 0 2px' }}>{a.name}</h2>
            <div className="ks-faint" style={{ fontSize: 12.5 }}>{[a.manufacturer, a.model].filter(Boolean).join(' · ') || '—'}</div>
          </div>
          <button className="ks-icon-btn" aria-label="Fermer" onClick={onClose}><X size={17} /></button>
        </div>

        <div className="ka-drawer__health">
          <RingGauge value={a.health} size={96} stroke={8} color={healthColor(a.health)} />
          <div style={{ flex: 1 }}>
            <div className="ks-eyebrow">Indice de santé</div>
            <div style={{ fontSize: 13, lineHeight: 1.5, marginTop: 4 }}>
              {drivers.length === 0 ? 'Aucun facteur de dégradation détecté.' : <>Principal facteur : <b>{DRIVER[drivers[0][0]] ?? drivers[0][0]}</b> (−{drivers[0][1]} pts).</>}
            </div>
          </div>
        </div>
        {drivers.length > 0 && (
          <div style={{ marginBottom: 22 }}>
            <ProgressRows rows={drivers.map(([k, v]) => ({ label: DRIVER[k] ?? k, value: v, right: `−${v}`, color: 'var(--ks-high)' }))} max={30} />
          </div>
        )}

        <div className="ka-facts">
          <Fact icon={<Gauge size={14} />} label="MTBF (12 mois)" value={a.mtbf_h != null ? `${a.mtbf_h} h` : 'Aucune panne'} />
          <Fact icon={<Timer size={14} />} label="MTTR" value={a.mttr_h != null ? `${a.mttr_h} h` : '—'} />
          <Fact icon={<Wrench size={14} />} label="OT ouverts" value={String(a.wo_open)} />
          <Fact icon={<AlertTriangle size={14} />} label="Arrêts 12 mois" value={`${a.downtime_12m_h} h`} />
          <Fact icon={<Factory size={14} />} label="Mise en service" value={String(year(a.install_date))} />
          <Fact icon={<CalendarClock size={14} />} label="Garantie" value={a.warranty_until ? (warrantyOk ? `jusqu’au ${new Date(a.warranty_until).toLocaleDateString('fr-FR')}` : 'Échue') : '—'} />
          <Fact icon={<Wallet size={14} />} label="Coût maintenance 12 m" value={fcfa(a.cost_12m)} />
          <Fact icon={<Wallet size={14} />} label="Valeur de remplacement" value={a.replacement_value ? fcfa(a.replacement_value) : '—'} />
        </div>

        <div className="kt-section-h" style={{ marginTop: 22 }}><h2 style={{ fontSize: 15 }}>AMDEC de l’équipement</h2><span className="kt-count">{fmea.length} modes</span></div>
        {fmea.length === 0 && <div className="ks-dim" style={{ fontSize: 13 }}>Aucune analyse AMDEC.</div>}
        {families.length > 0 && (
          <div className="ka-seed">
            <Library size={15} style={{ color: 'var(--ks-amber-700)', flexShrink: 0 }} />
            <select className="ka-select" value={family} onChange={(e) => setFamily(e.target.value)} aria-label="Famille d’équipement">
              {families.map((f) => <option key={f.family} value={f.family}>{f.family_label} · {f.modes} modes</option>)}
            </select>
            <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={seeding || !family} onClick={seed}>{seeding ? '…' : 'Initialiser l’AMDEC'}</button>
          </div>
        )}
        {seedErr && <div className="ks-mono" style={{ color: 'var(--ks-critical)', fontSize: 12, marginBottom: 8 }}>{seedErr}</div>}
        {fmea.map((f) => (
          <div key={f.id} className="ka-fmea">
            <span className="ks-wo-pill" style={{ color: CLASS[f.class].color, background: CLASS[f.class].bg, minWidth: 56, justifyContent: 'center' }}>{f.rpn}</span>
            <div style={{ minWidth: 0 }}>
              <div style={{ fontWeight: 600, fontSize: 13.5 }}>{f.component}</div>
              <div className="ks-faint" style={{ fontSize: 12 }}>{f.effect}</div>
            </div>
          </div>
        ))}
      </aside>
    </div>
  );
}

function Fact({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="ka-fact">
      <div className="ka-fact__lbl">{icon} {label}</div>
      <div className="ka-fact__val">{value}</div>
    </div>
  );
}

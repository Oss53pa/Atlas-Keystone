import { useEffect, useMemo, useState } from 'react';
import {
  ClipboardCheck, Gauge, AlertOctagon, CalendarClock, RefreshCw, Play, X, Check, CheckCircle2, ShieldAlert, PenLine, Wrench, Timer, ListChecks,
} from 'lucide-react';
import { Card, StatBig, TabBar, RingGauge } from '@keystone/ui';
import type { InspectionRound, InspectionHistoryRow, NcRow, NcStatus, NcSeverity, QualitySummary, Checkpoint, InspectionResult } from '@keystone/domain/db/keystone';
import { fetchRounds, fetchInspectionHistory, fetchNcs, fetchQualitySummary, submitInspection, ncTransition } from '../../data/inspections.ts';

const DOMAIN: Record<string, string> = { technique: 'Technique', securite: 'Sécurité', proprete: 'Propreté', environnement: 'Environnement' };
const SEV: Record<NcSeverity, { label: string; risk: 'critical' | 'high' | 'medium' }> = {
  critical: { label: 'Critique', risk: 'critical' }, major: { label: 'Majeure', risk: 'high' }, minor: { label: 'Mineure', risk: 'medium' },
};
const COLS: { id: NcStatus; label: string }[] = [
  { id: 'open', label: 'Ouvertes' }, { id: 'in_progress', label: 'En traitement' }, { id: 'pending_validation', label: 'À valider' }, { id: 'closed', label: 'Clôturées' },
];
const scoreColor = (s: number | null) => (s == null ? 'var(--ks-ink-3)' : s >= 80 ? 'var(--ks-low)' : s >= 60 ? 'var(--ks-amber)' : 'var(--ks-critical)');
const dd = (s: string) => new Date(s).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' });

/** Même règle que keystone.checkpoint_ok() — évaluation locale pour le score en direct. */
function cpOk(cp: Checkpoint, v: unknown): boolean | null {
  if (v == null || v === '') return null;
  if (cp.type === 'boolean') return v === true;
  if (cp.type === 'numeric') { const x = Number(v); return (cp.min == null || x >= cp.min) && (cp.max == null || x <= cp.max); }
  if (cp.type === 'choice') return !(cp.fail_options ?? []).includes(String(v));
  return true;
}

export function Inspections() {
  const [tab, setTab] = useState('rounds');
  const [rounds, setRounds] = useState<InspectionRound[] | null>(null);
  const [hist, setHist] = useState<InspectionHistoryRow[] | null>(null);
  const [ncs, setNcs] = useState<NcRow[] | null>(null);
  const [sum, setSum] = useState<QualitySummary | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [running, setRunning] = useState<InspectionRound | null>(null);
  const [editing, setEditing] = useState<NcRow | null>(null);

  function load() {
    fetchRounds().then(setRounds).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
    fetchInspectionHistory().then(setHist).catch(() => {});
    fetchNcs().then(setNcs).catch(() => {});
    fetchQualitySummary().then(setSum).catch(() => {});
  }
  useEffect(load, []);
  const flash = (m: string) => { setToast(m); setTimeout(() => setToast(null), 5000); };

  async function move(nc: NcRow, action: 'start' | 'close' | 'reject') {
    setErr(null);
    try { await ncTransition(nc.id, action); flash(`${nc.ref} mise à jour`); load(); } catch (e) { setErr(e instanceof Error ? e.message : String(e)); }
  }

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">HSSE · Qualité terrain</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Inspections &amp; non-conformités</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">rondes typées · score pondéré · NC automatiques · ISO 9001 / 45001 §10.2</span>
          </div>
        </div>
        <button className="ks-btn ks-btn--ghost" onClick={load} style={{ alignSelf: 'end' }}><RefreshCw size={15} /> Rafraîchir</button>
      </header>

      {toast && <div className="ka-toast"><CheckCircle2 size={16} /> {toast}</div>}
      {err && (
        <div className="ka-toast" style={{ background: 'var(--ks-critical-100)', color: '#8E1E22' }}>
          <ShieldAlert size={16} /> <span className="ks-mono" style={{ fontSize: 12.5 }}>{err}</span>
          <button className="ks-icon-btn" style={{ marginLeft: 'auto' }} aria-label="Fermer" onClick={() => setErr(null)}><X size={14} /></button>
        </div>
      )}

      {sum && (
        <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
          <Card><StatBig label="Score moyen 30 j" icon={<Gauge size={15} />} accent={scoreColor(sum.score_30d)} value={sum.score_30d ?? '—'} unit="%" sub={`${sum.rounds_30d} rondes réalisées`} /></Card>
          <Card><StatBig label="Rondes en retard" icon={<CalendarClock size={15} />} accent={sum.rounds_overdue ? 'var(--ks-high)' : 'var(--ks-low)'} value={sum.rounds_overdue} sub="selon fréquence du modèle" /></Card>
          <Card><StatBig label="NC ouvertes" icon={<AlertOctagon size={15} />} accent={sum.nc_critical ? 'var(--ks-critical)' : undefined} value={sum.nc_open} sub={`${sum.nc_critical} critique(s) · ${sum.nc_overdue} en retard`} /></Card>
          <Card><StatBig label="NC clôturées dans les délais" icon={<Timer size={15} />} accent="var(--ks-low)" value={sum.nc_closed_on_time_pct ?? '—'} unit="%" sub="efficacité du traitement" /></Card>
        </div>
      )}

      <div style={{ marginBottom: 16 }}>
        <TabBar
          tabs={[
            { id: 'rounds', label: 'Rondes', icon: <ListChecks size={15} /> },
            { id: 'nc', label: `Non-conformités${sum ? ` · ${sum.nc_open}` : ''}`, icon: <AlertOctagon size={15} /> },
          ]}
          active={tab} onChange={setTab}
        />
      </div>

      {tab === 'rounds' && rounds && (
        <>
          <div className="ki-rounds ks-reveal">
            {rounds.map((r) => (
              <Card key={r.template_id}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
                  <div style={{ minWidth: 0 }}>
                    <div className="ks-eyebrow">{DOMAIN[r.domain]} · tous les {r.frequency_days} j</div>
                    <div style={{ fontWeight: 700, fontSize: 15, margin: '4px 0 2px' }}>{r.name}</div>
                    <div className="ks-faint" style={{ fontSize: 12.5 }}>{r.location ?? '—'}{r.asset_tag ? ` · ${r.asset_tag}` : ''} · {r.checkpoints.length} points</div>
                  </div>
                  <RingGauge value={r.last_score ?? 0} size={54} stroke={5} color={scoreColor(r.last_score)} label={r.last_score != null ? String(Math.round(r.last_score)) : '—'} />
                </div>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 16, gap: 10 }}>
                  <span style={{ fontSize: 12.5, fontWeight: 600, color: r.days_to_due < 0 ? 'var(--ks-critical)' : r.days_to_due === 0 ? 'var(--ks-amber-700)' : 'var(--ks-ink-2)' }}>
                    {r.days_to_due < 0 ? `En retard de ${-r.days_to_due} j` : r.days_to_due === 0 ? 'Due aujourd’hui' : `Prochaine dans ${r.days_to_due} j`}
                  </span>
                  <button className="ks-btn ks-btn--primary ks-btn--sm" onClick={() => setRunning(r)}><Play size={13} /> Lancer la ronde</button>
                </div>
              </Card>
            ))}
          </div>
          <div className="kt-section-h"><h2>Historique</h2><span className="kt-count">30 dernières rondes</span></div>
          <Card pad={false} className="ks-reveal">
            <div style={{ overflowX: 'auto' }}>
              <table className="ks-table">
                <thead><tr><th>Réf.</th><th>Ronde</th><th>Inspecteur</th><th>Score</th><th>Écarts</th><th>Date</th></tr></thead>
                <tbody>
                  {(hist ?? []).map((h) => (
                    <tr key={h.id}>
                      <td className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{h.ref}</td>
                      <td style={{ fontWeight: 600 }}>{h.template}</td>
                      <td style={{ fontSize: 12.5 }}>{h.inspector ?? '—'}</td>
                      <td><span className="ks-mono" style={{ fontWeight: 600, color: scoreColor(h.score) }}>{h.score != null ? `${h.score} %` : '—'}</span></td>
                      <td className="ks-mono" style={{ fontSize: 12.5, color: h.failed ? 'var(--ks-high)' : 'var(--ks-ink-3)' }}>{h.failed}</td>
                      <td className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{dd(h.completed_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </>
      )}

      {tab === 'nc' && ncs && (
        <div className="ki-board ks-reveal">
          {COLS.map((c) => {
            const list = ncs.filter((n) => n.status === c.id);
            return (
              <div key={c.id} className="ki-col">
                <div className="ki-col__head"><span>{c.label}</span><span className="ks-mono ks-faint">{list.length}</span></div>
                {list.map((n) => (
                  <div key={n.id} className={`ki-nc ki-nc--${n.severity}`}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                      <span className="ks-mono ks-faint" style={{ fontSize: 11 }}>{n.ref}</span>
                      <span className={`ks-risk ks-risk--${SEV[n.severity].risk}`}>{SEV[n.severity].label}</span>
                    </div>
                    <div style={{ fontWeight: 600, fontSize: 13.5, margin: '6px 0 3px' }}>{n.title}</div>
                    <div className="ks-faint" style={{ fontSize: 12 }}>{n.location ?? '—'}{n.asset_tag ? ` · ${n.asset_tag}` : ''}{n.observed_value ? ` · relevé ${n.observed_value}` : ''}</div>
                    {n.corrective_action && <div style={{ fontSize: 12, marginTop: 6, lineHeight: 1.45 }}><b>Action :</b> {n.corrective_action}</div>}
                    <div className="ki-nc__foot">
                      <span style={{ fontSize: 11.5, fontWeight: 600, color: n.overdue ? 'var(--ks-critical)' : 'var(--ks-ink-3)' }}>
                        {n.status === 'closed' ? 'Clôturée' : `${n.overdue ? 'Échue' : 'Échéance'} ${dd(n.due_date)}`}
                      </span>
                      {n.wo_ref && <span className="ks-pill"><Wrench size={11} /> {n.wo_ref}</span>}
                    </div>
                    {n.status !== 'closed' && n.status !== 'rejected' && (
                      <div style={{ display: 'flex', gap: 6, marginTop: 10, flexWrap: 'wrap' }}>
                        {n.status === 'open' && <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => move(n, 'start')}>Prendre en charge</button>}
                        {(n.status === 'open' || n.status === 'in_progress') && <button className="ks-btn ks-btn--ghost ks-btn--sm" onClick={() => setEditing(n)}><PenLine size={12} /> Traiter</button>}
                        {n.status === 'pending_validation' && (
                          <>
                            <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => move(n, 'reject')}>Renvoyer</button>
                            <button className="ks-btn ks-btn--primary ks-btn--sm" onClick={() => move(n, 'close')}><Check size={12} /> Clôturer</button>
                          </>
                        )}
                      </div>
                    )}
                  </div>
                ))}
                {list.length === 0 && <div className="ks-faint" style={{ fontSize: 12, padding: '10px 2px' }}>—</div>}
              </div>
            );
          })}
        </div>
      )}

      {running && (
        <RoundRunner
          round={running}
          onClose={() => setRunning(null)}
          onDone={(r) => {
            setRunning(null);
            flash(`${r.ref} enregistrée · score ${r.score ?? '—'} % · ${r.nc_created} NC ouverte(s)${r.wo_created ? ` · ${r.wo_created} OT correctif(s) en brouillon` : ''}`);
            if (r.nc_created) setTab('nc');
            load();
          }}
        />
      )}
      {editing && (
        <NcTreat nc={editing} onClose={() => setEditing(null)} onDone={() => { setEditing(null); flash(`${editing.ref} soumise à validation`); load(); }} />
      )}
    </div>
  );
}

function RoundRunner({ round, onClose, onDone }: { round: InspectionRound; onClose: () => void; onDone: (r: InspectionResult) => void }) {
  const [ans, setAns] = useState<Record<string, unknown>>({});
  const [signed, setSigned] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const live = useMemo(() => {
    let num = 0, den = 0, answered = 0, failed = 0;
    for (const cp of round.checkpoints) {
      const ok = cpOk(cp, ans[cp.key]);
      if (ok == null) continue;
      answered++;
      const w = cp.critical ? 3 : 1;
      den += w;
      if (ok) num += w; else failed++;
    }
    const required = round.checkpoints.filter((c) => c.required !== false).length;
    const reqDone = round.checkpoints.filter((c) => c.required !== false && cpOk(c, ans[c.key]) != null).length;
    return { score: den ? Math.round((1000 * num) / den) / 10 : null, answered, failed, complete: reqDone === required };
  }, [ans, round.checkpoints]);

  async function submit() {
    setBusy(true); setErr(null);
    try { onDone(await submitInspection(round.template_id, ans, 'Awa Toko', signed)); }
    catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); }
  }
  const set = (k: string, v: unknown) => setAns((a) => ({ ...a, [k]: v }));

  return (
    <div className="ka-overlay" onClick={onClose}>
      <aside className="ka-drawer" onClick={(e) => e.stopPropagation()} role="dialog" aria-label={round.name}>
        <div className="ka-drawer__head">
          <div>
            <div className="ks-eyebrow">{DOMAIN[round.domain]} · {round.location}</div>
            <h2 style={{ fontSize: 21, fontWeight: 800, letterSpacing: '-.02em', margin: '4px 0 0' }}>{round.name}</h2>
          </div>
          <button className="ks-icon-btn" aria-label="Fermer" onClick={onClose}><X size={17} /></button>
        </div>

        <div className="ka-drawer__health" style={{ position: 'sticky', top: -24, zIndex: 2 }}>
          <RingGauge value={live.score ?? 0} size={70} stroke={7} color={scoreColor(live.score)} label={live.score != null ? String(Math.round(live.score)) : '—'} />
          <div style={{ fontSize: 13, lineHeight: 1.55 }}>
            <div><b>{live.answered}</b> / {round.checkpoints.length} points renseignés</div>
            <div style={{ color: live.failed ? 'var(--ks-critical)' : 'var(--ks-ink-3)' }}>{live.failed ? `${live.failed} écart(s) → NC automatique(s)` : 'Aucun écart'}</div>
            <div className="ks-faint" style={{ fontSize: 11.5 }}>points critiques pondérés ×3</div>
          </div>
        </div>

        {round.checkpoints.map((cp) => {
          const ok = cpOk(cp, ans[cp.key]);
          return (
            <div key={cp.key} className={`ki-cp${ok === false ? ' ki-cp--ko' : ok ? ' ki-cp--ok' : ''}`}>
              <div className="ki-cp__lbl">
                {cp.label}
                {cp.critical && <span className="ks-risk ks-risk--critical" style={{ marginLeft: 8 }}>critique</span>}
                {cp.required === false && <span className="ks-faint" style={{ fontSize: 11, marginLeft: 6 }}>facultatif</span>}
              </div>
              {cp.type === 'boolean' && (
                <div className="ks-segment ki-seg">
                  <button className={ans[cp.key] === true ? 'ki-seg--ok' : ''} onClick={() => set(cp.key, true)}><Check size={14} /> Conforme</button>
                  <button className={ans[cp.key] === false ? 'ki-seg--ko' : ''} onClick={() => set(cp.key, false)}><X size={14} /> Non conforme</button>
                </div>
              )}
              {cp.type === 'numeric' && (
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <input className="kt-field ki-input" type="number" step="0.1" inputMode="decimal" value={(ans[cp.key] as string) ?? ''}
                    onChange={(e) => set(cp.key, e.target.value === '' ? '' : Number(e.target.value))} />
                  <span className="ks-mono ks-faint" style={{ fontSize: 12 }}>{cp.unit} · plage {cp.min ?? '−∞'} – {cp.max ?? '+∞'}</span>
                </div>
              )}
              {cp.type === 'choice' && (
                <div className="ks-segment ki-seg">
                  {(cp.options ?? []).map((o) => {
                    const fail = (cp.fail_options ?? []).includes(o);
                    return <button key={o} className={ans[cp.key] === o ? (fail ? 'ki-seg--ko' : 'ki-seg--ok') : ''} onClick={() => set(cp.key, o)}>{o}</button>;
                  })}
                </div>
              )}
              {cp.type === 'text' && (
                <textarea className="kt-field ki-input" rows={2} style={{ width: '100%' }} value={(ans[cp.key] as string) ?? ''} onChange={(e) => set(cp.key, e.target.value)} />
              )}
            </div>
          );
        })}

        {round.requires_signature && (
          <label className="ki-sign">
            <input type="checkbox" checked={signed} onChange={(e) => setSigned(e.target.checked)} />
            <PenLine size={15} /> Je certifie l’exactitude des constats (signature requise pour cette ronde)
          </label>
        )}
        {err && <div className="ks-mono" style={{ color: 'var(--ks-critical)', fontSize: 12.5, marginTop: 12 }}>{err}</div>}
        <button className="ks-btn ks-btn--primary" style={{ width: '100%', justifyContent: 'center', marginTop: 18 }}
          disabled={busy || !live.complete || (round.requires_signature && !signed)} onClick={submit}>
          <ClipboardCheck size={16} /> {busy ? 'Enregistrement…' : live.complete ? 'Valider la ronde' : 'Renseignez les points obligatoires'}
        </button>
      </aside>
    </div>
  );
}

function NcTreat({ nc, onClose, onDone }: { nc: NcRow; onClose: () => void; onDone: () => void }) {
  const [root, setRoot] = useState(nc.root_cause ?? '');
  const [action, setAction] = useState(nc.corrective_action ?? '');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  async function go() {
    setBusy(true); setErr(null);
    try { await ncTransition(nc.id, 'submit', root, action); onDone(); }
    catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); }
  }
  return (
    <div className="ka-overlay" onClick={onClose}>
      <aside className="ka-drawer" onClick={(e) => e.stopPropagation()} role="dialog" aria-label={nc.title}>
        <div className="ka-drawer__head">
          <div>
            <div className="ks-mono ks-faint" style={{ fontSize: 12 }}>{nc.ref} · {SEV[nc.severity].label}</div>
            <h2 style={{ fontSize: 20, fontWeight: 800, letterSpacing: '-.02em', margin: '4px 0 0' }}>{nc.title}</h2>
          </div>
          <button className="ks-icon-btn" aria-label="Fermer" onClick={onClose}><X size={17} /></button>
        </div>
        <label className="ki-cp__lbl" htmlFor="nc-root">Cause racine</label>
        <textarea id="nc-root" className="kt-field ki-input" rows={3} style={{ width: '100%', marginBottom: 14 }} value={root} onChange={(e) => setRoot(e.target.value)} placeholder="Pourquoi l’écart s’est-il produit ? (5 Pourquoi)" />
        <label className="ki-cp__lbl" htmlFor="nc-action">Action corrective</label>
        <textarea id="nc-action" className="kt-field ki-input" rows={3} style={{ width: '100%' }} value={action} onChange={(e) => setAction(e.target.value)} placeholder="Ce qui est mis en place pour qu’il ne se reproduise pas" />
        <div className="ks-faint" style={{ fontSize: 12, marginTop: 10 }}>La base refuse la soumission sans cause racine ni action corrective (<span className="ks-mono">ACTION_REQUIRED</span>).</div>
        {err && <div className="ks-mono" style={{ color: 'var(--ks-critical)', fontSize: 12.5, marginTop: 12 }}>{err}</div>}
        <button className="ks-btn ks-btn--primary" style={{ width: '100%', justifyContent: 'center', marginTop: 18 }} disabled={busy} onClick={go}>
          <Check size={15} /> {busy ? '…' : 'Soumettre à validation'}
        </button>
      </aside>
    </div>
  );
}

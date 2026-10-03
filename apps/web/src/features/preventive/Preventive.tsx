import { useEffect, useState } from 'react';
import { CalendarCheck2, AlertTriangle, Gauge, Clock3, RefreshCw, Zap, ChevronDown, ShieldCheck, HardHat, User, Users, CheckCircle2, X } from 'lucide-react';
import { Card, StatBig, TabBar } from '@keystone/ui';
import type { PmPlanRow, PmStatus, PmStep, PmWorkloadRow, PmSummary } from '@keystone/domain/db/keystone';
import { fetchPmBoard, fetchPmSteps, fetchPmWorkload, fetchPmSummary, pmGenerate } from '../../data/preventive.ts';

const STATUS: Record<PmStatus, { label: string; risk: 'critical' | 'high' | 'low' | 'info' }> = {
  overdue: { label: 'En retard', risk: 'critical' }, due: { label: 'À lancer', risk: 'high' },
  scheduled: { label: 'OT planifié', risk: 'info' }, ok: { label: 'À jour', risk: 'low' },
};
const EXEC = {
  operator: { label: 'Opérateur', icon: <User size={13} /> },
  internal: { label: 'Technicien interne', icon: <Users size={13} /> },
  contractor: { label: 'Prestataire', icon: <HardHat size={13} /> },
} as const;
const every = (d: number) => (d % 365 === 0 ? `${d / 365} an` : d % 30 === 0 ? `${d / 30} mois` : d % 7 === 0 ? `${d / 7} sem.` : `${d} j`);
const dd = (s: string) => new Date(s).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' });

export function Preventive() {
  const [tab, setTab] = useState('plans');
  const [plans, setPlans] = useState<PmPlanRow[] | null>(null);
  const [load_, setLoad] = useState<PmWorkloadRow[] | null>(null);
  const [sum, setSum] = useState<PmSummary | null>(null);
  const [open, setOpen] = useState<string | null>(null);
  const [steps, setSteps] = useState<Record<string, PmStep[]>>({});
  const [err, setErr] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  function load() {
    fetchPmBoard().then(setPlans).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
    fetchPmWorkload(8).then(setLoad).catch(() => {});
    fetchPmSummary().then(setSum).catch(() => {});
  }
  useEffect(load, []);

  function toggle(id: string) {
    setOpen((o) => (o === id ? null : id));
    if (!steps[id]) fetchPmSteps(id).then((s) => setSteps((m) => ({ ...m, [id]: s }))).catch(() => {});
  }
  async function generate() {
    setBusy(true); setErr(null);
    try {
      const r = await pmGenerate(14);
      setToast(r.created ? `${r.created} OT préventif(s) planifié(s) : ${r.refs.join(', ')} — à affecter dans la GMAO` : 'Aucune gamme due dans les 14 prochains jours.');
      setTimeout(() => setToast(null), 5500); load();
    } catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); }
  }

  const peak = Math.max(1, ...(load_ ?? []).map((w) => Math.max(w.internal_h + w.operator_h, w.capacity_h)), ...(load_ ?? []).map((w) => w.contractor_h));
  const toLaunch = (plans ?? []).filter((p) => p.status === 'due' || p.status === 'overdue' || (p.status === 'ok' && p.days_to_due <= 14)).length;

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Hard FM · Maintenance préventive</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Préventif &amp; gammes</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">niveaux NF X60-000 · échéancier · charge vs capacité · EN 15341</span>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8, alignSelf: 'end' }}>
          <button className="ks-btn ks-btn--ghost" onClick={load}><RefreshCw size={15} /> Rafraîchir</button>
          <button className="ks-btn ks-btn--primary" disabled={busy || toLaunch === 0} onClick={generate}><Zap size={15} /> {busy ? '…' : `Générer les OT · 14 j${toLaunch ? ` (${toLaunch})` : ''}`}</button>
        </div>
      </header>

      {toast && <div className="ka-toast"><CheckCircle2 size={16} /> {toast}</div>}
      {err && (
        <div className="ka-toast" style={{ background: 'var(--ks-critical-100)', color: '#8E1E22' }}>
          <AlertTriangle size={16} /> <span className="ks-mono" style={{ fontSize: 12.5 }}>{err}</span>
          <button className="ks-icon-btn" style={{ marginLeft: 'auto' }} aria-label="Fermer" onClick={() => setErr(null)}><X size={14} /></button>
        </div>
      )}

      {sum && (
        <div className="kt-dash kt-dash--4 ks-reveal" style={{ marginBottom: 18 }}>
          <Card><StatBig label="Gammes actives" icon={<CalendarCheck2 size={15} />} value={sum.plans} sub={`${sum.scheduled} avec OT planifié`} /></Card>
          <Card><StatBig label="Gammes en retard" icon={<AlertTriangle size={15} />} accent={sum.overdue ? 'var(--ks-critical)' : 'var(--ks-low)'} value={sum.overdue} sub={`${sum.due} à lancer`} /></Card>
          <Card><StatBig label="Conformité préventive" icon={<Gauge size={15} />} accent={(sum.compliance_pct ?? 0) >= 90 ? 'var(--ks-low)' : 'var(--ks-amber)'} value={sum.compliance_pct ?? '—'} unit="%" sub="réalisé dans la tolérance · 12 mois" /></Card>
          <Card><StatBig label="Charge préventive" icon={<Clock3 size={15} />} value={sum.hours_per_year.toLocaleString('fr-FR')} unit="h/an" sub="toutes gammes confondues" /></Card>
        </div>
      )}

      <div style={{ marginBottom: 16 }}>
        <TabBar tabs={[{ id: 'plans', label: 'Échéancier des gammes', icon: <CalendarCheck2 size={15} /> }, { id: 'load', label: 'Charge vs capacité', icon: <Clock3 size={15} /> }]} active={tab} onChange={setTab} />
      </div>

      {tab === 'plans' && plans && (
        <Card pad={false} className="ks-reveal">
          {plans.map((p) => {
            const st = STATUS[p.status];
            const ex = EXEC[p.executor_kind];
            const isOpen = open === p.id;
            return (
              <div key={p.id} className="kn-row">
                <button className="kn-row__main" onClick={() => toggle(p.id)} aria-expanded={isOpen}>
                  <span className={`kn-lvl kn-lvl--${p.afnor_level ?? 0}`} title={p.level_label ?? ''}>{p.afnor_level ? `N${p.afnor_level}` : '—'}</span>
                  <div style={{ minWidth: 0, flex: 1, textAlign: 'left' }}>
                    <div style={{ fontWeight: 600, fontSize: 14 }}>{p.name}{p.regulatory && <ShieldCheck size={13} style={{ marginLeft: 6, verticalAlign: -2, color: 'var(--ks-info)' }} />}</div>
                    <div className="ks-faint" style={{ fontSize: 12 }}>
                      <span className="ks-mono">{p.asset_tag}</span> · tous les {every(p.interval_days)} · {p.estimated_hours} h · {p.steps} étapes
                      <span style={{ marginLeft: 8, display: 'inline-flex', alignItems: 'center', gap: 4 }}>{ex.icon} {p.contractor ?? ex.label}</span>
                    </div>
                  </div>
                  <div className="kn-due">
                    <div className="ks-mono" style={{ fontWeight: 600, fontSize: 13, color: p.days_to_due < 0 ? 'var(--ks-critical)' : undefined }}>{dd(p.next_due)}</div>
                    <div className="ks-faint" style={{ fontSize: 11 }}>{p.days_to_due < 0 ? `${-p.days_to_due} j de retard` : `J-${p.days_to_due}`}</div>
                  </div>
                  <span className={`ks-risk ks-risk--${st.risk}`} style={{ minWidth: 92, justifyContent: 'center' }}>{p.open_wo_ref ?? st.label}</span>
                  <ChevronDown size={16} className="ks-faint" style={{ transform: isOpen ? 'rotate(180deg)' : undefined, transition: 'transform var(--ks-dur)' }} />
                </button>
                {isOpen && (
                  <div className="kn-steps">
                    <div className="ks-faint" style={{ fontSize: 12, marginBottom: 8 }}>{p.level_label}{p.done_12m > 0 && ` · ${p.on_time_12m}/${p.done_12m} réalisations dans la tolérance sur 12 mois`}</div>
                    {(steps[p.id] ?? []).map((s) => (
                      <div key={s.seq} className="kn-step">
                        <span className="kn-step__n ks-mono">{s.seq}</span>
                        <div style={{ flex: 1 }}>
                          <div style={{ fontSize: 13, fontWeight: 600 }}>{s.label}{s.is_critical && <span className="ks-risk ks-risk--critical" style={{ marginLeft: 8 }}>critique</span>}</div>
                          {s.acceptance && <div className="ks-faint" style={{ fontSize: 12 }}>✓ {s.acceptance}</div>}
                        </div>
                        {s.checkpoint?.type === 'numeric' && <span className="ks-pill ks-mono">{s.checkpoint.min}–{s.checkpoint.max} {s.checkpoint.unit}</span>}
                        <span className="ks-mono ks-faint" style={{ fontSize: 12 }}>{s.duration_min} min</span>
                      </div>
                    ))}
                    {!steps[p.id] && <div className="ks-faint" style={{ fontSize: 12 }}>Chargement…</div>}
                  </div>
                )}
              </div>
            );
          })}
          {plans.length === 0 && <div className="ks-dim" style={{ textAlign: 'center', padding: 30 }}>Aucune gamme calendaire active.</div>}
        </Card>
      )}

      {tab === 'load' && load_ && (
        <Card className="ks-reveal">
          <div className="kt-cardtitle">Charge préventive des 8 prochaines semaines</div>
          <div className="kt-cardsub">heures planifiées par type d’exécutant · trait = capacité préventive interne</div>
          <div className="kn-load">
            {load_.map((w) => {
              const internal = w.internal_h + w.operator_h;
              const over = internal > w.capacity_h;
              return (
                <div key={w.week} className="kn-load__col">
                  <div className="kn-load__val ks-mono" style={{ color: over ? 'var(--ks-critical)' : undefined }}>{Math.round(internal + w.contractor_h)} h</div>
                  <div className="kn-load__track">
                    <span className="kn-load__cap" style={{ bottom: `${(w.capacity_h / peak) * 100}%` }} />
                    <span className="ks-grow" style={{ height: `${(w.contractor_h / peak) * 100}%`, background: 'var(--ks-info)', opacity: 0.55 }} />
                    <span className="ks-grow" style={{ height: `${(internal / peak) * 100}%`, background: over ? 'var(--ks-critical)' : 'var(--ks-amber)' }} />
                  </div>
                  <div className="kn-load__lbl">{dd(w.week)}</div>
                </div>
              );
            })}
          </div>
          <div className="kt-legend">
            <span><i style={{ background: 'var(--ks-amber)' }} /> Interne + conduite</span>
            <span><i style={{ background: 'var(--ks-info)', opacity: 0.55 }} /> Prestataires</span>
            <span><i style={{ background: 'var(--ks-ink)', borderRadius: 1, height: 2 }} /> Capacité interne ({load_[0]?.capacity_h ?? 0} h/sem.)</span>
          </div>
          <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 10 }}>Capacité = 35 % de 40 h par technicien actif, réservée au préventif (hypothèse à paramétrer).</div>
        </Card>
      )}
    </div>
  );
}

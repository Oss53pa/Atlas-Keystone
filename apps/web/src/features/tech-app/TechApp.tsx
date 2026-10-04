import { useEffect, useMemo, useRef, useState } from 'react';
import {
  Wrench, LogOut, Eye, ClipboardList, ScanLine, Package, Play, Pause, CheckCircle2, AlertTriangle, X, ChevronLeft, MapPin, Clock,
  ShieldAlert, Camera, Check, Minus, Plus, Search, HeartPulse, FileWarning, Navigation, PenLine, Lock,
} from 'lucide-react';
import { RingGauge } from '@keystone/ui';
import type { TechDayRow, TechWoDetail, ChecklistStep, AssetScan, StockRow } from '@keystone/domain/db/keystone';
import { useSession, signOut } from '../../lib/auth.ts';
import { Login } from '../auth/Login.tsx';
import {
  fetchTechPeople, fetchMyDay, fetchWoDetail, checkIn, holdWo, checkStep, usePart, completeWo, scanAsset, reportIssue, fetchStockLite, currentPosition,
} from '../../data/field.ts';
import { fetchPortalMe, uploadWoPhoto, signedPhotoUrls } from '../../data/portal-contractor.ts';

type Tab = 'day' | 'scan' | 'stock';
const healthColor = (h: number) => (h >= 75 ? 'var(--ks-low)' : h >= 55 ? 'var(--ks-amber)' : h >= 35 ? 'var(--ks-high)' : 'var(--ks-critical)');
function slaText(s: string | null): { text: string; late: boolean } | null {
  if (!s) return null;
  const m = Math.round((new Date(s).getTime() - Date.now()) / 60000);
  if (m < 0) return { text: `SLA dépassé de ${-m < 60 ? `${-m} min` : `${Math.round(-m / 60)} h`}`, late: true };
  return { text: `SLA ${m < 60 ? `${m} min` : `${Math.floor(m / 60)} h ${String(m % 60).padStart(2, '0')}`}`, late: false };
}

export function TechApp() {
  const { session, ready } = useSession();
  if (!ready) return <div className="kx-center ks-faint">Chargement…</div>;
  if (!session) return <Login />;
  return <TechSpace />;
}

function TechSpace() {
  const [people, setPeople] = useState<{ id: string; name: string; open_wo: number }[]>([]);
  const [person, setPerson] = useState<string | undefined>(undefined);   // undefined = ma propre journée
  const [tenantId, setTenantId] = useState('');
  const [day, setDay] = useState<TechDayRow[] | null>(null);
  const [tab, setTab] = useState<Tab>('day');
  const [openWo, setOpenWo] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const flash = (m: string) => { setToast(m); setTimeout(() => setToast(null), 4500); };

  useEffect(() => {
    fetchPortalMe().then((m) => setTenantId(m.tenant_id)).catch(() => {});
    // Un technicien voit ses OT ; un exploitant sans fiche technicien choisit qui prévisualiser
    fetchMyDay().then((d) => { setDay(d); }).catch(() => {});
    fetchTechPeople().then((p) => { setPeople(p); }).catch((e) => setErr(String(e)));
  }, []);
  // Exploitant sans fiche technicien : on ouvre directement la journée du premier technicien
  useEffect(() => {
    if (day && day.length === 0 && people.length && person === undefined) setPerson(people[0].id);
  }, [day, people, person]);
  function load() { fetchMyDay(person).then(setDay).catch((e) => setErr(e instanceof Error ? e.message : String(e))); }
  useEffect(() => { if (person) load(); }, [person]); // eslint-disable-line react-hooks/exhaustive-deps

  const name = person ? people.find((p) => p.id === person)?.name : undefined;
  const list = day ?? [];
  const urgent = list.filter((d) => d.priority <= 1 && d.status !== 'done').length;
  const todo = list.filter((d) => d.status !== 'done').length;

  return (
    <div className="kz-shell">
      <header className="kx-top">
        <div className="kx-top__brand">
          <span className="ks-rail__logo" style={{ width: 34, height: 34 }} aria-hidden><Wrench size={17} /></span>
          <div style={{ minWidth: 0 }}>
            <div className="ks-eyebrow">Atlas Keystone · Terrain</div>
            <div className="kx-top__name">{name ?? 'Mes interventions'}</div>
          </div>
        </div>
        <button className="ks-icon-btn" aria-label="Se déconnecter" onClick={() => void signOut()}><LogOut size={17} /></button>
      </header>
      {people.length > 0 && (
        <div className="kx-preview">
          <Eye size={15} /><span>Journée affichée :</span>
          <select className="ka-select" value={person ?? ''} aria-label="Technicien"
            onChange={(e) => { const v = e.target.value || undefined; setPerson(v); setDay(null); if (!v) fetchMyDay().then(setDay).catch(() => {}); }}>
            <option value="">Ma journée</option>
            {people.map((p) => <option key={p.id} value={p.id}>{p.name} · {p.open_wo} OT</option>)}
          </select>
        </div>
      )}

      <main className="kx-main kz-main">
        {toast && <div className="ka-toast"><CheckCircle2 size={16} /> {toast}</div>}
        {err && <div className="ka-toast" style={{ background: 'var(--ks-critical-100)', color: '#8E1E22' }}><AlertTriangle size={16} /> <span className="ks-mono" style={{ fontSize: 12.5 }}>{err}</span><button className="ks-icon-btn" style={{ marginLeft: 'auto' }} aria-label="Fermer" onClick={() => setErr(null)}><X size={14} /></button></div>}

        {tab === 'day' && (
          <div className="ks-reveal">
            <h1 className="kz-hello">Bonjour{name ? ` ${name.split(' ')[0]}` : ''} 👋</h1>
            <div className="kx-kpis" style={{ gridTemplateColumns: 'repeat(2, 1fr)' }}>
              <div className="kx-kpi"><b className="ks-mono">{todo}</b><span>OT à traiter</span></div>
              <div className={`kx-kpi${urgent ? ' kx-kpi--late' : ''}`}><b className="ks-mono">{urgent}</b><span>urgents (P1)</span></div>
            </div>
            <div className="kx-list">
              {list.map((d) => {
                const sla = d.status !== 'done' ? slaText(d.sla_due) : null;
                const pct = d.steps_total ? Math.round((d.steps_done / d.steps_total) * 100) : 0;
                return (
                  <button key={d.wo_id} className={`kx-wo kx-wo--${d.status === 'done' ? 'done' : d.priority <= 1 ? 'alert' : d.status === 'in_progress' ? 'wait' : 'todo'}`} onClick={() => setOpenWo(d.wo_id)}>
                    <div className="kx-wo__top">
                      <span className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{d.ref}{d.priority <= 1 && <span className="kx-p1">P1</span>}{d.type === 'preventive' && <span className="kf-prev">Préventif</span>}</span>
                      {sla && <span className={`kx-sla${sla.late ? ' kx-sla--late' : ''}`}><Clock size={12} /> {sla.text}</span>}
                    </div>
                    <div className="kx-wo__title">{d.title}</div>
                    <div className="ks-faint" style={{ fontSize: 12.5, display: 'flex', gap: 5, alignItems: 'center' }}><MapPin size={12} /> {d.location ?? '—'}{d.asset_tag ? ` · ${d.asset_tag}` : ''}</div>
                    {d.steps_total > 0 && <div className="kz-bar" style={{ marginTop: 8 }}><span style={{ width: `${pct}%` }} /></div>}
                    <div className="kx-wo__step">
                      <span>{d.status === 'done' ? 'Terminé · en attente de vérification' : d.status === 'in_progress' ? `En cours · ${d.steps_done}/${d.steps_total} étapes` : d.status === 'on_hold' ? 'En pause — reprendre' : d.requires_permit && !d.permit_active ? 'Permis requis avant démarrage' : 'Démarrer l’intervention'}</span>
                      {d.requires_permit && !d.permit_active && d.status === 'assigned' ? <Lock size={15} /> : <Play size={15} />}
                    </div>
                  </button>
                );
              })}
              {day && list.length === 0 && <div className="kx-empty">Aucun OT affecté pour aujourd’hui.</div>}
              {!day && <div className="kx-empty ks-faint">Chargement…</div>}
            </div>
          </div>
        )}

        {tab === 'scan' && <ScanTab onToast={flash} onError={setErr} />}
        {tab === 'stock' && <StockTab />}
      </main>

      <nav className="kz-nav" aria-label="Navigation">
        {([['day', 'Mes OT', ClipboardList], ['scan', 'Scanner', ScanLine], ['stock', 'Stock', Package]] as const).map(([id, label, Icon]) => (
          <button key={id} className={`kz-nav__btn${tab === id ? ' kz-nav__btn--on' : ''}`} onClick={() => setTab(id)} aria-current={tab === id ? 'page' : undefined}>
            <Icon size={20} /><span>{label}</span>{id === 'day' && urgent > 0 && <i className="kz-nav__badge">{urgent}</i>}
          </button>
        ))}
      </nav>

      {openWo && (
        <WoExecution woId={openWo} person={person} tenantId={tenantId} onClose={() => { setOpenWo(null); load(); }}
          onToast={flash} onDone={(m) => { flash(m); setOpenWo(null); load(); }} />
      )}
    </div>
  );
}

function WoExecution({ woId, person, tenantId, onClose, onToast, onDone }: {
  woId: string; person?: string; tenantId: string; onClose: () => void; onToast: (m: string) => void; onDone: (m: string) => void;
}) {
  const [d, setD] = useState<TechWoDetail | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [notes, setNotes] = useState('');
  const [signer, setSigner] = useState('');
  const [holdReason, setHoldReason] = useState('');
  const [showHold, setShowHold] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  function load() { fetchWoDetail(woId).then(setD).catch((e) => setErr(String(e))); }
  useEffect(load, [woId]); // eslint-disable-line react-hooks/exhaustive-deps
  const startedAt = useMemo(() => [...(d?.time ?? [])].reverse().find((t) => t.kind === 'check_in' || t.kind === 'resume')?.at, [d]);
  useEffect(() => {
    if (d?.status !== 'in_progress' || !startedAt) return;
    const tick = () => setElapsed(Math.floor((Date.now() - new Date(startedAt).getTime()) / 1000));
    tick(); const i = setInterval(tick, 1000); return () => clearInterval(i);
  }, [d?.status, startedAt]);

  async function act(key: string, fn: () => Promise<string | void>) {
    setBusy(key); setErr(null);
    try { const m = await fn(); if (m) onToast(m); load(); } catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(null); }
  }
  async function start() {
    await act('start', async () => {
      const pos = await currentPosition();
      const r = await checkIn(woId, pos, person);
      return r.distance_m == null ? 'Arrivée pointée (position GPS indisponible)' : r.off_site ? `Arrivée pointée — attention : ${Math.round(Number(r.distance_m))} m du site` : 'Arrivée pointée sur site ✓';
    });
  }
  async function finish() {
    setBusy('done'); setErr(null);
    try {
      const pos = await currentPosition();
      const r = await completeWo(woId, notes, signer, pos, person);
      onDone(`OT ${d?.ref} terminé · ${r.minutes} min pointées`);
    } catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(null); }
  }

  if (!d) return <div className="kx-sheet-wrap"><section className="kx-sheet"><div className="kx-empty ks-faint">Chargement…</div></section></div>;
  const running = d.status === 'in_progress';
  const steps = d.checklist ?? [];
  const missing = steps.filter((s) => s.required !== false && !s.done_at).length;
  const hh = String(Math.floor(elapsed / 3600)).padStart(2, '0'), mm = String(Math.floor((elapsed % 3600) / 60)).padStart(2, '0'), ss = String(elapsed % 60).padStart(2, '0');
  const sla = slaText(d.sla_due);

  return (
    <div className="kx-sheet-wrap" onClick={onClose}>
      <section className="kx-sheet kf-exec" onClick={(e) => e.stopPropagation()} role="dialog" aria-label={d.title}>
        <div className="kf-exec__top">
          <button className="ks-icon-btn" aria-label="Retour" onClick={onClose}><ChevronLeft size={18} /></button>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{d.ref} · {d.status === 'in_progress' ? 'en cours' : d.status === 'on_hold' ? 'en pause' : d.status === 'done' ? 'terminé' : 'à démarrer'}</div>
            <div style={{ fontWeight: 800, fontSize: 17, letterSpacing: '-.01em' }}>{d.title}</div>
          </div>
          {running && <span className="kf-timer ks-mono"><Clock size={13} /> {hh}:{mm}:{ss}</span>}
        </div>
        <div className="ks-faint" style={{ fontSize: 12.5, display: 'flex', gap: 10, flexWrap: 'wrap', margin: '6px 0 10px' }}>
          <span><MapPin size={12} style={{ verticalAlign: -2 }} /> {d.location ?? '—'}</span>
          {d.asset && <span>📦 {d.asset.tag} · {d.asset.name}</span>}
          {sla && d.status !== 'done' && <span style={{ color: sla.late ? 'var(--ks-critical)' : undefined, fontWeight: 600 }}><Clock size={12} style={{ verticalAlign: -2 }} /> {sla.text}</span>}
        </div>
        {err && <div className="kx-err"><AlertTriangle size={14} /> {err}</div>}
        {d.safety && <div className="kf-safety"><ShieldAlert size={16} /><div><b>Consignes de sécurité</b><div>{d.safety}</div></div></div>}
        {d.requires_permit && !d.permit_active && d.status !== 'done' && (
          <div className="kz-status kz-status--late"><Lock size={14} /> Permis de travail requis : le démarrage est bloqué tant qu’aucun permis n’est actif.</div>
        )}

        {(d.status === 'assigned' || d.status === 'on_hold') && (
          <button className="ks-btn ks-btn--primary kx-wide" disabled={busy === 'start'} onClick={() => void start()}>
            <Navigation size={15} /> {busy === 'start' ? 'Localisation…' : d.status === 'on_hold' ? 'Reprendre l’intervention' : 'Pointer mon arrivée et démarrer'}
          </button>
        )}

        {steps.length > 0 && (
          <div className="kv-sec">
            <h3><ClipboardList size={15} /> Checklist <span className="ks-faint ks-mono" style={{ fontWeight: 500 }}>{steps.filter((s) => s.done_at).length}/{steps.length}</span></h3>
            {steps.map((s) => <StepRow key={s.index} step={s} disabled={!running} woId={woId} tenantId={tenantId}
              onSave={(v) => act(`s${s.index}`, async () => { const r = await checkStep(woId, s.index, v); if (!r.ok) return `Étape « ${s.label} » non conforme${s.critical ? ' — étape critique' : ''}`; })} />)}
          </div>
        )}

        {(running || (d.parts ?? []).length > 0) && (
          <PartsBlock d={d} running={running} busy={busy} onUse={(part, qty) => act('part', async () => { await usePart(woId, part, qty); return `Pièce sortie du stock (${qty})`; })} />
        )}

        {running && (
          <div className="kv-sec">
            <h3><PenLine size={15} /> Clôture</h3>
            <textarea className="kt-field ki-input" rows={3} style={{ width: '100%' }} placeholder="Constat, travaux réalisés, recommandations…" value={notes} onChange={(e) => setNotes(e.target.value)} />
            <input className="kx-in" style={{ width: '100%', marginTop: 8 }} placeholder="Nom du technicien (signature)" value={signer} onChange={(e) => setSigner(e.target.value)} />
            {missing > 0 && <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 6 }}>{missing} étape(s) obligatoire(s) restante(s) avant de pouvoir terminer.</div>}
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="ks-btn ks-btn--ghost kx-wide" style={{ flex: '0 0 auto', width: 'auto' }} onClick={() => setShowHold((s) => !s)}><Pause size={15} /> Pause</button>
              <button className="ks-btn ks-btn--primary kx-wide" disabled={busy === 'done' || missing > 0 || !signer.trim()} onClick={() => void finish()}>
                <CheckCircle2 size={15} /> {busy === 'done' ? '…' : 'Pointer mon départ et terminer'}
              </button>
            </div>
            {showHold && (
              <div className="kx-box" style={{ marginTop: 10 }}>
                <input className="kx-in" style={{ width: '100%' }} placeholder="Motif (attente pièce, accès refusé…)" value={holdReason} onChange={(e) => setHoldReason(e.target.value)} />
                <button className="ks-btn ks-btn--ghost kx-wide" disabled={!holdReason.trim() || busy === 'hold'} onClick={() => act('hold', async () => { await holdWo(woId, holdReason, person); setShowHold(false); return 'OT mis en pause'; })}><Pause size={15} /> Mettre en pause</button>
              </div>
            )}
          </div>
        )}
        {d.status === 'done' && <div className="kz-status kz-status--ok"><CheckCircle2 size={14} /> Intervention terminée — en attente de vérification par un superviseur (séparation des tâches).</div>}
      </section>
    </div>
  );
}

function StepRow({ step, disabled, woId, tenantId, onSave }: { step: ChecklistStep; disabled: boolean; woId: string; tenantId: string; onSave: (v: unknown) => void }) {
  const [num, setNum] = useState(step.value != null && step.type === 'numeric' ? String(step.value) : '');
  const [txt, setTxt] = useState(step.type === 'text' && typeof step.value === 'string' ? step.value : '');
  const [url, setUrl] = useState<string | null>(null);
  const [up, setUp] = useState(false);
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (step.type === 'photo' && typeof step.value === 'string') signedPhotoUrls([step.value]).then((m) => setUrl(m[step.value as string] ?? null)).catch(() => {});
  }, [step]);
  const done = !!step.done_at;
  const state = !done ? '' : step.ok ? ' kf-step--ok' : ' kf-step--ko';
  async function photo(f: File | undefined) {
    if (!f || !tenantId) return;
    setUp(true);
    try { onSave(await uploadWoPhoto(tenantId, woId, `etape${step.index + 1}`, f)); } finally { setUp(false); }
  }
  return (
    <div className={`kf-step${state}`}>
      <div className="kf-step__lbl">
        <span className="kf-step__dot">{done ? (step.ok ? <Check size={12} strokeWidth={3} /> : <X size={12} strokeWidth={3} />) : step.index + 1}</span>
        <span style={{ flex: 1 }}>{step.label}{step.critical && <span className="ks-risk ks-risk--critical" style={{ marginLeft: 6 }}>critique</span>}{step.required === false && <span className="ks-faint" style={{ fontSize: 11 }}> · facultatif</span>}</span>
      </div>
      <div className="kf-step__ctl">
        {step.type === 'check' && (
          <div className="ks-segment ki-seg">
            <button disabled={disabled} className={step.value === true ? 'ki-seg--ok' : ''} onClick={() => onSave(true)}><Check size={14} /> Fait / conforme</button>
            <button disabled={disabled} className={step.value === false ? 'ki-seg--ko' : ''} onClick={() => onSave(false)}><X size={14} /> Non conforme</button>
          </div>
        )}
        {step.type === 'numeric' && (
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <input className="kx-in kx-in--num" style={{ width: 100 }} type="number" inputMode="decimal" step="0.1" disabled={disabled} value={num} onChange={(e) => setNum(e.target.value)} />
            <span className="ks-faint ks-mono" style={{ fontSize: 12 }}>{step.unit} · {step.min ?? '−∞'}–{step.max ?? '+∞'}</span>
            <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={disabled || num === ''} onClick={() => onSave(Number(num))}>Valider</button>
          </div>
        )}
        {step.type === 'text' && (
          <div style={{ display: 'flex', gap: 8 }}>
            <input className="kx-in kx-in--grow" disabled={disabled} value={txt} onChange={(e) => setTxt(e.target.value)} />
            <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={disabled || !txt.trim()} onClick={() => onSave(txt.trim())}>Valider</button>
          </div>
        )}
        {step.type === 'photo' && (
          <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            {url ? <img src={url} alt="" className="kf-thumb" /> : done ? <span className="kf-thumb"><Camera size={16} /></span> : null}
            <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={disabled || up} onClick={() => input.current?.click()}><Camera size={13} /> {up ? 'Envoi…' : done ? 'Reprendre la photo' : 'Prendre la photo'}</button>
            <input ref={input} type="file" accept="image/*" capture="environment" hidden onChange={(e) => void photo(e.target.files?.[0])} />
          </div>
        )}
      </div>
    </div>
  );
}

function PartsBlock({ d, running, busy, onUse }: { d: TechWoDetail; running: boolean; busy: string | null; onUse: (part: string, qty: number) => void }) {
  const [stock, setStock] = useState<StockRow[]>([]);
  const [q, setQ] = useState('');
  const [qty, setQty] = useState<Record<string, number>>({});
  useEffect(() => { if (running) fetchStockLite().then(setStock).catch(() => {}); }, [running]);
  const used = (d.parts ?? []).filter((p) => p.kind === 'part');
  const planned = (d.parts ?? []).filter((p) => p.kind === 'planned_part');
  const found = q.trim().length >= 2 ? stock.filter((s) => `${s.ref} ${s.name}`.toLowerCase().includes(q.toLowerCase())).slice(0, 5) : [];
  return (
    <div className="kv-sec">
      <h3><Package size={15} /> Pièces</h3>
      {planned.map((p) => (
        <div key={p.id} className="kv-line"><span><span className="ks-faint">Prévu · </span>{p.label} × {Number(p.qty)}<span className="ks-faint"> (stock {p.in_stock ?? '—'})</span></span>
          {running && p.part_id && <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={busy === 'part'} onClick={() => onUse(p.part_id!, Number(p.qty))}>Sortir</button>}</div>
      ))}
      {used.map((p) => <div key={p.id} className="kv-line"><span><Check size={12} style={{ color: 'var(--ks-low)', verticalAlign: -1 }} /> {p.label}</span><b className="ks-mono">× {Number(p.qty)}</b></div>)}
      {running && (
        <>
          <div className="kz-reply" style={{ marginTop: 8 }}><Search size={15} className="ks-faint" style={{ alignSelf: 'center' }} /><input className="kx-in kx-in--grow" placeholder="Chercher une pièce (réf. ou nom)" value={q} onChange={(e) => setQ(e.target.value)} /></div>
          {found.map((s) => (
            <div key={s.id} className="kv-line">
              <span><span className="ks-mono" style={{ fontSize: 11.5 }}>{s.ref}</span> {s.name}<span className="ks-faint"> · stock {s.qty}</span></span>
              <span style={{ display: 'inline-flex', gap: 4, alignItems: 'center' }}>
                <button className="ks-icon-btn" aria-label="Moins" onClick={() => setQty((x) => ({ ...x, [s.id]: Math.max(1, (x[s.id] ?? 1) - 1) }))}><Minus size={13} /></button>
                <b className="ks-mono" style={{ minWidth: 18, textAlign: 'center' }}>{qty[s.id] ?? 1}</b>
                <button className="ks-icon-btn" aria-label="Plus" onClick={() => setQty((x) => ({ ...x, [s.id]: (x[s.id] ?? 1) + 1 }))}><Plus size={13} /></button>
                <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={busy === 'part' || s.qty < (qty[s.id] ?? 1)} onClick={() => { onUse(s.id, qty[s.id] ?? 1); setQ(''); }}>Sortir</button>
              </span>
            </div>
          ))}
        </>
      )}
    </div>
  );
}

/* ---------------- Scan QR / code équipement ---------------- */
type Detector = { detect: (src: CanvasImageSource) => Promise<{ rawValue: string }[]> };
function ScanTab({ onToast, onError }: { onToast: (m: string) => void; onError: (m: string) => void }) {
  const video = useRef<HTMLVideoElement>(null);
  const [scanning, setScanning] = useState(false);
  const [code, setCode] = useState('');
  const [res, setRes] = useState<AssetScan | null>(null);
  const [issue, setIssue] = useState('');
  const supported = typeof window !== 'undefined' && 'BarcodeDetector' in window;

  async function lookup(c: string) {
    try { setRes(await scanAsset(c)); setScanning(false); } catch (e) { onError(e instanceof Error ? e.message : String(e)); }
  }
  useEffect(() => {
    if (!scanning) return;
    let stream: MediaStream | null = null; let stop = false;
    (async () => {
      try {
        stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
        if (video.current) { video.current.srcObject = stream; await video.current.play(); }
        const det = new (window as unknown as { BarcodeDetector: new (o: { formats: string[] }) => Detector }).BarcodeDetector({ formats: ['qr_code', 'code_128', 'ean_13'] });
        while (!stop && video.current) {
          const found = await det.detect(video.current).catch(() => []);
          if (found[0]?.rawValue) { stop = true; await lookup(found[0].rawValue); break; }
          await new Promise((r) => setTimeout(r, 300));
        }
      } catch { onError('Caméra indisponible ou refusée — saisissez le code manuellement.'); setScanning(false); }
    })();
    return () => { stop = true; stream?.getTracks().forEach((t) => t.stop()); };
  }, [scanning]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div className="ks-reveal">
      <h1 className="kz-title">Scanner un équipement</h1>
      {!res && (
        <>
          <div className="kf-cam">
            {scanning ? <video ref={video} playsInline muted /> : <div className="kf-cam__idle"><ScanLine size={40} /><span>Pointez l’étiquette QR de l’équipement</span></div>}
            {scanning && <span className="kf-cam__frame" aria-hidden />}
          </div>
          {supported
            ? <button className="ks-btn ks-btn--primary kx-wide" onClick={() => setScanning((s) => !s)}><ScanLine size={15} /> {scanning ? 'Arrêter' : 'Ouvrir la caméra'}</button>
            : <div className="ks-faint" style={{ fontSize: 12, marginTop: 8 }}>Scan caméra non pris en charge par ce navigateur : saisissez le code.</div>}
          <div className="kz-reply" style={{ marginTop: 12 }}>
            <input className="kx-in kx-in--grow" placeholder="Code de l’étiquette ou repère (ex. QR-GF02, GE-01)" value={code} onChange={(e) => setCode(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && code.trim() && void lookup(code)} />
            <button className="ks-btn ks-btn--ghost ks-btn--sm" disabled={!code.trim()} onClick={() => void lookup(code)}>Ouvrir</button>
          </div>
        </>
      )}
      {res && (
        <div className="ks-reveal">
          <section className="kz-card">
            <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
              <RingGauge value={res.asset.health} size={66} stroke={6} color={healthColor(res.asset.health)} />
              <div style={{ minWidth: 0 }}>
                <div className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{res.asset.tag} · {res.asset.category}</div>
                <div style={{ fontWeight: 800, fontSize: 17 }}>{res.asset.name}</div>
                <div className="ks-faint" style={{ fontSize: 12.5 }}>{res.asset.location} · {[res.asset.manufacturer, res.asset.model].filter(Boolean).join(' ')}</div>
              </div>
            </div>
            <div className="kz-grid" style={{ marginTop: 12, gridTemplateColumns: 'repeat(3, 1fr)' }}>
              <div className="kx-kpi"><b className="ks-mono" style={{ fontSize: 16 }}>{res.asset.mtbf_h ?? '—'}</b><span>MTBF (h)</span></div>
              <div className="kx-kpi"><b className="ks-mono" style={{ fontSize: 16 }}>{res.asset.max_rpn ?? '—'}</b><span>RPN max</span></div>
              <div className="kx-kpi"><b className="ks-mono" style={{ fontSize: 16 }}>{res.asset.rul_days != null ? `${Math.round(Number(res.asset.rul_days))} j` : '—'}</b><span>RUL prédite</span></div>
            </div>
            {res.top_risk && <div className="kz-status kz-status--late"><HeartPulse size={14} /> Risque principal : {res.top_risk.component} (RPN {res.top_risk.rpn}) — {res.top_risk.effect}</div>}
          </section>
          <h2 className="kz-sub">OT ouverts</h2>
          <section className="kz-card">
            {(res.open_wo ?? []).map((w) => <div key={w.ref} className="kv-line"><span><span className="ks-mono" style={{ fontSize: 11.5 }}>{w.ref}</span> {w.title}</span><span className="kz-tag kz-tag--run">{w.status}</span></div>)}
            {!res.open_wo && <div className="ks-faint" style={{ fontSize: 13 }}>Aucun OT ouvert.</div>}
          </section>
          <h2 className="kz-sub">Dernières interventions</h2>
          <section className="kz-card">
            {(res.history ?? []).map((h) => <div key={h.ref} className="kv-line"><span>{h.title}</span><span className="ks-faint ks-mono" style={{ fontSize: 11.5 }}>{h.actual_end ? new Date(h.actual_end).toLocaleDateString('fr-FR') : ''}</span></div>)}
            {!res.history && <div className="ks-faint" style={{ fontSize: 13 }}>Pas d’historique.</div>}
          </section>
          <h2 className="kz-sub"><FileWarning size={15} style={{ verticalAlign: -2 }} /> Signaler une anomalie</h2>
          <section className="kz-card">
            <input className="kx-in" style={{ width: '100%' }} placeholder="Ce que vous constatez" value={issue} onChange={(e) => setIssue(e.target.value)} />
            <button className="ks-btn ks-btn--primary kx-wide" disabled={issue.trim().length < 5} onClick={async () => {
              try { const r = await reportIssue(res.asset.id, issue.trim(), 2); onToast(`Anomalie signalée · OT ${r.ref} créé en brouillon`); setIssue(''); }
              catch (e) { onError(e instanceof Error ? e.message : String(e)); }
            }}>Créer l’OT correctif</button>
          </section>
          <button className="ks-btn ks-btn--quiet kx-wide" onClick={() => { setRes(null); setCode(''); }}><ScanLine size={15} /> Scanner un autre équipement</button>
        </div>
      )}
    </div>
  );
}

function StockTab() {
  const [rows, setRows] = useState<StockRow[] | null>(null);
  const [q, setQ] = useState('');
  useEffect(() => { fetchStockLite().then(setRows).catch(() => {}); }, []);
  const shown = (rows ?? []).filter((r) => !q || `${r.ref} ${r.name}`.toLowerCase().includes(q.toLowerCase()));
  return (
    <div className="ks-reveal">
      <h1 className="kz-title">Stock du magasin</h1>
      <div className="kz-reply" style={{ marginBottom: 12 }}><Search size={15} className="ks-faint" style={{ alignSelf: 'center' }} /><input className="kx-in kx-in--grow" placeholder="Rechercher une pièce" value={q} onChange={(e) => setQ(e.target.value)} /></div>
      {shown.map((r) => (
        <section key={r.id} className="kz-card" style={{ marginBottom: 8 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
            <div><div className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{r.ref}</div><div style={{ fontWeight: 600 }}>{r.name}</div></div>
            <div style={{ textAlign: 'right' }}>
              <b className="ks-mono" style={{ fontSize: 17, color: r.level === 'ok' ? 'var(--ks-ink)' : r.level === 'warning' ? 'var(--ks-amber-700)' : 'var(--ks-critical)' }}>{r.qty}</b>
              <div className="ks-faint" style={{ fontSize: 11 }}>min {r.min_qty}{r.on_order > 0 ? ` · +${r.on_order} commandés` : ''}</div>
            </div>
          </div>
        </section>
      ))}
      <div className="ks-faint" style={{ fontSize: 12, marginTop: 8 }}>Les sorties se font depuis l’OT concerné (onglet Mes OT → Pièces) pour être imputées.</div>
    </div>
  );
}

import { useEffect, useMemo, useRef, useState } from 'react';
import {
  HardHat, LogOut, Eye, FileText, FilePlus2, Timer, ClipboardSignature, Camera, Plus, Trash2, Send, Pause, Play, X,
  CheckCircle2, AlertTriangle, ChevronRight, MapPin, Clock, RefreshCw, ImagePlus,
} from 'lucide-react';
import { money, format } from '@keystone/domain';
import type { PortalRow, PortalDetail } from '@keystone/domain/db/keystone';
import { useSession, signOut } from '../../lib/auth.ts';
import { Login } from '../auth/Login.tsx';
import {
  fetchPortalBoard, fetchPortalDetail, fetchPortalMe, fetchPortalContractors, quoteSubmit, variationSubmit, slaPause, slaResume,
  reportSubmit, uploadWoPhoto, signedPhotoUrls, isStoredPhoto, type PortalMe, type QuoteItemInput, type AnomalyInput,
} from '../../data/portal-contractor.ts';

const fcfa = (n: number) => format(money(n, 'XOF'));
const PAUSE_REASONS: { id: string; label: string; hint: string }[] = [
  { id: 'waiting_parts', label: 'Attente de pièces', hint: 'à justifier auprès du client' },
  { id: 'waiting_quote', label: 'Attente validation devis', hint: 'à justifier auprès du client' },
  { id: 'waiting_permit', label: 'Attente permis de travail', hint: 'acceptée d’office (imputable au site)' },
  { id: 'client_delay', label: 'Site indisponible', hint: 'acceptée d’office (imputable au site)' },
  { id: 'force_majeure', label: 'Force majeure', hint: 'à justifier auprès du client' },
];
const KIND: Record<QuoteItemInput['kind'], string> = { labor: 'Main d’œuvre', material: 'Fournitures', travel: 'Déplacement', other: 'Autre' };
const SEV: Record<AnomalyInput['severity'], string> = { minor: 'Mineure', major: 'Majeure', critical: 'Critique' };

/** Prochaine action attendue du prestataire sur un OT. */
function nextStep(r: PortalRow): { label: string; tone: 'todo' | 'wait' | 'done' | 'alert' } {
  if (r.report_status === 'validated') return { label: 'Clôturé · signé par le client', tone: 'done' };
  if (r.report_status === 'submitted') return { label: 'Rapport en validation client', tone: 'wait' };
  if (r.report_status === 'rejected') return { label: 'Rapport renvoyé — à corriger', tone: 'alert' };
  if (r.paused_now) return { label: 'En pause — reprendre l’intervention', tone: 'alert' };
  if (!r.quote_status || r.quote_status === 'rejected') return { label: r.quote_status === 'rejected' ? 'Devis refusé — à refaire' : 'Envoyer le devis', tone: 'todo' };
  if (r.quote_status === 'submitted') return { label: 'Devis en validation client', tone: 'wait' };
  return { label: 'Intervenir puis rédiger le rapport', tone: 'todo' };
}

/** Échéance SLA effective = échéance + pauses justifiées. */
function slaLeft(r: PortalRow): { text: string; late: boolean } | null {
  if (!r.sla_due || r.report_status === 'validated') return null;
  const due = new Date(r.sla_due).getTime() + r.paused_h * 3600e3;
  const h = (due - Date.now()) / 3600e3;
  if (r.paused_now) return { text: 'chrono SLA en pause', late: false };
  return h >= 0 ? { text: `SLA dans ${h < 1 ? `${Math.round(h * 60)} min` : `${Math.floor(h)} h`}`, late: false } : { text: `SLA dépassé de ${Math.ceil(-h)} h`, late: true };
}

export function ContractorApp() {
  const { session, ready } = useSession();
  if (!ready) return <div className="kx-center ks-faint">Chargement…</div>;
  if (!session) return <Login />;
  return <ContractorSpace />;
}

function ContractorSpace() {
  const [me, setMe] = useState<PortalMe | null>(null);
  const [contractors, setContractors] = useState<{ id: string; name: string; open_wo: number }[]>([]);
  const [previewId, setPreviewId] = useState<string | null>(null);
  const [rows, setRows] = useState<PortalRow[] | null>(null);
  const [open, setOpen] = useState<PortalRow | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  useEffect(() => {
    fetchPortalMe().then((m) => {
      setMe(m);
      if (!m.is_contractor) fetchPortalContractors().then((cs) => { setContractors(cs); setPreviewId((p) => p ?? cs[0]?.id ?? null); }).catch(() => {});
    }).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
  }, []);

  const scope = me?.is_contractor ? undefined : previewId ?? undefined;
  function load() {
    if (!me || (!me.is_contractor && !previewId)) return;
    fetchPortalBoard(scope).then(setRows).catch((e) => setErr(e instanceof Error ? e.message : String(e)));
  }
  useEffect(load, [me, previewId]); // eslint-disable-line react-hooks/exhaustive-deps

  const name = me?.is_contractor ? me.contractor_name : contractors.find((c) => c.id === previewId)?.name;
  const counts = useMemo(() => {
    const list = rows ?? [];
    return {
      todo: list.filter((r) => nextStep(r).tone === 'todo' || nextStep(r).tone === 'alert').length,
      wait: list.filter((r) => nextStep(r).tone === 'wait').length,
      late: list.filter((r) => slaLeft(r)?.late).length,
      done: list.filter((r) => nextStep(r).tone === 'done').length,
    };
  }, [rows]);
  const flash = (m: string) => { setToast(m); setTimeout(() => setToast(null), 4500); };

  return (
    <div className="kx-shell">
      <header className="kx-top">
        <div className="kx-top__brand">
          <span className="ks-rail__logo" style={{ width: 34, height: 34 }} aria-hidden><HardHat size={17} /></span>
          <div style={{ minWidth: 0 }}>
            <div className="ks-eyebrow">Atlas Keystone · Espace prestataire</div>
            <div className="kx-top__name">{name ?? '—'}</div>
          </div>
        </div>
        <button className="ks-icon-btn" aria-label="Se déconnecter" onClick={() => void signOut()}><LogOut size={17} /></button>
      </header>

      {me && !me.is_contractor && (
        <div className="kx-preview">
          <Eye size={15} />
          <span>Aperçu exploitant — vous voyez le portail tel que le prestataire le voit.</span>
          <select className="ka-select" value={previewId ?? ''} onChange={(e) => { setPreviewId(e.target.value); setRows(null); }} aria-label="Prestataire à prévisualiser">
            {contractors.map((c) => <option key={c.id} value={c.id}>{c.name} · {c.open_wo} OT ouverts</option>)}
          </select>
        </div>
      )}

      <main className="kx-main">
        {toast && <div className="ka-toast"><CheckCircle2 size={16} /> {toast}</div>}
        {err && <div className="ka-toast" style={{ background: 'var(--ks-critical-100)', color: '#8E1E22' }}><AlertTriangle size={16} /> <span className="ks-mono" style={{ fontSize: 12.5 }}>{err}</span></div>}

        <div className="kx-kpis ks-reveal">
          <div className="kx-kpi"><b className="ks-mono">{counts.todo}</b><span>à traiter</span></div>
          <div className="kx-kpi"><b className="ks-mono">{counts.wait}</b><span>chez le client</span></div>
          <div className={`kx-kpi${counts.late ? ' kx-kpi--late' : ''}`}><b className="ks-mono">{counts.late}</b><span>SLA dépassés</span></div>
          <div className="kx-kpi"><b className="ks-mono">{counts.done}</b><span>clôturés</span></div>
        </div>

        <div className="kx-listhead">
          <h1>Mes interventions</h1>
          <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={load}><RefreshCw size={13} /> Actualiser</button>
        </div>

        <div className="kx-list ks-reveal">
          {(rows ?? []).map((r) => {
            const s = nextStep(r);
            const sla = slaLeft(r);
            return (
              <button key={r.wo_id} className={`kx-wo kx-wo--${s.tone}`} onClick={() => setOpen(r)}>
                <div className="kx-wo__top">
                  <span className="ks-mono ks-faint" style={{ fontSize: 11.5 }}>{r.wo_ref}{r.priority <= 1 && <span className="kx-p1">P1</span>}</span>
                  {sla && <span className={`kx-sla${sla.late ? ' kx-sla--late' : ''}`}><Clock size={12} /> {sla.text}</span>}
                </div>
                <div className="kx-wo__title">{r.title}</div>
                <div className="ks-faint" style={{ fontSize: 12.5, display: 'flex', alignItems: 'center', gap: 5 }}>
                  <MapPin size={12} /> {r.location ?? '—'}{r.asset_tag ? ` · ${r.asset_tag}` : ''}
                </div>
                <div className="kx-wo__step"><span>{s.label}</span><ChevronRight size={16} /></div>
              </button>
            );
          })}
          {rows && rows.length === 0 && <div className="kx-empty">Aucune intervention qui vous est confiée pour le moment.</div>}
          {!rows && <div className="kx-empty ks-faint">Chargement…</div>}
        </div>
      </main>

      {open && me && (
        <WoSheet row={open} tenantId={me.tenant_id} onClose={() => setOpen(null)} onDone={(m) => { flash(m); setOpen(null); load(); }} />
      )}
    </div>
  );
}

function WoSheet({ row, tenantId, onClose, onDone }: { row: PortalRow; tenantId: string; onClose: () => void; onDone: (m: string) => void }) {
  const [d, setD] = useState<PortalDetail | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => { fetchPortalDetail(row.wo_id).then(setD).catch((e) => setErr(e instanceof Error ? e.message : String(e))); }, [row.wo_id]);

  async function act(fn: () => Promise<string>) {
    setBusy(true); setErr(null);
    try { onDone(await fn()); } catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); }
  }

  const canQuote = !row.quote_status || row.quote_status === 'rejected';
  const quoteTotal = (d?.quote_items ?? []).reduce((s, i) => s + Number(i.total), 0);
  const canReport = row.quote_status === 'approved' && row.report_status !== 'submitted' && row.report_status !== 'validated';
  const closed = row.report_status === 'validated';

  return (
    <div className="kx-sheet-wrap" onClick={onClose}>
      <section className="kx-sheet" onClick={(e) => e.stopPropagation()} role="dialog" aria-label={row.title}>
        <div className="kx-sheet__grab" aria-hidden />
        <div className="ka-drawer__head">
          <div style={{ minWidth: 0 }}>
            <div className="ks-mono ks-faint" style={{ fontSize: 12 }}>{row.wo_ref} · {row.asset_tag ?? row.location}</div>
            <h2 style={{ fontSize: 20, fontWeight: 800, letterSpacing: '-.02em', margin: '4px 0 0' }}>{row.title}</h2>
          </div>
          <button className="ks-icon-btn" aria-label="Fermer" onClick={onClose}><X size={17} /></button>
        </div>
        {err && <div className="kx-err"><AlertTriangle size={14} /> {err}</div>}

        {/* 1. Devis */}
        <div className="kv-sec">
          <h3><FileText size={15} /> Devis {row.quote_ref && <span className="ks-mono ks-faint">{row.quote_ref}</span>}</h3>
          {canQuote ? (
            <QuoteForm busy={busy} rejected={row.quote_status === 'rejected'}
              onSubmit={(items, notes) => act(async () => { const r = await quoteSubmit(row.wo_id, items, notes); return `Devis ${r.ref} envoyé au client · ${fcfa(Number(r.total))} HT`; })} />
          ) : (
            <>
              {d?.quote_items?.map((i, k) => (
                <div key={k} className="kv-line"><span><span className="ks-faint">{KIND[i.kind as QuoteItemInput['kind']] ?? i.kind} · </span>{i.label} <span className="ks-faint">× {Number(i.qty)}</span></span><b className="ks-mono">{fcfa(Number(i.total))}</b></div>
              ))}
              <div className="kv-line kv-line--total"><span>Total HT</span><b className="ks-mono">{fcfa(quoteTotal)}</b></div>
              <div className={`kx-state kx-state--${row.quote_status === 'approved' ? 'ok' : 'wait'}`}>
                {row.quote_status === 'approved' ? <><CheckCircle2 size={14} /> Approuvé par le client — vous pouvez intervenir</> : <><Clock size={14} /> En attente de validation par le client</>}
              </div>
            </>
          )}
        </div>

        {/* 2. Avenants */}
        {row.quote_status === 'approved' && !closed && (
          <div className="kv-sec">
            <h3><FilePlus2 size={15} /> Avenant (travaux supplémentaires)</h3>
            {d?.variations?.map((v) => (
              <div key={v.id} className="kv-var">
                <div style={{ flex: 1, fontSize: 13 }}>{v.reason}<div className="ks-faint ks-mono" style={{ fontSize: 11.5 }}>+{fcfa(Number(v.extra_cost))} · +{Number(v.extra_hours)} h</div></div>
                <span className="ks-pill" style={{ color: v.status === 'approved' ? 'var(--ks-low)' : v.status === 'rejected' ? 'var(--ks-critical)' : 'var(--ks-amber-700)' }}>
                  {v.status === 'approved' ? 'Accepté' : v.status === 'rejected' ? 'Refusé' : v.status === 'escalated' ? 'En 2ᵉ validation' : 'En attente'}
                </span>
              </div>
            ))}
            <VariationForm busy={busy} quoteTotal={quoteTotal}
              onSubmit={(reason, cost, hours) => act(async () => { await variationSubmit(row.wo_id, reason, cost, hours); return 'Avenant envoyé au client'; })} />
          </div>
        )}

        {/* 3. Chrono SLA */}
        {!closed && row.report_status !== 'submitted' && (
          <div className="kv-sec">
            <h3><Timer size={15} /> Chrono SLA</h3>
            <div className="ks-faint" style={{ fontSize: 12.5, marginBottom: 10 }}>
              Écoulé {row.elapsed_h} h · {row.paused_h} h de pause déduites{row.pending_pause_h > 0 ? ` · ${row.pending_pause_h} h en attente d’acceptation` : ''}
            </div>
            {row.paused_now ? (
              <button className="ks-btn ks-btn--primary kx-wide" disabled={busy} onClick={() => act(async () => { await slaResume(row.wo_id); return 'Intervention reprise — chrono SLA relancé'; })}>
                <Play size={15} /> Reprendre l’intervention
              </button>
            ) : <PauseForm busy={busy} onSubmit={(reason) => act(async () => { await slaPause(row.wo_id, reason); return 'Pause déclarée — le client sera invité à la justifier'; })} />}
          </div>
        )}

        {/* 4. Rapport */}
        <div className="kv-sec">
          <h3><ClipboardSignature size={15} /> Rapport d’intervention</h3>
          {d?.report && (row.report_status === 'submitted' || closed) ? (
            <ReportView report={d.report} />
          ) : canReport ? (
            <>
              {row.report_status === 'rejected' && <div className="kx-state kx-state--alert"><AlertTriangle size={14} /> Le client a renvoyé le rapport précédent : complétez-le et renvoyez-le.</div>}
              <ReportForm busy={busy} tenantId={tenantId} woId={row.wo_id} corrective={row.type === 'corrective'}
                onSubmit={(summary, tech, before, after, anomalies) => act(async () => {
                  await reportSubmit(row.wo_id, summary, tech, before, after, anomalies);
                  return 'Rapport envoyé au client pour signature';
                })} />
            </>
          ) : (
            <div className="ks-faint" style={{ fontSize: 12.5 }}>Disponible une fois le devis approuvé par le client.</div>
          )}
        </div>
      </section>
    </div>
  );
}

function QuoteForm({ busy, rejected, onSubmit }: { busy: boolean; rejected: boolean; onSubmit: (items: QuoteItemInput[], notes: string) => void }) {
  const [items, setItems] = useState<QuoteItemInput[]>([{ kind: 'labor', label: '', qty: 1, unit_price: 0 }]);
  const [notes, setNotes] = useState('');
  const total = items.reduce((s, i) => s + i.qty * i.unit_price, 0);
  const valid = items.length > 0 && items.every((i) => i.label.trim() && i.qty > 0 && i.unit_price >= 0) && total > 0;
  const set = (k: number, patch: Partial<QuoteItemInput>) => setItems((xs) => xs.map((x, i) => (i === k ? { ...x, ...patch } : x)));
  return (
    <>
      {rejected && <div className="kx-state kx-state--alert"><AlertTriangle size={14} /> Votre précédent devis a été refusé : proposez-en un nouveau.</div>}
      {items.map((it, k) => (
        <div key={k} className="kx-qline">
          <select className="ka-select" value={it.kind} onChange={(e) => set(k, { kind: e.target.value as QuoteItemInput['kind'] })} aria-label="Nature">
            {(Object.keys(KIND) as QuoteItemInput['kind'][]).map((x) => <option key={x} value={x}>{KIND[x]}</option>)}
          </select>
          <input className="kx-in kx-in--grow" placeholder="Désignation" value={it.label} onChange={(e) => set(k, { label: e.target.value })} />
          <input className="kx-in kx-in--num" type="number" inputMode="decimal" min={0} step="0.5" aria-label="Quantité" value={it.qty} onChange={(e) => set(k, { qty: Number(e.target.value) })} />
          <input className="kx-in kx-in--price" type="number" inputMode="numeric" min={0} step="500" aria-label="Prix unitaire FCFA" value={it.unit_price} onChange={(e) => set(k, { unit_price: Number(e.target.value) })} />
          <button className="ks-icon-btn" aria-label="Supprimer la ligne" disabled={items.length === 1} onClick={() => setItems((xs) => xs.filter((_, i) => i !== k))}><Trash2 size={14} /></button>
        </div>
      ))}
      <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => setItems((xs) => [...xs, { kind: 'material', label: '', qty: 1, unit_price: 0 }])}><Plus size={13} /> Ajouter une ligne</button>
      <textarea className="kt-field ki-input" rows={2} style={{ width: '100%', marginTop: 10 }} placeholder="Conditions, délai d’intervention…" value={notes} onChange={(e) => setNotes(e.target.value)} />
      <div className="kv-line kv-line--total"><span>Total HT</span><b className="ks-mono">{fcfa(total)}</b></div>
      <button className="ks-btn ks-btn--primary kx-wide" disabled={busy || !valid} onClick={() => onSubmit(items.map((i) => ({ ...i, label: i.label.trim() })), notes)}>
        <Send size={15} /> {busy ? 'Envoi…' : 'Envoyer le devis au client'}
      </button>
    </>
  );
}

function VariationForm({ busy, quoteTotal, onSubmit }: { busy: boolean; quoteTotal: number; onSubmit: (reason: string, cost: number, hours: number) => void }) {
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState('');
  const [cost, setCost] = useState(0);
  const [hours, setHours] = useState(0);
  if (!open) return <button className="ks-btn ks-btn--ghost ks-btn--sm" onClick={() => setOpen(true)}><Plus size={13} /> Déclarer des travaux supplémentaires</button>;
  const pct = quoteTotal > 0 ? Math.round((cost / quoteTotal) * 100) : 0;
  return (
    <div className="kx-box">
      <textarea className="kt-field ki-input" rows={2} style={{ width: '100%' }} placeholder="Ce qui a été découvert et pourquoi c’est nécessaire" value={reason} onChange={(e) => setReason(e.target.value)} />
      <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
        <label className="kx-lbl">Montant HT (FCFA)<input className="kx-in" type="number" inputMode="numeric" min={0} step="500" value={cost} onChange={(e) => setCost(Number(e.target.value))} /></label>
        <label className="kx-lbl">Heures en plus<input className="kx-in" type="number" inputMode="decimal" min={0} step="0.5" value={hours} onChange={(e) => setHours(Number(e.target.value))} /></label>
      </div>
      {pct > 20 && <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 6, color: 'var(--ks-high)' }}>+{pct} % du devis : le client devra faire valider par une seconde personne.</div>}
      <button className="ks-btn ks-btn--primary kx-wide" disabled={busy || !reason.trim() || cost <= 0} onClick={() => onSubmit(reason.trim(), cost, hours)}><Send size={15} /> Envoyer l’avenant</button>
    </div>
  );
}

function PauseForm({ busy, onSubmit }: { busy: boolean; onSubmit: (reason: string) => void }) {
  const [reason, setReason] = useState(PAUSE_REASONS[0].id);
  const hint = PAUSE_REASONS.find((p) => p.id === reason)?.hint;
  return (
    <>
      <div className="kx-chips" role="radiogroup" aria-label="Motif de pause">
        {PAUSE_REASONS.map((p) => (
          <button key={p.id} role="radio" aria-checked={reason === p.id} className={`kx-chip${reason === p.id ? ' kx-chip--on' : ''}`} onClick={() => setReason(p.id)}>{p.label}</button>
        ))}
      </div>
      <div className="ks-faint" style={{ fontSize: 11.5, margin: '6px 0 10px' }}>Pause {hint}. Seules les pauses justifiées sont déduites du chrono.</div>
      <button className="ks-btn ks-btn--ghost kx-wide" disabled={busy} onClick={() => onSubmit(reason)}><Pause size={15} /> Mettre en pause</button>
    </>
  );
}

function PhotoPicker({ label, paths, onAdd, onRemove, tenantId, woId, phase }: {
  label: string; paths: string[]; onAdd: (p: string) => void; onRemove: (p: string) => void; tenantId: string; woId: string; phase: 'avant' | 'apres';
}) {
  const input = useRef<HTMLInputElement>(null);
  const [urls, setUrls] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => { signedPhotoUrls(paths).then(setUrls).catch(() => {}); }, [paths]);
  async function pick(files: FileList | null) {
    if (!files?.length) return;
    setBusy(true); setErr(null);
    try { for (const f of Array.from(files)) onAdd(await uploadWoPhoto(tenantId, woId, phase, f)); }
    catch (e) { setErr(e instanceof Error ? e.message : String(e)); } finally { setBusy(false); if (input.current) input.current.value = ''; }
  }
  return (
    <div>
      <div className="ks-eyebrow" style={{ marginBottom: 6 }}>{label}</div>
      <div className="kx-photos">
        {paths.map((p) => (
          <div key={p} className="kx-photo">
            {urls[p] ? <img src={urls[p]} alt={label} /> : <Camera size={16} />}
            <button className="kx-photo__x" aria-label="Retirer la photo" onClick={() => onRemove(p)}><X size={11} /></button>
          </div>
        ))}
        <button className="kx-photo kx-photo--add" disabled={busy} onClick={() => input.current?.click()} aria-label={`Ajouter une photo ${label.toLowerCase()}`}>
          {busy ? '…' : <ImagePlus size={18} />}
        </button>
        <input ref={input} type="file" accept="image/*" capture="environment" multiple hidden onChange={(e) => void pick(e.target.files)} />
      </div>
      {err && <div className="ks-mono" style={{ color: 'var(--ks-critical)', fontSize: 11.5, marginTop: 4 }}>{err}</div>}
    </div>
  );
}

function ReportForm({ busy, tenantId, woId, corrective, onSubmit }: {
  busy: boolean; tenantId: string; woId: string; corrective: boolean;
  onSubmit: (summary: string, tech: string, before: string[], after: string[], anomalies: AnomalyInput[]) => void;
}) {
  const [summary, setSummary] = useState('');
  const [tech, setTech] = useState('');
  const [before, setBefore] = useState<string[]>([]);
  const [after, setAfter] = useState<string[]>([]);
  const [anoms, setAnoms] = useState<AnomalyInput[]>([]);
  const photosOk = !corrective || (before.length > 0 && after.length > 0);
  const valid = summary.trim().length >= 10 && tech.trim() && photosOk && anoms.every((a) => a.description.trim());
  return (
    <>
      <textarea className="kt-field ki-input" rows={3} style={{ width: '100%' }} placeholder="Travaux réalisés, mesures, essais de remise en service…" value={summary} onChange={(e) => setSummary(e.target.value)} />
      <div className="kv-photos">
        <PhotoPicker label="Avant" phase="avant" tenantId={tenantId} woId={woId} paths={before} onAdd={(p) => setBefore((x) => [...x, p])} onRemove={(p) => setBefore((x) => x.filter((y) => y !== p))} />
        <PhotoPicker label="Après" phase="apres" tenantId={tenantId} woId={woId} paths={after} onAdd={(p) => setAfter((x) => [...x, p])} onRemove={(p) => setAfter((x) => x.filter((y) => y !== p))} />
      </div>
      {corrective && !photosOk && <div className="ks-faint" style={{ fontSize: 11.5, marginBottom: 8 }}>Correctif : au moins une photo avant et une photo après sont obligatoires.</div>}

      <div className="ks-eyebrow" style={{ margin: '10px 0 6px' }}>Anomalies constatées</div>
      {anoms.map((a, k) => (
        <div key={k} className="kx-qline">
          <select className="ka-select" value={a.severity} aria-label="Gravité" onChange={(e) => setAnoms((xs) => xs.map((x, i) => (i === k ? { ...x, severity: e.target.value as AnomalyInput['severity'] } : x)))}>
            {(Object.keys(SEV) as AnomalyInput['severity'][]).map((s) => <option key={s} value={s}>{SEV[s]}</option>)}
          </select>
          <input className="kx-in kx-in--grow" placeholder="Description de l’anomalie" value={a.description} onChange={(e) => setAnoms((xs) => xs.map((x, i) => (i === k ? { ...x, description: e.target.value } : x)))} />
          <button className="ks-icon-btn" aria-label="Retirer l’anomalie" onClick={() => setAnoms((xs) => xs.filter((_, i) => i !== k))}><Trash2 size={14} /></button>
        </div>
      ))}
      <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => setAnoms((xs) => [...xs, { severity: 'minor', description: '' }])}><Plus size={13} /> Signaler une anomalie</button>
      {anoms.some((a) => a.severity !== 'minor') && <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 6 }}>Les anomalies majeures et critiques ouvriront un OT de suivi à la signature du client.</div>}

      <input className="kx-in" style={{ width: '100%', marginTop: 12 }} placeholder="Nom du technicien (signature)" value={tech} onChange={(e) => setTech(e.target.value)} />
      <button className="ks-btn ks-btn--primary kx-wide" disabled={busy || !valid} onClick={() => onSubmit(summary.trim(), tech.trim(), before, after, anoms)}>
        <ClipboardSignature size={15} /> {busy ? 'Envoi…' : 'Signer et envoyer le rapport'}
      </button>
    </>
  );
}

function ReportView({ report }: { report: NonNullable<PortalDetail['report']> }) {
  const [urls, setUrls] = useState<Record<string, string>>({});
  useEffect(() => { signedPhotoUrls([...report.before, ...report.after]).then(setUrls).catch(() => {}); }, [report]);
  return (
    <>
      <div style={{ fontSize: 13, lineHeight: 1.55 }}>{report.summary}</div>
      <div className="ks-faint" style={{ fontSize: 12, marginTop: 4 }}>Signé par {report.technician}</div>
      <div className="kv-photos">
        {(['before', 'after'] as const).map((k) => (
          <div key={k}>
            <div className="ks-eyebrow" style={{ marginBottom: 6 }}>{k === 'before' ? 'Avant' : 'Après'}</div>
            <div className="kx-photos">
              {report[k].map((p) => <div key={p} className="kx-photo">{isStoredPhoto(p) && urls[p] ? <img src={urls[p]} alt="" /> : <Camera size={16} />}</div>)}
            </div>
          </div>
        ))}
      </div>
      <div className={`kx-state kx-state--${report.status === 'validated' ? 'ok' : 'wait'}`}>
        {report.status === 'validated' ? <><CheckCircle2 size={14} /> Signé par le client ({report.client_signed_by})</> : <><Clock size={14} /> En attente de signature du client</>}
      </div>
    </>
  );
}

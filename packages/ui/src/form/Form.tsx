// Feuille de formulaire Atlas Keystone : rendu de la maquette v4 (rail de sections, cartes de section, champs),
// comportement du cahier des charges (D30 page continue, Lot 1 partie 2 §7, partie 3 §9.5.1).
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { AlertCircle, Camera, Check, ChevronsLeft, ChevronsRight, FileUp, Upload, X } from 'lucide-react';
import {
  FORM_MESSAGES, fmt, formatBytes, groupDigits, isEmpty, isVisible, isoToFr, parseAmount, parseFrDate, requiredProgress,
  sectionState, sniffMime, submittedValues, toAppError, validateForm,
  type FieldSpec, type FileValue, type FormSpec, type FormValues, type SignatureValue,
} from '@keystone/domain';

const DEFAULT_ACCEPT = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf'];
const DEFAULT_MAX_BYTES = 25 * 1024 * 1024;
const ACCEPT_LABEL: Record<string, string> = { 'image/jpeg': 'JPG', 'image/png': 'PNG', 'image/webp': 'WEBP', 'image/heic': 'HEIC', 'application/pdf': 'PDF' };

// ---------------------------------------------------------------- Brouillon local (IndexedDB, Lot 1 §7.27)

const DB = 'keystone-drafts';
function idb(): Promise<IDBDatabase> {
  return new Promise((res, rej) => {
    const r = indexedDB.open(DB, 1);
    r.onupgradeneeded = () => r.result.createObjectStore('drafts');
    r.onsuccess = () => res(r.result);
    r.onerror = () => rej(r.error);
  });
}
export const drafts = {
  async get(key: string): Promise<{ at: string; values: FormValues } | undefined> {
    try { const db = await idb(); return await new Promise((res) => { const q = db.transaction('drafts').objectStore('drafts').get(key); q.onsuccess = () => res(q.result); q.onerror = () => res(undefined); }); } catch { return undefined; }
  },
  async set(key: string, values: FormValues): Promise<void> {
    try { const db = await idb(); db.transaction('drafts', 'readwrite').objectStore('drafts').put({ at: new Date().toISOString(), values }, key); } catch { /* stockage indisponible : la saisie reste en mémoire */ }
  },
  async del(key: string): Promise<void> {
    try { const db = await idb(); db.transaction('drafts', 'readwrite').objectStore('drafts').delete(key); } catch { /* idem */ }
  },
};

// ---------------------------------------------------------------- Photo : compression sur l'appareil, EXIF retiré

async function compressImage(file: File): Promise<Blob> {
  const url = URL.createObjectURL(file);
  try {
    const img = await new Promise<HTMLImageElement>((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = url; });
    const k = Math.min(1, 2048 / Math.max(img.naturalWidth, img.naturalHeight));
    const c = document.createElement('canvas');
    c.width = Math.round(img.naturalWidth * k); c.height = Math.round(img.naturalHeight * k);
    c.getContext('2d')?.drawImage(img, 0, 0, c.width, c.height);
    return await new Promise<Blob>((res, rej) => c.toBlob((b) => (b ? res(b) : rej(new Error('encode'))), 'image/jpeg', 0.8));
  } finally { URL.revokeObjectURL(url); }
}

// ---------------------------------------------------------------- Champs

interface FieldProps {
  f: FieldSpec;
  value: unknown;
  error: string | null;
  showError: boolean;
  onChange: (v: unknown) => void;
  onBlur: () => void;
  signer: string;
  now: Date;
}

function FieldShell({ f, error, showError, children, counter }: { f: FieldSpec; error: string | null; showError: boolean; children: ReactNode; counter?: string }) {
  const id = `akf-${f.key}`;
  const wide = !f.half || ['textarea', 'file', 'photo', 'signature', 'radio'].includes(f.component);
  return (
    <div id={`akw-${f.key}`} className="akf-field" style={{ gridColumn: wide ? '1 / -1' : 'auto' }}>
      {f.component !== 'checkbox' && (
        <div className="akf-field__head">
          <label htmlFor={id} id={`${id}-l`}>{f.label}{f.required && <span className="akf-req" aria-hidden> *</span>}</label>
          {counter && <span className="akf-counter" aria-hidden>{counter}</span>}
        </div>
      )}
      {children}
      {showError && error ? (
        <div id={`${id}-e`} className="akf-error"><AlertCircle size={12} aria-hidden />{error}</div>
      ) : f.help ? (
        <div id={`${id}-h`} className="akf-help">{f.help}</div>
      ) : null}
    </div>
  );
}

function aria(f: FieldSpec, error: string | null, showError: boolean) {
  const id = `akf-${f.key}`;
  const desc = [showError && error ? `${id}-e` : '', !(showError && error) && f.help ? `${id}-h` : ''].filter(Boolean).join(' ');
  return { id, 'aria-invalid': showError && !!error, 'aria-required': f.required, 'aria-describedby': desc || undefined };
}

const maxLen = (f: FieldSpec) => (f.rules?.find((r) => r.rule === 'max_length') as { n: number } | undefined)?.n ?? (f.component === 'textarea' ? 2000 : 160);

function DateInput({ f, value, error, showError, onChange, onBlur, now, withTime }: FieldProps & { withTime?: boolean }) {
  const iso = typeof value === 'string' ? value : '';
  const [text, setText] = useState(iso ? isoToFr(iso) : '');
  const [time, setTime] = useState(withTime && iso.length > 10 ? iso.slice(11, 16) : '');
  const [local, setLocal] = useState<string | null>(null);
  useEffect(() => { setText(iso ? isoToFr(iso) : ''); if (withTime) setTime(iso.length > 10 ? iso.slice(11, 16) : ''); }, [iso, withTime]);
  const commit = (t = text, h = time) => {
    if (!t.trim()) { setLocal(null); onChange(''); onBlur(); return; }
    const p = parseFrDate(t, now);
    if ('error' in p) { setLocal(p.error === 'date_invalid' ? fmt(FORM_MESSAGES.date_invalid, { jour: p.jour ?? '' }) : FORM_MESSAGES.date_incomplete); onChange(''); onBlur(); return; }
    setLocal(null);
    setText(isoToFr(p.iso));
    const hh = /^(\d{1,2})[:h]?(\d{2})$/.exec(h.trim());
    onChange(withTime ? (hh ? `${p.iso}T${hh[1].padStart(2, '0')}:${hh[2]}:00` : `${p.iso}T00:00:00`) : p.iso);
    onBlur();
  };
  const err = local ?? error;
  return (
    <FieldShell f={f} error={err} showError={!!local || showError}>
      <div style={{ display: 'flex', gap: 8 }} role={withTime ? 'group' : undefined} aria-labelledby={withTime ? `akf-${f.key}-l` : undefined}>
        <input {...aria(f, err, !!local || showError)} className="akf-input akf-mono" style={{ maxWidth: 170 }} inputMode="numeric" placeholder="JJ/MM/AAAA"
          value={text} maxLength={12} onChange={(e) => setText(e.target.value)} onBlur={() => commit()} />
        {withTime && (
          <input className="akf-input akf-mono" style={{ maxWidth: 110 }} aria-label={`${f.label}, heure`} placeholder="HH:MM" inputMode="numeric"
            value={time} maxLength={5} onChange={(e) => setTime(e.target.value)} onBlur={() => commit(text, time)} />
        )}
      </div>
    </FieldShell>
  );
}

function FilesInput({ f, value, error, showError, onChange, onBlur, now }: FieldProps) {
  const files = (Array.isArray(value) ? value : []) as FileValue[];
  const [local, setLocal] = useState<string | null>(null);
  const [drag, setDrag] = useState(false);
  const accept = f.accept ?? (f.component === 'photo' ? DEFAULT_ACCEPT.filter((m) => m.startsWith('image/')) : DEFAULT_ACCEPT);
  const maxB = f.maxBytes ?? DEFAULT_MAX_BYTES;
  const maxN = f.maxFiles ?? 10;
  const add = async (list: FileList | null) => {
    if (!list?.length) return;
    const next = [...files];
    for (const file of Array.from(list)) {
      if (next.length >= maxN) { setLocal(fmt(FORM_MESSAGES.max_length, { n: maxN }).replace('caractères', 'fichiers').replace('Texte', 'Envoi')); break; }
      const head = new Uint8Array(await file.slice(0, 16).arrayBuffer());
      const mime = sniffMime(head);
      if (!mime || !accept.includes(mime)) { setLocal(fmt(FORM_MESSAGES.file_type, { formats: accept.map((m) => ACCEPT_LABEL[m] ?? m).join(', ') })); continue; }
      let blob: Blob = file;
      if (mime !== 'application/pdf' && mime !== 'image/heic') { try { blob = await compressImage(file); } catch { /* garde l'original */ } }
      if (blob.size > maxB) { setLocal(fmt(FORM_MESSAGES.file_too_large, { taille: formatBytes(blob.size), limite: formatBytes(maxB) })); continue; }
      setLocal(null);
      next.push({ name: file.name.slice(0, 120), size: blob.size, type: blob === file ? mime : 'image/jpeg', at: now.toISOString(), url: mime.startsWith('image/') ? URL.createObjectURL(blob) : undefined });
    }
    onChange(next); onBlur();
  };
  const err = local ?? error;
  return (
    <FieldShell f={f} error={err} showError={!!local || showError}>
      <label
        className="akf-drop" data-drag={drag} data-invalid={(!!local || showError) && !!err}
        onDragOver={(e) => { e.preventDefault(); setDrag(true); }} onDragLeave={() => setDrag(false)}
        onDrop={(e) => { e.preventDefault(); setDrag(false); void add(e.dataTransfer.files); }}
      >
        {f.component === 'photo' ? <Camera size={18} aria-hidden /> : <Upload size={18} aria-hidden />}
        <span>{f.component === 'photo' ? 'Prendre une photo ou ' : 'Glissez vos fichiers ici ou '}<u>parcourez</u></span>
        <span className="akf-help">{accept.map((m) => ACCEPT_LABEL[m] ?? m).join(', ')}, {formatBytes(maxB)} au plus</span>
        <input {...aria(f, err, !!local || showError)} type="file" multiple={maxN > 1} accept={accept.join(',')}
          capture={f.component === 'photo' ? 'environment' : undefined} className="akf-sr" onChange={(e) => { void add(e.target.files); e.target.value = ''; }} />
      </label>
      {files.length > 0 && (
        <ul className="akf-files">
          {files.map((x, i) => (
            <li key={`${x.name}-${i}`}>
              {x.url ? <span className="akf-thumb" style={{ backgroundImage: `url(${x.url})` }} /> : <span className="akf-thumb akf-thumb--doc"><FileUp size={16} aria-hidden /></span>}
              <span className="akf-files__name" title={x.name}>{x.name}</span>
              <span className="akf-help">{formatBytes(x.size)}</span>
              <button type="button" className="akf-icon" aria-label={`Retirer ${x.name}`} onClick={() => onChange(files.filter((_, j) => j !== i))}><X size={14} aria-hidden /></button>
            </li>
          ))}
        </ul>
      )}
    </FieldShell>
  );
}

function SignatureInput({ f, value, error, showError, onChange, onBlur, signer }: FieldProps) {
  const sig = value && typeof value === 'object' && !Array.isArray(value) ? (value as SignatureValue) : null;
  const cv = useRef<HTMLCanvasElement>(null);
  const pts = useRef(0);
  const drawing = useRef(false);
  const [ink, setInk] = useState(0);
  const [local, setLocal] = useState<string | null>(null);
  const pos = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const c = e.currentTarget; const r = c.getBoundingClientRect();
    return [((e.clientX - r.left) * c.width) / r.width, ((e.clientY - r.top) * c.height) / r.height] as const;
  };
  const clear = () => { cv.current?.getContext('2d')?.clearRect(0, 0, 900, 240); pts.current = 0; setInk(0); setLocal(null); onChange(undefined); };
  const validate = () => {
    if (pts.current < 20) { setLocal('Signature trop courte, recommencez.'); return; }
    onChange({ by: signer, at: new Date().toISOString(), points: pts.current, image: cv.current?.toDataURL('image/png') });
    setLocal(null); onBlur();
  };
  const err = local ?? error;
  if (sig) return (
    <FieldShell f={f} error={err} showError={showError}>
      <div className="akf-sig akf-sig--done">
        {sig.image && <img src={sig.image} alt={`Signature de ${sig.by}`} />}
        <div className="akf-help">Signé par {sig.by} le {new Date(sig.at).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })}</div>
        <button type="button" className="akf-link" onClick={clear}>Effacer</button>
      </div>
    </FieldShell>
  );
  return (
    <FieldShell f={f} error={err} showError={!!local || showError}>
      <div className="akf-sig" data-invalid={(!!local || showError) && !!err}>
        <div className="akf-help">Signataire : {signer}</div>
        <canvas
          ref={cv} width={900} height={240} role="img" aria-label="Zone de signature" {...{ id: `akf-${f.key}` }}
          onPointerDown={(e) => { e.currentTarget.setPointerCapture(e.pointerId); drawing.current = true; const c = e.currentTarget.getContext('2d'); if (!c) return; const [x, y] = pos(e); c.lineWidth = 3; c.lineCap = 'round'; c.lineJoin = 'round'; c.strokeStyle = '#16150F'; c.beginPath(); c.moveTo(x, y); }}
          onPointerMove={(e) => { if (!drawing.current) return; const c = e.currentTarget.getContext('2d'); if (!c) return; const [x, y] = pos(e); c.lineTo(x, y); c.stroke(); pts.current += 1; if (pts.current % 5 === 0) setInk(pts.current); }}
          onPointerUp={() => { drawing.current = false; setInk(pts.current); }}
        />
        {!ink && <span className="akf-sig__ph" aria-hidden>Signez ici</span>}
        <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
          <button type="button" className="akf-btn akf-btn--ghost" onClick={clear}>Effacer</button>
          <button type="button" className="akf-btn akf-btn--primary" onClick={validate} disabled={!ink} title={!ink ? 'Tracez votre signature' : undefined}>Valider la signature</button>
        </div>
      </div>
    </FieldShell>
  );
}

export function FieldInput(p: FieldProps) {
  const { f, value, error, showError, onChange, onBlur } = p;
  const v = typeof value === 'string' ? value : '';
  const a = aria(f, error, showError);
  switch (f.component) {
    case 'date': return <DateInput {...p} />;
    case 'datetime': return <DateInput {...p} withTime />;
    case 'file': case 'photo': return <FilesInput {...p} />;
    case 'signature': return <SignatureInput {...p} />;
    case 'textarea': {
      const max = maxLen(f);
      return (
        <FieldShell f={f} error={error} showError={showError} counter={v.length >= max * 0.8 ? `${v.length} sur ${max}` : undefined}>
          <textarea {...a} className="akf-input akf-area" rows={3} maxLength={max} value={v} onChange={(e) => onChange(e.target.value)} onBlur={onBlur} />
        </FieldShell>
      );
    }
    case 'number': return (
      <FieldShell f={f} error={error} showError={showError}>
        <div className="akf-affix">
          <input {...a} className="akf-input akf-mono" style={{ textAlign: 'right', paddingRight: f.unit ? 56 : 12 }} inputMode="decimal"
            aria-label={f.unit ? `${f.label}, en ${f.unit}` : undefined} value={v} maxLength={20}
            onChange={(e) => onChange(e.target.value.replace('.', ','))} onBlur={onBlur} />
          {f.unit && <span className="akf-suffix">{f.unit}</span>}
        </div>
      </FieldShell>
    );
    case 'amount': return (
      <FieldShell f={f} error={error} showError={showError}>
        <div className="akf-affix">
          <input {...a} className="akf-input akf-mono" style={{ textAlign: 'right', paddingRight: 64 }} inputMode="numeric" value={v} maxLength={24}
            aria-label={`${f.label}, en francs CFA`}
            onChange={(e) => onChange(e.target.value)}
            onBlur={() => { const r = parseAmount(v); if ('value' in r) onChange(groupDigits(r.value)); onBlur(); }} />
          <span className="akf-suffix">{f.unit ?? 'FCFA'}</span>
        </div>
      </FieldShell>
    );
    case 'select': return (
      <FieldShell f={f} error={error} showError={showError}>
        <select {...a} className="akf-input akf-select" value={v} onChange={(e) => onChange(e.target.value)} onBlur={onBlur} data-empty={!v}>
          <option value="" disabled>Sélectionner</option>
          {f.options?.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
      </FieldShell>
    );
    case 'radio': return (
      <FieldShell f={f} error={error} showError={showError}>
        <div role="radiogroup" aria-labelledby={`akf-${f.key}-l`} {...{ id: a.id, 'aria-invalid': a['aria-invalid'], 'aria-describedby': a['aria-describedby'] }}
          className={(f.options ?? []).every((o) => !o.description && o.label.length <= 34) && (f.options ?? []).length <= 4 ? 'akf-seg' : 'akf-cards'} data-invalid={showError && !!error}>
          {f.options?.map((o) => (
            <button type="button" role="radio" key={o.value} aria-checked={v === o.value} onClick={() => { onChange(o.value); onBlur(); }}>
              <span>{o.label}</span>{o.description && <small>{o.description}</small>}
            </button>
          ))}
        </div>
      </FieldShell>
    );
    case 'rating': return (
      <FieldShell f={f} error={error} showError={showError}>
        <div role="radiogroup" aria-labelledby={`akf-${f.key}-l`} className="akf-seg">
          {[1, 2, 3, 4, 5].map((n) => (
            <button type="button" role="radio" key={n} aria-checked={v === String(n)} aria-label={`${n} sur 5`} onClick={() => { onChange(String(n)); onBlur(); }} style={{ width: 40 }}>{n}</button>
          ))}
        </div>
      </FieldShell>
    );
    case 'checkbox': return (
      <FieldShell f={f} error={error} showError={showError}>
        <label className="akf-check">
          <input type="checkbox" {...a} checked={value === true} onChange={(e) => { onChange(e.target.checked); onBlur(); }} />
          <span>{f.label}{f.required && <span className="akf-req" aria-hidden> *</span>}</span>
        </label>
      </FieldShell>
    );
    default: {
      const max = maxLen(f);
      return (
        <FieldShell f={f} error={error} showError={showError} counter={v.length >= max * 0.8 ? `${v.length} sur ${max}` : undefined}>
          <input {...a} className="akf-input" value={v} maxLength={max} onChange={(e) => onChange(e.target.value)} onBlur={onBlur} />
        </FieldShell>
      );
    }
  }
}

// ---------------------------------------------------------------- Feuille de formulaire

export interface FormSheetProps {
  spec: FormSpec;
  eyebrow: string;
  /** Clé du brouillon local (IndexedDB) ; absente = pas de brouillon. */
  draftKey?: string;
  initial?: FormValues;
  signer: string;
  primaryLabel: string;
  /** Envoi : en cas d'échec, l'erreur (PostgREST ou autre) est traduite par le catalogue des messages (A69). */
  onSubmit: (values: FormValues) => Promise<void>;
  onClose: () => void;
  now?: () => Date;
}

export function FormSheet({ spec, eyebrow, draftKey, initial, signer, primaryLabel, onSubmit, onClose, now = () => new Date() }: FormSheetProps) {
  const [values, setValues] = useState<FormValues>(() => {
    const v: FormValues = { ...(initial ?? {}) };
    for (const s of spec.sections) for (const f of s.fields) if (v[f.key] === undefined && f.default !== undefined) v[f.key] = f.default;
    return v;
  });
  const [touched, setTouched] = useState<Record<string, boolean>>({});
  const [tried, setTried] = useState(false);
  const [dirty, setDirty] = useState(false);
  const [saving, setSaving] = useState(false);
  const [serverErr, setServerErr] = useState<{ message: string; code?: string } | null>(null);
  const [guard, setGuard] = useState(false);
  const [draftOffer, setDraftOffer] = useState<{ at: string; values: FormValues } | null>(null);
  const [savedAt, setSavedAt] = useState<Date | null>(null);
  const [railOpen, setRailOpen] = useState(true);
  const [current, setCurrent] = useState(spec.sections[0]?.id);
  const [secPanel, setSecPanel] = useState(false);
  const navLock = useRef(0);
  const body = useRef<HTMLDivElement>(null);
  const errSum = useRef<HTMLDivElement>(null);
  const opener = useRef<Element | null>(null);
  const t0 = useMemo(now, []); // eslint-disable-line react-hooks/exhaustive-deps

  const errors = useMemo(() => validateForm(spec, values, { now: t0 }), [spec, values, t0]);
  const shown = useCallback((k: string) => tried || !!touched[k], [tried, touched]);
  const progress = requiredProgress(spec, values);
  const sections = spec.sections.filter((s) => isVisible(s.showIf, values));

  useEffect(() => { opener.current = document.activeElement; return () => { (opener.current as HTMLElement | null)?.focus?.(); }; }, []);
  useEffect(() => { if (draftKey) void drafts.get(draftKey).then((d) => { if (d && Object.keys(d.values).length) setDraftOffer(d); }); }, [draftKey]);
  // Sauvegarde locale automatique toutes les 5 s (Lot 1 §7.27).
  useEffect(() => {
    if (!draftKey || !dirty) return;
    const t = window.setTimeout(() => { void drafts.set(draftKey, values); setSavedAt(new Date()); }, 5000);
    return () => window.clearTimeout(t);
  }, [draftKey, dirty, values]);
  // Section courante suivant le défilement.
  useEffect(() => {
    const root = body.current; if (!root) return;
    const io = new IntersectionObserver((es) => { if (Date.now() < navLock.current) return; const vis = es.filter((e) => e.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)[0]; if (vis) setCurrent(vis.target.id.replace('aks-', '')); }, { root, rootMargin: '0px 0px -60% 0px' });
    root.querySelectorAll('section[id^="aks-"]').forEach((el) => io.observe(el));
    const onScroll = () => { if (Date.now() < navLock.current) return; if (root.scrollTop + root.clientHeight >= root.scrollHeight - 4) { const last = root.querySelectorAll('section[id^="aks-"]'); const el = last[last.length - 1]; if (el) setCurrent(el.id.replace('aks-', '')); } };
    root.addEventListener('scroll', onScroll, { passive: true });
    return () => { io.disconnect(); root.removeEventListener('scroll', onScroll); };
  }, [sections.length]);

  const set = (k: string, v: unknown) => { setValues((s) => ({ ...s, [k]: v })); setDirty(true); setServerErr(null); };
  const touch = (k: string) => setTouched((t) => (t[k] ? t : { ...t, [k]: true }));
  const goSection = (id: string) => { navLock.current = Date.now() + 700; setCurrent(id); const el = document.getElementById(`aks-${id}`); el?.scrollIntoView({ block: 'start' }); (el?.querySelector('h3') as HTMLElement | null)?.focus(); };
  const goField = (k: string) => { document.getElementById(`akw-${k}`)?.scrollIntoView({ block: 'center' }); document.getElementById(`akf-${k}`)?.focus({ preventScroll: true }); };
  const close = () => (dirty ? setGuard(true) : onClose());

  const submit = async () => {
    if (saving) return;
    setTried(true);
    if (errors.ordered.length) { setTimeout(() => errSum.current?.focus(), 0); body.current?.scrollTo({ top: 0 }); return; }
    setSaving(true);
    try {
      await onSubmit(submittedValues(spec, values));
      if (draftKey) await drafts.del(draftKey);
      setDirty(false); onClose();
    } catch (e) {
      // Traduction par le catalogue (A69) : jamais le message technique brut à l'écran.
      const app = toAppError(e);
      setServerErr({ message: app.message, code: app.code });
      if (draftKey) void drafts.set(draftKey, values);
    } finally { setSaving(false); }
  };

  useEffect(() => {
    const k = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { e.preventDefault(); if (guard) setGuard(false); else close(); }
      if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); void submit(); }
    };
    window.addEventListener('keydown', k);
    return () => window.removeEventListener('keydown', k);
  });

  const STATE_LABEL = { complete: 'Complet', incomplete: '', error: '', optional: 'Facultatif' } as const;
  const completeN = sections.filter((x) => sectionState(x, values, errors.byKey, shown).state === 'complete').length;
  const curIdx = Math.max(0, sections.findIndex((x) => x.id === current));
  const railItems = (full: boolean) => sections.map((s, i) => {
              const st = sectionState(s, values, errors.byKey, shown);
              const sub = st.state === 'error' ? `${st.errors} erreur${st.errors > 1 ? 's' : ''}` : st.state === 'incomplete' ? `${st.done} sur ${st.total} obligatoires` : STATE_LABEL[st.state];
              return (
                <a key={s.id} href={`#aks-${s.id}`} className="akf-rail__item" data-state={st.state} aria-current={current === s.id ? 'location' : undefined}
                  aria-label={`${s.title}, ${st.state === 'complete' ? 'complète' : st.state === 'optional' ? 'facultative' : st.state === 'error' ? `en erreur, ${st.errors} champ${st.errors > 1 ? 's' : ''}` : `incomplète, ${st.total - st.done} champ${st.total - st.done > 1 ? 's' : ''} obligatoire${st.total - st.done > 1 ? 's' : ''} restant${st.total - st.done > 1 ? 's' : ''}`}`}
                  onClick={(e) => { e.preventDefault(); setSecPanel(false); goSection(s.id); }} title={s.title}>
                  <span className="akf-pastille">{st.state === 'complete' ? <Check size={11} aria-hidden /> : st.state === 'error' ? <AlertCircle size={11} aria-hidden /> : i + 1}</span>
                  {full && <span style={{ minWidth: 0 }}><span className="akf-rail__t">{s.title}</span><span className="akf-rail__s">{sub}</span></span>}
                </a>
              );
            });

  return (
    <div className="akf-overlay" role="dialog" aria-modal="true" aria-labelledby="akf-title">
      <div className="akf-sheet">
        <header className="akf-sheet__head">
          <div style={{ minWidth: 0 }}>
            <div className="ak-eyebrow">{eyebrow}</div>
            <h2 id="akf-title">{spec.title}</h2>
          </div>
          <button type="button" className="ak-close" onClick={close} aria-label="Fermer"><X size={15} aria-hidden /></button>
        </header>

        <div className="akf-sheet__main" style={{ gridTemplateColumns: `${railOpen ? 248 : 64}px minmax(0,1fr)` }}>
          <nav aria-label="Sections du formulaire" className="akf-rail ak-scroll">
            <div className="akf-rail__top">
              {railOpen && <span className="ak-eyebrow" style={{ fontSize: 10.5, letterSpacing: '.14em' }}>Sections</span>}
              <button type="button" className="akf-icon akf-icon--box" onClick={() => setRailOpen((o) => !o)} aria-expanded={railOpen} aria-label={railOpen ? 'Replier le sommaire' : 'Déplier le sommaire'}>
                {railOpen ? <ChevronsLeft size={14} aria-hidden /> : <ChevronsRight size={14} aria-hidden />}
              </button>
            </div>
            {railItems(railOpen)}
            {railOpen && <div className="akf-rail__note">Les champs marqués <span className="akf-req">*</span> sont obligatoires. Le brouillon est conservé sur cet appareil.</div>}
          </nav>

          <div ref={body} className="akf-body ak-scroll">
            <div className="akf-secbar">
              <button type="button" className="akf-secbar__btn akf-secbar__btn--md" aria-expanded={secPanel} onClick={() => setSecPanel((o) => !o)}>
                Sections ({completeN} sur {sections.length} complètes)
              </button>
              <button type="button" className="akf-secbar__btn akf-secbar__btn--sm" aria-expanded={secPanel} onClick={() => setSecPanel((o) => !o)}>
                Section {curIdx + 1} sur {sections.length} : {sections[curIdx]?.title}
              </button>
              {secPanel && <nav aria-label="Sections du formulaire" className="akf-secpanel">{railItems(true)}</nav>}
            </div>
            {draftOffer && (
              <div className="akf-banner akf-banner--info" role="status">
                <span>Un brouillon du {new Date(draftOffer.at).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })} est disponible.</span>
                <button type="button" className="akf-link" onClick={() => { setValues(draftOffer.values); setDirty(true); setDraftOffer(null); }}>Reprendre</button>
                <button type="button" className="akf-link" style={{ color: 'var(--ink-3)' }} onClick={() => { if (draftKey) void drafts.del(draftKey); setDraftOffer(null); }}>Supprimer le brouillon</button>
              </div>
            )}
            {serverErr && (
              <div className="akf-banner akf-banner--err" role="alert">
                <AlertCircle size={16} aria-hidden />
                <div><strong>{serverErr.message}</strong>{serverErr.code && <div className="akf-code">Code : {serverErr.code}</div>}</div>
              </div>
            )}
            {tried && errors.ordered.length > 0 && (
              <div ref={errSum} tabIndex={-1} role="alert" className="akf-errsum">
                <div className="akf-errsum__t"><AlertCircle size={16} aria-hidden />{errors.ordered.length > 1 ? fmt(FORM_MESSAGES.summary_many, { n: errors.ordered.length }) : FORM_MESSAGES.summary_one}</div>
                <ul>{errors.ordered.map((e) => <li key={e.key}><a href={`#akw-${e.key}`} onClick={(ev) => { ev.preventDefault(); goField(e.key); }}>{e.label}</a><span> : {e.message}</span></li>)}</ul>
              </div>
            )}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              {sections.map((s, i) => {
                const st = sectionState(s, values, errors.byKey, shown);
                return (
                  <section key={s.id} id={`aks-${s.id}`} aria-labelledby={`aks-${s.id}-h`} className="akf-section" data-state={st.state}>
                    <header><span className="akf-section__n">{i + 1}</span><h3 id={`aks-${s.id}-h`} tabIndex={-1}>{s.title}</h3></header>
                    <div className="akf-section__body">
                      {s.intro && <p className="akf-intro">{s.intro}</p>}
                      <div className="akf-grid">
                        {s.fields.filter((f) => isVisible(f.showIf, values)).map((f) => (
                          <FieldInput key={f.key} f={f} value={values[f.key]} error={errors.byKey[f.key] ?? null} showError={shown(f.key)}
                            onChange={(v) => set(f.key, v)} onBlur={() => touch(f.key)} signer={signer} now={t0} />
                        ))}
                      </div>
                    </div>
                  </section>
                );
              })}
            </div>
          </div>
        </div>

        <footer className="akf-foot">
          <div className="akf-progress" aria-live="polite">
            <span className="akf-progress__bar"><i style={{ width: `${progress.total ? (progress.done / progress.total) * 100 : 100}%` }} /></span>
            <span><span className="ak-mono">{progress.done}</span> sur <span className="ak-mono">{progress.total}</span> champs obligatoires</span>
            <span className="akf-help">{saving ? 'Transmission en cours…' : savedAt ? `Brouillon local enregistré à ${savedAt.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}` : 'Saisie conservée sur cet appareil'}</span>
          </div>
          <button type="button" className="akf-btn akf-btn--ghost" onClick={close}>Revenir</button>
          {draftKey && <button type="button" className="akf-btn akf-btn--ghost" onClick={() => { void drafts.set(draftKey, values); setSavedAt(new Date()); setDirty(false); }}>Enregistrer le brouillon</button>}
          <button type="button" className="akf-btn akf-btn--primary" onClick={() => void submit()} aria-busy={saving} disabled={saving}>{primaryLabel}</button>
        </footer>

        {guard && (
          <div className="akf-guard" role="alertdialog" aria-modal="true" aria-labelledby="akf-guard-t">
            <div className="akf-guard__box">
              <h3 id="akf-guard-t">Quitter sans enregistrer ?</h3>
              <p>Vos modifications seront perdues.</p>
              <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                <button type="button" className="akf-btn akf-btn--ghost" autoFocus onClick={() => setGuard(false)}>Revenir</button>
                <button type="button" className="akf-btn akf-btn--danger" onClick={() => { if (draftKey) void drafts.del(draftKey); onClose(); }}>Quitter</button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export { isEmpty as isFieldEmpty };

import { useEffect, useState } from 'react';
import { ClipboardList, Plus, Trash2, Save, ShieldAlert, Lock, Clock, ExternalLink, CheckCircle2, AlertTriangle, X, ChevronUp, ChevronDown } from 'lucide-react';
import { Card } from '@keystone/ui';
import type { WoTemplateRow, StepType } from '@keystone/domain/db/keystone';
import { supabase } from '../../lib/supabase.ts';
import { fetchTemplates } from '../../data/field.ts';

type StepDraft = { label: string; type: StepType; min?: number; max?: number; unit?: string; required?: boolean; critical?: boolean };
const TYPE: Record<StepType, string> = { check: 'Contrôle', numeric: 'Mesure', photo: 'Photo', text: 'Texte' };
const WO_TYPE: Record<string, string> = { corrective: 'Correctif', preventive: 'Préventif', conditional: 'Conditionnel', predictive: 'Prédictif', regulatory: 'Réglementaire' };
const EMPTY = { name: '', wo_type: 'corrective', estimated_minutes: 60, requires_permit: false, safety_instructions: '', steps: [] as StepDraft[], required_parts: [] as { part_ref: string; qty: number }[] };

export function WoTemplates() {
  const [rows, setRows] = useState<WoTemplateRow[] | null>(null);
  const [sel, setSel] = useState<string | 'new' | null>(null);
  const [draft, setDraft] = useState(EMPTY);
  const [err, setErr] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  function load() { fetchTemplates().then(setRows).catch((e) => setErr(String(e))); }
  useEffect(load, []);
  function open(t: WoTemplateRow | null) {
    setSel(t ? t.id : 'new');
    setDraft(t ? { name: t.name, wo_type: t.wo_type, estimated_minutes: t.estimated_minutes, requires_permit: t.requires_permit,
      safety_instructions: t.safety_instructions ?? '', steps: t.steps as StepDraft[], required_parts: t.required_parts } : EMPTY);
  }
  const setStep = (i: number, p: Partial<StepDraft>) => setDraft((d) => ({ ...d, steps: d.steps.map((s, k) => (k === i ? { ...s, ...p } : s)) }));
  const move = (i: number, dir: -1 | 1) => setDraft((d) => {
    const s = [...d.steps]; const j = i + dir; if (j < 0 || j >= s.length) return d; [s[i], s[j]] = [s[j], s[i]]; return { ...d, steps: s };
  });
  async function save() {
    if (!supabase) return;
    setErr(null);
    const payload = { ...draft, steps: draft.steps.filter((s) => s.label.trim()), safety_instructions: draft.safety_instructions || null, updated_at: new Date().toISOString() };
    const q = sel === 'new' ? supabase.schema('keystone').from('wo_templates').insert(payload) : supabase.schema('keystone').from('wo_templates').update(payload).eq('id', sel!);
    const { error } = await q;
    if (error) { setErr(error.message); return; }
    setToast('Modèle enregistré'); setTimeout(() => setToast(null), 3500); setSel(null); load();
  }

  return (
    <div className="ks-container">
      <header className="kt-hero" style={{ marginBottom: 18 }}>
        <div className="ks-reveal">
          <div className="ks-eyebrow">Hard FM · Méthodes</div>
          <h1 className="kt-hero__title" style={{ fontSize: 34 }}>Modèles d’OT</h1>
          <div className="kt-hero__sub">
            <span className="ks-sync"><span className="ks-sync__dot" /> LIVE · Supabase</span>
            <span className="ks-faint">procédures pas à pas · mesures contrôlées · étapes critiques · pièces prévues · consignes de sécurité</span>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8, alignSelf: 'end' }}>
          <a className="ks-btn ks-btn--ghost" href="?technicien" target="_blank" rel="noreferrer"><ExternalLink size={15} /> App technicien</a>
          <button className="ks-btn ks-btn--primary" onClick={() => open(null)}><Plus size={15} /> Nouveau modèle</button>
        </div>
      </header>
      {toast && <div className="ka-toast"><CheckCircle2 size={16} /> {toast}</div>}
      {err && <div className="ka-toast" style={{ background: 'var(--ks-critical-100)', color: '#8E1E22' }}><AlertTriangle size={16} /> <span className="ks-mono" style={{ fontSize: 12.5 }}>{err}</span><button className="ks-icon-btn" style={{ marginLeft: 'auto' }} aria-label="Fermer" onClick={() => setErr(null)}><X size={14} /></button></div>}

      <div className="ki-rounds ks-reveal">
        {(rows ?? []).map((t) => (
          <Card key={t.id} hover style={{ cursor: 'pointer' }} onClick={() => open(t)}>
            <div className="ks-eyebrow">{WO_TYPE[t.wo_type] ?? t.wo_type}{t.category ? ` · ${t.category}` : ''}</div>
            <div style={{ fontWeight: 700, fontSize: 15, margin: '4px 0 8px' }}>{t.name}</div>
            <div className="ks-faint" style={{ fontSize: 12.5, display: 'flex', gap: 12, flexWrap: 'wrap' }}>
              <span><ClipboardList size={12} style={{ verticalAlign: -2 }} /> {t.steps.length} étapes · {t.steps.filter((s) => s.critical).length} critiques</span>
              <span><Clock size={12} style={{ verticalAlign: -2 }} /> {t.estimated_minutes} min</span>
              {t.requires_permit && <span style={{ color: 'var(--ks-high)' }}><Lock size={12} style={{ verticalAlign: -2 }} /> permis</span>}
            </div>
            <div className="ks-faint" style={{ fontSize: 11.5, marginTop: 8 }}>utilisé sur {t.uses} OT</div>
          </Card>
        ))}
      </div>

      {sel && (
        <div className="ka-overlay" onClick={() => setSel(null)}>
          <aside className="ka-drawer" style={{ width: 'min(640px, 100vw)' }} onClick={(e) => e.stopPropagation()} role="dialog" aria-label="Modèle d’OT">
            <div className="ka-drawer__head">
              <h2 style={{ fontSize: 20, fontWeight: 800, margin: 0 }}>{sel === 'new' ? 'Nouveau modèle' : 'Modifier le modèle'}</h2>
              <button className="ks-icon-btn" aria-label="Fermer" onClick={() => setSel(null)}><X size={17} /></button>
            </div>
            <input className="kx-in" style={{ width: '100%' }} placeholder="Nom du modèle" value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} />
            <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
              <select className="ka-select" style={{ height: 40, flex: 1 }} value={draft.wo_type} onChange={(e) => setDraft({ ...draft, wo_type: e.target.value })} aria-label="Type d’OT">
                {Object.entries(WO_TYPE).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
              </select>
              <label className="kx-lbl" style={{ flex: '0 0 120px' }}>Durée (min)<input className="kx-in" type="number" min={5} value={draft.estimated_minutes} onChange={(e) => setDraft({ ...draft, estimated_minutes: Number(e.target.value) })} /></label>
              <label className="kn-rule" style={{ border: 'none', flex: '0 0 auto' }}>
                <span className={`kn-switch${draft.requires_permit ? ' kn-switch--on' : ''}`} role="switch" aria-checked={draft.requires_permit} tabIndex={0}
                  onClick={() => setDraft({ ...draft, requires_permit: !draft.requires_permit })}><i /></span> Permis requis
              </label>
            </div>
            <div className="ks-eyebrow" style={{ margin: '14px 0 6px' }}><ShieldAlert size={12} style={{ verticalAlign: -2 }} /> Consignes de sécurité</div>
            <textarea className="kt-field ki-input" rows={2} style={{ width: '100%' }} value={draft.safety_instructions} onChange={(e) => setDraft({ ...draft, safety_instructions: e.target.value })} />

            <div className="ks-eyebrow" style={{ margin: '14px 0 6px' }}>Étapes</div>
            {draft.steps.map((s, i) => (
              <div key={i} className="kx-box" style={{ marginBottom: 8 }}>
                <div className="kx-qline" style={{ marginBottom: 6 }}>
                  <span className="ks-mono ks-faint" style={{ width: 18 }}>{i + 1}</span>
                  <input className="kx-in kx-in--grow" placeholder="Libellé de l’étape" value={s.label} onChange={(e) => setStep(i, { label: e.target.value })} />
                  <select className="ka-select" style={{ flex: '0 0 110px', height: 40 }} value={s.type} onChange={(e) => setStep(i, { type: e.target.value as StepType })} aria-label="Type d’étape">
                    {Object.entries(TYPE).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                  </select>
                  <button className="ks-icon-btn" aria-label="Monter" onClick={() => move(i, -1)}><ChevronUp size={14} /></button>
                  <button className="ks-icon-btn" aria-label="Descendre" onClick={() => move(i, 1)}><ChevronDown size={14} /></button>
                  <button className="ks-icon-btn" aria-label="Supprimer" onClick={() => setDraft((d) => ({ ...d, steps: d.steps.filter((_, k) => k !== i) }))}><Trash2 size={14} /></button>
                </div>
                <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', paddingLeft: 26 }}>
                  {s.type === 'numeric' && <>
                    <input className="kx-in kx-in--num" placeholder="min" type="number" value={s.min ?? ''} onChange={(e) => setStep(i, { min: e.target.value === '' ? undefined : Number(e.target.value) })} />
                    <input className="kx-in kx-in--num" placeholder="max" type="number" value={s.max ?? ''} onChange={(e) => setStep(i, { max: e.target.value === '' ? undefined : Number(e.target.value) })} />
                    <input className="kx-in kx-in--num" placeholder="unité" value={s.unit ?? ''} onChange={(e) => setStep(i, { unit: e.target.value })} />
                  </>}
                  <label style={{ fontSize: 12.5, display: 'inline-flex', gap: 5 }}><input type="checkbox" checked={s.required !== false} onChange={(e) => setStep(i, { required: e.target.checked })} /> obligatoire</label>
                  <label style={{ fontSize: 12.5, display: 'inline-flex', gap: 5, color: 'var(--ks-critical)' }}><input type="checkbox" checked={!!s.critical} onChange={(e) => setStep(i, { critical: e.target.checked })} /> critique (bloque la clôture si non conforme)</label>
                </div>
              </div>
            ))}
            <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => setDraft((d) => ({ ...d, steps: [...d.steps, { label: '', type: 'check', required: true }] }))}><Plus size={13} /> Ajouter une étape</button>

            <div className="ks-eyebrow" style={{ margin: '14px 0 6px' }}>Pièces prévues (réf. magasin)</div>
            {draft.required_parts.map((p, i) => (
              <div key={i} className="kx-qline">
                <input className="kx-in kx-in--grow ks-mono" placeholder="FLT-G4-592" value={p.part_ref} onChange={(e) => setDraft((d) => ({ ...d, required_parts: d.required_parts.map((x, k) => (k === i ? { ...x, part_ref: e.target.value } : x)) }))} />
                <input className="kx-in kx-in--num" type="number" min={1} value={p.qty} onChange={(e) => setDraft((d) => ({ ...d, required_parts: d.required_parts.map((x, k) => (k === i ? { ...x, qty: Number(e.target.value) } : x)) }))} />
                <button className="ks-icon-btn" aria-label="Retirer" onClick={() => setDraft((d) => ({ ...d, required_parts: d.required_parts.filter((_, k) => k !== i) }))}><Trash2 size={14} /></button>
              </div>
            ))}
            <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={() => setDraft((d) => ({ ...d, required_parts: [...d.required_parts, { part_ref: '', qty: 1 }] }))}><Plus size={13} /> Ajouter une pièce</button>

            <button className="ks-btn ks-btn--primary kx-wide" disabled={draft.name.trim().length < 3 || draft.steps.filter((s) => s.label.trim()).length === 0} onClick={() => void save()}><Save size={15} /> Enregistrer le modèle</button>
          </aside>
        </div>
      )}
    </div>
  );
}

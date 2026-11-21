// Moteur de formulaires Atlas Keystone : description de formulaire au niveau champ et validation Zod partagée.
//
// Sources qui font foi :
//  - Registre D30 et A98 : formulaire de saisie en page continue avec sommaire latéral, aucun assistant.
//  - Lot 1 Design System partie 2 §7 (gabarit de champ, nombre, montant FCFA, date, fichier, signature, formulaire §7.27).
//  - Catalogue des messages partie 1 (codes `REQUIRED_FIELD`, `INVALID_ARGUMENT`, `INVALID_DATE`, `FILE_*`)
//    et partie 4 §28 bis (messages de champ, vocabulaire des règles : `min_length`, `not_future`, `after:…`…).
//  - Le texte d'un message propre à un champ vient de la table de champs de son lot (colonne « Validation ») ;
//    il se déclare dans `FieldSpec.messages`. Ce module ne crée aucun formulaire métier.
//
// Fonctions pures : utilisables par l'interface, les tests, le hors-ligne et les gardes serveur.
import { z } from 'zod';

/** Composants du Lot 1 partie 2 §7. */
export type FieldComponent =
  | 'text' | 'textarea' | 'number' | 'amount' | 'date' | 'datetime' | 'select' | 'radio'
  | 'checkbox' | 'rating' | 'file' | 'photo' | 'signature';

/** Vocabulaire des règles de validation (Catalogue partie 4 §28 bis, Lot 1 partie 2 §7). */
export type Rule =
  | { rule: 'min_length'; n: number }
  | { rule: 'max_length'; n: number }
  | { rule: 'min'; n: number }
  | { rule: 'max'; n: number }
  | { rule: 'decimals'; n: number }
  | { rule: 'not_future' }
  | { rule: 'not_past' }
  | { rule: 'after_today' }
  | { rule: 'after_now' }
  | { rule: 'after'; field: string }
  | { rule: 'before'; field: string }
  | { rule: 'required_one_of'; fields: string[] }
  | { rule: 'required_if'; field: string; equals: unknown }
  | { rule: 'must_be_true' }
  | { rule: 'min_files'; n: number };

export type RuleName = Rule['rule'];

/** Condition d'affichage (colonne « Règle d'affichage ») : un champ masqué n'est ni validé ni transmis. */
export interface ShowIf { field: string; equals?: unknown; in?: unknown[]; truthy?: boolean }

export interface FieldSpec {
  key: string;
  label: string;
  component: FieldComponent;
  /** `table.colonne` de l'annexe (colonne « Source »). */
  source?: string;
  required: boolean;
  rules?: Rule[];
  default?: unknown;
  help?: string;
  showIf?: ShowIf;
  options?: { value: string; label: string; description?: string }[];
  /** Unité affichée en suffixe (nombre, Lot 1 §7.4). */
  unit?: string;
  /** Formats acceptés pour un fichier (types MIME), taille maximale en octets. */
  accept?: string[];
  maxBytes?: number;
  maxFiles?: number;
  /** Texte du message par règle, pris dans la table de champs du lot (« Validation »). */
  messages?: Partial<Record<RuleName | 'required' | 'format', string>>;
  /** Code serveur renvoyé pour la même règle (A69), affiché avec le message serveur. */
  serverCode?: string;
  /** Champ sur deux colonnes au-delà de 1280 px (champs courts liés). */
  half?: boolean;
}

export interface SectionSpec { id: string; title: string; intro?: string; fields: FieldSpec[]; showIf?: ShowIf }
export interface FormSpec { id: string; title: string; sections: SectionSpec[] }

export interface SignatureValue { by: string; at: string; points: number; image?: string }
export interface FileValue { name: string; size: number; type: string; at: string; path?: string; url?: string }
export type FormValues = Record<string, unknown>;

/** Textes génériques du Lot 1 partie 2 §7 et du catalogue partie 1 ; `{champ}` = libellé en minuscule initiale. */
export const FORM_MESSAGES = {
  required: 'Renseignez {champ}.',
  required_select: 'Choisissez {champ}.',
  number: 'Saisissez un nombre.',
  range: 'La valeur doit être comprise entre {min} et {max}.',
  min: 'La valeur doit être au moins {min}.',
  max: 'La valeur doit être au plus {max}.',
  decimals: '{n} décimales au plus.',
  amount_decimals: 'Les francs CFA n’ont pas de décimales.',
  amount_max: 'Montant trop élevé.',
  date_incomplete: 'Date incomplète, format JJ/MM/AAAA.',
  date_invalid: 'Le {jour} n’existe pas.',
  not_future: 'La date ne peut pas être dans le futur.',
  not_past: 'La date ne peut pas être dans le passé.',
  after_today: 'L’échéance doit être postérieure à aujourd’hui.',
  after_now: 'Choisissez une date et une heure à venir.',
  after: '{champ} suit {autre}.',
  before: '{champ} précède {autre}.',
  min_length: 'Saisissez {n} caractères au moins.',
  max_length: 'Texte limité à {n} caractères.',
  required_one_of: 'Renseignez {champs}.',
  must_be_true: 'Cochez la confirmation pour continuer.',
  min_files: '{n} fichiers requis, {actuel} ajouté(s).',
  file_too_large: 'Ce fichier fait {taille}, la limite est {limite}. Réduisez-le ou choisissez-en un autre.',
  file_type: 'Ce format n’est pas accepté. Formats acceptés : {formats}.',
  signature: 'Tracez votre signature.',
  summary_one: '1 champ à corriger',
  summary_many: '{n} champs à corriger',
} as const;

export function fmt(tpl: string, vars: Record<string, string | number>): string {
  return tpl.replace(/\{(\w+)\}/g, (m, k: string) => (k in vars ? String(vars[k]) : m));
}

const lcFirst = (s: string) => (s ? s.charAt(0).toLowerCase() + s.slice(1) : s);

// ---------------------------------------------------------------- Valeurs

/** Nombre saisi à la française : virgule décimale, espaces fines tolérées. NaN si invalide. */
export function parseDecimal(v: unknown): number {
  if (typeof v === 'number') return v;
  const s = String(v ?? '').replace(/[\s  ]/g, '').replace(',', '.');
  return /^-?\d+(\.\d+)?$/.test(s) ? Number(s) : Number.NaN;
}

export const AMOUNT_MAX = 999_999_999_999n;

/** Montant FCFA saisi ou collé (Lot 1 §7.5) → chaîne d'entier, ou motif de refus. */
export function parseAmount(raw: string): { value: string } | { error: 'amount_decimals' | 'amount_max' | 'number' } {
  let s = raw.replace(/[\s  ]/g, '');
  s = s.replace(/[.,]00$/, '');
  if (/[.,]\d{1,2}$/.test(s) && !/[.,]\d{3}/.test(s)) return { error: 'amount_decimals' };
  s = s.replace(/[.,]/g, '');
  if (!/^-?\d+$/.test(s)) return { error: 'number' };
  const n = BigInt(s);
  if (n > AMOUNT_MAX || n < -AMOUNT_MAX) return { error: 'amount_max' };
  return { value: n.toString() };
}

/** Groupement par 3 chiffres avec espace fine insécable U+202F. */
export function groupDigits(intStr: string): string {
  const neg = intStr.startsWith('-');
  const d = neg ? intStr.slice(1) : intStr;
  return (neg ? '-' : '') + d.replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
}

/** Date saisie librement (« 5/11/26 », « 05112026 », « aujourd'hui », « demain ») → AAAA-MM-JJ. */
export function parseFrDate(raw: string, today: Date): { iso: string } | { error: 'date_incomplete' | 'date_invalid'; jour?: string } {
  const s = raw.trim().toLowerCase();
  const iso = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  if (s === 'aujourd’hui' || s === "aujourd'hui") return { iso: iso(today) };
  if (s === 'demain') return { iso: iso(new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1)) };
  let d: string, m: string, y: string;
  const sep = /^(\d{1,2})[/.\-\s](\d{1,2})[/.\-\s](\d{2}|\d{4})$/.exec(s);
  const compact = /^(\d{2})(\d{2})(\d{4})$/.exec(s);
  if (sep) [, d, m, y] = sep; else if (compact) [, d, m, y] = compact; else return { error: 'date_incomplete' };
  const yy = y.length === 2 ? 2000 + Number(y) : Number(y);
  const dt = new Date(yy, Number(m) - 1, Number(d));
  if (dt.getFullYear() !== yy || dt.getMonth() !== Number(m) - 1 || dt.getDate() !== Number(d))
    return { error: 'date_invalid', jour: `${d.padStart(2, '0')}/${m.padStart(2, '0')}` };
  return { iso: iso(dt) };
}

export function isoToFr(iso: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : iso;
}

export function isEmpty(f: Pick<FieldSpec, 'component'>, v: unknown): boolean {
  if (v === undefined || v === null) return true;
  if (f.component === 'checkbox') return v !== true;
  if (f.component === 'signature') return !(v && typeof v === 'object' && (v as SignatureValue).by);
  if (Array.isArray(v)) return v.length === 0;
  return String(v).trim() === '';
}

export function isVisible(cond: ShowIf | undefined, values: FormValues): boolean {
  if (!cond) return true;
  const v = values[cond.field];
  if (cond.in) return cond.in.includes(v);
  if ('equals' in cond) return v === cond.equals;
  if (cond.truthy) return !!v && !(Array.isArray(v) && !v.length);
  return true;
}

/** Champs visibles avec leur section, dans l'ordre de la page. */
export function visibleFields(spec: FormSpec, values: FormValues): { section: SectionSpec; field: FieldSpec }[] {
  const out: { section: SectionSpec; field: FieldSpec }[] = [];
  for (const section of spec.sections) {
    if (!isVisible(section.showIf, values)) continue;
    for (const field of section.fields) if (isVisible(field.showIf, values)) out.push({ section, field });
  }
  return out;
}

// ---------------------------------------------------------------- Validation

export interface ValidationContext {
  /** Instant de référence (heure serveur bornée en hors ligne, A94). */
  now: Date;
}

const dayOf = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

/** Message d'erreur d'un champ visible, ou null. */
export function fieldError(f: FieldSpec, values: FormValues, all: FieldSpec[], ctx: ValidationContext): string | null {
  const v = values[f.key];
  const msg = (k: keyof typeof FORM_MESSAGES | RuleName | 'required' | 'format', vars: Record<string, string | number> = {}) =>
    fmt((f.messages?.[k as RuleName] ?? FORM_MESSAGES[k as keyof typeof FORM_MESSAGES] ?? FORM_MESSAGES.required) as string, { champ: lcFirst(f.label), ...vars });
  const labelOf = (key: string) => lcFirst(all.find((x) => x.key === key)?.label ?? key);

  if (isEmpty(f, v)) {
    if (f.required) {
      if (f.component === 'signature') return msg('signature');
      if (f.component === 'checkbox') return msg('must_be_true');
      return f.messages?.required ? msg('required') : fmt(['select', 'radio'].includes(f.component) ? FORM_MESSAGES.required_select : FORM_MESSAGES.required, { champ: lcFirst(f.label) });
    }
    for (const r of f.rules ?? []) {
      if (r.rule === 'required_one_of' && r.fields.every((k) => { const o = all.find((x) => x.key === k); return !o || isEmpty(o, values[k]); }))
        return msg('required_one_of', { champs: [f.key, ...r.fields.filter((k) => k !== f.key)].map(labelOf).join(' ou ') });
      if (r.rule === 'required_if' && values[r.field] === r.equals) return msg('required');
    }
    return null;
  }

  if (['select', 'radio'].includes(f.component) && f.options && !f.options.some((o) => o.value === v)) return msg('format', {});
  if (f.component === 'number' || f.component === 'rating') {
    const x = parseDecimal(v);
    if (Number.isNaN(x)) return msg('number');
    const mn = f.rules?.find((r) => r.rule === 'min') as { n: number } | undefined;
    const mx = f.rules?.find((r) => r.rule === 'max') as { n: number } | undefined;
    if (mn && mx && (x < mn.n || x > mx.n)) return msg('range', { min: mn.n, max: mx.n });
    if (mn && x < mn.n) return msg('min', { min: mn.n });
    if (mx && x > mx.n) return msg('max', { max: mx.n });
    const dec = f.rules?.find((r) => r.rule === 'decimals') as { n: number } | undefined;
    const frac = String(v).replace(',', '.').split('.')[1] ?? '';
    if (dec && frac.length > dec.n) return msg('decimals', { n: dec.n });
  }
  if (f.component === 'amount') {
    const p = parseAmount(String(v));
    if ('error' in p) return msg(p.error);
  }
  if (typeof v === 'string' && ['text', 'textarea'].includes(f.component)) {
    const s = v.trim();
    for (const r of f.rules ?? []) {
      if (r.rule === 'min_length' && s.length < r.n) return msg('min_length', { n: r.n });
      if (r.rule === 'max_length' && s.length > r.n) return msg('max_length', { n: r.n });
    }
  }
  if ((f.component === 'date' || f.component === 'datetime') && typeof v === 'string') {
    if (!/^\d{4}-\d{2}-\d{2}/.test(v)) return msg('date_incomplete');
    const day = v.slice(0, 10);
    const today = dayOf(ctx.now);
    for (const r of f.rules ?? []) {
      if (r.rule === 'not_future' && (f.component === 'datetime' ? Date.parse(v) > ctx.now.getTime() : day > today)) return msg('not_future');
      if (r.rule === 'not_past' && day < today) return msg('not_past');
      if (r.rule === 'after_today' && day <= today) return msg('after_today');
      if (r.rule === 'after_now' && Date.parse(v) <= ctx.now.getTime()) return msg('after_now');
      if (r.rule === 'after' || r.rule === 'before') {
        const o = values[r.field];
        if (typeof o === 'string' && o) {
          const bad = r.rule === 'after' ? v <= o : v >= o;
          if (bad) return msg(r.rule, { autre: labelOf(r.field), champ: f.label });
        }
      }
    }
  }
  if (f.component === 'file' || f.component === 'photo') {
    const files = (Array.isArray(v) ? v : []) as FileValue[];
    const mf = f.rules?.find((r) => r.rule === 'min_files') as { n: number } | undefined;
    if (mf && files.length < mf.n) return msg('min_files', { n: mf.n, actuel: files.length });
  }
  return null;
}

export interface FormErrors { byKey: Record<string, string>; ordered: { key: string; label: string; message: string; section: string }[] }

export function validateForm(spec: FormSpec, values: FormValues, ctx: ValidationContext): FormErrors {
  const vis = visibleFields(spec, values);
  const all = vis.map((x) => x.field);
  const byKey: Record<string, string> = {};
  const ordered: FormErrors['ordered'] = [];
  for (const { section, field } of vis) {
    const e = fieldError(field, values, all, ctx);
    if (e) { byKey[field.key] = e; ordered.push({ key: field.key, label: field.label, message: e, section: section.id }); }
  }
  return { byKey, ordered };
}

export type SectionState = 'complete' | 'incomplete' | 'error' | 'optional';

/** État d'une section pour le sommaire latéral (Lot 1 partie 3 §9.5.1). */
export function sectionState(section: SectionSpec, values: FormValues, errors: Record<string, string>, shown: (k: string) => boolean) {
  const fields = section.fields.filter((f) => isVisible(f.showIf, values));
  const req = fields.filter((f) => f.required);
  const done = req.filter((f) => !isEmpty(f, values[f.key])).length;
  const errN = fields.filter((f) => errors[f.key] && shown(f.key)).length;
  const state: SectionState = errN ? 'error' : !req.length ? 'optional' : done === req.length ? 'complete' : 'incomplete';
  return { state, done, total: req.length, errors: errN };
}

/**
 * Schéma Zod équivalent, pour une garde côté serveur ou hors ligne : champs inconnus refusés (`strict`),
 * champs masqués retirés avant validation, mêmes règles que `fieldError`.
 */
export function zodSchemaFor(spec: FormSpec, ctx: ValidationContext) {
  const keys = spec.sections.flatMap((s) => s.fields.map((f) => f.key));
  const shape = Object.fromEntries(keys.map((k) => [k, z.unknown().optional()]));
  return z
    .object(shape)
    .strict()
    .superRefine((vals, c) => {
      for (const e of validateForm(spec, vals, ctx).ordered) c.addIssue({ code: z.ZodIssueCode.custom, path: [e.key], message: e.message });
    });
}

/** Valeurs transmises : uniquement les champs visibles et renseignés. */
export function submittedValues(spec: FormSpec, values: FormValues): FormValues {
  return Object.fromEntries(
    visibleFields(spec, values).filter(({ field }) => values[field.key] !== undefined).map(({ field }) => [field.key, values[field.key]]),
  );
}

export function requiredProgress(spec: FormSpec, values: FormValues) {
  const req = visibleFields(spec, values).filter((x) => x.field.required);
  return { done: req.filter((x) => !isEmpty(x.field, values[x.field.key])).length, total: req.length };
}

// ---------------------------------------------------------------- Fichiers

/** Signatures d'octets des formats acceptés : le type se vérifie sur le contenu, jamais sur l'extension seule. */
export function sniffMime(bytes: Uint8Array): string | null {
  const b = (i: number) => bytes[i];
  if (b(0) === 0xff && b(1) === 0xd8 && b(2) === 0xff) return 'image/jpeg';
  if (b(0) === 0x89 && b(1) === 0x50 && b(2) === 0x4e && b(3) === 0x47) return 'image/png';
  if (b(0) === 0x25 && b(1) === 0x50 && b(2) === 0x44 && b(3) === 0x46) return 'application/pdf';
  if (b(0) === 0x52 && b(1) === 0x49 && b(2) === 0x46 && b(3) === 0x46 && b(8) === 0x57 && b(9) === 0x45 && b(10) === 0x42 && b(11) === 0x50) return 'image/webp';
  if (b(4) === 0x66 && b(5) === 0x74 && b(6) === 0x79 && b(7) === 0x70) {
    const brand = String.fromCharCode(b(8), b(9), b(10), b(11));
    if (/^(heic|heix|hevc|mif1|msf1)$/.test(brand)) return 'image/heic';
  }
  return null;
}

export function formatBytes(n: number): string {
  return n < 1024 * 1024 ? `${Math.max(1, Math.round(n / 1024))} Ko` : `${(n / 1048576).toLocaleString('fr-FR', { maximumFractionDigits: 1 })} Mo`;
}

/** Nom de stockage régénéré : jamais le nom fourni par l'utilisateur. */
export function storageName(mime: string, rand: () => string): string {
  const ext = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic', 'application/pdf': 'pdf' }[mime] ?? 'bin';
  return `${rand()}.${ext}`;
}

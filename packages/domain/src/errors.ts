// Traduction des erreurs serveur par le catalogue des messages (Registre A69, A96).
// Format serveur : ERRCODE = « PT » + statut HTTP, MESSAGE = code du catalogue, DETAIL = paramètres JSON.
// Supabase (PostgREST) le renvoie en { code: 'PT403', message: 'PERMISSION_DENIED', details: '{"permission":…}' }.
// Le texte affiché vient du catalogue seul : jamais le message technique brut ni le détail interne (règle de sécurité).
import catalog from './i18n/errors.fr.json' with { type: 'json' };

interface Entry { text: string; http: number | null }
const ERRORS = (catalog as { errors: Record<string, Entry>; aliases: Record<string, string> }).errors;
const ALIASES = (catalog as { aliases: Record<string, string> }).aliases;

export interface AppError {
  /** Code du catalogue (après résolution des alias), ex. `PERMISSION_DENIED`. */
  code: string;
  /** Statut HTTP du catalogue, ou celui porté par l'erreur. */
  status: number | null;
  /** Texte affichable, variables remplacées ; variable absente laissée vide de jeton. */
  message: string;
  /** Paramètres reçus (DETAIL), pour l'action contextuelle (focus sur un champ…). */
  detail: Record<string, unknown>;
}

const fill = (tpl: string, vars: Record<string, unknown>) =>
  tpl.replace(/\{(\w+)\}/g, (_m, k: string) => (vars[k] === undefined || vars[k] === null ? '…' : String(vars[k])));

function parseDetail(d: unknown): Record<string, unknown> {
  if (d && typeof d === 'object') return d as Record<string, unknown>;
  if (typeof d !== 'string' || !d.trim().startsWith('{')) return {};
  try { const v = JSON.parse(d); return v && typeof v === 'object' ? v : {}; } catch { return {}; }
}

export function hasErrorCode(code: string): boolean {
  return code in ERRORS || code in ALIASES;
}

/** Message du catalogue pour un code, variables remplies. */
export function errorText(code: string, vars: Record<string, unknown> = {}): string {
  const c = ALIASES[code] ?? code;
  return fill((ERRORS[c] ?? ERRORS.SERVER_ERROR).text, vars);
}

/**
 * Erreur quelconque (PostgREST, réseau, exception JS) → erreur affichable.
 * Code inconnu du catalogue : `SERVER_ERROR` (le code brut n'est pas exposé à l'écran).
 */
export function toAppError(err: unknown): AppError {
  const e = (err ?? {}) as { code?: unknown; message?: unknown; details?: unknown; name?: unknown; status?: unknown };
  const pt = typeof e.code === 'string' && /^PT\d{3}$/.test(e.code) ? Number(e.code.slice(2)) : null;
  const raw = typeof e.message === 'string' ? e.message.trim() : '';
  if (raw && /^[A-Z][A-Z0-9_]{2,63}$/.test(raw) && hasErrorCode(raw)) {
    const code = ALIASES[raw] ?? raw;
    const detail = parseDetail(e.details);
    return { code, status: ERRORS[code]?.http ?? pt, message: errorText(code, detail), detail };
  }
  const offline = typeof navigator !== 'undefined' && navigator.onLine === false;
  if (offline || e.name === 'TypeError' && /fetch|network/i.test(raw)) {
    return { code: 'NETWORK_UNAVAILABLE', status: null, message: errorText('NETWORK_UNAVAILABLE'), detail: {} };
  }
  if (e.name === 'AbortError' || /timeout/i.test(raw)) {
    return { code: 'REQUEST_TIMEOUT', status: 504, message: errorText('REQUEST_TIMEOUT'), detail: {} };
  }
  return { code: 'SERVER_ERROR', status: pt ?? (typeof e.status === 'number' ? e.status : 500), message: errorText('SERVER_ERROR'), detail: {} };
}

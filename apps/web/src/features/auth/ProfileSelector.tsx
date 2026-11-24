import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from 'react';
import { X } from 'lucide-react';
import type { AppError } from '@keystone/domain';
import { SURFACE_LABEL, setDefaultProfile, type ProfileCard } from '../../lib/profiles.ts';

/**
 * AP-01 « Choisir un profil » (Architecture Portails partie 2 §15 ; maquette Lot 2 §3.1).
 * Choix obligatoire à la connexion (pas de « Fermer » ni de « Revenir »), facultatif en cours de session.
 * 360 : page plein écran, « Continuer » en barre basse ; 768 et plus : modale de 480 (keystone.css, .ak-profiles).
 */

const fmtDH = (iso: string) =>
  new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }).format(new Date(iso));

function scopeText(p: ProfileCard): string | null {
  if (p.kind !== 'internal' && p.kind !== 'client') return null;
  if (p.scope_all) return 'Tous les sites';
  const n = p.scope_sites ?? 0;
  return n === 1 ? '1 site' : `${n} sites`;
}

function accessibleName(p: ProfileCard): string {
  return [p.label, SURFACE_LABEL[p.surface], p.organization ?? 'Non renseigné', p.role_label ?? 'Non renseigné', p.is_default ? 'par défaut' : null]
    .filter(Boolean).join(', ');
}

export function ProfileSelector({
  profiles, inSession, onContinue, onClose, onSetDefault = setDefaultProfile,
}: {
  profiles: ProfileCard[];
  /** En cours de session : bouton « Fermer » et « Revenir » présents. */
  inSession: boolean;
  onContinue: (profileId: string) => Promise<void>;
  onClose?: () => void;
  /** Remplaçable pour l'aperçu de développement ; par défaut la RPC set_default_profile. */
  onSetDefault?: (profileId: string, isDefault: boolean) => Promise<void>;
}) {
  const selectable = profiles.filter((p) => p.status === 'active');
  const initial = selectable.find((p) => p.is_active_session) ?? selectable.find((p) => p.is_default) ?? selectable[0];
  const [sel, setSel] = useState(initial?.profile_id ?? '');
  const [makeDefault, setMakeDefault] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const refs = useRef<Record<string, HTMLButtonElement | null>>({});
  const current = useMemo(() => profiles.find((p) => p.profile_id === sel), [profiles, sel]);

  const firstFocus = useRef(sel);
  useEffect(() => { refs.current[firstFocus.current]?.focus(); }, []);
  useEffect(() => { setMakeDefault(current?.is_default ?? false); }, [current]);

  async function submit() {
    if (!sel || busy) return;
    setBusy(true); setErr(null);
    try {
      if (current && makeDefault !== current.is_default) await onSetDefault(sel, makeDefault);
      await onContinue(sel);
    } catch (x) {
      setErr((x as AppError).message ?? 'Chargement impossible.');
      setBusy(false);
    }
  }

  function onKey(e: KeyboardEvent<HTMLDivElement>) {
    if (e.key === 'Enter') { e.preventDefault(); void submit(); return; }
    if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
    e.preventDefault();
    const i = selectable.findIndex((p) => p.profile_id === sel);
    const next = selectable[(i + (e.key === 'ArrowDown' ? 1 : selectable.length - 1)) % selectable.length];
    if (next) { setSel(next.profile_id); refs.current[next.profile_id]?.focus(); }
  }

  return (
    <div className="ak-profiles__scrim" role="presentation" onKeyDown={(e) => { if (e.key === 'Escape' && inSession) onClose?.(); }}>
      <div className="ak-profiles" role="dialog" aria-modal="true" aria-labelledby="ak-profiles-t" aria-describedby="ak-profiles-s">
        <div className="ak-profiles__head">
          <div>
            <h1 id="ak-profiles-t">Choisir un profil</h1>
            <p id="ak-profiles-s">Vous travaillez avec plusieurs organisations.</p>
          </div>
          {inSession && <button className="ak-close" onClick={onClose} aria-label="Fermer"><X size={16} /></button>}
        </div>

        <div className="ak-profiles__list" role="radiogroup" aria-label="Profil" onKeyDown={onKey}>
          {profiles.map((p) => {
            const suspended = p.status === 'suspended';
            const checked = p.profile_id === sel;
            const sub = [p.role_label ?? 'Non renseigné', scopeText(p)].filter(Boolean).join(', ');
            return (
              <button
                key={p.profile_id}
                ref={(el) => { refs.current[p.profile_id] = el; }}
                type="button" role="radio" aria-checked={checked} aria-disabled={suspended || undefined}
                aria-label={accessibleName(p)} tabIndex={checked ? 0 : -1}
                className="ak-profiles__card" disabled={suspended}
                onClick={() => !suspended && setSel(p.profile_id)}
              >
                <span className="ak-profiles__dot" aria-hidden />
                <span className="ak-profiles__main">
                  <span className="ak-profiles__row">
                    <strong>{p.label}</strong>
                    <span className="ak-profiles__surface">{SURFACE_LABEL[p.surface]}</span>
                  </span>
                  <span className="ak-profiles__org">{p.organization ?? 'Non renseigné'}</span>
                  <span className="ak-profiles__sub">{suspended ? `Suspendu${p.suspended_reason ? ` : ${p.suspended_reason}` : ''}` : sub}</span>
                  <span className="ak-profiles__row ak-profiles__meta">
                    {p.is_default && <span className="ak-profiles__pill">Par défaut</span>}
                    {p.last_used_at && <span>Utilisé le {fmtDH(p.last_used_at)}</span>}
                  </span>
                </span>
              </button>
            );
          })}
        </div>

        <label className="akf-check ak-profiles__default">
          <input type="checkbox" checked={makeDefault} disabled={!current || current.status !== 'active'} onChange={(e) => setMakeDefault(e.target.checked)} />
          <span>Utiliser ce profil par défaut<small>Ce profil s'ouvre directement à votre prochaine connexion.</small></span>
        </label>

        {err && <div className="ak-profiles__err" role="alert">{err}</div>}

        <div className="ak-profiles__foot">
          {inSession && <button className="ak-btn-line ak-btn-line--lg" onClick={onClose} disabled={busy}>Revenir</button>}
          <button className="ak-btn-brand ak-btn-brand--lg" onClick={() => void submit()} disabled={!sel || busy}>
            {busy ? 'Ouverture…' : 'Continuer'}
          </button>
        </div>
      </div>
    </div>
  );
}

/** États hors liste (§15) : chargement en squelette, aucun profil actif, erreur avec « Réessayer ». */
export function ProfileStatePage({ kind, message, onRetry }: { kind: 'loading' | 'none' | 'error'; message?: string; onRetry?: () => void }) {
  return (
    <div className="ak-profiles__scrim" role="presentation">
      <div className="ak-profiles" aria-busy={kind === 'loading'}>
        {kind === 'loading' && (
          <>
            <div className="ak-profiles__head"><div><h1>Choisir un profil</h1><p>Chargement…</p></div></div>
            <div className="ak-profiles__list">{[0, 1, 2].map((i) => <div key={i} className="ak-profiles__skel" />)}</div>
          </>
        )}
        {kind === 'none' && <p className="ak-profiles__empty">Aucun profil actif. Contactez l'administrateur de votre organisation.</p>}
        {kind === 'error' && (
          <div className="ak-profiles__empty">
            <p role="alert">{message ?? 'Chargement impossible.'}</p>
            <button className="ak-btn-brand ak-btn-brand--lg" onClick={onRetry}>Réessayer</button>
          </div>
        )}
      </div>
    </div>
  );
}

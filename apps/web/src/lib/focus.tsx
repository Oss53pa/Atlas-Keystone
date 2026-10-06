import { createContext, useContext, useEffect, useRef, type ReactNode } from 'react';

/** Cible d'ouverture depuis la palette ⌘K : un objet (kind + id) à montrer dans son module. */
export interface Focus { kind: string; id: string; nonce: number }

const Ctx = createContext<Focus | null>(null);

export function FocusProvider({ value, children }: { value: Focus | null; children: ReactNode }) {
  useFocusFlash(value);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

/**
 * Réagit à une cible ⌘K des types donnés (une fois par demande) : bascule d'onglet, ouverture de fiche…
 * Le rappel reçoit l'id ciblé.
 */
export function useFocus(kinds: string[], onFocus: (id: string, kind: string) => void) {
  const f = useContext(Ctx);
  const cb = useRef(onFocus);
  cb.current = onFocus;
  useEffect(() => {
    if (f && kinds.includes(f.kind)) cb.current(f.id, f.kind);
  }, [f?.nonce]); // eslint-disable-line react-hooks/exhaustive-deps
}

/** Id ciblé courant pour un type (pour ouvrir une fiche dès que les données sont chargées). */
export function useFocusTarget(kinds: string[]): string | null {
  const f = useContext(Ctx);
  return f && kinds.includes(f.kind) ? f.id : null;
}

/**
 * Fait défiler jusqu'à l'élément marqué data-focus="kind:id" et l'illumine brièvement.
 * Attend que le module ait chargé ses données (jusqu'à 5 s).
 */
function useFocusFlash(f: Focus | null) {
  useEffect(() => {
    if (!f) return;
    const sel = `[data-focus~="${f.kind}:${f.id}"]`;
    let tries = 0;
    let done: number | undefined;
    const tick = window.setInterval(() => {
      const el = document.querySelector<HTMLElement>(sel);
      if (el) {
        window.clearInterval(tick);
        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        el.classList.remove('ks-focus-flash');
        void el.offsetWidth; // relance l'animation
        el.classList.add('ks-focus-flash');
        done = window.setTimeout(() => el.classList.remove('ks-focus-flash'), 2600);
      } else if (++tries > 33) window.clearInterval(tick);
    }, 150);
    return () => { window.clearInterval(tick); if (done) window.clearTimeout(done); };
  }, [f?.nonce]); // eslint-disable-line react-hooks/exhaustive-deps
}

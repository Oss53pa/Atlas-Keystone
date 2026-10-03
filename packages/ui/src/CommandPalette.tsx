import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Search, CornerDownLeft, ArrowUp, ArrowDown } from 'lucide-react';

export interface Command {
  id: string;
  label: string;
  group: string;
  hint?: string;
  icon: ReactNode;
  run: () => void;
}

export function CommandPalette({
  open,
  onClose,
  commands,
}: {
  open: boolean;
  onClose: () => void;
  commands: Command[];
}) {
  const [q, setQ] = useState('');
  const [cursor, setCursor] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLDivElement>(null);

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    if (!needle) return commands;
    return commands.filter((c) => (c.label + ' ' + c.group).toLowerCase().includes(needle));
  }, [q, commands]);

  useEffect(() => {
    if (open) {
      setQ('');
      setCursor(0);
      requestAnimationFrame(() => inputRef.current?.focus());
    }
  }, [open]);

  useEffect(() => setCursor(0), [q]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
      else if (e.key === 'ArrowDown') {
        e.preventDefault();
        setCursor((c) => Math.min(filtered.length - 1, c + 1));
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        setCursor((c) => Math.max(0, c - 1));
      } else if (e.key === 'Enter') {
        e.preventDefault();
        const sel = filtered[cursor];
        if (sel) {
          sel.run();
          onClose();
        }
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, filtered, cursor, onClose]);

  useEffect(() => {
    listRef.current?.querySelector('[data-active="true"]')?.scrollIntoView({ block: 'nearest' });
  }, [cursor]);

  if (!open) return null;

  let lastGroup = '';
  let idx = -1;

  return (
    <div className="kc-overlay" onMouseDown={onClose} role="dialog" aria-modal="true" aria-label="Palette de commandes">
      <div className="kc-panel" onMouseDown={(e) => e.stopPropagation()}>
        <div className="kc-search">
          <Search size={18} color="var(--ks-ink-3)" />
          <input
            ref={inputRef}
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Rechercher ou poser une question en langage naturel…"
            aria-label="Recherche"
          />
          <kbd>Échap</kbd>
        </div>

        <div className="kc-list" ref={listRef}>
          {filtered.length === 0 && <div className="kc-empty">Aucun résultat pour « {q} »</div>}
          {filtered.map((c) => {
            idx += 1;
            const here = idx;
            const showGroup = c.group !== lastGroup;
            lastGroup = c.group;
            return (
              <div key={c.id}>
                {showGroup && <div className="kc-group">{c.group}</div>}
                <div
                  className="kc-item"
                  data-active={here === cursor}
                  onMouseEnter={() => setCursor(here)}
                  onClick={() => {
                    c.run();
                    onClose();
                  }}
                >
                  <span className="kc-item__icon">{c.icon}</span>
                  <span className="kc-item__label">{c.label}</span>
                  {c.hint && <span className="kc-item__hint">{c.hint}</span>}
                </div>
              </div>
            );
          })}
        </div>

        <div className="kc-foot">
          <span><kbd><ArrowUp size={11} /></kbd><kbd><ArrowDown size={11} /></kbd> naviguer</span>
          <span><kbd><CornerDownLeft size={11} /></kbd> ouvrir</span>
          <span style={{ marginLeft: 'auto' }}>Keystone UI · ⌘K</span>
        </div>
      </div>
    </div>
  );
}

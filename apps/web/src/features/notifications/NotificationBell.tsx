import { useEffect, useRef, useState } from 'react';
import { Bell, CheckCheck, AlertTriangle, Info } from 'lucide-react';
import type { MyNotification } from '@keystone/domain/db/keystone';
import { supabase } from '../../lib/supabase.ts';
import { fetchMyNotifications, markAllRead } from '../../data/notifications.ts';

const ago = (s: string) => {
  const m = Math.round((Date.now() - new Date(s).getTime()) / 60000);
  return m < 1 ? 'à l’instant' : m < 60 ? `${m} min` : m < 1440 ? `${Math.round(m / 60)} h` : `${Math.round(m / 1440)} j`;
};

/** Cloche de la barre du haut : notifications personnelles (canal in-app), temps réel. */
export function NotificationBell({ onOpenCenter }: { onOpenCenter: () => void }) {
  const [items, setItems] = useState<MyNotification[]>([]);
  const [open, setOpen] = useState(false);
  const [pulse, setPulse] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  function load() { fetchMyNotifications(15).then(setItems).catch(() => {}); }
  useEffect(() => {
    load();
    if (!supabase) return;
    const ch = supabase.channel('my-notifications')
      .on('postgres_changes', { event: 'INSERT', schema: 'keystone', table: 'notifications' }, () => {
        load(); setPulse(true); setTimeout(() => setPulse(false), 1800);
      })
      .subscribe();
    return () => { void supabase?.removeChannel(ch); };
  }, []);
  useEffect(() => {
    if (!open) return;
    const close = (e: MouseEvent) => { if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false); };
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('mousedown', close); window.addEventListener('keydown', esc);
    return () => { document.removeEventListener('mousedown', close); window.removeEventListener('keydown', esc); };
  }, [open]);

  const unread = items.filter((i) => !i.read_at).length;
  async function readAll() { await markAllRead().catch(() => 0); load(); }

  return (
    <div className="kb-wrap" ref={ref}>
      <button className={`ks-icon-btn kb-btn${pulse ? ' kb-btn--pulse' : ''}`} aria-label={`Notifications${unread ? ` (${unread} non lues)` : ''}`}
        aria-expanded={open} onClick={() => setOpen((o) => !o)}>
        <Bell size={18} />
        {unread > 0 && <span className="kb-badge">{unread > 9 ? '9+' : unread}</span>}
      </button>
      {open && (
        <div className="kb-panel" role="dialog" aria-label="Notifications">
          <div className="kb-head">
            <b>Notifications</b>
            {unread > 0 && <button className="ks-btn ks-btn--quiet ks-btn--sm" onClick={readAll}><CheckCheck size={13} /> Tout marquer lu</button>}
          </div>
          <div className="kb-list">
            {items.map((n) => (
              <div key={n.id} className={`kb-item${n.read_at ? '' : ' kb-item--unread'}`}>
                <span className={`kb-ico kb-ico--${n.severity}`}>{n.severity === 'critical' || n.severity === 'high' ? <AlertTriangle size={14} /> : <Info size={14} />}</span>
                <div style={{ minWidth: 0, flex: 1 }}>
                  <div className="kb-title">{n.title}</div>
                  {n.body && <div className="kb-body">{n.body}</div>}
                </div>
                <span className="ks-faint" style={{ fontSize: 11, whiteSpace: 'nowrap' }}>{ago(n.created_at)}</span>
              </div>
            ))}
            {items.length === 0 && <div className="ks-faint" style={{ padding: 24, textAlign: 'center', fontSize: 13 }}>Aucune notification.</div>}
          </div>
          <button className="kb-foot" onClick={() => { setOpen(false); onOpenCenter(); }}>Centre de notifications · règles &amp; canaux</button>
        </div>
      )}
    </div>
  );
}

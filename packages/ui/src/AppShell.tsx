import { useState, type ReactNode } from 'react';
import { Search, PanelLeftClose, PanelLeft, Bell, LogOut } from 'lucide-react';
import { Avatar, IconButton } from './primitives.tsx';

export interface NavItem {
  id: string;
  label: string;
  icon: ReactNode;
  badge?: number;
}
export interface NavGroup {
  label: string;
  items: NavItem[];
}

export type Density = 'office' | 'terrain';

export function AppShell({
  groups,
  activeId,
  onNavigate,
  density,
  onDensity,
  site,
  sites,
  onSite,
  user,
  children,
  onCommand,
  onSignOut,
}: {
  groups: NavGroup[];
  activeId: string;
  onNavigate: (id: string) => void;
  density: Density;
  onDensity: (d: Density) => void;
  site: string;
  sites: string[];
  onSite: (s: string) => void;
  user: { name: string; initials: string; role: string };
  children: ReactNode;
  onCommand?: () => void;
  onSignOut?: () => void;
}) {
  const [collapsed, setCollapsed] = useState(false);
  return (
    <div className="ks-shell" data-density={density}>
      <nav className={`ks-rail${collapsed ? ' ks-rail--collapsed' : ''}`} aria-label="Navigation principale">
        <div className="ks-rail__brand">
          <span className="ks-rail__logo" aria-hidden>
            {/* clé de voûte / keystone */}
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <path d="M7 3h10l3 7-8 11-8-11 3-7Z" fill="currentColor" opacity=".9" />
            </svg>
          </span>
          {!collapsed && (
            <span className="ks-rail__name">
              Atlas Keystone
              <small>Facility Management</small>
            </span>
          )}
        </div>

        <div style={{ overflowY: 'auto', flex: 1, marginRight: -6, paddingRight: 6 }}>
          {groups.map((g) => (
            <div className="ks-navgroup" key={g.label}>
              {!collapsed && <div className="ks-navgroup__label">{g.label}</div>}
              {g.items.map((it) => (
                <div
                  key={it.id}
                  className={`ks-nav${it.id === activeId ? ' ks-nav--active' : ''}`}
                  onClick={() => onNavigate(it.id)}
                  role="button"
                  tabIndex={0}
                  title={collapsed ? it.label : undefined}
                  onKeyDown={(e) => e.key === 'Enter' && onNavigate(it.id)}
                >
                  <span className="ks-nav__icon">{it.icon}</span>
                  {!collapsed && <span>{it.label}</span>}
                  {!collapsed && it.badge ? <span className="ks-nav__badge">{it.badge}</span> : null}
                </div>
              ))}
            </div>
          ))}
        </div>

        <IconButton label={collapsed ? 'Déplier' : 'Replier'} onClick={() => setCollapsed((c) => !c)}>
          {collapsed ? <PanelLeft size={18} /> : <PanelLeftClose size={18} />}
        </IconButton>
      </nav>

      <div className="ks-main">
        <header className="ks-topbar">
          <button className="ks-search" onClick={onCommand} aria-label="Recherche & commandes">
            <Search size={16} />
            <span>Rechercher un actif, un OT, une obligation…</span>
            <kbd>⌘K</kbd>
          </button>

          <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 14 }}>
            <label className="ks-pill" style={{ paddingRight: 4 }}>
              <span style={{ color: 'var(--ks-ink-3)' }}>Site</span>
              <select
                value={site}
                onChange={(e) => onSite(e.target.value)}
                style={{
                  border: 'none', background: 'transparent', font: 'inherit',
                  fontWeight: 600, color: 'var(--ks-ink)', cursor: 'pointer', outline: 'none',
                }}
              >
                {sites.map((s) => (
                  <option key={s}>{s}</option>
                ))}
              </select>
            </label>

            <div className="ks-segment" role="group" aria-label="Densité">
              <button aria-pressed={density === 'office'} onClick={() => onDensity('office')}>
                Office
              </button>
              <button aria-pressed={density === 'terrain'} onClick={() => onDensity('terrain')}>
                Terrain
              </button>
            </div>

            <span className="ks-sync" title="Synchronisation temps réel active">
              <span className="ks-sync__dot" /> Live
            </span>

            <IconButton label="Notifications">
              <Bell size={18} />
            </IconButton>

            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <Avatar initials={user.initials} />
              <div style={{ lineHeight: 1.2 }}>
                <div style={{ fontSize: 13, fontWeight: 600 }}>{user.name}</div>
                <div style={{ fontSize: 11.5, color: 'var(--ks-ink-3)' }}>{user.role}</div>
              </div>
            </div>

            {onSignOut && (
              <IconButton label="Se déconnecter" onClick={onSignOut}>
                <LogOut size={18} />
              </IconButton>
            )}
          </div>
        </header>

        <main className="ks-content">{children}</main>
      </div>
    </div>
  );
}

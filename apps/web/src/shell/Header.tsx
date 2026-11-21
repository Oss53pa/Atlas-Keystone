import type { ReactNode } from 'react';
import { ArrowLeft, Bell, ChevronDown, LogOut, Search } from 'lucide-react';

/** En-tête de l'application (refonte v4) : logo, sommaire, retour, entité, recherche, état, alertes. */
export function Header({
  onHome, onSommaire, onBack, canBack, site, onCycleSite, dateFull, time, onSearch, bell, onIncident, user, onSignOut,
}: {
  onHome: () => void;
  onSommaire: () => void;
  onBack: () => void;
  canBack: boolean;
  site: string;
  onCycleSite: () => void;
  dateFull: string;
  time: string;
  onSearch: () => void;
  bell?: ReactNode;
  onIncident: () => void;
  user: { initials: string; title: string };
  onSignOut?: () => void;
}) {
  return (
    <header className="ak-header ak-noprint">
      <button className="ak-header__logo" onClick={onHome} aria-label="Accueil, Tour de contrôle">
        <img src="/brand/keystone_hn.svg" alt="Atlas Keystone, an Atlas Studio company" />
      </button>
      <span className="ak-vsep" aria-hidden />
      <button className="ak-btn-ink" onClick={onSommaire}>
        Sommaire<kbd>Ctrl K</kbd>
      </button>
      <button className="ak-btn-text" onClick={onBack} disabled={!canBack} style={{ marginLeft: 6, opacity: canBack ? 1 : 0.5 }}>
        <ArrowLeft size={14} aria-hidden /> Retour
      </button>
      <span className="ak-vsep ak-vsep--soft" aria-hidden />
      <button className="ak-site" onClick={onCycleSite} title="Changer d’entité">
        <div className="ak-site__name">
          {site}
          <ChevronDown size={12} aria-hidden style={{ color: 'var(--ink-3)' }} />
        </div>
        <div className="ak-site__date">{dateFull}</div>
      </button>
      <div className="ak-underline-input" onClick={onSearch} role="button" tabIndex={0} onKeyDown={(e) => e.key === 'Enter' && onSearch()}>
        <Search size={14} aria-hidden style={{ color: 'var(--brand)' }} />
        <input readOnly placeholder="Rechercher ou demander à PROPH3T" aria-label="Rechercher" style={{ cursor: 'pointer' }} />
      </div>
      <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', flex: 'none' }}>
        <span className="ak-sync"><i aria-hidden />Synchronisé {time}</span>
        <span className="ak-vsep ak-vsep--soft" style={{ margin: 0 }} aria-hidden />
        {bell ?? (
          <button className="ak-btn-text" title="Notifications" aria-label="Notifications">
            <Bell size={16} aria-hidden />
          </button>
        )}
        <button className="ak-btn-line" onClick={onIncident} style={{ margin: '0 12px 0 6px' }}>
          Signaler un incident
        </button>
        <span className="ak-avatar" title={user.title}>{user.initials}</span>
        {onSignOut && (
          <button className="ak-btn-text" onClick={onSignOut} title="Se déconnecter" aria-label="Se déconnecter" style={{ marginLeft: 4 }}>
            <LogOut size={15} aria-hidden />
          </button>
        )}
      </div>
    </header>
  );
}

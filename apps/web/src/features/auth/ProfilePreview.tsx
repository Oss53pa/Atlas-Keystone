import { useState } from 'react';
import { ProfileSelector, ProfileStatePage } from './ProfileSelector.tsx';
import type { ProfileCard } from '../../lib/profiles.ts';

/** Aperçu du sélecteur de profil (AP-01), mode développement uniquement : données de démonstration du §15. */
const base = { tenant_id: 'demo', is_active_session: false, suspended_reason: null, scope_sites: null, scope_all: false, last_used_at: null } as const;
const DEMO: ProfileCard[] = [
  { ...base, profile_id: 'p1', kind: 'internal', surface: 'console', label: 'Équipe Keystone', organization: 'Équipe Keystone', role_label: 'Exploitation', scope_sites: 3, is_default: false, status: 'active', last_used_at: '2026-11-23T08:42:00Z' },
  { ...base, profile_id: 'p2', kind: 'vendor', surface: 'vendor_portal', label: 'Fournisseur FRN-0021', organization: 'Fournisseur démo FRN-0021', role_label: 'Prestataire de services', is_default: false, status: 'active' },
  { ...base, profile_id: 'p3', kind: 'client', surface: 'client_portal', label: 'Client Démo SA', organization: 'Client Démo SA', role_label: 'Lecteur', scope_all: true, is_default: false, status: 'active' },
  { ...base, profile_id: 'p4', kind: 'occupant', surface: 'occupant_portal', label: 'Occupant, Boutique Démo', organization: 'Enseigne démo A', role_label: null, is_default: false, status: 'suspended', suspended_reason: 'Contrat clos' },
];

export function ProfilePreview() {
  const kind = new URLSearchParams(window.location.search).get('apercu-profils');
  const [msg, setMsg] = useState('');
  if (kind === 'chargement') return <ProfileStatePage kind="loading" />;
  if (kind === 'aucun') return <ProfileStatePage kind="none" />;
  if (kind === 'erreur') return <ProfileStatePage kind="error" onRetry={() => undefined} />;
  return (
    <>
      <ProfileSelector profiles={DEMO} inSession={kind === 'session'} onClose={() => setMsg('Fermé')}
        onSetDefault={async () => undefined}
        onContinue={async (id) => { setMsg(`Continuer : ${id}`); }} />
      {msg && <div className="ak-toast" role="status">{msg}</div>}
    </>
  );
}

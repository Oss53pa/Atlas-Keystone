import { useCallback, useEffect, useState } from 'react';
import type { Session } from '@supabase/supabase-js';
import { toAppError, type AppError } from '@keystone/domain';
import { supabase } from './supabase.ts';

/**
 * Profil actif (Architecture Portails §3.2, partie 2 §15 AP-01).
 * La base reste seule juge : switch_profile contrôle propriété, statut, surface et double authentification ;
 * le jeton rafraîchi porte tenant_id et active_profile_id (crochet keystone.custom_access_token_hook).
 * L'interface ne fait que lire ces revendications pour savoir quel écran montrer.
 */

export type Surface = 'console' | 'client_portal' | 'vendor_portal' | 'occupant_portal' | 'field_app';

export interface ProfileCard {
  profile_id: string;
  tenant_id: string;
  kind: 'internal' | 'vendor' | 'client' | 'occupant';
  surface: Surface;
  label: string;
  organization: string | null;
  role_label: string | null;
  scope_sites: number | null;
  scope_all: boolean;
  is_default: boolean;
  is_active_session: boolean;
  status: 'active' | 'suspended';
  suspended_reason: string | null;
  last_used_at: string | null;
}

export const SURFACE_LABEL: Record<Surface, string> = {
  console: 'Console',
  client_portal: 'Portail client',
  vendor_portal: 'Portail fournisseurs',
  occupant_portal: 'Portail occupants',
  field_app: 'Application terrain',
};

export interface ActiveClaims { tenantId: string; profileId: string; surface: Surface }

/** Lecture des revendications du jeton d'accès, sans vérification (affichage seulement ; PostgREST vérifie la signature). */
export function claimsOf(session: Session | null): ActiveClaims | null {
  const t = session?.access_token;
  if (!t) return null;
  try {
    const part = t.split('.')[1] ?? '';
    const bin = atob(part.replace(/-/g, '+').replace(/_/g, '/'));
    const json = JSON.parse(new TextDecoder().decode(Uint8Array.from(bin, (ch) => ch.charCodeAt(0))));
    const tenantId = typeof json.tenant_id === 'string' ? json.tenant_id : '';
    const profileId = typeof json.active_profile_id === 'string' ? json.active_profile_id : '';
    const surface = typeof json.surface === 'string' ? (json.surface as Surface) : 'console';
    return tenantId && profileId ? { tenantId, profileId, surface } : null;
  } catch {
    return null;
  }
}

const ks = () => {
  if (!supabase) throw new Error('backend');
  return supabase.schema('keystone');
};

export async function listProfiles(): Promise<ProfileCard[]> {
  const { data, error } = await ks().rpc('my_profiles');
  if (error) throw toAppError(error);
  return (data ?? []) as ProfileCard[];
}

export async function setDefaultProfile(profileId: string, isDefault: boolean): Promise<void> {
  const { error } = await ks().rpc('set_default_profile', { p_profile: profileId, p_default: isDefault });
  if (error) throw toAppError(error);
}

/** Bascule, puis rafraîchissement du jeton pour qu'il porte le nouveau tenant et le nouveau profil. */
export async function switchProfile(profileId: string): Promise<ActiveClaims> {
  const { error } = await ks().rpc('switch_profile', { p_profile: profileId });
  if (error) throw toAppError(error);
  const { data, error: e2 } = await supabase!.auth.refreshSession();
  if (e2) throw toAppError(e2);
  const c = claimsOf(data.session);
  // Jeton rafraîchi sans revendication : crochet non activé côté Supabase. Message générique (règle de sécurité).
  if (!c || c.profileId !== profileId) throw toAppError({ message: 'SERVER_ERROR' });
  return c;
}

export async function fetchPermissions(): Promise<Set<string>> {
  const { data, error } = await ks().rpc('my_permissions');
  if (error) throw toAppError(error);
  return new Set((data ?? []) as string[]);
}

export type ProfileState =
  | { step: 'loading' }
  | { step: 'choose'; profiles: ProfileCard[] }
  | { step: 'none' }
  | { step: 'mfa'; profileId: string }
  | { step: 'error'; error: AppError }
  | { step: 'ready'; claims: ActiveClaims; permissions: Set<string> };

/**
 * Règles d'ouverture (§3.2) : profil déjà actif dans le jeton : ouverture ; un seul profil actif : bascule directe ;
 * plusieurs avec un défaut : bascule sur le défaut ; plusieurs sans défaut : sélecteur obligatoire ; aucun : page dédiée.
 */
export function useActiveProfile(session: Session | null, enabled: boolean) {
  const [state, setState] = useState<ProfileState>({ step: 'loading' });
  const [picker, setPicker] = useState<ProfileCard[] | null>(null);
  const claims = claimsOf(session);
  const userId = session?.user?.id ?? '';
  const activeId = claims?.profileId ?? '';

  const ready = useCallback(async (c: ActiveClaims) => {
    const permissions = await fetchPermissions();
    setState({ step: 'ready', claims: c, permissions });
  }, []);

  const choose = useCallback(async (profileId: string) => {
    try {
      const c = await switchProfile(profileId);
      setPicker(null);
      await ready(c);
    } catch (x) {
      const e = x as AppError;
      if (e.code === 'MFA_REQUIRED') { setState({ step: 'mfa', profileId }); return; }
      throw e;
    }
  }, [ready]);

  const load = useCallback(async () => {
    if (!enabled || !userId) return;
    setState({ step: 'loading' });
    try {
      const c = claimsOf((await supabase!.auth.getSession()).data.session);
      if (c) { await ready(c); return; }
      const all = await listProfiles();
      const active = all.filter((p) => p.status === 'active');
      if (!active.length) { setState({ step: 'none' }); return; }
      const auto = active.length === 1 ? active[0] : active.find((p) => p.is_default);
      if (auto) { await choose(auto.profile_id); return; }
      setState({ step: 'choose', profiles: all });
    } catch (x) {
      setState({ step: 'error', error: (x as AppError).code ? (x as AppError) : toAppError(x) });
    }
  }, [enabled, userId, ready, choose]);

  // Rechargé à chaque changement de compte ; pas à chaque rafraîchissement de jeton du même profil.
  useEffect(() => { void load(); }, [load]);

  /** Ouverture en cours de session (menu de l'avatar, raccourci G P). */
  const openPicker = useCallback(async () => {
    try { setPicker(await listProfiles()); } catch (x) { setState({ step: 'error', error: toAppError(x) }); }
  }, []);

  return { state, picker, activeId, choose, load, openPicker, closePicker: () => setPicker(null) };
}

import { useCallback, useEffect, useState } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from './supabase.ts';

/** Double authentification TOTP (Supabase Auth MFA) — application d'authentification type Google Authenticator, Microsoft Authenticator… */
export interface TotpFactor { id: string; friendly_name: string | null; status: 'verified' | 'unverified'; created_at: string }
export interface Aal { current: 'aal1' | 'aal2' | null; next: 'aal1' | 'aal2' | null }

function auth() {
  if (!supabase) throw new Error('Supabase non configuré.');
  return supabase.auth;
}
const fail = (e: { message: string } | null) => { if (e) throw new Error(e.message); };

export async function getAal(): Promise<Aal> {
  const { data, error } = await auth().mfa.getAuthenticatorAssuranceLevel();
  fail(error);
  return { current: (data?.currentLevel ?? null) as Aal['current'], next: (data?.nextLevel ?? null) as Aal['next'] };
}

/** Niveau d'assurance de la session : « aal2 » requis dès qu'un facteur vérifié existe. */
export function useAal(session: Session | null) {
  const [aal, setAal] = useState<Aal | null>(null);
  const refresh = useCallback(() => {
    if (!session || !supabase) { setAal(null); return; }
    getAal().then(setAal).catch(() => setAal({ current: 'aal1', next: 'aal1' }));
  }, [session]);
  useEffect(refresh, [refresh]);
  return { aal, refresh };
}

export async function listTotp(): Promise<TotpFactor[]> {
  const { data, error } = await auth().mfa.listFactors();
  fail(error);
  return ((data?.all ?? []) as unknown as TotpFactor[]).filter((f) => (f as unknown as { factor_type: string }).factor_type === 'totp');
}

export async function enrollTotp(name: string): Promise<{ id: string; qr: string; secret: string; uri: string }> {
  // un facteur non vérifié abandonné bloquerait un nouvel enrôlement du même nom
  for (const f of await listTotp()) if (f.status === 'unverified') await auth().mfa.unenroll({ factorId: f.id });
  const { data, error } = await auth().mfa.enroll({ factorType: 'totp', friendlyName: name });
  fail(error);
  if (!data || data.type !== 'totp') throw new Error('Enrôlement TOTP indisponible.');
  return { id: data.id, qr: data.totp.qr_code, secret: data.totp.secret, uri: data.totp.uri };
}

/** Vérifie un code à 6 chiffres : confirme un enrôlement ou élève la session en aal2. */
export async function verifyTotp(factorId: string, code: string): Promise<void> {
  const { error } = await auth().mfa.challengeAndVerify({ factorId, code: code.replace(/\s/g, '') });
  fail(error);
  await auth().refreshSession();
}

export async function verifyLogin(code: string): Promise<void> {
  const f = (await listTotp()).find((x) => x.status === 'verified');
  if (!f) throw new Error('Aucun facteur de double authentification vérifié.');
  await verifyTotp(f.id, code);
}

export async function unenrollTotp(factorId: string): Promise<void> {
  const { error } = await auth().mfa.unenroll({ factorId });
  fail(error);
  await auth().refreshSession();
}

import { createClient, type SupabaseClient } from '@supabase/supabase-js';

/**
 * Client Supabase — clé ANON uniquement (CDC §2.3). Jamais de service_role côté client.
 * Reste null si l'env n'est pas configuré, afin que l'UI tourne en mode démo.
 */
const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

export const supabase: SupabaseClient | null =
  url && anon ? createClient(url, anon, { auth: { persistSession: true } }) : null;

export const isBackendConfigured = Boolean(supabase);

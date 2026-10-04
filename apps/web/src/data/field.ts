import { supabase } from '../lib/supabase.ts';
import type { TechDayRow, TechWoDetail, AssetScan, WoTemplateRow, StockRow } from '@keystone/domain/db/keystone';

async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  if (!supabase) throw new Error('Supabase non configuré.');
  const { data, error } = await supabase.schema('keystone').rpc(fn, args);
  if (error) throw new Error(error.details ? `${error.message} — ${error.details}` : error.message);
  return data as T;
}

export const fetchTechPeople = () => rpc<{ id: string; name: string; open_wo: number }[]>('tech_people');
export const fetchMyDay = (person?: string) => rpc<TechDayRow[]>('tech_my_day', { p_person: person ?? null });
export const fetchWoDetail = (wo: string) => rpc<TechWoDetail>('tech_wo_detail', { p_wo: wo });
export const checkIn = (wo: string, pos: GeolocationCoordinates | null, person?: string) =>
  rpc<{ status: string; distance_m: number | null; off_site: boolean | null }>('tech_check_in', {
    p_wo: wo, p_lat: pos?.latitude ?? null, p_lng: pos?.longitude ?? null, p_accuracy: pos?.accuracy ?? null, p_person: person ?? null,
  });
export const holdWo = (wo: string, reason: string, person?: string) => rpc<void>('tech_hold', { p_wo: wo, p_reason: reason, p_person: person ?? null });
export const checkStep = (wo: string, index: number, value: unknown) => rpc<{ ok: boolean }>('tech_check_step', { p_wo: wo, p_index: index, p_value: value });
export const usePart = (wo: string, part: string, qty: number) => rpc<{ remaining: number }>('tech_use_part', { p_wo: wo, p_part: part, p_qty: qty });
export const completeWo = (wo: string, notes: string, signedBy: string, pos: GeolocationCoordinates | null, person?: string) =>
  rpc<{ minutes: number; labor_cost: number }>('tech_complete', {
    p_wo: wo, p_notes: notes, p_signed_by: signedBy, p_lat: pos?.latitude ?? null, p_lng: pos?.longitude ?? null, p_person: person ?? null,
  });
export const scanAsset = (code: string) => rpc<AssetScan>('asset_scan', { p_code: code });
export const reportIssue = (asset: string, title: string, priority: number) =>
  rpc<{ id: string; ref: string }>('tech_report_issue', { p_asset: asset, p_title: title, p_priority: priority });
export async function fetchStockLite(): Promise<StockRow[]> {
  const rows = await rpc<StockRow[]>('stock_board');
  return (rows ?? []).map((r) => ({ ...r, qty: Number(r.qty), min_qty: Number(r.min_qty) }));
}
export const fetchTemplates = () => rpc<WoTemplateRow[]>('wo_templates_board');
export const applyTemplate = (wo: string, template: string) => rpc<{ steps: number; planned_parts: number }>('wo_apply_template', { p_wo: wo, p_template: template });

/** Position GPS courante (null si refusée / indisponible — le pointage reste possible, sans distance). */
export function currentPosition(timeoutMs = 8000): Promise<GeolocationCoordinates | null> {
  return new Promise((resolve) => {
    if (!('geolocation' in navigator)) return resolve(null);
    navigator.geolocation.getCurrentPosition((p) => resolve(p.coords), () => resolve(null), { enableHighAccuracy: true, timeout: timeoutMs, maximumAge: 30000 });
  });
}

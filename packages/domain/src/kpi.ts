/**
 * KPI — formules faisant autorité (CDC §17). TypeScript pur, testé, jamais de LLM.
 */
import { type Money, subtract, toUnits } from './money.ts';

const safeDiv = (n: number, d: number): number => (d === 0 ? 0 : n / d);

/* ---------- Sécurité (indicateurs retardés) ---------- */

/** TRIR = (accidents enregistrables × 200 000) / heures travaillées. */
export const trir = (recordables: number, hoursWorked: number): number =>
  safeDiv(recordables * 200_000, hoursWorked);

/** LTIFR = (accidents avec arrêt × 1 000 000) / heures travaillées. */
export const ltifr = (lostTime: number, hoursWorked: number): number =>
  safeDiv(lostTime * 1_000_000, hoursWorked);

/** Taux de gravité = (jours perdus × 1 000) / heures travaillées. */
export const severityRate = (lostDays: number, hoursWorked: number): number =>
  safeDiv(lostDays * 1_000, hoursWorked);

/* ---------- Sécurité (indicateurs avancés) ---------- */

/** % CAPA dans les délais = CAPA clôturées à temps / CAPA dues. */
export const capaOnTimeRate = (closedOnTime: number, due: number): number =>
  safeDiv(closedOnTime, due);

/* ---------- FM / fiabilité ---------- */

export const mtbf = (uptimeHours: number, failures: number): number => safeDiv(uptimeHours, failures);
export const mttr = (repairHours: number, repairs: number): number => safeDiv(repairHours, repairs);

/** Disponibilité = MTBF / (MTBF + MTTR). */
export const availability = (mtbfH: number, mttrH: number): number => safeDiv(mtbfH, mtbfH + mttrH);

/** % préventif = OT préventifs / total OT. */
export const preventiveShare = (preventiveWO: number, totalWO: number): number =>
  safeDiv(preventiveWO, totalWO);

/* ---------- Budget (OPEX/CAPEX) ---------- */

export interface BudgetPosition {
  available: Money;
  executionRate: number;
}

/** Disponible = Budget − Engagé − Réalisé ; Taux d'exécution = Réalisé / Budget. */
export function budgetPosition(budget: Money, committed: Money, spent: Money): BudgetPosition {
  const available = subtract(subtract(budget, committed), spent);
  return { available, executionRate: safeDiv(toUnits(spent), toUnits(budget)) };
}

/* ---------- Conformité réglementaire (CRP) ---------- */

/** Taux de conformité CRP = contrôles à jour / contrôles dus. */
export const crpComplianceRate = (upToDate: number, due: number): number => safeDiv(upToDate, due);

/* ---------- Helpers d'affichage ---------- */

export const asPercent = (ratio: number, digits = 1): string =>
  `${(ratio * 100).toFixed(digits)} %`;

export const asRate = (value: number, digits = 2): string => value.toFixed(digits);

/**
 * Money.ts — arithmétique monétaire faisant autorité (CDC §2.1, §4.3).
 * Stockage en unités mineures (centimes) via bigint : JAMAIS de float natif.
 * XOF et XAF sont distinctes malgré la parité : aucune conversion automatique.
 */

export type Currency = 'XOF' | 'XAF';

export interface Money {
  /** Montant en unités mineures (centimes). numeric(18,2) en base => ×100. */
  readonly minor: bigint;
  readonly currency: Currency;
}

const MINOR_PER_UNIT = 100n;

export function money(amount: number | bigint | string, currency: Currency): Money {
  if (typeof amount === 'bigint') return { minor: amount, currency };
  if (typeof amount === 'number') {
    if (!Number.isFinite(amount)) throw new Error('Money: montant non fini');
    // On passe par une string à 2 décimales pour éviter toute imprécision float.
    return fromDecimalString(amount.toFixed(2), currency);
  }
  return fromDecimalString(amount, currency);
}

function fromDecimalString(s: string, currency: Currency): Money {
  const cleaned = s.trim().replace(/\s/g, '').replace(',', '.');
  const neg = cleaned.startsWith('-');
  const body = neg ? cleaned.slice(1) : cleaned;
  const [whole, frac = ''] = body.split('.');
  const fracPadded = (frac + '00').slice(0, 2);
  const minor = BigInt(whole || '0') * MINOR_PER_UNIT + BigInt(fracPadded || '0');
  return { minor: neg ? -minor : minor, currency };
}

function assertSameCurrency(a: Money, b: Money): void {
  if (a.currency !== b.currency) {
    throw new Error(
      `Money: opération entre devises distinctes (${a.currency} vs ${b.currency}) interdite. Conversion explicite requise.`,
    );
  }
}

export function add(a: Money, b: Money): Money {
  assertSameCurrency(a, b);
  return { minor: a.minor + b.minor, currency: a.currency };
}

export function subtract(a: Money, b: Money): Money {
  assertSameCurrency(a, b);
  return { minor: a.minor - b.minor, currency: a.currency };
}

/** Multiplication par un scalaire entier (ex. quantité). */
export function multiply(a: Money, factor: number | bigint): Money {
  if (typeof factor === 'bigint') return { minor: a.minor * factor, currency: a.currency };
  if (!Number.isInteger(factor)) {
    // Pour un facteur fractionnaire, on travaille au millième puis on arrondit (demi-supérieur).
    const scaled = BigInt(Math.round(factor * 1000));
    const product = a.minor * scaled;
    return { minor: roundDiv(product, 1000n), currency: a.currency };
  }
  return { minor: a.minor * BigInt(factor), currency: a.currency };
}

function roundDiv(num: bigint, den: bigint): bigint {
  const half = den / 2n;
  return num >= 0n ? (num + half) / den : -((-num + half) / den);
}

export function sum(items: Money[], currency: Currency): Money {
  return items.reduce((acc, m) => add(acc, m), money(0n, currency));
}

export function compare(a: Money, b: Money): -1 | 0 | 1 {
  assertSameCurrency(a, b);
  return a.minor < b.minor ? -1 : a.minor > b.minor ? 1 : 0;
}

export const isZero = (m: Money): boolean => m.minor === 0n;
export const isNegative = (m: Money): boolean => m.minor < 0n;

export interface FormatOptions {
  /** Afficher les centimes même si nuls (le franc CFA n'a pas de subdivision en circulation). */
  showMinor?: boolean;
  /** Symbole affiché (FCFA par défaut). */
  symbol?: string;
  locale?: string;
}

/** Formatage premium : groupes par espace fine insécable (U+202F), suffixe FCFA. */
export function format(m: Money, opts: FormatOptions = {}): string {
  const { showMinor = false, symbol = 'FCFA', locale = 'fr-FR' } = opts;
  const neg = m.minor < 0n;
  const abs = neg ? -m.minor : m.minor;
  const whole = abs / MINOR_PER_UNIT;
  const minor = abs % MINOR_PER_UNIT;
  const groups = new Intl.NumberFormat(locale, { useGrouping: true }).format(whole);
  const decimals = showMinor ? ',' + minor.toString().padStart(2, '0') : '';
  return `${neg ? '−' : ''}${groups}${decimals} ${symbol}`;
}

/** Valeur numérique en unités majeures — pour calculs KPI / ratios uniquement, jamais pour re-stocker. */
export const toUnits = (m: Money): number => Number(m.minor) / 100;

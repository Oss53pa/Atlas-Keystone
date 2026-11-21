/**
 * Money.ts : arithmétique monétaire de référence (Registre I01, I02, I03).
 *
 * I01  Montant = entier `bigint` en unité de la devise ; XOF et XAF à exposant 0 (ISO 4217) : un franc est l'unité,
 *      il n'existe pas de centime. Jamais de `number` flottant pour un montant stocké.
 * I02  Calcul intermédiaire exact, arrondi final au franc « demi vers le pair » (arrondi bancaire), une seule fois,
 *      au moment de stocker ; une répartition distribue les francs restants au plus fort reste.
 * I03  XOF et XAF ne s'additionnent jamais sans conversion explicite (parité 1 pour 1 en valeur, devises distinctes).
 */

export type Currency = 'XOF' | 'XAF';

export interface Money {
  /** Montant en francs entiers (exposant 0, I01). Nom historique conservé pour compatibilité. */
  readonly minor: bigint;
  readonly currency: Currency;
}

/** Rationnel exact (numérateur et dénominateur entiers), pour les calculs intermédiaires (I02). */
interface Ratio { n: bigint; d: bigint }

/** Arrondi « demi vers le pair » d'un rationnel n/d, d > 0 (I02). */
export function roundHalfEven(n: bigint, d: bigint): bigint {
  if (d <= 0n) throw new Error('Money: dénominateur non positif');
  const q = n / d;          // troncature vers zéro
  const r = n % d;          // même signe que n
  const twice = (r < 0n ? -r : r) * 2n;
  if (twice < d) return q;
  if (twice > d) return n < 0n ? q - 1n : q + 1n;
  // Exactement la moitié : vers l'entier pair.
  if (q % 2n === 0n) return q;
  return n < 0n ? q - 1n : q + 1n;
}

/** Décimal exact depuis une chaîne « 1 250 000 », « 12,5 », « -3.75 ». */
function parseDecimal(s: string): Ratio {
  const c = s.trim().replace(/[\s  ]/g, '').replace(',', '.');
  if (!/^-?\d+(\.\d+)?$/.test(c)) throw new Error(`Money: montant invalide « ${s} »`);
  const neg = c.startsWith('-');
  const [w, f = ''] = (neg ? c.slice(1) : c).split('.');
  const d = 10n ** BigInt(f.length);
  const n = BigInt(w) * d + BigInt(f || '0');
  return { n: neg ? -n : n, d };
}

function numberToRatio(x: number): Ratio {
  if (!Number.isFinite(x)) throw new Error('Money: montant non fini');
  // Représentation décimale la plus courte qui redonne x, sans notation exponentielle pour les montants usuels.
  return parseDecimal(Number.isInteger(x) ? x.toFixed(0) : x.toFixed(6).replace(/0+$/, '').replace(/\.$/, ''));
}

/**
 * Montant en francs. Un nombre ou une chaîne décimale est arrondi au franc par l'arrondi bancaire (I02) :
 * à n'employer qu'au moment de stocker ou d'afficher une valeur lue d'une source décimale.
 */
export function money(amount: number | bigint | string, currency: Currency): Money {
  if (typeof amount === 'bigint') return { minor: amount, currency };
  const r = typeof amount === 'number' ? numberToRatio(amount) : parseDecimal(amount);
  return { minor: roundHalfEven(r.n, r.d), currency };
}

function assertSameCurrency(a: Money, b: Money): void {
  if (a.currency !== b.currency) {
    throw new Error(`Money: ${a.currency} et ${b.currency} ne s'additionnent pas sans conversion (I03).`);
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

/**
 * Multiplication par un facteur (quantité, taux) : calcul exact puis un seul arrondi bancaire (I02).
 * Un facteur `number` est lu en décimal exact (ex. 0.18 = 18/100), jamais en flottant.
 */
export function multiply(a: Money, factor: number | bigint | string): Money {
  if (typeof factor === 'bigint') return { minor: a.minor * factor, currency: a.currency };
  const r = typeof factor === 'number' ? numberToRatio(factor) : parseDecimal(factor);
  return { minor: roundHalfEven(a.minor * r.n, r.d), currency: a.currency };
}

export function sum(items: Money[], currency: Currency): Money {
  return items.reduce((acc, m) => add(acc, m), money(0n, currency));
}

/**
 * Répartition d'un montant selon des poids entiers ou décimaux, au plus fort reste (I02) :
 * la somme des parts égale exactement le total ; à reste égal, l'ordre d'origine départage.
 */
export function allocate(total: Money, weights: (number | bigint | string)[]): Money[] {
  if (!weights.length) return [];
  const rs = weights.map((w) => (typeof w === 'bigint' ? { n: w, d: 1n } : typeof w === 'number' ? numberToRatio(w) : parseDecimal(w)));
  const lcm = rs.reduce((acc, r) => (acc * r.d) / gcd(acc, r.d), 1n);
  const ints = rs.map((r) => (r.n * lcm) / r.d);
  if (ints.some((x) => x < 0n)) throw new Error('Money: poids négatif');
  const W = ints.reduce((a, b) => a + b, 0n);
  if (W === 0n) throw new Error('Money: somme des poids nulle');
  const neg = total.minor < 0n;
  const T = neg ? -total.minor : total.minor;
  const base = ints.map((w) => (T * w) / W);
  const rest = ints.map((w, i) => ({ i, r: (T * w) % W }));
  let left = T - base.reduce((a, b) => a + b, 0n);
  rest.sort((x, y) => (y.r > x.r ? 1 : y.r < x.r ? -1 : x.i - y.i));
  for (const { i } of rest) { if (left === 0n) break; base[i] += 1n; left -= 1n; }
  return base.map((b) => ({ minor: neg ? -b : b, currency: total.currency }));
}

function gcd(a: bigint, b: bigint): bigint {
  while (b) [a, b] = [b, a % b];
  return a < 0n ? -a : a;
}

export function compare(a: Money, b: Money): -1 | 0 | 1 {
  assertSameCurrency(a, b);
  return a.minor < b.minor ? -1 : a.minor > b.minor ? 1 : 0;
}

export const isZero = (m: Money): boolean => m.minor === 0n;
export const isNegative = (m: Money): boolean => m.minor < 0n;

export interface FormatOptions {
  /** Symbole affiché. Défaut : « FCFA » ; en contexte multi-devises (I03), passer la devise (XOF ou XAF). */
  symbol?: string;
}

/** Groupes de 3 chiffres séparés par une espace fine insécable U+202F, sans décimale (Lot 1 §7.5). */
export function format(m: Money, opts: FormatOptions = {}): string {
  const { symbol = 'FCFA' } = opts;
  const neg = m.minor < 0n;
  const digits = (neg ? -m.minor : m.minor).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  return `${neg ? '−' : ''}${digits} ${symbol}`;
}

/** Valeur en francs, pour ratios et indicateurs seulement : jamais pour recalculer ni re-stocker un montant. */
export const toUnits = (m: Money): number => Number(m.minor);

/** Totaux multi-devises (I03) : un total par devise, jamais additionnés entre eux. */
export function totalsByCurrency(items: Money[]): Partial<Record<Currency, Money>> {
  const out: Partial<Record<Currency, Money>> = {};
  for (const m of items) out[m.currency] = out[m.currency] ? add(out[m.currency]!, m) : m;
  return out;
}

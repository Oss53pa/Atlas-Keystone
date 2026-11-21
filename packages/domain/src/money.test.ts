import { test } from 'node:test';
import assert from 'node:assert/strict';
import { money, add, multiply, allocate, format, roundHalfEven, totalsByCurrency, toUnits } from './money.ts';

test('I01 : francs entiers en bigint, aucune décimale stockée', () => {
  assert.equal(money('1 250 000', 'XOF').minor, 1250000n);
  assert.equal(money(1250000, 'XOF').minor, 1250000n);
  assert.equal(format(money(1250000, 'XOF')), '1 250 000 FCFA');
  assert.equal(format(money(-5000, 'XAF'), { symbol: 'XAF' }), '−5 000 XAF');
});

test('I02 : arrondi demi vers le pair, une seule fois', () => {
  assert.equal(roundHalfEven(5n, 2n), 2n);   // 2,5 -> 2
  assert.equal(roundHalfEven(7n, 2n), 4n);   // 3,5 -> 4
  assert.equal(roundHalfEven(-5n, 2n), -2n); // -2,5 -> -2
  assert.equal(roundHalfEven(-7n, 2n), -4n);
  assert.equal(roundHalfEven(26n, 10n), 3n); // 2,6 -> 3
  assert.equal(money('2,5', 'XOF').minor, 2n);
  assert.equal(money('3.5', 'XOF').minor, 4n);
  // TVA 18 % sur 1 250 001 : 225 000,18 -> 225 000 (calcul exact, pas de flottant)
  assert.equal(multiply(money(1250001, 'XOF'), 0.18).minor, 225000n);
  assert.equal(multiply(money(250, 'XOF'), '0.5').minor, 125n);
  assert.equal(multiply(money(5, 'XOF'), '0.5').minor, 2n); // 2,5 -> 2
});

test('I02 : répartition au plus fort reste, somme exacte', () => {
  const parts = allocate(money(100, 'XOF'), [1, 1, 1]);
  assert.deepEqual(parts.map((p) => p.minor), [34n, 33n, 33n]);
  const p2 = allocate(money(1000, 'XOF'), ['0.5', '0.3', '0.2']);
  assert.deepEqual(p2.map((p) => p.minor), [500n, 300n, 200n]);
  const p3 = allocate(money(-10, 'XOF'), [1, 2]);
  assert.equal(p3.reduce((a, p) => a + p.minor, 0n), -10n);
  assert.throws(() => allocate(money(10, 'XOF'), [0, 0]));
});

test('I03 : XOF et XAF jamais additionnés', () => {
  assert.throws(() => add(money(1, 'XOF'), money(1, 'XAF')), /I03/);
  const t = totalsByCurrency([money(10, 'XOF'), money(5, 'XAF'), money(7, 'XOF')]);
  assert.equal(t.XOF?.minor, 17n);
  assert.equal(t.XAF?.minor, 5n);
  assert.equal(toUnits(money(42, 'XOF')), 42);
});

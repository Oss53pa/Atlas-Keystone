import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  parseAmount, groupDigits, parseFrDate, parseDecimal, validateForm, sectionState, zodSchemaFor,
  submittedValues, sniffMime, storageName, type FormSpec,
} from './forms.ts';

const now = new Date(2026, 10, 21, 10, 0, 0);
const spec: FormSpec = {
  id: 'demo', title: 'Démonstration',
  sections: [
    { id: 's1', title: 'Quoi', fields: [
      { key: 'what', label: 'Quoi ?', component: 'textarea', required: true, rules: [{ rule: 'min_length', n: 10 }], messages: { min_length: 'Décrivez le problème en 10 caractères au moins.' } },
      { key: 'kind', label: 'Type', component: 'select', required: true, options: [{ value: 'a', label: 'A' }, { value: 'b', label: 'B' }] },
      { key: 'detail', label: 'Précision', component: 'text', required: true, showIf: { field: 'kind', equals: 'b' } },
    ] },
    { id: 's2', title: 'Quand', fields: [
      { key: 'start', label: 'Début prévu', component: 'date', required: false },
      { key: 'end', label: 'Fin prévue', component: 'date', required: false, rules: [{ rule: 'after', field: 'start' }], messages: { after: 'La fin prévue suit le début.' } },
      { key: 'when', label: 'Survenu le', component: 'datetime', required: false, rules: [{ rule: 'not_future' }] },
      { key: 'temp', label: 'Température', component: 'number', required: false, unit: '°C', rules: [{ rule: 'min', n: -40 }, { rule: 'max', n: 120 }, { rule: 'decimals', n: 1 }] },
      { key: 'amt', label: 'Montant HT', component: 'amount', required: false },
    ] },
  ],
};

test('montant FCFA : entier, groupement U+202F, centimes refusés', () => {
  assert.deepEqual(parseAmount('1 250 000'), { value: '1250000' });
  assert.deepEqual(parseAmount('1.250.000'), { value: '1250000' });
  assert.deepEqual(parseAmount('1250000,00'), { value: '1250000' });
  assert.deepEqual(parseAmount('1250,50'), { error: 'amount_decimals' });
  assert.deepEqual(parseAmount('1000000000000'), { error: 'amount_max' });
  assert.equal(groupDigits('1250000'), '1 250 000');
});

test('date libre normalisée, date impossible refusée', () => {
  assert.deepEqual(parseFrDate('5/11/26', now), { iso: '2026-11-05' });
  assert.deepEqual(parseFrDate('05112026', now), { iso: '2026-11-05' });
  assert.deepEqual(parseFrDate('demain', now), { iso: '2026-11-22' });
  assert.deepEqual(parseFrDate('31/11/2026', now), { error: 'date_invalid', jour: '31/11' });
  assert.deepEqual(parseFrDate('3/11', now), { error: 'date_incomplete' });
  assert.equal(parseDecimal('12,5'), 12.5);
});

test('obligatoires, message du lot, champ conditionnel', () => {
  let e = validateForm(spec, {}, { now });
  assert.equal(e.byKey.what, 'Renseignez quoi ?.');
  assert.equal(e.byKey.kind, 'Choisissez type.');
  assert.equal(e.byKey.detail, undefined, 'champ masqué non validé');
  e = validateForm(spec, { what: 'court', kind: 'b' }, { now });
  assert.equal(e.byKey.what, 'Décrivez le problème en 10 caractères au moins.');
  assert.equal(e.byKey.detail, 'Renseignez précision.');
  assert.deepEqual(Object.keys(submittedValues(spec, { what: 'x', kind: 'a', detail: 'caché' })), ['what', 'kind']);
});

test('dates relatives, nombre borné, décimales', () => {
  const e = validateForm(spec, { what: 'Fuite sous évier', kind: 'a', start: '2026-11-25', end: '2026-11-24', when: '2026-11-21T12:00:00', temp: '130', amt: '12,50' }, { now });
  assert.equal(e.byKey.end, 'La fin prévue suit le début.');
  assert.equal(e.byKey.when, 'La date ne peut pas être dans le futur.');
  assert.equal(e.byKey.temp, 'La valeur doit être comprise entre -40 et 120.');
  assert.equal(e.byKey.amt, 'Les francs CFA n’ont pas de décimales.');
  assert.equal(validateForm(spec, { what: 'Fuite sous évier', kind: 'a', temp: '4,25' }, { now }).byKey.temp, '1 décimales au plus.');
});

test('état des sections pour le sommaire latéral', () => {
  const v = { what: 'Fuite sous évier', kind: 'a' };
  const e = validateForm(spec, v, { now }).byKey;
  assert.equal(sectionState(spec.sections[0], v, e, () => true).state, 'complete');
  assert.equal(sectionState(spec.sections[1], v, e, () => true).state, 'optional');
  assert.equal(sectionState(spec.sections[0], {}, validateForm(spec, {}, { now }).byKey, () => true).state, 'error');
  assert.equal(sectionState(spec.sections[0], {}, {}, () => false).state, 'incomplete');
});

test('schéma Zod strict : champ inconnu refusé', () => {
  const z = zodSchemaFor(spec, { now });
  assert.equal(z.safeParse({ what: 'Fuite sous évier', kind: 'a' }).success, true);
  assert.equal(z.safeParse({ what: 'Fuite sous évier', kind: 'a', pirate: 1 }).success, false);
});

test('type vérifié sur les octets, nom régénéré', () => {
  assert.equal(sniffMime(new Uint8Array([0xff, 0xd8, 0xff, 0xe0])), 'image/jpeg');
  assert.equal(sniffMime(new Uint8Array([0x25, 0x50, 0x44, 0x46])), 'application/pdf');
  assert.equal(sniffMime(new Uint8Array([0x3c, 0x73, 0x76, 0x67])), null);
  assert.equal(storageName('image/png', () => 'abc'), 'abc.png');
});

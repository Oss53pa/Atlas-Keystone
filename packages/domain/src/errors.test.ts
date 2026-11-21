import { test } from 'node:test';
import assert from 'node:assert/strict';
import { toAppError, errorText, hasErrorCode } from './errors.ts';

test('erreur PostgREST au format A69 : code, statut, variables du détail', () => {
  const e = toAppError({ code: 'PT409', message: 'PO_NOT_RECEIVABLE', details: '{"reference":"CMD-2026-000188","statut":"brouillon"}' });
  assert.equal(e.code, 'PO_NOT_RECEIVABLE');
  assert.equal(e.status, 409);
  assert.equal(e.message, 'La commande CMD-2026-000188 est au statut « brouillon » : seule une commande envoyée ou partiellement reçue se réceptionne.');
});

test('alias résolu vers le code officiel (A67)', () => {
  assert.equal(toAppError({ code: 'PT409', message: 'STALE_RECORD', details: '{}' }).code, 'VERSION_CONFLICT');
});

test('code inconnu ou message technique : SERVER_ERROR, sans fuite du texte brut', () => {
  const e = toAppError({ code: '23505', message: 'duplicate key value violates unique constraint "uq_x" (secret)' });
  assert.equal(e.code, 'SERVER_ERROR');
  assert.ok(!e.message.includes('secret') && !e.message.includes('uq_x'));
  assert.equal(toAppError({ code: 'PT400', message: 'CODE_QUI_NEXISTE_PAS' }).code, 'SERVER_ERROR');
});

test('réseau et délai', () => {
  assert.equal(toAppError(new TypeError('Failed to fetch')).code, 'NETWORK_UNAVAILABLE');
  assert.equal(toAppError({ name: 'AbortError', message: 'aborted' }).code, 'REQUEST_TIMEOUT');
});

test('variable absente : jeton remplacé, jamais affiché brut', () => {
  assert.equal(errorText('REQUIRED_FIELD'), 'Renseignez ….');
  assert.equal(errorText('REQUIRED_FIELD', { champ: 'le lieu' }), 'Renseignez le lieu.');
  assert.ok(hasErrorCode('PERMISSION_DENIED') && !hasErrorCode('NOPE'));
});

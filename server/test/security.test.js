// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import assert from 'node:assert/strict';
import { test } from 'node:test';

import * as seed from '../src/seed.js';
import { cleanText, hashSecret, isTrivialPin, safeEqual, signJwt, verifyJwt, verifySecret } from '../src/security.js';

const KEY = Buffer.alloc(32, 7);
const OPTS = { issuer: 'aquaaware', audience: 'aquaaware-app' };

test('PBKDF2 hashes are interchangeable with the Flutter app', async () => {
  // The same encoded hashes ship in lib/data/seed/community_seed.dart.
  const kavitha = seed.accounts.find((a) => a.id === 'EDU001');
  assert.equal(await verifySecret('Kavitha#2026', kavitha.secretHash), true);
  assert.equal(await verifySecret('kavitha#2026', kavitha.secretHash), false);
  const fresh = await hashSecret('Monsoon rain 2026!');
  assert.match(fresh, /^pbkdf2-sha256\$100000\$[A-Za-z0-9+/=]+\$[A-Za-z0-9+/=]+$/);
  assert.equal(await verifySecret('Monsoon rain 2026!', fresh), true);
});

test('malformed or weakened hashes never verify', async () => {
  assert.equal(await verifySecret('x', 'plain-text-password'), false);
  assert.equal(await verifySecret('x', 'pbkdf2-sha256$10$AAAA$AAAA'), false, 'too few iterations');
  assert.equal(await verifySecret('x', null), false);
});

test('JWT: valid, expired, wrong audience', () => {
  const now = Date.now();
  const iat = Math.floor(now / 1000);
  const base = { sub: 'EDU001', sid: 'SES-1', role: 'educator', iat, exp: iat + 60, iss: 'aquaaware', aud: 'aquaaware-app' };
  assert.equal(verifyJwt(signJwt(base, KEY), KEY, OPTS)?.sub, 'EDU001');
  assert.equal(verifyJwt(signJwt({ ...base, exp: iat - 1 }, KEY), KEY, OPTS), null);
  assert.equal(verifyJwt(signJwt({ ...base, aud: 'someone-else' }, KEY), KEY, OPTS), null);
  assert.equal(verifyJwt(signJwt(base, Buffer.alloc(32, 8)), KEY, OPTS), null, 'different key');
  assert.equal(verifyJwt('not.a.jwt', KEY, OPTS), null);
});

test('constant-time comparison handles different lengths', () => {
  assert.equal(safeEqual('abc', 'abc'), true);
  assert.equal(safeEqual('abc', 'abcd'), false);
  assert.equal(safeEqual(Buffer.from([1, 2]), Buffer.from([1, 3])), false);
});

test('text cleaning and PIN rules match the app', () => {
  assert.equal(cleanText('Hi‮evil​ there\u0007', 500), 'Hievil there');
  assert.equal(cleanText('a'.repeat(600), 500).length, 500);
  assert.equal(cleanText(42, 10), '');
  for (const pin of ['1111', '1234', '4321', '9012']) assert.equal(isTrivialPin(pin), true, pin);
  assert.equal(isTrivialPin('2580'), false);
});

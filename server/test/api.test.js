// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { isQuietHours } from '../src/app.js';
import { students as seedStudents } from '../src/seed.js';
import { STAFF, startServer } from './helpers.js';

const withServer = (name, fn, env) =>
  test(name, async () => {
    const s = await startServer(env);
    try {
      await fn(s);
    } finally {
      await s.close();
    }
  });

// ------------------------------------------------------------ transport ---

withServer('health check answers with hardened headers', async ({ call }) => {
  const r = await call('GET', '/health');
  assert.equal(r.status, 200);
  assert.equal(r.json.ok, true);
  assert.equal(r.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(r.headers.get('x-frame-options'), 'DENY');
  assert.equal(r.headers.get('cache-control'), 'no-store');
  assert.match(r.headers.get('content-security-policy'), /default-src 'none'/);
});

withServer('unknown routes give JSON 404 with no internals', async ({ call }) => {
  const r = await call('GET', '/nope');
  assert.equal(r.status, 404);
  assert.equal(r.json.code, 'not_found');
  assert.doesNotMatch(r.text, /at .*\.js:\d+/, 'no stack trace');
});

withServer('CORS allows only listed web origins', async ({ call }) => {
  const bad = await call('GET', '/health', { headers: { origin: 'https://evil.example' } });
  assert.equal(bad.status, 403);
  assert.equal(bad.headers.get('access-control-allow-origin'), null);
  const good = await call('GET', '/health', { headers: { origin: 'https://app.aquaaware.org' } });
  assert.equal(good.status, 200);
  assert.equal(good.headers.get('access-control-allow-origin'), 'https://app.aquaaware.org');
  const native = await call('GET', '/health');
  assert.equal(native.status, 200, 'apps send no Origin header');
});

withServer('oversized and non-JSON bodies are refused', async ({ call }) => {
  const big = await call('POST', '/auth/staff', { raw: 'x'.repeat(40_000), headers: { 'content-type': 'application/json' } });
  assert.equal(big.status, 413);
  const text = await call('POST', '/auth/staff', { raw: 'role=manager', headers: { 'content-type': 'text/plain' } });
  assert.equal(text.status, 415);
  const broken = await call('POST', '/auth/staff', { raw: '{"role":', headers: { 'content-type': 'application/json' } });
  assert.equal(broken.status, 400);
});

// --------------------------------------------------------------- sign-in ---

withServer('staff sign in with the seeded demo accounts', async ({ login }) => {
  for (const who of ['educator', 'ngo', 'manager']) {
    const s = await login(who);
    assert.ok(s.token.split('.').length === 3, `${who} gets a JWT`);
    assert.equal(Buffer.from(s.signingKey, 'base64').length, 32, `${who} gets a 256-bit signing key`);
    assert.equal(s.user.role, STAFF[who].role);
  }
});

withServer('offices use AquaAware too: a team lead and an employee sign in', async ({ login, student, sync }) => {
  const lead = await login('officeLead');
  assert.equal(lead.user.role, 'educator', 'a team lead has the leader role');
  assert.equal(lead.user.classCode, 'AWA-2026-CTP');
  const ravi = await student('Ravi', 'AWA-2026-CTP', '4826');
  assert.equal(ravi.user.role, 'student', 'an employee has the member role');
  const post = await sync(lead, 'announcement', {
    id: 'ANN-office-test-1',
    message: 'Switch off the corridor taps before you leave.',
    audience: 'AWA-2026-CTP',
  });
  assert.equal(post.status, 201, `the team lead posts to their team: ${post.text}`);
});

withServer('wrong password and unknown email get the same answer', async ({ call }) => {
  const wrong = await call('POST', '/auth/staff', { body: { ...STAFF.educator, secret: 'nope-nope-nope' } });
  const unknown = await call('POST', '/auth/staff', { body: { ...STAFF.educator, loginId: 'ghost@aquaaware.org' } });
  assert.equal(wrong.status, 401);
  assert.equal(unknown.status, 401);
  assert.equal(wrong.json.error, unknown.json.error, 'no account enumeration');
});

withServer('five failures lock the sign-in and send Retry-After', async ({ call }) => {
  let last;
  for (let i = 0; i < 5; i++) {
    last = await call('POST', '/auth/staff', { body: { ...STAFF.manager, secret: `wrong-${i}-password` } });
  }
  assert.equal(last.status, 429);
  assert.ok(Number(last.headers.get('retry-after')) >= 1);
  const right = await call('POST', '/auth/staff', { body: STAFF.manager });
  assert.equal(right.status, 429, 'even the right password waits out the lock');
});

withServer('auth endpoints are rate limited per address', async ({ call }) => {
  const codes = [];
  for (let i = 0; i < 12; i++) {
    const r = await call('POST', '/auth/student', { body: { name: 'Priya', classCode: 'AWA-2024-GHS', pin: 'abcd' } });
    codes.push(r.status);
  }
  assert.ok(codes.slice(0, 10).every((c) => c === 400), 'first ten are processed');
  assert.equal(codes.at(-1), 429);
});

withServer('students claim a profile with a PIN, then must use it', async ({ call, student }) => {
  const weak = await call('POST', '/auth/student', { body: { name: 'Priya', classCode: 'AWA-2024-GHS', pin: '1234' } });
  assert.equal(weak.status, 400);
  assert.equal(weak.json.code, 'weak_pin');

  const first = await student('Priya', 'AWA-2024-GHS', '2580');
  assert.equal(first.user.id, 'STU002', 'seeded profile keeps its id');
  const again = await student('priya', 'awa-2024-ghs', '2580');
  assert.equal(again.user.id, 'STU002', 'name and code are case-insensitive');

  const wrong = await call('POST', '/auth/student', { body: { name: 'Priya', classCode: 'AWA-2024-GHS', pin: '9071' } });
  assert.equal(wrong.status, 401);
  const noClass = await call('POST', '/auth/student', { body: { name: 'Priya', classCode: 'AWA-2099-XYZ', pin: '2580' } });
  assert.equal(noClass.status, 401);
});

withServer('forged, edited and alg:none tokens are rejected', async ({ call, login }) => {
  const s = await login('educator');
  const [h, body, sig] = s.token.split('.');
  const claims = JSON.parse(Buffer.from(body, 'base64url').toString());
  const edited = Buffer.from(JSON.stringify({ ...claims, role: 'manager' })).toString('base64url');
  const none = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  for (const token of [`${h}.${edited}.${sig}`, `${none}.${body}.`, `${h}.${body}.${'A'.repeat(43)}`]) {
    const r = await call('GET', '/announcements', { token });
    assert.equal(r.status, 401, token.slice(0, 20));
  }
  const ok = await call('GET', '/announcements', { token: s.token });
  assert.equal(ok.status, 200);
});

withServer('sign-out revokes the session on the server', async ({ call, login }) => {
  const s = await login('ngo');
  assert.equal((await call('POST', '/auth/logout', { token: s.token })).status, 200);
  assert.equal((await call('GET', '/announcements', { token: s.token })).status, 401);
});

withServer('production refuses to start without a strong secret or TLS', async () => {
  const { loadConfig } = await import('../src/config.js');
  assert.throws(() => loadConfig({ NODE_ENV: 'production', AQUA_QUIET: '1' }), /AQUA_JWT_SECRET/);
  assert.throws(
    () => loadConfig({ NODE_ENV: 'production', AQUA_JWT_SECRET: 'x'.repeat(40), AQUA_QUIET: '1' }),
    /TLS/,
  );
  const ok = loadConfig({ NODE_ENV: 'production', AQUA_JWT_SECRET: 'x'.repeat(40), AQUA_BEHIND_TLS_PROXY: '1' });
  assert.equal(ok.production, true);
});

// ------------------------------------------------------------------ sync ---

withServer('sync requires a session-signed body and an idempotency key', async ({ call, student, sync }) => {
  const st = await student();
  const unsigned = await sync(st, 'quiz_score', { moduleId: 'MOD_A', correct: 7, total: 10 }, { sign: false });
  assert.equal(unsigned.status, 401);
  assert.equal(unsigned.json.code, 'bad_signature');

  const tampered = await sync(st, 'quiz_score', { moduleId: 'MOD_A', correct: 7, total: 10 }, {
    tamper: (t) => t.replace('"correct":7', '"correct":10'),
  });
  assert.equal(tampered.status, 401, 'an edited body fails the HMAC (Q7 integrity)');

  const noKey = await call('POST', '/sync/quiz_score', {
    token: st.token,
    headers: { 'content-type': 'application/json' },
    raw: '{}',
  });
  assert.equal(noKey.status, 400);
});

withServer('a retried request is acknowledged once, never applied twice (Q5)', async ({ db, student, sync }) => {
  const st = await student();
  const first = await sync(st, 'points', { delta: 20, reason: 'Finished module A', ref: 'module:MOD_A' }, { id: 'retry-test-0001' });
  assert.equal(first.status, 201);
  const retry = await sync(st, 'points', { delta: 20, reason: 'Finished module A', ref: 'module:MOD_A' }, { id: 'retry-test-0001', createdAt: JSON.parse(first.text).createdAt });
  assert.equal(retry.status, 200);
  assert.equal(retry.json.duplicate, true);
  const rows = db.prepare("SELECT COUNT(*) AS n FROM events WHERE id = 'retry-test-0001'").get().n;
  assert.equal(rows, 1);

  const reused = await sync(st, 'quiz_score', { moduleId: 'MOD_A', correct: 3, total: 10 }, { id: 'retry-test-0001' });
  assert.equal(reused.status, 409, 'same key, different body');
});

withServer('stale or future-dated items are refused', async ({ student, sync }) => {
  const st = await student();
  const old = await sync(st, 'quiz_score', { moduleId: 'MOD_A', correct: 3, total: 10 }, {
    createdAt: new Date(Date.now() - 40 * 86_400_000).toISOString(),
  });
  assert.equal(old.status, 422);
  const future = await sync(st, 'quiz_score', { moduleId: 'MOD_A', correct: 3, total: 10 }, {
    createdAt: new Date(Date.now() + 3_600_000).toISOString(),
  });
  assert.equal(future.status, 422);
});

withServer('roles are enforced per kind of update', async ({ login, student, sync }) => {
  const st = await student();
  const asStudent = await sync(st, 'announcement', { id: 'ANN-student-01', message: 'Hi', audience: 'ALL' });
  assert.equal(asStudent.status, 403);

  const edu = await login('educator');
  const otherClass = await sync(edu, 'announcement', { id: 'ANN-other-0001', message: 'Hi', audience: 'AWA-2024-SJH' });
  assert.equal(otherClass.status, 403, 'educators post only to their own class (Q6)');
  const quiz = await sync(edu, 'quiz_score', { moduleId: 'MOD_A', correct: 3, total: 10 });
  assert.equal(quiz.status, 403);

  const mgr = await login('manager');
  const redeem = await sync(mgr, 'redemption', { claimId: 'CLM-abcdef', nonce: 'abcdefghijkl' });
  assert.equal(redeem.status, 403, 'only NGO desks redeem');
});

withServer('announcements reach exactly their audience (Q6)', async ({ call, login, student, sync }) => {
  const edu = await login('educator'); // AWA-2024-GHS
  const posted = await sync(edu, 'announcement', {
    id: 'ANN-ghs-task-01',
    message: 'Bring a steel bottle tomorrow‮.',
    audience: 'AWA-2024-GHS',
    urgent: true,
    sentAt: new Date().toISOString(),
  });
  assert.equal(posted.status, 201);

  const ghs = await student('Priya', 'AWA-2024-GHS', '2580');
  const sjh = await student('Vishwa', 'AWA-2024-SJH', '3691');
  const ngo = await login('ngo');

  const seen = async (s) => (await call('GET', '/announcements', { token: s.token })).json.events
    .filter((e) => e.type === 'announcement')
    .map((e) => e.data.id);
  assert.ok((await seen(ghs)).includes('ANN-ghs-task-01'));
  assert.ok(!(await seen(sjh)).includes('ANN-ghs-task-01'), 'another school cannot see it');
  assert.ok((await seen(ngo)).includes('ANN-ghs-task-01'));
  assert.ok((await seen(sjh)).includes('ANN-seed-1'), 'NGO broadcasts to ALL reach every school');

  const events = (await call('GET', '/announcements', { token: ghs.token })).json.events;
  const msg = events.find((e) => e.data.id === 'ANN-ghs-task-01').data.message;
  assert.equal(msg, 'Bring a steel bottle tomorrow.', 'bidi-override characters are stripped');

  const since = Math.max(...events.map((e) => e.seq));
  const later = (await call('GET', `/announcements?since=${since}`, { token: ghs.token })).json.events;
  assert.equal(later.length, 0, '"since" returns only newer events');
});

withServer('completions reach the sender, once per student', async ({ call, login, student, sync }) => {
  const edu = await login('educator');
  const st = await student();
  const a = await sync(st, 'announcement_done', { announcementId: 'ANN-seed-2' });
  assert.equal(a.status, 201);
  const b = await sync(st, 'announcement_done', { announcementId: 'ANN-seed-2' });
  assert.equal(b.json.duplicate, true);
  const sjh = await student('Vishwa', 'AWA-2024-SJH', '3691');
  const other = await sync(sjh, 'announcement_done', { announcementId: 'ANN-seed-2' });
  assert.equal(other.status, 403, 'not for that class');

  const feed = (await call('GET', '/announcements', { token: edu.token })).json.events;
  const done = feed.filter((e) => e.type === 'announcement_done');
  assert.equal(done.length, 1);
  assert.equal(done[0].data.announcementId, 'ANN-seed-2');
});

// ---------------------------------------------------------------- points ---

withServer('points must match the rules; the server keeps the caps', async ({ db, student, sync }) => {
  const st = await student();
  const give = (delta, ref, id) => sync(st, 'points', { delta, reason: 'test', ref }, id ? { id } : {});

  assert.equal((await give(20, 'module:MOD_A')).status, 201);
  assert.equal((await give(99, 'module:MOD_B')).json.code, 'points_rule', 'wrong amount for a module');
  assert.equal((await give(10, 'made-up:thing')).json.code, 'points_rule', 'unknown achievement');

  // Quiz: improvements only — 6/10 then 8/10 pays 60 + 20; claiming 8/10 again is ignored,
  // and paying more than the score allows is refused.
  assert.equal((await give(60, 'quiz:MOD_A:6')).status, 201);
  assert.equal((await give(20, 'quiz:MOD_A:8')).status, 201);
  assert.equal((await give(30, 'quiz:MOD_A:9')).json.code, 'points_rule', '80 + 30 > 90');
  assert.equal((await give(10, 'quiz:MOD_A:9')).status, 201);

  // Tasks: the amount depends on who sent the task.
  assert.equal((await give(10, 'ann:ANN-seed-1')).status, 201, 'NGO task = 10');
  assert.equal((await give(10, 'ann:ANN-seed-2')).json.code, 'points_rule', 'educator task = 5');
  assert.equal((await give(5, 'ann:ANN-seed-2')).status, 201);

  // Pickups: must have been requested, and only two a day pay.
  assert.equal((await give(15, 'pickup:PCK-never-asked')).json.code, 'points_rule');
  for (const id of ['PCK-one-1', 'PCK-two-2', 'PCK-three-3']) {
    assert.equal((await sync(st, 'pickup', { id, collectorId: 'COL001' })).status, 201);
  }
  assert.equal((await give(15, 'pickup:PCK-one-1')).status, 201);
  assert.equal((await give(15, 'pickup:PCK-two-2')).status, 201);
  assert.equal((await give(15, 'pickup:PCK-three-3')).json.code, 'points_rule', 'daily cap');

  // Water bonus: only for today.
  const today = new Date(Date.now() + 5.5 * 3_600_000).toISOString().slice(0, 10);
  assert.equal((await give(5, `water:${today}`)).status, 201);
  assert.equal((await give(5, 'water:2020-01-01')).json.code, 'points_rule');

  const total = db.prepare("SELECT SUM(delta) AS t FROM points WHERE user_id = 'STU002'").get().t;
  assert.equal(total, 20 + 60 + 20 + 10 + 10 + 5 + 15 + 15 + 5);
});

withServer('a reward ticket can be redeemed once (Q9 anti-replay)', async ({ login, sync }) => {
  const desk = await login('ngo');
  const first = await sync(desk, 'redemption', { claimId: 'CLM-abcdef01', nonce: 'nonce-0123456789' });
  assert.equal(first.status, 201);
  const replay = await sync(desk, 'redemption', { claimId: 'CLM-abcdef01', nonce: 'nonce-0123456789' });
  assert.equal(replay.status, 409);
  assert.equal(replay.json.code, 'replay');
});

withServer('managers move students; only managers see the audit log', async ({ call, db, login, sync }) => {
  const mgr = await login('manager');
  const moved = await sync(mgr, 'student_transfer', { studentId: 'STU001', from: 'AWA-2024-GHS', to: 'AWA-2024-SJH' });
  assert.equal(moved.status, 201);
  assert.equal(db.prepare("SELECT class_code FROM students WHERE id = 'STU001'").get().class_code, 'AWA-2024-SJH');

  const edu = await login('educator');
  assert.equal((await call('GET', '/admin/audit', { token: edu.token })).status, 403);
  const audit = await call('GET', '/admin/audit?limit=5', { token: mgr.token });
  assert.equal(audit.status, 200);
  assert.ok(audit.json.entries.some((e) => /moved STU001/.test(e.action)));
  const summary = await call('GET', '/admin/summary', { token: mgr.token });
  assert.equal(summary.json.students.total, seedStudents.length);
});

// -------------------------------------------------------------- realtime ---

withServer('the live feed replays missed events, then streams new ones', async ({ base, login, student, sync }) => {
  const st = await student();
  const edu = await login('educator');
  const controller = new AbortController();
  const res = await fetch(`${base}/feed`, { headers: { authorization: `Bearer ${st.token}` }, signal: controller.signal });
  assert.equal(res.status, 200);
  assert.match(res.headers.get('content-type'), /text\/event-stream/);
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  const readUntil = async (needle) => {
    const deadline = Date.now() + 3000;
    while (!buffer.includes(needle)) {
      if (Date.now() > deadline) throw new Error(`timed out waiting for ${needle}`);
      const { value, done } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
    }
  };
  await readUntil('ANN-seed-2'); // backlog for the student's class
  await sync(edu, 'announcement', { id: 'ANN-live-0001', message: 'Live!', audience: 'AWA-2024-GHS' });
  await readUntil('ANN-live-0001');
  controller.abort();
});

test('quiet hours follow the school day in India (Q2)', () => {
  // 10:00 IST on a Monday = 04:30 UTC.
  assert.equal(isQuietHours(new Date('2026-10-12T04:30:00Z')), true);
  // 16:00 IST Monday.
  assert.equal(isQuietHours(new Date('2026-10-12T10:30:00Z')), false);
  // 10:00 IST Sunday.
  assert.equal(isQuietHours(new Date('2026-10-11T04:30:00Z')), false);
});

// ------------------------------------------------- app compatibility ---

withServer('every update the Flutter app sends is accepted as it builds it', async ({ login, student, sync }) => {
  // Shapes copied from lib/data/app_store.dart (AppStore + SyncService).
  const today = new Date(Date.now() + 5.5 * 3_600_000).toISOString().slice(0, 10);
  const st = await student('Priya', 'AWA-2024-GHS', '2580');
  const studentFlow = [
    ['points', { userId: 'STU002', delta: 20, reason: 'Finished "The water crisis"', ref: 'module:MOD_A' }],
    ['quiz_score', { studentId: 'STU002', moduleId: 'MOD_A', correct: 7, total: 10, at: new Date().toISOString() }],
    ['points', { userId: 'STU002', delta: 70, reason: 'Quiz: The water crisis (7/10)', ref: 'quiz:MOD_A:7' }],
    ['points', { userId: 'STU002', delta: 20, reason: 'Sorting challenge completed', ref: 'sort_game' }],
    ['points', { userId: 'STU002', delta: 5, reason: 'School stayed under its water target', ref: `water:${today}` }],
    ['pickup', { id: 'PCK-AbCdEfGhIjK', collectorId: 'COL001' }],
    ['points', { userId: 'STU002', delta: 15, reason: 'Handed plastic waste to Ramesh Kumar', ref: 'pickup:PCK-AbCdEfGhIjK' }],
    ['announcement_done', { announcementId: 'ANN-seed-1' }],
    ['points', { userId: 'STU002', delta: 10, reason: 'NGO task from Community Seva Centre', ref: 'ann:ANN-seed-1' }],
    ['points', { userId: 'STU002', delta: 10, reason: 'Checked in: Beach clean-up', ref: 'checkin:NGO001:A1' }],
  ];
  for (const [kind, payload] of studentFlow) {
    const r = await sync(st, kind, payload);
    assert.equal(r.status, 201, `${kind} ${JSON.stringify(payload)} -> ${r.text}`);
  }

  const edu = await login('educator');
  const ann = await sync(edu, 'announcement', {
    id: 'ANN-q1W2e3R4t5Y',
    message: 'Finish module B before Friday.',
    audience: 'AWA-2024-GHS',
    urgent: false,
    sentAt: new Date().toISOString(),
  });
  assert.equal(ann.status, 201, ann.text);

  const ngo = await login('ngo');
  for (const [kind, payload] of [
    ['announcement', { id: 'ANN-z9X8c7V6b5N', message: 'Beach clean-up on Saturday', audience: 'ALL', urgent: true, sentAt: new Date().toISOString() }],
    ['activity', { id: 'ACT-AbCdEfGhIjK', ngoId: 'NGO001', date: today }],
    ['redemption', { claimId: 'CLM-AbCdEfGhIjK', nonce: 'AbCdEfGhIjKlMnOp', desk: 'DESK-NGO001' }],
  ]) {
    const r = await sync(ngo, kind, payload);
    assert.equal(r.status, 201, `${kind} -> ${r.text}`);
  }

  const mgr = await login('manager');
  const moved = await sync(mgr, 'student_transfer', { studentId: 'STU003', from: 'AWA-2024-GHS', to: 'AWA-2024-SJH' });
  assert.equal(moved.status, 201, moved.text);
});

test('an older database gains new demo entries without losing anything', async () => {
  const { openDatabase } = await import('../src/db.js');
  const { mkdtempSync, rmSync } = await import('node:fs');
  const { join } = await import('node:path');
  const { tmpdir } = await import('node:os');
  const dir = mkdtempSync(join(tmpdir(), 'aqua-'));
  const file = join(dir, 'old.db');
  try {
    // A database created before the demo college existed, with a change made since.
    let db = openDatabase(file);
    db.exec("DELETE FROM students WHERE class_code = 'AWA-2024-CCAS'");
    db.exec("DELETE FROM accounts WHERE id = 'EDU003'");
    db.exec("DELETE FROM classes WHERE code = 'AWA-2024-CCAS'");
    db.exec("UPDATE students SET class_code = 'AWA-2024-SJH' WHERE id = 'STU001'");
    db.close();

    db = openDatabase(file);
    const n = (sql) => db.prepare(sql).get().n;
    assert.equal(n("SELECT COUNT(*) AS n FROM classes WHERE code = 'AWA-2024-CCAS'"), 1, 'the college class is added');
    assert.equal(n("SELECT COUNT(*) AS n FROM accounts WHERE id = 'EDU003'"), 1, 'the college teacher is added');
    assert.equal(n('SELECT COUNT(*) AS n FROM students'), seedStudents.length);
    assert.equal(
      db.prepare("SELECT class_code FROM students WHERE id = 'STU001'").get().class_code,
      'AWA-2024-SJH',
      'existing rows are not reset',
    );
    db.close();
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

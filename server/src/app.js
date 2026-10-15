// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import { randomBytes } from 'node:crypto';

import { transaction } from './db.js';
import {
  HttpError,
  RateLimiter,
  applyCors,
  applySecurityHeaders,
  clientIp,
  parseJson,
  readBody,
  sendError,
  sendJson,
} from './http.js';
import { RealtimeHub, canSeeAnnouncement } from './realtime.js';
import { collectorIds } from './seed.js';
import {
  DUMMY_HASH,
  cleanText,
  hashSecret,
  hmacHex,
  isTrivialPin,
  randomId,
  safeEqual,
  sha256Hex,
  signJwt,
  verifyJwt,
  verifySecret,
} from './security.js';

const STAFF_ROLES = new Set(['educator', 'ngo', 'manager']);
const NAME_RE = /^[\p{L}][\p{L}\p{M} .'-]{1,59}$/u;
const CLASS_RE = /^[A-Z]{3}-\d{4}-[A-Z]{2,5}$/;
const IDEM_RE = /^[A-Za-z0-9_-]{8,64}$/;
const DAY_MS = 24 * 60 * 60 * 1000;

/** Q2 — non-urgent notices sent during class (8 am–3 pm, Mon–Fri, IST) are
 * marked as held so apps can show them after school. */
export function isQuietHours(date = new Date()) {
  const ist = new Date(date.getTime() + 5.5 * 60 * 60 * 1000);
  const day = ist.getUTCDay(); // 0 = Sunday
  const hour = ist.getUTCHours();
  return day >= 1 && day <= 5 && hour >= 8 && hour < 15;
}

const fail = (status, message, code) => {
  throw new HttpError(status, message, { code });
};

function int(v, min, max, what) {
  if (!Number.isInteger(v) || v < min || v > max) fail(422, `${what} must be a whole number from ${min} to ${max}.`, 'invalid');
  return v;
}

function str(v, re, what) {
  if (typeof v !== 'string' || !re.test(v)) fail(422, `${what} is not valid.`, 'invalid');
  return v;
}

function isoDate(v, what) {
  const t = typeof v === 'string' ? Date.parse(v) : Number.NaN;
  if (!Number.isFinite(t)) fail(422, `${what} must be an ISO-8601 date.`, 'invalid');
  return new Date(t).toISOString();
}

export function createApp(config, { db, log = (m) => console.error(m) }) {
  const hub = new RealtimeHub();
  const authLimiter = new RateLimiter({ capacity: 10, refillPerMinute: 10 });
  const apiLimiter = new RateLimiter({ capacity: 240, refillPerMinute: 240 });

  const q = {
    account: db.prepare('SELECT * FROM accounts WHERE id = ?'),
    accountByLogin: db.prepare('SELECT * FROM accounts WHERE role = ? AND login_id = ?'),
    student: db.prepare('SELECT * FROM students WHERE id = ?'),
    studentByName: db.prepare('SELECT * FROM students WHERE class_code = ? AND name_key = ?'),
    studentInsert: db.prepare('INSERT INTO students (id, name, name_key, class_code, pin_hash, joined_at) VALUES (?, ?, ?, ?, ?, ?)'),
    studentPin: db.prepare('UPDATE students SET pin_hash = ? WHERE id = ?'),
    studentMove: db.prepare('UPDATE students SET class_code = ? WHERE id = ?'),
    classByCode: db.prepare('SELECT * FROM classes WHERE code = ?'),
    sessionInsert: db.prepare(
      'INSERT INTO sessions (id, user_id, role, signing_key, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?)',
    ),
    session: db.prepare('SELECT * FROM sessions WHERE id = ?'),
    sessionRevoke: db.prepare('UPDATE sessions SET revoked = 1 WHERE id = ?'),
    guard: db.prepare('SELECT * FROM login_guards WHERE key = ?'),
    guardSet: db.prepare(
      'INSERT INTO login_guards (key, failures, locked_until) VALUES (?, ?, ?) ON CONFLICT(key) DO UPDATE SET failures = excluded.failures, locked_until = excluded.locked_until',
    ),
    guardClear: db.prepare('DELETE FROM login_guards WHERE key = ?'),
    eventById: db.prepare('SELECT * FROM events WHERE id = ?'),
    eventInsert: db.prepare(
      'INSERT INTO events (id, user_id, role, kind, audience, target, payload, body_hash, received_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    ),
    announcementById: db.prepare("SELECT * FROM events WHERE kind = 'announcement' AND target = ?"),
    doneBy: db.prepare("SELECT 1 FROM events WHERE kind = 'announcement_done' AND user_id = ? AND target = ?"),
    announcementsSince: db.prepare("SELECT * FROM events WHERE kind = 'announcement' AND seq > ? ORDER BY seq DESC LIMIT 100"),
    doneForSender: db.prepare(
      "SELECT d.* FROM events d JOIN events a ON a.kind = 'announcement' AND a.target = d.target WHERE d.kind = 'announcement_done' AND a.user_id = ? AND d.seq > ? ORDER BY d.seq DESC LIMIT 200",
    ),
    pointsInsert: db.prepare('INSERT OR IGNORE INTO points (user_id, ref, delta, reason, at) VALUES (?, ?, ?, ?, ?)'),
    pointsWithPrefix: db.prepare('SELECT COALESCE(SUM(delta), 0) AS total, COUNT(*) AS n FROM points WHERE user_id = ? AND instr(ref, ?) = 1'),
    pointsWithPrefixSince: db.prepare('SELECT COUNT(*) AS n FROM points WHERE user_id = ? AND instr(ref, ?) = 1 AND at >= ?'),
    pickupBy: db.prepare("SELECT 1 FROM events WHERE kind = 'pickup' AND user_id = ? AND target = ?"),
    nonceInsert: db.prepare('INSERT INTO redeemed_nonces (nonce, claim_id, desk_id, at) VALUES (?, ?, ?, ?)'),
    nonce: db.prepare('SELECT * FROM redeemed_nonces WHERE nonce = ?'),
    audit: db.prepare('INSERT INTO audit (at, actor, action, ip) VALUES (?, ?, ?, ?)'),
    auditList: db.prepare('SELECT at, actor, action FROM audit ORDER BY seq DESC LIMIT ?'),
    kindCounts: db.prepare('SELECT kind, COUNT(*) AS n FROM events GROUP BY kind'),
    studentCounts: db.prepare('SELECT COUNT(*) AS total, SUM(pin_hash IS NOT NULL) AS joined FROM students'),
    pointsTotal: db.prepare('SELECT COALESCE(SUM(delta), 0) AS issued FROM points'),
  };

  const audit = (actor, action, ip) => q.audit.run(Date.now(), actor, action, ip ?? null);

  // ------------------------------------------------------------ identity --

  function loadUser(id, role) {
    if (role === 'student') {
      const s = q.student.get(id);
      return s && { id: s.id, role: 'student', name: s.name, classCode: s.class_code, ngoId: null };
    }
    const a = q.account.get(id);
    if (!a || a.role !== role) return null;
    return { id: a.id, role: a.role, name: a.name, classCode: a.class_code, ngoId: a.ngo_id };
  }

  const publicUser = (u) => ({ id: u.id, role: u.role, name: u.name, classCode: u.classCode, ngoId: u.ngoId });

  function issueSession(user, ip) {
    const sid = randomId('SES', 12);
    const signingKey = randomBytes(32);
    const now = Date.now();
    const exp = now + config.sessionMs;
    q.sessionInsert.run(sid, user.id, user.role, signingKey.toString('base64'), now, exp);
    const token = signJwt(
      {
        sub: user.id,
        role: user.role,
        sid,
        iat: Math.floor(now / 1000),
        exp: Math.floor(exp / 1000),
        iss: config.issuer,
        aud: config.audience,
      },
      config.jwtSecret,
    );
    audit(user.name, 'signed in', ip);
    return { token, signingKey: signingKey.toString('base64'), expiresAt: new Date(exp).toISOString(), user: publicUser(user) };
  }

  function authenticate(req) {
    const m = /^Bearer ([A-Za-z0-9._-]{20,2048})$/.exec(String(req.headers.authorization ?? ''));
    if (!m) fail(401, 'Sign in first.', 'unauthenticated');
    const claims = verifyJwt(m[1], config.jwtSecret, { issuer: config.issuer, audience: config.audience });
    if (!claims) fail(401, 'Your session is not valid. Sign in again.', 'unauthenticated');
    const session = q.session.get(claims.sid);
    if (!session || session.revoked || session.expires_at <= Date.now() || session.user_id !== claims.sub) {
      fail(401, 'Your session ended. Sign in again.', 'unauthenticated');
    }
    const user = loadUser(session.user_id, session.role);
    if (!user) fail(401, 'This account no longer exists.', 'unauthenticated');
    return { user, session };
  }

  // ------------------------------------------------------------- lockout --

  function lockSeconds(key) {
    const g = q.guard.get(key);
    if (!g?.locked_until) return 0;
    const left = g.locked_until - Date.now();
    return left > 0 ? Math.ceil(left / 1000) : 0;
  }

  /** Same policy as the app: 5 failures lock for 30 s, doubling, max 15 min. */
  function recordFailure(key, actor, ip) {
    const g = q.guard.get(key);
    const failures = (g?.failures ?? 0) + 1;
    let lockedUntil = null;
    if (failures >= 5) {
      const seconds = Math.min(900, 30 * 2 ** (failures - 5));
      lockedUntil = Date.now() + seconds * 1000;
      audit(actor, `was locked out after ${failures} failed sign-ins`, ip);
    }
    q.guardSet.run(key, failures, lockedUntil);
    return lockedUntil ? Math.ceil((lockedUntil - Date.now()) / 1000) : 0;
  }

  // ---------------------------------------------------------------- auth --

  async function staffLogin(req, ip) {
    const body = parseJson(await readBody(req, config.maxBodyBytes), req);
    const role = body.role;
    const loginId = typeof body.loginId === 'string' ? body.loginId.trim().toLowerCase() : '';
    const secret = typeof body.secret === 'string' ? body.secret : '';
    if (!STAFF_ROLES.has(role) || !loginId || loginId.length > 120 || !secret || secret.length > 256) {
      fail(400, 'Send role, loginId and secret.', 'invalid');
    }
    const key = `${role}:${loginId}`;
    const locked = lockSeconds(key);
    if (locked) throw new HttpError(429, 'Too many attempts. Try again later.', { code: 'locked', retryAfter: locked });

    const account = q.accountByLogin.get(role, loginId);
    const ok = await verifySecret(secret, account?.secret_hash ?? DUMMY_HASH);
    if (!account || !ok) {
      const lock = recordFailure(key, loginId, ip);
      if (lock) throw new HttpError(429, 'Too many attempts. Try again later.', { code: 'locked', retryAfter: lock });
      // Never say which part was wrong.
      fail(401, 'Those sign-in details do not match.', 'bad_credentials');
    }
    q.guardClear.run(key);
    return issueSession(loadUser(account.id, account.role), ip);
  }

  async function studentLogin(req, ip) {
    const body = parseJson(await readBody(req, config.maxBodyBytes), req);
    const name = cleanText(body.name, 60);
    const code = typeof body.classCode === 'string' ? body.classCode.trim().toUpperCase() : '';
    const pin = typeof body.pin === 'string' ? body.pin.trim() : '';
    if (!NAME_RE.test(name) || !CLASS_RE.test(code) || !/^\d{4}$/.test(pin)) {
      fail(400, 'Send your name, class code and 4-digit PIN.', 'invalid');
    }
    if (!q.classByCode.get(code)) fail(401, 'We could not find that class code.', 'bad_class');
    const nameKey = name.toLowerCase();
    const key = `student:${code}:${nameKey}`;
    const locked = lockSeconds(key);
    if (locked) throw new HttpError(429, 'Too many attempts. Try again later.', { code: 'locked', retryAfter: locked });

    let student = q.studentByName.get(code, nameKey);
    if (student?.pin_hash) {
      if (!(await verifySecret(pin, student.pin_hash))) {
        const lock = recordFailure(key, name, ip);
        if (lock) throw new HttpError(429, 'Too many attempts. Try again later.', { code: 'locked', retryAfter: lock });
        fail(401, 'That PIN is not right.', 'bad_credentials');
      }
    } else {
      if (isTrivialPin(pin)) fail(400, 'Choose a PIN that is harder to guess.', 'weak_pin');
      const hash = await hashSecret(pin);
      if (student) {
        q.studentPin.run(hash, student.id);
      } else {
        const id = randomId('STU');
        q.studentInsert.run(id, name, nameKey, code, hash, Date.now());
        audit(name, `joined ${code}`, ip);
        student = q.student.get(id);
      }
    }
    q.guardClear.run(key);
    return issueSession(loadUser(student.id, 'student'), ip);
  }

  // -------------------------------------------------------------- points --

  /**
   * Q3 + Q7 — the server decides what an achievement is worth.
   *
   * The first version (and a naive sync) would store whatever amount the
   * client sent, so a modified app could award itself unlimited points. The
   * client only says *which* achievement it earned (the ref); the amount must
   * match the same rules the app uses (lib/data/points_rules.dart), and caps
   * are enforced here, where a student cannot change them.
   * Returns null when allowed, otherwise the reason it was refused.
   */
  function checkPoints(u, ref, delta, now = Date.now()) {
    let m;
    if (/^module:MOD_[A-F]$/.test(ref)) return delta === 20 ? null : 'A finished module is worth 20 points.';
    if ((m = /^quiz:(MOD_[A-F]):(\d{1,2})$/.exec(ref))) {
      // Points only for improving your best: in total, at most 10 per correct answer.
      const correct = Number(m[2]);
      if (correct < 1 || delta % 10 !== 0) return 'Quiz points come in steps of 10.';
      const earned = q.pointsWithPrefix.get(u.id, `quiz:${m[1]}:`).total;
      return earned + delta <= correct * 10 ? null : 'Those quiz points are more than the score allows.';
    }
    if (ref === 'sort_game') return delta === 20 ? null : 'The sorting challenge is worth 20 points.';
    if ((m = /^water:(\d{4}-\d{2}-\d{2})$/.exec(ref))) {
      if (delta !== 5) return 'The water bonus is worth 5 points.';
      const day = Date.parse(`${m[1]}T00:00:00+05:30`);
      return Number.isFinite(day) && Math.abs(now - day) <= 2 * DAY_MS ? null : 'The water bonus can only be claimed for today.';
    }
    if ((m = /^ann:(ANN-[A-Za-z0-9_-]{4,40})$/.exec(ref))) {
      const ann = q.announcementById.get(m[1]);
      if (!ann || !canSeeAnnouncement(u, ann.audience)) return 'That task is not on the server for your class.';
      return delta === (ann.role === 'ngo' ? 10 : 5) ? null : 'Tasks are worth 5 points (educator) or 10 (NGO).';
    }
    if ((m = /^pickup:(PCK-[A-Za-z0-9_-]{4,40})$/.exec(ref))) {
      if (delta !== 15) return 'A handover is worth 15 points.';
      if (!q.pickupBy.get(u.id, m[1])) return 'That pickup was never requested.';
      const istMidnight = Date.parse(`${new Date(now + 5.5 * 3_600_000).toISOString().slice(0, 10)}T00:00:00+05:30`);
      const today = q.pointsWithPrefixSince.get(u.id, 'pickup:', istMidnight).n;
      return today < 2 ? null : 'Only two handovers a day earn points.';
    }
    if (/^checkin:[A-Za-z0-9_-]{1,40}:[A-Za-z0-9_-]{1,40}$/.test(ref)) {
      return delta === 10 ? null : 'An event check-in is worth 10 points.';
    }
    return 'Points can only be given for a known achievement.';
  }

  // ---------------------------------------------------------------- sync --

  /** Each kind: who may send it, how its payload is validated, what it
   * changes, and who hears about it. Identity always comes from the
   * session, never from the payload. */
  const KINDS = {
    quiz_score: {
      roles: ['student'],
      accept: (u, p) => {
        const total = int(p.total, 1, 50, 'total');
        const correct = int(p.correct, 0, total, 'correct');
        return { payload: { moduleId: str(p.moduleId, /^MOD_[A-F]$/, 'moduleId'), correct, total } };
      },
    },
    points: {
      roles: ['student'],
      accept: (u, p) => {
        const delta = int(p.delta, 1, 100, 'delta');
        const reason = cleanText(p.reason, 120) || fail(422, 'reason is required.', 'invalid');
        const ref = str(p.ref, /^[A-Za-z0-9:._-]{1,80}$/, 'ref');
        const problem = checkPoints(u, ref, delta);
        if (problem) fail(422, problem, 'points_rule');
        return {
          payload: { delta, reason, ref },
          // Idempotent by (student, ref): the same achievement can't pay twice.
          effect: () => q.pointsInsert.run(u.id, ref, delta, reason, Date.now()),
        };
      },
    },
    announcement: {
      roles: ['educator', 'ngo'],
      accept: (u, p) => {
        const id = str(p.id, /^ANN-[A-Za-z0-9_-]{4,40}$/, 'id');
        const message = cleanText(p.message, 500) || fail(422, 'message is required.', 'invalid');
        const audience = typeof p.audience === 'string' ? p.audience : '';
        if (u.role === 'educator' && audience !== u.classCode) {
          fail(403, 'Educators can only post to their own class.', 'forbidden');
        }
        if (u.role === 'ngo' && audience !== 'ALL' && !q.classByCode.get(audience)) {
          fail(422, 'audience must be ALL or a class code.', 'invalid');
        }
        if (q.announcementById.get(id)) fail(409, 'An announcement with this id already exists.', 'conflict');
        const urgent = p.urgent === true;
        const sentAt = isoDate(p.sentAt ?? new Date().toISOString(), 'sentAt');
        const payload = {
          id,
          message,
          audience,
          urgent,
          sentAt,
          senderId: u.id,
          senderName: u.name,
          senderRole: u.role,
          held: !urgent && isQuietHours(),
        };
        return {
          payload,
          audience,
          target: id,
          publish: { type: 'announcement', data: payload, canSee: (viewer) => canSeeAnnouncement(viewer, audience) },
        };
      },
    },
    announcement_done: {
      roles: ['student'],
      accept: (u, p) => {
        const id = str(p.announcementId, /^ANN-[A-Za-z0-9_-]{4,40}$/, 'announcementId');
        const ann = q.announcementById.get(id);
        if (!ann) fail(404, 'That announcement is not on the server.', 'not_found');
        if (!canSeeAnnouncement(u, ann.audience)) fail(403, 'That announcement is not for your class.', 'forbidden');
        if (q.doneBy.get(u.id, id)) return { duplicate: true };
        const data = { announcementId: id, studentId: u.id, studentName: u.name };
        return {
          payload: data,
          target: id,
          publish: {
            type: 'announcement_done',
            data,
            canSee: (viewer) => viewer.id === ann.user_id || viewer.role === 'manager',
          },
        };
      },
    },
    pickup: {
      roles: ['student'],
      accept: (u, p) => {
        const collectorId = typeof p.collectorId === 'string' && collectorIds.includes(p.collectorId)
          ? p.collectorId
          : fail(422, 'collectorId is not a known collector.', 'invalid');
        const id = str(p.id, /^PCK-[A-Za-z0-9_-]{4,40}$/, 'id');
        return { payload: { id, collectorId }, target: id };
      },
    },
    redemption: {
      roles: ['ngo'],
      accept: (u, p, ip) => {
        const claimId = str(p.claimId, /^CLM-[A-Za-z0-9_-]{4,40}$/, 'claimId');
        const nonce = str(p.nonce, /^[A-Za-z0-9_-]{8,40}$/, 'nonce');
        if (q.nonce.get(nonce)) fail(409, 'This reward ticket was already redeemed.', 'replay');
        return {
          payload: { claimId, nonce },
          effect: () => {
            q.nonceInsert.run(nonce, claimId, u.id, Date.now());
            audit(u.name, `redeemed ${claimId}`, ip);
          },
        };
      },
    },
    student_transfer: {
      roles: ['manager'],
      accept: (u, p, ip) => {
        const studentId = str(p.studentId, /^STU[A-Za-z0-9_-]{1,40}$/, 'studentId');
        const to = str(p.to, CLASS_RE, 'to');
        if (!q.classByCode.get(to)) fail(422, 'That class does not exist.', 'invalid');
        return {
          payload: { studentId, from: typeof p.from === 'string' ? p.from.slice(0, 20) : null, to },
          effect: () => {
            q.studentMove.run(to, studentId);
            audit(u.name, `moved ${studentId} to ${to}`, ip);
          },
        };
      },
    },
    activity: {
      roles: ['ngo'],
      accept: (u, p) => ({
        payload: {
          id: str(p.id, /^ACT-[A-Za-z0-9_-]{4,40}$/, 'id'),
          ngoId: u.ngoId, // from the session, never from the payload
          date: str(p.date, /^\d{4}-\d{2}-\d{2}$/, 'date'),
        },
      }),
    },
  };

  async function sync(req, res, kind, ip) {
    const { user, session } = authenticate(req);
    const raw = await readBody(req, config.maxBodyBytes);

    const idem = String(req.headers['idempotency-key'] ?? '');
    if (!IDEM_RE.test(idem)) fail(400, 'Send an Idempotency-Key header (8–64 URL-safe characters).', 'invalid');

    // Q7 integrity: the body must be signed with this session's key.
    const signature = String(req.headers['x-aqua-signature'] ?? '').toLowerCase();
    const expected = hmacHex(Buffer.from(session.signing_key, 'base64'), raw);
    if (!safeEqual(signature, expected)) fail(401, 'The request signature is not valid.', 'bad_signature');

    const body = parseJson(raw, req);
    if (body.id !== idem || body.kind !== kind) fail(400, 'Body id and kind must match the request.', 'invalid');
    const created = Date.parse(body.createdAt);
    const now = Date.now();
    if (!Number.isFinite(created) || created < now - 30 * DAY_MS || created > now + 5 * 60_000) {
      fail(422, 'createdAt is outside the accepted window.', 'stale');
    }

    const spec = KINDS[kind];
    if (!spec) fail(404, 'Unknown kind of update.', 'not_found');
    if (!spec.roles.includes(user.role)) fail(403, 'Your role cannot send this kind of update.', 'forbidden');

    // Q5 ARQ: a retry after a lost acknowledgement is answered, not re-applied.
    const bodyHash = sha256Hex(raw);
    const existing = q.eventById.get(idem);
    if (existing) {
      if (existing.user_id === user.id && existing.body_hash === bodyHash) {
        return sendJson(res, 200, { ok: true, duplicate: true, seq: existing.seq });
      }
      fail(409, 'This Idempotency-Key was already used for a different request.', 'conflict');
    }

    const p = body.payload !== null && typeof body.payload === 'object' && !Array.isArray(body.payload) ? body.payload : {};
    const accepted = spec.accept(user, p, ip);
    if (accepted.duplicate) return sendJson(res, 200, { ok: true, duplicate: true });

    const seq = transaction(db, () => {
      const r = q.eventInsert.run(
        idem,
        user.id,
        user.role,
        kind,
        accepted.audience ?? null,
        accepted.target ?? null,
        JSON.stringify(accepted.payload),
        bodyHash,
        now,
      );
      accepted.effect?.();
      return Number(r.lastInsertRowid);
    });

    if (accepted.publish) {
      hub.publish({ seq, type: accepted.publish.type, data: accepted.publish.data }, accepted.publish.canSee);
    }
    return sendJson(res, 201, { ok: true, seq });
  }

  // ---------------------------------------------------------------- feed --

  function backlogFor(user, since) {
    const events = [];
    for (const row of q.announcementsSince.all(since)) {
      if (canSeeAnnouncement(user, row.audience)) {
        events.push({ seq: row.seq, type: 'announcement', data: JSON.parse(row.payload) });
      }
    }
    if (user.role === 'educator' || user.role === 'ngo') {
      for (const row of q.doneForSender.all(user.id, since)) {
        events.push({ seq: row.seq, type: 'announcement_done', data: JSON.parse(row.payload) });
      }
    }
    return events.sort((a, b) => a.seq - b.seq);
  }

  function feed(req, res, url) {
    const { user, session } = authenticate(req);
    const since = Number.parseInt(String(req.headers['last-event-id'] ?? url.searchParams.get('since') ?? '0'), 10);
    hub.attach(req, res, user, session.expires_at, backlogFor(user, Number.isFinite(since) && since > 0 ? since : 0));
  }

  // -------------------------------------------------------------- router --

  async function route(req, res) {
    applySecurityHeaders(res, { https: Boolean(config.tlsCert) || config.production });
    if (!applyCors(req, res, config.corsOrigins)) fail(403, 'This web origin is not allowed.', 'cors');
    if (req.method === 'OPTIONS') {
      res.writeHead(204);
      res.end();
      return;
    }

    const url = new URL(req.url ?? '/', 'http://localhost');
    const path = url.pathname;
    const ip = clientIp(req, config.trustProxy);
    const limiter = path.startsWith('/api/auth/') ? authLimiter : apiLimiter;
    const wait = limiter.take(ip);
    if (wait) throw new HttpError(429, 'Too many requests. Slow down.', { code: 'rate_limited', retryAfter: wait });

    const is = (method, p) => req.method === method && path === p;

    if (is('GET', '/api/health')) return sendJson(res, 200, { ok: true, time: new Date().toISOString() });
    if (is('POST', '/api/auth/staff')) return sendJson(res, 200, await staffLogin(req, ip));
    if (is('POST', '/api/auth/student')) return sendJson(res, 200, await studentLogin(req, ip));
    if (is('POST', '/api/auth/logout')) {
      const { user, session } = authenticate(req);
      q.sessionRevoke.run(session.id);
      hub.disconnectUser(user.id);
      audit(user.name, 'signed out', ip);
      return sendJson(res, 200, { ok: true });
    }
    const syncMatch = /^\/api\/sync\/([a-z_]{3,32})$/.exec(path);
    if (req.method === 'POST' && syncMatch) return sync(req, res, syncMatch[1], ip);
    if (is('GET', '/api/feed')) return feed(req, res, url);
    if (is('GET', '/api/announcements')) {
      const { user } = authenticate(req);
      const since = Number.parseInt(url.searchParams.get('since') ?? '0', 10) || 0;
      return sendJson(res, 200, { events: backlogFor(user, since) });
    }
    if (is('GET', '/api/admin/summary')) {
      const { user } = authenticate(req);
      if (user.role !== 'manager') fail(403, 'Managers only.', 'forbidden');
      const kinds = Object.fromEntries(q.kindCounts.all().map((r) => [r.kind, r.n]));
      const st = q.studentCounts.get();
      return sendJson(res, 200, {
        students: { total: st.total, joined: st.joined ?? 0 },
        events: kinds,
        pointsIssued: q.pointsTotal.get().issued,
        liveConnections: hub.size,
      });
    }
    if (is('GET', '/api/admin/audit')) {
      const { user } = authenticate(req);
      if (user.role !== 'manager') fail(403, 'Managers only.', 'forbidden');
      const limit = Math.min(200, Math.max(1, Number.parseInt(url.searchParams.get('limit') ?? '50', 10) || 50));
      return sendJson(res, 200, { entries: q.auditList.all(limit) });
    }
    fail(404, 'Not found.', 'not_found');
  }

  async function handle(req, res) {
    const started = Date.now();
    try {
      await route(req, res);
    } catch (err) {
      sendError(res, err, log);
    } finally {
      if (!config.quiet && !res.getHeader('Content-Type')?.toString().startsWith('text/event-stream')) {
        // Method, path and status only: never tokens, bodies or PINs.
        log(`${req.method} ${new URL(req.url ?? '/', 'http://x').pathname} ${res.statusCode} ${Date.now() - started}ms`);
      }
    }
  }

  return { handle, hub, close: () => hub.close() };
}

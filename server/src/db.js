// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

import * as seed from './seed.js';

const SCHEMA = `
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS classes (
  code        TEXT PRIMARY KEY,
  school      TEXT NOT NULL,
  educator_id TEXT NOT NULL,
  city        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS accounts (
  id          TEXT PRIMARY KEY,
  role        TEXT NOT NULL CHECK (role IN ('educator', 'ngo', 'manager')),
  name        TEXT NOT NULL,
  login_id    TEXT NOT NULL,
  secret_hash TEXT NOT NULL,
  class_code  TEXT,
  ngo_id      TEXT,
  UNIQUE (role, login_id)
);

CREATE TABLE IF NOT EXISTS students (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  name_key   TEXT NOT NULL,
  class_code TEXT NOT NULL REFERENCES classes(code),
  pin_hash   TEXT,
  joined_at  INTEGER NOT NULL,
  UNIQUE (class_code, name_key)
);

CREATE TABLE IF NOT EXISTS sessions (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL,
  role        TEXT NOT NULL,
  signing_key TEXT NOT NULL,
  created_at  INTEGER NOT NULL,
  expires_at  INTEGER NOT NULL,
  revoked     INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS login_guards (
  key          TEXT PRIMARY KEY,
  failures     INTEGER NOT NULL,
  locked_until INTEGER
);

-- Every accepted sync item. The primary key is the client's Idempotency-Key,
-- so a retried request after a lost acknowledgement is stored once (Q5).
CREATE TABLE IF NOT EXISTS events (
  seq         INTEGER PRIMARY KEY AUTOINCREMENT,
  id          TEXT NOT NULL UNIQUE,
  user_id     TEXT NOT NULL,
  role        TEXT NOT NULL,
  kind        TEXT NOT NULL,
  audience    TEXT,
  target      TEXT,
  payload     TEXT NOT NULL,
  body_hash   TEXT NOT NULL,
  received_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS events_kind ON events (kind, seq);

-- One row per (student, reason) so the same achievement can't pay twice.
CREATE TABLE IF NOT EXISTS points (
  user_id TEXT NOT NULL,
  ref     TEXT NOT NULL,
  delta   INTEGER NOT NULL,
  reason  TEXT NOT NULL,
  at      INTEGER NOT NULL,
  PRIMARY KEY (user_id, ref)
);

-- Q9 — server-side anti-replay for reward tickets.
CREATE TABLE IF NOT EXISTS redeemed_nonces (
  nonce    TEXT PRIMARY KEY,
  claim_id TEXT NOT NULL,
  desk_id  TEXT NOT NULL,
  at       INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS audit (
  seq    INTEGER PRIMARY KEY AUTOINCREMENT,
  at     INTEGER NOT NULL,
  actor  TEXT NOT NULL,
  action TEXT NOT NULL,
  ip     TEXT
);
`;

export function openDatabase(path) {
  const db = new DatabaseSync(path);
  if (path !== ':memory:') db.exec('PRAGMA journal_mode = WAL;');
  db.exec(SCHEMA);
  const count = db.prepare('SELECT COUNT(*) AS n FROM accounts').get().n;
  if (count === 0) seedDatabase(db);
  else addMissingSeed(db);
  return db;
}

/**
 * Adds classes, accounts and students that were added to the seed after this
 * database was created (for example the demo college). Rows that already
 * exist are never changed.
 */
function addMissingSeed(db) {
  const now = Date.now();
  db.exec('BEGIN');
  try {
    const cls = db.prepare('INSERT OR IGNORE INTO classes (code, school, educator_id, city) VALUES (?, ?, ?, ?)');
    for (const c of seed.classes) cls.run(c.code, c.school, c.educatorId, c.city);
    const acc = db.prepare(
      'INSERT OR IGNORE INTO accounts (id, role, name, login_id, secret_hash, class_code, ngo_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
    );
    for (const a of seed.accounts) {
      acc.run(a.id, a.role, a.name, a.loginId.toLowerCase(), a.secretHash, a.classCode ?? null, a.ngoId ?? null);
    }
    const st = db.prepare(
      'INSERT OR IGNORE INTO students (id, name, name_key, class_code, pin_hash, joined_at) VALUES (?, ?, ?, ?, NULL, ?)',
    );
    for (const s of seed.students) st.run(s.id, s.name, s.name.toLowerCase(), s.classCode, now);
    db.exec('COMMIT');
  } catch (e) {
    db.exec('ROLLBACK');
    throw e;
  }
}

function seedDatabase(db) {
  const now = Date.now();
  db.exec('BEGIN');
  try {
    const cls = db.prepare('INSERT INTO classes (code, school, educator_id, city) VALUES (?, ?, ?, ?)');
    for (const c of seed.classes) cls.run(c.code, c.school, c.educatorId, c.city);
    const acc = db.prepare(
      'INSERT INTO accounts (id, role, name, login_id, secret_hash, class_code, ngo_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
    );
    for (const a of seed.accounts) {
      acc.run(a.id, a.role, a.name, a.loginId.toLowerCase(), a.secretHash, a.classCode ?? null, a.ngoId ?? null);
    }
    const st = db.prepare('INSERT INTO students (id, name, name_key, class_code, pin_hash, joined_at) VALUES (?, ?, ?, ?, NULL, ?)');
    for (const s of seed.students) st.run(s.id, s.name, s.name.toLowerCase(), s.classCode, now);
    const ev = db.prepare(
      'INSERT INTO events (id, user_id, role, kind, audience, target, payload, body_hash, received_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    );
    for (const a of seed.announcements) {
      const sentAt = new Date(now - a.hoursAgo * 3_600_000).toISOString();
      const payload = JSON.stringify({
        id: a.id,
        message: a.message,
        audience: a.audience,
        urgent: false,
        sentAt,
        senderId: a.senderId,
        senderName: a.senderName,
        senderRole: a.senderRole,
        held: false,
      });
      const hash = createHash('sha256').update(payload).digest('hex');
      ev.run(`seed-${a.id}`, a.senderId, a.senderRole, 'announcement', a.audience, a.id, payload, hash, now);
    }
    db.exec('COMMIT');
  } catch (e) {
    db.exec('ROLLBACK');
    throw e;
  }
}

/** Runs fn inside a transaction (node:sqlite is synchronous, so this is atomic). */
export function transaction(db, fn) {
  db.exec('BEGIN IMMEDIATE');
  try {
    const out = fn();
    db.exec('COMMIT');
    return out;
  } catch (e) {
    db.exec('ROLLBACK');
    throw e;
  }
}

// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import { createHmac, randomBytes } from 'node:crypto';

import { loadConfig } from '../src/config.js';
import { openDatabase } from '../src/db.js';
import { createAquaServer } from '../src/server.js';

export const STAFF = {
  educator: { role: 'educator', loginId: 'kavitha@aquaaware.org', secret: 'Kavitha#2026' },
  educator2: { role: 'educator', loginId: 'rajan@aquaaware.org', secret: 'Rajan#2026' },
  officeLead: { role: 'educator', loginId: 'deepa@aquaaware.org', secret: 'Deepa#2026' },
  ngo: { role: 'ngo', loginId: 'NGO001', secret: 'PSF-GREEN-2026' },
  manager: { role: 'manager', loginId: 'admin@aquaaware.org', secret: 'Manager#2026!' },
};

/** Starts a real HTTP server on a random port with an in-memory database. */
export async function startServer(env = {}) {
  const config = loadConfig({ AQUA_QUIET: '1', AQUA_CORS_ORIGINS: 'https://app.aquaaware.org', ...env });
  const db = openDatabase(':memory:');
  const { server, close } = createAquaServer(config, { db, log: () => {} });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}/api`;

  async function call(method, path, { body, token, headers = {}, raw } = {}) {
    const h = { ...headers };
    if (token) h.authorization = `Bearer ${token}`;
    let payload;
    if (raw !== undefined) {
      payload = raw;
    } else if (body !== undefined) {
      payload = JSON.stringify(body);
      h['content-type'] ??= 'application/json';
    }
    const res = await fetch(base + path, { method, headers: h, body: payload });
    const text = await res.text();
    let json = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      json = null;
    }
    return { status: res.status, headers: res.headers, json, text };
  }

  async function login(who) {
    const r = await call('POST', '/auth/staff', { body: STAFF[who] });
    if (r.status !== 200) throw new Error(`login ${who} failed: ${r.status} ${r.text}`);
    return r.json;
  }

  async function student(name = 'Priya', classCode = 'AWA-2024-GHS', pin = '2580') {
    const r = await call('POST', '/auth/student', { body: { name, classCode, pin } });
    if (r.status !== 200) throw new Error(`student login failed: ${r.status} ${r.text}`);
    return r.json;
  }

  /** Sends one outbox item exactly like the Flutter SyncService does. */
  async function sync(session, kind, payload, { id = randomBytes(12).toString('base64url'), createdAt, sign = true, tamper } = {}) {
    const text = JSON.stringify({ id, kind, createdAt: createdAt ?? new Date().toISOString(), payload });
    const signature = createHmac('sha256', Buffer.from(session.signingKey, 'base64')).update(text).digest('hex');
    const headers = { 'content-type': 'application/json', 'idempotency-key': id };
    if (sign) headers['x-aqua-signature'] = signature;
    const r = await call('POST', `/sync/${kind}`, { token: session.token, headers, raw: tamper ? tamper(text) : text });
    return { ...r, id, text };
  }

  return { base, call, login, student, sync, db, close, config };
}

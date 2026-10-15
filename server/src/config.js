// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import { randomBytes } from 'node:crypto';

/**
 * Reads configuration from the environment.
 *
 * The first version signed tokens with `process.env.JWT_SECRET || 'secret'`,
 * so a missing variable silently made every token forgeable. Here a missing
 * or short secret stops the server in production; in development a random
 * secret is generated (sessions simply reset on restart).
 */
export function loadConfig(env = process.env) {
  const production = env.NODE_ENV === 'production';
  let secret = env.AQUA_JWT_SECRET ?? '';
  if (secret.length < 32) {
    if (production) {
      throw new Error('AQUA_JWT_SECRET must be set to at least 32 random characters in production.');
    }
    secret = randomBytes(48).toString('base64url');
    if (env.AQUA_QUIET !== '1') {
      console.warn('[aquaaware] AQUA_JWT_SECRET is not set; using a random development secret.');
    }
  }

  const tlsCert = env.AQUA_TLS_CERT || null;
  const tlsKey = env.AQUA_TLS_KEY || null;
  if (production && !(tlsCert && tlsKey) && env.AQUA_BEHIND_TLS_PROXY !== '1') {
    throw new Error(
      'In production either set AQUA_TLS_CERT and AQUA_TLS_KEY, or run behind an HTTPS reverse proxy and set AQUA_BEHIND_TLS_PROXY=1.',
    );
  }

  return Object.freeze({
    production,
    host: env.HOST || '127.0.0.1',
    port: Number.parseInt(env.PORT || '8443', 10),
    dbPath: env.AQUA_DB || 'aquaaware.db',
    jwtSecret: Buffer.from(secret, 'utf8'),
    issuer: 'aquaaware',
    audience: 'aquaaware-app',
    sessionMs: 8 * 60 * 60 * 1000,
    // No wildcard: only listed web origins may call the API from a browser.
    corsOrigins: new Set(
      (env.AQUA_CORS_ORIGINS || '')
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean),
    ),
    trustProxy: env.AQUA_TRUST_PROXY === '1',
    tlsCert,
    tlsKey,
    maxBodyBytes: 32 * 1024,
    quiet: env.AQUA_QUIET === '1',
  });
}

// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import { randomUUID } from 'node:crypto';

export class HttpError extends Error {
  constructor(status, message, { code, retryAfter } = {}) {
    super(message);
    this.status = status;
    this.code = code;
    this.retryAfter = retryAfter;
  }
}

/** Headers for every response. The API serves JSON only, so the content
 * security policy forbids everything a browser could otherwise load. */
export function applySecurityHeaders(res, { https }) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'");
  res.setHeader('Cross-Origin-Resource-Policy', 'same-site');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  res.setHeader('Cache-Control', 'no-store');
  if (https) res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
}

/** CORS for listed origins only (native apps send no Origin header). */
export function applyCors(req, res, allowed) {
  const origin = req.headers.origin;
  if (!origin) return true;
  if (!allowed.has(origin)) return false;
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, Idempotency-Key, X-Aqua-Signature, Last-Event-ID');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Max-Age', '600');
  return true;
}

export function sendJson(res, status, body) {
  if (res.headersSent) return;
  const text = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(text),
  });
  res.end(text);
}

export function sendError(res, err, log) {
  const requestId = randomUUID();
  if (err instanceof HttpError) {
    if (err.retryAfter) res.setHeader('Retry-After', String(err.retryAfter));
    sendJson(res, err.status, { error: err.message, code: err.code, requestId });
    return;
  }
  // Never leak stack traces or internal messages (the first version sent
  // `err.message` from database errors straight to the client).
  log?.(`[${requestId}] ${err?.stack ?? err}`);
  sendJson(res, 500, { error: 'Something went wrong. Try again later.', requestId });
}

/** Reads the request body with a hard size limit; returns a Buffer. */
export function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const declared = Number(req.headers['content-length'] ?? 0);
    if (declared > limit) {
      reject(new HttpError(413, 'Request body is too large.'));
      req.resume();
      return;
    }
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > limit) {
        reject(new HttpError(413, 'Request body is too large.'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

export function parseJson(buf, req) {
  const type = String(req.headers['content-type'] ?? '');
  if (!/^application\/json\b/i.test(type)) {
    throw new HttpError(415, 'Send JSON with Content-Type: application/json.');
  }
  try {
    const value = JSON.parse(buf.toString('utf8'));
    if (value === null || typeof value !== 'object' || Array.isArray(value)) throw new Error('not an object');
    return value;
  } catch {
    throw new HttpError(400, 'The request body is not valid JSON.');
  }
}

/** Token bucket per key (usually the client IP). */
export class RateLimiter {
  constructor({ capacity, refillPerMinute }) {
    this.capacity = capacity;
    this.refillPerMs = refillPerMinute / 60_000;
    this.buckets = new Map();
  }

  take(key, now = Date.now()) {
    let b = this.buckets.get(key);
    if (!b) {
      b = { tokens: this.capacity, at: now };
      this.buckets.set(key, b);
    }
    b.tokens = Math.min(this.capacity, b.tokens + (now - b.at) * this.refillPerMs);
    b.at = now;
    if (b.tokens < 1) return Math.ceil((1 - b.tokens) / this.refillPerMs / 1000);
    b.tokens -= 1;
    if (this.buckets.size > 50_000) this.prune(now);
    return 0;
  }

  prune(now = Date.now()) {
    for (const [k, b] of this.buckets) {
      if (now - b.at > 10 * 60_000) this.buckets.delete(k);
    }
  }
}

export function clientIp(req, trustProxy) {
  if (trustProxy) {
    const fwd = String(req.headers['x-forwarded-for'] ?? '').split(',')[0].trim();
    if (fwd) return fwd;
  }
  return req.socket.remoteAddress ?? 'unknown';
}

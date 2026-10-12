import { createHash, createHmac, pbkdf2, randomBytes, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

const pbkdf2Async = promisify(pbkdf2);

export const b64url = (data) => Buffer.from(data).toString('base64url');

export const randomId = (prefix, bytes = 9) => `${prefix}-${randomBytes(bytes).toString('base64url')}`;

export const sha256Hex = (data) => createHash('sha256').update(data).digest('hex');

export const hmacHex = (key, data) => createHmac('sha256', key).update(data).digest('hex');

/** Constant-time comparison that never throws on length mismatch. */
export function safeEqual(a, b) {
  const x = Buffer.isBuffer(a) ? a : Buffer.from(String(a), 'utf8');
  const y = Buffer.isBuffer(b) ? b : Buffer.from(String(b), 'utf8');
  if (x.length !== y.length) {
    timingSafeEqual(x, x); // spend comparable time
    return false;
  }
  return timingSafeEqual(x, y);
}

// ------------------------------------------------------------- passwords ---

/**
 * Same encoding as the Flutter app (`pbkdf2-sha256$<iterations>$<salt>$<hash>`),
 * so seeded accounts verify identically on the device and on the server.
 */
export async function hashSecret(secret, iterations = 100_000) {
  const salt = randomBytes(16);
  const dk = await pbkdf2Async(String(secret), salt, iterations, 32, 'sha256');
  return `pbkdf2-sha256$${iterations}$${salt.toString('base64')}$${dk.toString('base64')}`;
}

export async function verifySecret(secret, encoded) {
  const parts = String(encoded ?? '').split('$');
  if (parts.length !== 4 || parts[0] !== 'pbkdf2-sha256') return false;
  const iterations = Number.parseInt(parts[1], 10);
  if (!Number.isInteger(iterations) || iterations < 10_000 || iterations > 2_000_000) return false;
  const salt = Buffer.from(parts[2], 'base64');
  const expected = Buffer.from(parts[3], 'base64');
  if (salt.length < 8 || expected.length !== 32) return false;
  const actual = await pbkdf2Async(String(secret), salt, iterations, 32, 'sha256');
  return safeEqual(actual, expected);
}

/** A hash nobody knows the secret for, checked when an account doesn't
 * exist so response time doesn't reveal which emails are registered. */
export const DUMMY_HASH =
  'pbkdf2-sha256$100000$AAAAAAAAAAAAAAAAAAAAAA==$47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=';

// ------------------------------------------------------------------- JWT ---

const JWT_HEADER = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));

/** Q8 — lightweight HS256 tokens, implemented with node:crypto only. */
export function signJwt(claims, key) {
  const body = b64url(JSON.stringify(claims));
  const sig = createHmac('sha256', key).update(`${JWT_HEADER}.${body}`).digest('base64url');
  return `${JWT_HEADER}.${body}.${sig}`;
}

/**
 * Returns the claims, or null. The header must be exactly
 * {"alg":"HS256","typ":"JWT"}: this blocks "alg: none" and algorithm-confusion
 * attacks that plague hand-rolled JWT code.
 */
export function verifyJwt(token, key, { issuer, audience, now = Date.now() }) {
  if (typeof token !== 'string' || token.length > 2048) return null;
  const parts = token.split('.');
  if (parts.length !== 3 || parts[0] !== JWT_HEADER) return null;
  const expected = createHmac('sha256', key).update(`${parts[0]}.${parts[1]}`).digest();
  if (!/^[A-Za-z0-9_-]+$/.test(parts[2]) || !safeEqual(Buffer.from(parts[2], 'base64url'), expected)) return null;
  let claims;
  try {
    claims = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch {
    return null;
  }
  if (!claims || typeof claims !== 'object') return null;
  const nowSec = Math.floor(now / 1000);
  if (!Number.isInteger(claims.exp) || claims.exp <= nowSec) return null;
  if (!Number.isInteger(claims.iat) || claims.iat > nowSec + 120) return null;
  if (claims.iss !== issuer || claims.aud !== audience) return null;
  if (typeof claims.sub !== 'string' || typeof claims.sid !== 'string') return null;
  return claims;
}

// ------------------------------------------------------- input hygiene ---

// Control characters and bidirectional overrides ("Trojan Source").
const CONTROL = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F\u200B-\u200F\u202A-\u202E\u2066-\u2069]/g;

export function cleanText(value, max) {
  if (typeof value !== 'string') return '';
  let s = value.replace(CONTROL, '').replace(/\r\n/g, '\n').trim().replace(/\n{3,}/g, '\n\n');
  if (s.length > max) s = s.slice(0, max).trimEnd();
  return s;
}

export function isTrivialPin(pin) {
  if (/^(\d)\1{3}$/.test(pin)) return true;
  return '0123456789012'.includes(pin) || '9876543210987'.includes(pin);
}

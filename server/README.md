# AquaAware server (optional)

The app works fully offline without this server. Run it when you want several devices to share one class: an educator posts on one phone, students see it on theirs, and points, quiz scores and reward redemptions are recorded in one place.

It is a small Node.js program with **no third-party packages**. It uses only what ships with Node (`node:http`, `node:crypto`, and the built-in SQLite database `node:sqlite`), so there is nothing to `npm install` and nothing extra to keep patched.

Version 1's server used Express, MongoDB and socket.io, but only one socket event (`updateLocation`) was ever relayed, so announcements and replies never actually reached other devices. This version replaces it.

## Run it

You need **Node.js 22.13 or newer** (`node --version`).

```bash
cd server
npm start        # listens on http://127.0.0.1:8443
npm test         # 29 tests: sign-in, lockout, signatures, replay, points rules, privacy
```

The database is a single file, `aquaaware.db`, created on first start with the same pilot accounts as the app (see the main README for the demo logins). Delete the file to start over.

Point the app at it:

```bash
flutter run --dart-define=AQUA_API_URL=http://127.0.0.1:8443   # desktop, web or iOS simulator
flutter run --dart-define=AQUA_API_URL=http://10.0.2.2:8443    # Android emulator
```

On a real phone, run the server on your computer with `HOST=0.0.0.0` and use HTTPS (below), because the app only allows plain `http://` for a server on the same machine in debug builds.

## Settings

All settings are environment variables.

| Variable | Default | What it does |
|---|---|---|
| `NODE_ENV` | (unset) | Set to `production` for a real deployment. The server then refuses to start without a strong secret and TLS. |
| `AQUA_JWT_SECRET` | random each start | Secret for signing sign-in passes. At least 32 random characters. In development a random one is made, so sessions reset when the server restarts. |
| `AQUA_TLS_CERT`, `AQUA_TLS_KEY` | (unset) | Paths to a certificate and key. The server then speaks HTTPS (TLS 1.2 or newer). |
| `AQUA_BEHIND_TLS_PROXY` | (unset) | Set to `1` if an HTTPS reverse proxy (nginx, Caddy, a cloud load balancer) handles TLS in front of the server. |
| `AQUA_TRUST_PROXY` | (unset) | Set to `1` to read the client address from `X-Forwarded-For`. Only do this behind a proxy you control, or rate limits can be dodged. |
| `AQUA_CORS_ORIGINS` | none | Comma-separated web addresses allowed to call the API from a browser, for example `https://aqua.example.org`. There is no wildcard. |
| `HOST` / `PORT` | `127.0.0.1` / `8443` | Where to listen. |
| `AQUA_DB` | `aquaaware.db` | Database file path. |
| `AQUA_QUIET` | (unset) | Set to `1` to silence request logs (used by the tests). |

A production start looks like this:

```bash
NODE_ENV=production \
AQUA_JWT_SECRET="$(openssl rand -base64 48)" \
AQUA_TLS_CERT=/etc/aqua/cert.pem AQUA_TLS_KEY=/etc/aqua/key.pem \
AQUA_CORS_ORIGINS=https://aqua.example.org \
HOST=0.0.0.0 npm start
```

Keep `aquaaware.db` backed up and out of version control (the project `.gitignore` already excludes it).

## How it works, in short

**Signing in.** `POST /api/auth/staff` with `{ role, loginId, secret }` (educators and the manager use their email, NGO desks use their id such as `NGO001` and access code) or `POST /api/auth/student` with `{ name, classCode, pin }`. The reply contains:

- `token`: a JWT (a signed sign-in pass), sent as `Authorization: Bearer …` on every later request. It is tied to a session stored on the server, so signing out (`POST /api/auth/logout`) cancels it at once.
- `signingKey`: a random key for this session only. The app keeps it in the device keystore and uses it to sign every update.

Five wrong attempts lock that sign-in for 30 seconds, doubling each time up to 15 minutes. A wrong password and an unknown email get the same answer.

**Sending updates (Q5 reliable delivery, Q7 integrity).** Every change goes to `POST /api/sync/<kind>` with two headers:

- `Idempotency-Key`: a unique id for this update. If the app resends after losing the reply, the server answers "already have it" instead of applying it twice.
- `X-Aqua-Signature`: an HMAC-SHA256 of the exact body, made with the session's `signingKey`. An edited body fails the check.

| Kind | Who may send it | What the server checks |
|---|---|---|
| `points` | student | The server decides what the achievement is worth and applies the caps (lesson 20, sorting 20, water bonus 5 for today only, task 5 or 10 depending on who posted it, handover 15 only after a real pickup request and at most 2 a day, event check-in 10, quiz points in steps of 10 that never total more than 10 per correct answer). Each achievement pays once. |
| `quiz_score` | student | Module id and score ranges (the score record; the points travel as a `points` update). |
| `announcement` | educator, NGO | Educators can post only to their own class; NGOs to all schools or one valid class. Non-urgent posts during school hours (Mon–Fri, 8 am–3 pm India time) are marked to wait. |
| `announcement_done` | student | The task exists and is meant for the student's class. |
| `pickup` | student | A known collector. |
| `redemption` | NGO | The ticket's nonce has never been redeemed before (anti-replay). |
| `student_transfer` | manager | The new class exists. Points stay with the student (Q3). |
| `activity` | NGO | Date format; the NGO comes from the session, never from the request. |

Identity always comes from the session, never from the request body, so nobody can send updates in someone else's name.

**Live updates (Q2 push relay, Q6 partitioning).** `GET /api/feed` is a Server-Sent Events stream: the server pushes each announcement only to people allowed to see it, and each completion only to the person who posted the task (and the manager). Apps that cannot hold a stream open can poll `GET /api/announcements?since=<seq>`; the AquaAware app polls every 20 seconds.

**Manager reports.** `GET /api/admin/summary` (counts) and `GET /api/admin/audit` (the audit log) are open to the manager only.

**Health check.** `GET /api/health`.

## Protections

- Requests are limited: 10 sign-in requests a minute and 240 other requests a minute per address.
- Bodies must be JSON and at most 32 KB. Slow or oversized requests are cut off.
- Responses carry strict security headers (`Content-Security-Policy`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Cache-Control: no-store`, and HSTS when TLS is on).
- Error replies give a short message and a code, never internal details or stack traces.
- Logs record method, path, status and time only: never tokens, bodies, passwords or PINs.
- Text is cleaned of invisible and direction-changing characters before it is stored, using the same rules as the app.

See [../docs/SECURITY.md](../docs/SECURITY.md) for the full picture and its honest limits.

## Files

```
src/server.js     start-up, HTTP or HTTPS, timeouts
src/config.js     settings and production safety checks
src/app.js        routes, sign-in, points rules, sync, feed
src/security.js   PBKDF2 hashing, JWT, HMAC, constant-time compare, text cleaning
src/http.js       body limits, JSON parsing, CORS, security headers, rate limiter
src/realtime.js   Server-Sent Events hub
src/db.js         SQLite schema and queries
src/seed.js       pilot accounts and classes (generated from the app's seed data)
test/             node:test suites (npm test)
```

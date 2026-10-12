# Security and privacy in AquaAware 2.0

AquaAware holds information about school children, and its points turn into real rewards handed out by NGOs. So it has three jobs: keep personal data private, keep points and rewards fair, and keep working when the network does not.

This page explains each protection in plain words. Every claim here is backed by code you can read, and the **Privacy and security** screen in the app runs live checks of the important ones.

## A few words first

| Term | What it means here |
|---|---|
| **Encryption** | Scrambling data so only someone with the key can read it. |
| **AES-256-GCM** | The encryption method used. "256" is the key size; "GCM" means it also detects any change to the scrambled data. |
| **Keystore** | A protected vault the operating system gives each app (Android Keystore, iOS/macOS Keychain, Windows DPAPI, Linux Secret Service). Keys kept there do not sit in normal app storage. |
| **Hash** | A one-way fingerprint of some data. You can't turn a hash back into the data. |
| **Salt** | Random bytes mixed into each password before hashing, so two people with the same password get different hashes. |
| **PBKDF2** | A deliberately slow way to hash passwords (100,000 rounds here), so guessing millions of passwords takes too long. |
| **HMAC** | A hash made *with a secret key*. Anyone can recompute a plain hash after changing data, but nobody can recompute an HMAC without the key, so it proves the data was not changed. |
| **Nonce** | A random "number used once". A ticket's nonce is recorded when it is used, so a copy is recognised. |
| **JWT** | A signed sign-in pass the server gives the app ("JSON Web Token"). |
| **TLS / HTTPS** | Encryption for data travelling over the network. |
| **Idempotency key** | A unique label on each update, so if the app has to resend it the server applies it only once. |
| **Constant-time comparison** | Checking two secrets in a way that takes the same time whether they match early or late, so timing gives nothing away. |

## What version 1 got wrong, and what version 2 does

| Version 1 | Version 2 |
|---|---|
| Any password was accepted, and any role could be picked, including Manager. | Real sign-in: passwords and PINs checked against salted PBKDF2 hashes. Manager and NGO accounts can't be self-registered. |
| The session was the string `mock-token` in plain app storage. | A session record signed with an HMAC, kept in the platform keystore. It lasts 8 hours and ends after 15 minutes without activity. |
| Points were a plain number anyone could edit; retaking a quiz paid again every time. | Points live in a hash-chained ledger (below). Quizzes pay only for beating your best score. |
| "HMAC" for QR codes was a plain SHA-256 with `Math.random()`, the QR was random squares, and the scanner accepted any text containing `AQUA_REWARD`. | Real signed, expiring, single-use tickets with a cryptographically secure nonce, rendered as real QR codes and verified properly. |
| The quiz "integrity hash" was SHA-256 of the score, which anyone can recompute. | Updates are signed with an HMAC using a key the server issues per session. |
| The server signed tokens with `JWT_SECRET \|\| 'secret'`, allowed every web origin, and returned database error messages to clients. | The server refuses to start in production without a strong secret and TLS, allows only listed web origins, and never sends internal errors. |
| The real-time socket had no authentication, and educator replies were meant to go to every device and be filtered on the phone. | Every request is authenticated. The server sends each announcement only to people allowed to see it. Private messages never go to other students. |
| Collector "OTP" sign-in accepted `1234` for any phone number. | Removed. Collectors are reached by call or SMS. |
| Real students' phone numbers were in the source code and shown in full. | Placeholders in the source; numbers are masked until an educator chooses to see one, and that choice is logged. |
| The GPS reward check compared raw degree differences against coordinates that didn't match the desk. | Real distances in metres (Haversine formula), the correct desk location, and fake-GPS apps detected on Android. |
| The Security tab listed "AES-256 · Active", "TLS 1.3 · Active" as fixed labels. | The Security Center runs real checks you can repeat. |

## How data is protected on the device (confidentiality)

- **Encrypted storage.** Two random 256-bit keys are created on first launch and kept in the platform keystore. All app data is stored encrypted with AES-256-GCM. The name of each storage slot is bound into the encryption, so data copied from one slot into another is rejected. (`lib/core/security/secure_vault.dart`)
- **Fails closed.** If the keystore is unavailable, the app does not fall back to storing keys in plain text. It keeps data in memory for that session and says so in the Security Center.
- **No backups of encrypted data.** Android backup is switched off (`allowBackup="false"`), because restored data would be unreadable without the keys, which are never backed up.
- **Secrets cleared.** Password fields are cleared on sign-in failure and when the sign-in screen closes.

## How points and rewards stay fair (integrity)

- **Hash-chained ledger.** Every award or redemption is a ledger entry whose HMAC covers the previous entry. Editing, deleting or reordering any past entry breaks the chain from that point on. The app checks the chain at start-up and in the Security Center. If it is broken, awards and claims pause and the manager is alerted. (`lib/core/security/ledger.dart`)
- **Each achievement pays once.** Every entry carries a reference such as `module:MOD_A` or `ann:ANN-…`; the same reference never pays twice.
- **Anti-farming rules.** Quizzes pay only for improvement; a pickup can be confirmed only after the collector has had time to arrive, and only two a day earn points; at most three reward claims a day. (`lib/data/points_rules.dart`)
- **Reward tickets.** Each ticket is `AQ1.claim.<data>.<HMAC>`. The data holds the claim, the student, the points, an issue time, a 7-day expiry and a 96-bit random nonce. The desk checks the signature (in constant time), the type, the expiry, that the nonce was never used, that it matches the claim on record, and that the student still has the points. (`lib/core/security/signed_token.dart`, `AppStore.redeemClaim`)
- **Event check-in codes** are signed the same way but expire after 15 minutes, and the desk shows a fresh one automatically, so a photo shared later stops working. A check-in code can't be used as a reward ticket, or the other way round, because the type is part of the signed part.
- **Clean input.** Messages are stripped of invisible and direction-changing characters (used in "Trojan Source" spoofing), trimmed and limited to 500 characters. Names, emails, class codes and PINs are validated. (`lib/core/security/input_rules.dart`)
- **Safe file sharing.** Only PDF, slides, documents and plain text up to 25 MB. The first bytes of the file must match its type (every real PDF starts with `%PDF-`, Office files with a fixed signature), so a renamed program is refused. File names are cleaned before saving, so a name like `../../x` can't write outside the app's folder. (`lib/core/security/file_rules.dart`)

## Who can do what (authentication and access)

- **Passwords.** At least 10 characters, a check against the most common choices, and a strength meter. Stored only as PBKDF2-SHA256 hashes with a 16-byte salt and 100,000 rounds; the hashing runs in a background thread so the screen stays smooth.
- **Student PINs.** Four digits chosen on the first sign-in; easy ones like `1111` or `1234` are refused. Educators can reset a forgotten PIN.
- **Same answer for every failure.** A wrong password and an unknown email get the same message, and the app spends the same time checking either, so nobody can find out which emails exist.
- **Lockout.** Five failures lock that sign-in for 30 seconds, doubling each time up to 15 minutes. This applies on the device and on the server.
- **Role-based screens.** Each role's screens declare who may open them; anyone else is sent to their own home. Only shared pages such as Settings are open to every signed-in person. A conversation is only possible between a student and their own class educator. (`lib/routing/app_router.dart`)
- **Quick unlock with biometrics** (fingerprint, face or device PIN) is offered to staff only, because students often share classroom devices.

## Privacy

- Phone numbers are masked (`+91 ••••• ••210`) until an educator or manager deliberately reveals one, and each reveal is written to the audit log.
- Location is used only when you tap a button that needs it (nearest collectors, the reward desk), never in the background. Camera access happens only on the scan screen.
- The audit log records sign-ins, lockouts, broadcasts, redemptions and phone-number views. It never records message contents, passwords or PINs.
- No analytics or advertising code is included.

## Over the network

- The app only talks to `https://` servers (TLS 1.2 or 1.3, negotiated by the operating system). Plain `http://` is allowed only for a server on the same computer in debug builds.
- Each update carries an idempotency key and an HMAC made with the per-session key from the server. The server rejects edited bodies, reused keys with different content, and updates more than 30 days old.
- Updates wait in the encrypted outbox until they are delivered, with three attempts and back-off. Each person's updates are sent only with their own server session, so on a shared device one student's quiz can never be sent in another's name.
- Data received from the server is cleaned again before it is shown.

## The server

`server/` is a small Node.js program with no third-party packages, which leaves nothing to keep patched beyond Node itself. Its own tests (`npm test`) cover each item below.

- JWTs are HS256 with a fixed header, so tokens claiming `alg: none` or another algorithm are refused. Issuer, audience, expiry and issue time are all checked. Each token is tied to a server-side session that is revoked on sign-out.
- Rate limits: 10 sign-in requests a minute per address, 240 other requests a minute.
- Request bodies are limited to 32 KB and must be JSON. Responses carry strict security headers (`Content-Security-Policy`, `X-Frame-Options`, `nosniff`, `no-store`, and HSTS with TLS).
- **Points rules are enforced on the server.** The app says which achievement was earned; the server decides what it is worth and applies the same caps. A modified app can't award itself extra points.
- The server stores every redeemed ticket's nonce and refuses a second redemption of the same ticket.
- In production the server will not start without a secret of at least 32 characters, and without TLS or an HTTPS proxy in front.

## Honest limits

- **Tickets and check-in codes are verified on the device that made them.** They are signed with that device's own key. The single-device flow in the README works fully; the server records used tickets, but it doesn't yet sign or verify them, so scanning a ticket shown on a *different* phone is refused with "issued by a different device". Server-signed tickets are the next step for multi-device desks.
- **Student profiles are claimed by name and class code.** Before a student's first sign-in, someone who knows both could claim the profile. An educator can reset the PIN. A real rollout should give each student a one-time join code.
- **A 4-digit PIN is short.** The lockout means guessing all 10,000 PINs would take months, but PINs suit shared classroom devices, not sensitive data.
- **Self-reported actions** (task done, waste handed over) rely on honesty. The caps limit how much anyone can gain.
- **A device that is rooted, or unlocked in someone else's hands,** can expose what the app can see. The keystore protects keys at rest, not a compromised phone.
- **On the web** the browser is the keystore, which is weaker than a phone's hardware-backed one.
- **Password hashing uses 100,000 rounds** so sign-in stays under about a second on modest phones. OWASP's current advice for servers is higher. The stored format includes the round count, so it can be raised later without breaking existing passwords.

## Before going live

1. Change every demo password and NGO access code, and build with `--dart-define=AQUA_HIDE_DEMO=true`.
2. Run the server with `NODE_ENV=production`, a random `AQUA_JWT_SECRET` (32+ characters), TLS (`AQUA_TLS_CERT` / `AQUA_TLS_KEY`, or an HTTPS proxy with `AQUA_BEHIND_TLS_PROXY=1`) and `AQUA_CORS_ORIGINS` set to your web app's address only.
3. Build the app with `--dart-define=AQUA_API_URL=https://your-server`.
4. Back up the server database file, and keep it out of version control (it already is, in `.gitignore`).
5. Replace the placeholder phone numbers with real contacts only in the live data, never in source code.

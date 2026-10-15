# What changed from version 1

Version 1 had a strong idea and a lot of good features. Many of them were mock-ups, though: the sign-in accepted anything, the "real-time" messages never left the phone, the reward QR was random squares, and points could be edited. Version 2 keeps every idea, makes them work for real, and adds a design system, purposeful animation, security and accessibility.

## 1. One codebase for six platforms

Version 1 was React Native with Expo. It ran on Android and iOS, but on the web the maps showed "Map View is optimized for Mobile App" and saving files did nothing.

Version 2 is **Flutter**. The same code runs on Android, iOS, web, Windows, macOS and Linux. Maps use OpenStreetMap through `flutter_map`, which works on every platform, including the web. Phone-only features (camera scanning, fingerprint unlock, read-aloud) check what the device supports and offer an alternative when it doesn't: for example, typing a ticket code instead of scanning it.

## 1a. For everyone: schools, colleges, offices and communities

Version 1 talked only about schools. Version 2 works for **any group**:

- The sign-in roles are **Student or member**, **Teacher or team lead**, **NGO partner** and **Admin**. Members join with the code their leader gives them.
- A leader registering a group chooses **School**, **College**, **Office** or **Community**. The group remembers it, and the app's words follow everywhere: a school has a *teacher*, *students* and a *class code*; a college has *faculty*; an office has a *team lead*, *employees* and a *team code*; a community has an *organiser*, *members* and a *group code*. (`InstitutionKind` in `lib/data/models/models.dart`)
- Behaviour follows the kind too. Schools and colleges hold non-urgent notices during class hours (8 am – 3 pm); offices and communities get them straight away. The daily water bonus opens when the group's day ends (3 pm for schools and colleges, 6 pm otherwise).
- NGO partners and the admin see each group with its kind and icon, and speak to everyone in neutral words ("people", "members", "groups").
- Demo groups show each kind: a college class (AWA-2024-CCAS, Dr. Anitha) and an office team (AWA-2026-CTP, team lead Ms. Deepa, employee Ravi). Devices that already had the app keep all their data and simply gain the new groups.

## 1b. Author credit and copyright

- The sign-in screen shows **Created by P Om Shiva · M.Tech CSE (2nd year) · Pondicherry University** to everyone who opens the app, with a link to **Why I made AquaAware**.
- A new **About AquaAware** page (sign-in screen, account menu and Settings) gives the author, the author's message, who the app is for, and the copyright notice. It opens without signing in.
- Every source file carries a copyright notice, the repository has a [LICENSE](../LICENSE) that reserves all rights, and the server's package is marked `UNLICENSED` (it used to say MIT, which would have allowed anyone to copy it). The website's page carries author and copyright tags.

## 2. The look

| Version 1 | Version 2 |
|---|---|
| Colours chosen per screen (`#27AE60`, `#FFF3CD`, `#856404`…), several failing contrast checks | One palette taken from Pondicherry itself: the Bay of Bengal blues, sea-salt background, the ochre walls of White Town for points, the Ariyankuppam mangrove green for NGOs. Every text colour pair is measured at 4.5:1 or better. (`lib/core/theme/tokens.dart`) |
| Emoji used as icons (they also turned into garbled characters like `ðŸ“©` in the source file) | Material icons, and lesson pictures drawn in code (`widgets/slide_art.dart`), so nothing depends on fonts or random stock photos |
| System font | **Atkinson Hyperlegible Next**, a typeface designed by the Braille Institute so that letters like I, l and 1 are hard to confuse, bundled so it works offline |
| Light mode only | Light, dark and high-contrast themes |
| Phone layout stretched on big screens | Bottom navigation on phones, a side rail on tablets and desktops, and content width capped for comfortable reading (`widgets/adaptive_shell.dart`) |
| Spacing and corner sizes picked per widget | Shared spacing, corner and motion scales, so every screen feels like the same app |

## 3. Animation with a purpose

Each animation tells the user something. All of them stop when the device asks for reduced motion, when the in-app *Reduce motion* switch is on, or when the battery is low (Q2).

- **The reservoir** (student home). A tank of water whose level shows your points towards the next eco level, with gently moving waves. It is the app's signature picture: your actions literally fill it. (`widgets/reservoir.dart`)
- **The wordmark** on the sign-in screen rises letter by letter out of the sea. This was version 1's idea, and it is kept.
- **Droplet burst.** A small splash when you finish a quiz, complete a task or redeem a reward. (`widgets/motion.dart`)
- **Counting numbers.** Points count up when they change. Screen readers hear only the final number.
- **Quiz timer.** A bar that empties and changes colour in the last third, a live seconds counter, and a spoken warning at 10 seconds. Number keys or A–D answer, and Enter moves on.
- **One entrance per screen.** The home and sign-in screens fade in once; lists don't animate item by item, so nothing slows you down.

## 4. Screen by screen

### Sign-in

| Version 1 | Version 2 |
|---|---|
| Any password worked; anyone could choose Manager | Real accounts with hashed passwords, a lockout after repeated failures, and no self-registration for staff |
| Educator name made from the email address | Names come from the account |
| "Register" showed a success message and saved nothing | Members join with name + their group's code and choose their own 4-digit PIN on the first visit |
| Fingerprint button said "Demo: please use manual login" | Staff can turn on quick unlock with fingerprint, face or device PIN, which really reopens their session |

### Students

| Version 1 | Version 2 |
|---|---|
| Points and streak shown as numbers | The reservoir, eco levels, streaks, badges and a full points history |
| Announcement card: "Mark as done" added points to an editable number | Tasks pay once each, recorded in a tamper-evident ledger. Non-urgent tasks posted during class hours wait until 3 pm, and a **Show now** button is there if you need it |
| Module progress always said "4 of 6" | Real progress from the lessons you finished |
| Lesson pictures were random photos from picsum.photos | Drawn illustrations with real descriptions for screen readers, and a speaker button that reads each slide aloud |
| The last lesson slide promised a "drag-and-drop segregation challenge" that did not exist | The sorting challenge is real: drag each item into the green, blue, red or yellow bin, or tap to sort if dragging is hard |
| Quizzes existed only for modules A and B; modules C–F silently showed module A's quiz | All six modules have their own quiz |
| The timer always showed "30s" and never counted down | A live countdown, adjustable to 30 s, 60 s or off; progress is saved after every answer |
| "+N points earned" on the results screen, but nothing was added | Points are added, for improving your best score only |
| The score went to `/scores/submit`, which the server didn't have, so every quiz waited through 3 failed tries and then said "Offline" | Scores go to the encrypted outbox and sync quietly in the background |
| Rewards: claiming didn't take away any points | Points are deducted when the desk hands the reward over |
| The reward QR was random squares, redrawn differently on every refresh | A real, scannable QR code holding a signed ticket that expires in 7 days and works once |
| The GPS check compared raw latitude/longitude differences against desk coordinates that didn't match the rest of the app | Real distances in metres, the correct desk location, and fake-GPS detection on Android |
| Eco-map: "Request pickup" changed the pin colour on that phone only; the tracking screen was unreachable | Pickup tracking with an arrival estimate, "handed over" confirmation, the three nearest free collectors highlighted, and Call or SMS (the SMS works without internet) |
| Profile stats and settings were fixed text | Real stats; working settings for theme, contrast, text size, motion, quiz timer and data saver |

### Educators

| Version 1 | Version 2 |
|---|---|
| "Start Local Hotspot Server" showed an alert and did nothing | Removed. The app now works fully offline instead, and the overview says how many updates are waiting to sync |
| Analytics charts and the "At Risk" / "Top Performers" lists were hard-coded | Calculated from the class's real progress. Every chart can be switched to a table |
| Student phone numbers shown in full | Masked until the educator chooses **Show**, and that choice is logged |
| Messages and replies relied on socket events the server never relayed | Private conversations per student that work on one device and sync through the server |
| Any file type could be "uploaded" | PDF, slides, documents and text only, up to 25 MB, with a check that the file really is what its name says |
| Security tab listed "AES-256 · Active", "TLS 1.3 · Active" as fixed labels | The Privacy and security screen runs real checks you can repeat |

### NGO desks

| Version 1 | Version 2 |
|---|---|
| Broadcast to everyone | Broadcast to every school and college or to one class, with completion counts |
| "+ Add New Activity" and "Join +10pts" buttons did nothing | Schedule events; each event shows a check-in QR code that changes every 15 minutes, and students earn 10 points for checking in |
| "Scan QR" opened the student scanner, which accepted any text containing `AQUA_REWARD` | A reward desk that checks the ticket's signature, expiry, single use and the student's balance, then says exactly what to hand over |

### Manager

| Version 1 | Version 2 |
|---|---|
| Search box that filtered nothing | A searchable directory of students, educators and NGOs |
| "Alerts: 3" and the activity list were fixed text | Real alerts (ledger integrity, tampered data, lockouts, refused updates, students at risk) and a live audit log |
| Sign-out left the dashboard on screen | Sign-out returns to the sign-in screen, as it does for every role |
| | New: move a student to another class without losing points or badges (Q3) |

## 5. Bugs fixed from version 1

1. Sign-in accepted any details and any role, including Manager.
2. The session was the text `mock-token` in plain storage, and points lived in the same editable record.
3. Quiz points were shown but never added; the quiz timer label never changed; modules C–F reused module A's quiz.
4. Score submission called an endpoint that didn't exist, so every quiz ended with a 9-second wait and an "Offline" message.
5. The reward QR was random and redrawn on each render; claiming never deducted points; the `loading` state on the claim button was never set.
6. The scanner looked for `AQUA_REWARD`, but the signed codes the app could generate started with `AQUA_<id>`, so a genuine code would have been refused and any text containing `AQUA_REWARD` accepted.
7. The "HMAC" was a plain SHA-256 hash with `Math.random()` for the nonce. Anyone can recompute a plain hash, and `Math.random()` is predictable.
8. The GPS reward check measured distance in raw degrees and used desk coordinates that differed from the rest of the app.
9. `socket.off('new_announcement')` in one screen removed every screen's listener; the NGO screen never removed its own. The server relayed none of these events, so nothing reached other devices.
10. "Quiet hours" for notifications dropped non-urgent messages instead of holding them until after class.
11. Manager and NGO sign-out did not leave the dashboard.
12. Real-looking student phone numbers were in the source code, and two of them were reused as collectors' numbers.
13. The server signed tokens with `'secret'` when no secret was set, allowed every web origin, accepted OTP `1234` for any phone, let anyone sign in as a student by name and class code alone, and sent raw database errors to clients. Its user model also had no NGO or Manager role.

## 6. Security and accessibility

These are covered in full, in plain words, in:

- [SECURITY.md](SECURITY.md): encrypted storage, the points ledger, signed tickets, sign-in protection, privacy, the server, and honest limits.
- [ACCESSIBILITY.md](ACCESSIBILITY.md): screen readers, text size, contrast, motion, keyboard use, and a WCAG 2.2 checklist.

## 7. The course concepts (Q1–Q12): before and after

| | Concept | Version 1 | Version 2 |
|---|---|---|---|
| Q1 | Adaptive quality | Added `?w=200&blur=1` to the end of image addresses on mobile data | Photos are fetched at one third of the size on mobile data, on small Android screens, or with the *Data saver* setting; lesson pictures are drawn in code, so they cost no data at all |
| Q2 | Battery and notifications | A low-battery banner; non-urgent notices during class were dropped | Low battery pauses all motion and saves quiz progress after every answer; class-hour notices are held, not lost; the server fans one post out to the right class |
| Q3 | Points follow the student | A server route that was never called | The ledger is keyed by student; the admin can move a student to another class and everything comes along |
| Q4 | Smart paging, daily tips | A function that sorted collectors from an empty cache | Only the three nearest free collectors are highlighted and alerted; a different tip each day |
| Q5 | Reliable delivery (ARQ) | 3 tries against a missing endpoint, then a local copy that was never resent | An encrypted outbox, 3 attempts with back-off, idempotency keys so a resend is never counted twice, and resending on the next launch |
| Q6 | Data partitioned by class | `schoolId` field in the model | Class codes scope every screen and query; the server checks who may see each announcement and completion |
| Q7 | CIA triad and 4W context | SecureStore helper (unused for the session), a plain SHA-256 "integrity hash", a greeting that always said "at School" | AES-256-GCM storage with keystore keys, an HMAC hash chain for points, HMAC-signed updates; the greeting uses who, when, where (school hours) and what to do next |
| Q8 | Reward checks and lightweight JWT | Degree-based GPS check; `fraudFlag = false`; JWT with a `'secret'` fallback | Distance in metres, fake-GPS detection, 3 claims a day, balance checked at the desk; HS256 JWTs with issuer, audience, expiry and server-side revocation |
| Q9 | QR anti-replay, SMS fallback | Unkeyed hash, unused generator, scanner accepting any `AQUA_REWARD` text | Signed tickets with a secure 96-bit nonce, expiry and a used-nonce record; an SMS button to collectors that works offline |
| Q10 | Low-end devices | Lower-resolution image addresses on small Android screens | Small Android screens (narrower than 360 points) are detected live, including after rotation, and get lighter images |
| Q11 | TLS instead of IPSec | A comment explaining the choice | HTTPS-only sync (TLS 1.2 or 1.3); the server refuses to start in production without TLS or an HTTPS proxy |
| Q12 | Biometrics and IoT water meter | Biometric demo message; a water card fixed at "280 L / 300 L" | Real biometric quick unlock for staff; a school or college water meter reading with a daily bonus when it stays under target |

## 8. What was left out, and why

- **Collector OTP sign-in.** It accepted `1234` for every phone number. Collectors are reached by call or SMS until there is a real SMS provider.
- **The local hotspot server.** It never did anything. Working fully offline gives students the same benefit with no setup.
- **Stock photos in lessons.** They were random pictures that didn't match the text. The gallery still uses sample photos, labelled as samples, until NGOs add their own.

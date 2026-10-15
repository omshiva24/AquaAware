# Accessibility in AquaAware 2.0

AquaAware is used by school and college students of different ages and reading levels, on shared and low-cost phones, sometimes outdoors in bright sun. Accessibility is part of the design, not an add-on. The target is **WCAG 2.2 level AA** (the Web Content Accessibility Guidelines, the usual standard for apps).

## For people who read with difficulty or have low vision

- **Typeface.** Atkinson Hyperlegible Next, designed by the Braille Institute for readers with low vision. Easily confused letters like `I l 1` and `O 0` have clearly different shapes.
- **Contrast.** Every text colour meets AA contrast (4.5:1 or more) in light and dark themes. Measured examples: body text 14.9:1, secondary text 6.7:1, white on the primary blue 5.7:1, and secondary text over the reservoir water at least 4.5:1.
- **High contrast mode** (Settings) makes text darker and outlines thicker. It also follows the system's high-contrast setting.
- **Text size.** The app follows the device's text size, and Settings adds its own slider (85–160%) on top. Layouts grow instead of cutting text off: the reservoir, sorting bins and cards get taller.
- **Dark theme** follows the system or can be chosen in Settings.
- **Read aloud.** Lessons and quiz questions have a speaker button, with an adjustable speed and an Indian English voice where the device has one. It helps younger readers, students learning in a second language, and anyone with dyslexia or low vision.

## For screen reader users (TalkBack, VoiceOver, NVDA, Narrator)

- Every icon-only button has a name (for example "Close quiz", "Read the question aloud", "Copy team code").
- Screen titles and section titles are marked as headings, so you can jump between them.
- Changes are announced: right or wrong quiz answers, "10 seconds left", sign-in errors, scan results, a new slide, and finished tasks.
- Charts have a spoken summary of every value, and a **Show as table** button.
- The eco-map has a **List** view with the same information, sorted by distance. It opens automatically when a screen reader is running.
- The sorting challenge doesn't need dragging: select an item, then choose a bin.
- Lesson illustrations are decorative and hidden from screen readers, because the slide text says everything they show. (Version 1 showed random stock photos that had nothing to do with the lesson.)
- Combined controls (a quiz option, a role card, a statistic) are read as one sentence, such as "Option B: 13.5 percent, correct answer".

## For people who find motion or time pressure hard

- **Reduce motion.** The app follows the system setting, has its own switch, and turns motion down automatically on low battery. Waves stop, page changes become instant, and celebrations are skipped.
- **Quiz timer.** 30 seconds, 60 seconds, or no timer at all (Settings → Quizzes). This meets WCAG's "timing adjustable" rule. If you leave a quiz, your answers are saved and you can resume later that day.
- **Sessions.** The app signs out after 15 minutes without activity. Any tap or key press counts as activity.

## For people who use a keyboard, switch or larger targets

- Every button and tap target is at least 48 × 48 points.
- On desktop and web: the arrow keys move between lesson slides; in quizzes, **1–4** or **A–D** choose an answer and **Enter** goes on; **Escape** closes the photo viewer. Tab moves through controls in reading order with a visible focus ring.
- Phones get a bottom navigation bar, tablets a side rail, and wide desktop windows an extended rail with labels.

## Meaning never depends on colour alone

The waste bins say "Green bin: wet and organic" as well as being green. Map pins carry an icon, and busy collectors have a marked badge plus the word "Busy". Right and wrong quiz answers show a tick or a cross and say so. Status labels always pair a word with an icon.

## Clear words

Buttons say what they do ("Join", "Send to team", "Collect +5 water bonus"). Errors explain how to fix the problem ("Codes look like AWA-2024-GHS."). Empty screens say what to do next. Sentence case throughout, no all-capital labels.

## WCAG 2.2 checklist

| Success criterion | How AquaAware meets it |
|---|---|
| 1.1.1 Non-text content | Icon buttons are named; decorative art is hidden; gallery photos have descriptions |
| 1.3.1 Info and relationships | Headings marked; form fields labelled; grouped values read together |
| 1.4.1 Use of colour | Words and icons accompany every colour cue |
| 1.4.3 Contrast (minimum) | All text 4.5:1 or more (measured) |
| 1.4.4 Resize text | System size plus an in-app slider, up to 2.2 times combined |
| 1.4.10 Reflow | Single-column phone layouts; content width capped on desktop |
| 1.4.11 Non-text contrast | Outlines and focus rings 3:1 or more; thicker in high contrast |
| 2.1.1 Keyboard | All actions reachable by keyboard; shortcuts for lessons and quizzes |
| 2.2.1 Timing adjustable | Quiz timer 30 s, 60 s or off; quizzes resume after leaving |
| 2.3.3 Animation from interactions | Reduce-motion switch, system setting and low-battery mode |
| 2.5.7 Dragging movements | Tap-to-sort alternative in the sorting challenge |
| 2.5.8 Target size | 48 × 48 points minimum |
| 3.3.1 / 3.3.3 Error identification and suggestion | Each error says what is wrong and how to fix it |
| 4.1.3 Status messages | Live announcements for results, errors and timers |

## How to check it yourself

1. **Screen reader:** turn on TalkBack (Android) or VoiceOver (iOS, macOS), then sign in as a student and take a quiz without looking at the screen.
2. **Large text:** set the device's text size to its largest, plus 160% in Settings. Then visit Home, Learn, a quiz and Rewards.
3. **Reduce motion:** switch it on in Settings and sign in again; the waves should be still.
4. **Keyboard:** run `flutter run -d windows` (or `-d macos`, `-d chrome`) and use only Tab, the arrow keys, number keys and Enter.
5. **Automated:** `flutter test test/app_smoke_test.dart` signs in as every role and opens every screen, at phone and desktop sizes, with reduced motion and screen-reader navigation turned on. Any layout overflow fails the test.

# Digital Pet — In-Class Activity 07

Mobile Application Development · Georgia State University · Due October 1, 2026

A Flutter pet-care app that turns user actions and time into visible state changes using `StatefulWidget`, `setState()`, lifecycle-aware timers, and accessible mood feedback.

## Developer and workstreams

Solo submission: Om Swaroop Reddy Udumula · Undergraduate pathway. _(Note the instructor approval for solo work here, if given.)_

Both workstreams were built on separate branches and merged through pull requests to keep the history traceable:

| Workstream | Branch | Scope |
|---|---|---|
| Care Systems | `team-1/care-systems` | Care loop, bounded meters, hunger/win timers, outcomes, session controls |
| Pet Personality | `team-2/pet-personality` | Derived messages, mood feedback, pet asset, motion/accessibility polish |

## Setup, run, test, build

```bash
git clone <repository-url>
cd <repository-folder>
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk -> renamed DigitalPet_TeamName.apk
```

Asset registration in `pubspec.yaml` (under the existing `flutter:` section):

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/pet.png
```

## Game rules (team-chosen balance)

| Event | Effect |
|---|---|
| Feed | Hunger −10. If resulting hunger < 30, happiness −20 (overfed); otherwise happiness +10. |
| Play | Happiness +10, hunger +5. |
| Hunger tick (every 30 s) | Hunger +5. A tick that would push hunger above 100 clamps it to 100 and reduces happiness by 20. 95 → 100 has no penalty. |
| Win | Happiness strictly > 80 continuously for 3 minutes. Timer starts on first crossing above 80, is cancelled and cleared at 80 or below, and restarts fresh on the next crossing. |
| Loss | Hunger == 100 and happiness ≤ 10. |
| After win/loss | Feed, Play, Pause and pet-tap are disabled; both timers stop until Reset/Restart. |
| Reset | Restores happiness 50 / hunger 50 and outcome flags, cancels the win timer, starts exactly one new hunger timer. Pet name is kept. |
| Tapping the pet | Bounce animation only; does **not** change happiness, so it cannot make the win trivial. |

All meters are clamped to 0–100 through one `_clampMeter()` helper. `_updateOutcome()` runs after every action, tick, reset, and resume.

Mood thresholds (shared by label, icon, tint, scale, and message): > 70 Happy / green / scale 1.06; 30–70 Neutral / yellow / 1.0; < 30 Unhappy / red / 0.94.

## Advanced features (undergraduate: 2)

| Feature | User flow | State changes and why | PR |
|---|---|---|---|
| Session controls (pause/resume + restart) | Tap Pause → timers stop, actions disabled, message "Taking a little break...". Tap Resume → play continues. Restart button appears after win/loss. | `_isPaused` toggles. Pause cancels the hunger timer and the win timer so no state changes while paused. Resume starts one fresh hunger timer and re-runs `_updateOutcome()`, starting a **new** 3-minute streak (pausing breaks "continuous"). | _PR #_ |
| Visual polish & accessible motion (bundle = 1 feature) | Feed/Play/tap → pet bounces; meters glide; mood and speech crossfade; tint and size change at thresholds. | Bounce uses short-lived `_bounce` with a cancellable timer; message, tint, scale, mood are getters derived from `_happiness`/`_hunger`/outcome flags, never stored. `MediaQuery.disableAnimations` switches all durations to zero and skips the bounce. | _PR #_ |

Effects implemented: action bounce (`AnimatedScale`), living meters (`TweenAnimationBuilder`), expression switch (`AnimatedSwitcher` + `ValueKey`), mood tint & size, derived pet speech, reduced-motion support.

## Feature-to-learning-outcome map

| Feature | Learning outcome | Evidence |
|---|---|---|
| Core care loop | `setState()` notifies Flutter after an action; related fields updated together | Feed/Play before/after values (test matrix) |
| Bounded meters | Values kept within defined ranges; UI derived from same state | Boundary rows in test matrix |
| Hunger + win timers | Periodic work started in `initState()`, cancelled in `dispose()` | Leave-screen test; `flutter test` disposes tree with no pending timers |
| Session controls | Timer lifecycle handled safely across pause/resume | Pause/resume test rows |
| Animated bounce | Delayed callbacks respect lifecycle (`mounted`, cancel previous) | Rapid-tap demo, no console errors |
| Mood tint and size | Color/scale derive from happiness with same thresholds as label | 29/30/70/71 screenshots |
| Smooth meters | `build()` reads state-derived values without side effects | Before/after screenshot |
| Reduced motion | Interaction usable with motion disabled | Demo with setting on and off |

## Manual test matrix

_Fill in with real observed values. Use a temporary 5-second hunger interval for timer tests, then restore 30 seconds before the release build._

| Scenario | Expected | Observed (before → after) | Pass? |
|---|---|---|---|
| Feed at hunger 5 | Hunger 0; happiness −20 (resulting hunger < 30) | | |
| Feed at hunger 95 | Hunger 85; happiness +10 | | |
| Play at happiness 95 | Happiness 100 (clamped) | | |
| Happiness 29 / 30 / 70 / 71 | Unhappy-red-small / Neutral-yellow / Neutral-yellow / Happy-green-large, text label always shown | | |
| > 80 for 2:59, then drops to 80 | No win; streak text clears | | |
| > 80 again for 3:00 | Win; hunger timer stops; actions disabled | | |
| Hunger 95 → 100, then another tick | First tick no penalty; second tick hunger stays 100, happiness −20 | | |
| Hunger 100 and happiness ≤ 10 | Game over; actions disabled until Restart | | |
| Leave screen / close app with timer running | No "setState() called after dispose()" in console | | |
| Pause during happy streak, resume | Timers stop while paused; streak restarts on resume | | |
| Reset during running streak | Win timer cancelled; exactly one hunger timer (hunger rises by 5 once per interval) | | |
| Reduced motion on vs. off | No bounce/glide/crossfade when on; labels and values unchanged | | |
| Release APK installed on device | Launches; Feed/Play/Pause/Reset work | | |

`flutter test` result: _paste output_

## Screenshots

_Add real screenshots: happy, neutral, unhappy, paused, win, game over, reduced motion._

## Workflow evidence

- Issues (one per core feature and advanced feature): _links_
- Care Systems PR: _link_ (self-reviewed against the test matrix before merge)
- Pet Personality PR: _link_ (self-reviewed against the test matrix before merge)

## Asset attribution

`assets/pet.png` — original artwork created for this project (no third-party license). Light/near-white so `BlendMode.modulate` shows the mood tint clearly. If the asset is missing, the app falls back to a tinted `Icons.pets` icon.

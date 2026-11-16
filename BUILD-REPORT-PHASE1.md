# 4-7-8 Breathing Timer — Build Report, Phase 1

**Date:** 16 Nov 2026 · **Project:** `~/workspace/breathing-timer-app`
**Display name:** 4-7-8 Breathing Timer · **Package id:** `com.breathe478.timer`
(verified in `android/app/build.gradle.kts` `applicationId` + `namespace`,
`MainActivity.kt` package, and iOS `PRODUCT_BUNDLE_IDENTIFIER`)
**Flutter 3.50.0 / Dart 3.14.0** · **Version:** 1.0.0+1

## What was built

A complete Flutter app, no login, no account, no server — all data on device
via SharedPreferences. Calm dark blue/teal Material 3 theme, large text,
one tap starts a session.

### Files created

| Area | Files |
|---|---|
| App entry + theme | `lib/main.dart` |
| Models | `lib/models/breathing_pattern.dart` — 8 patterns, custom validation, background sounds |
| Engine | `lib/services/breathing_engine.dart` — pure-Dart timer (inhale → hold → exhale, per cycle) + `BreathingSessionRunner` |
| Settings (versioned keys) | `lib/services/settings_service.dart` |
| Premium gating | `lib/services/premium_service.dart` |
| Streaks + stats | `lib/services/streak_service.dart` |
| Audio (mix, never exclusive) | `lib/services/audio_service.dart` |
| Voice + vibration cues | `lib/services/cue_service.dart` |
| Bedtime reminder | `lib/services/notification_service.dart` |
| Home-screen widget | `lib/services/widget_service.dart` + native `BreathingWidgetProvider.kt`, `res/layout/breathing_widget.xml`, `res/xml/breathing_widget_info.xml`, manifest receiver |
| UI | `lib/widgets/breathing_circle.dart`; `lib/screens/` — `home_screen.dart`, `session_screen.dart`, `session_end_screen.dart`, `settings_screen.dart`, `unlock_screen.dart` |
| Sounds (generated, offline) | `assets/sounds/rain.wav`, `ocean.wav`, `chime.wav` + generator `tools/generate_sounds.py` |
| Tests | `test/breathing_engine_test.dart`, `test/custom_pattern_test.dart`, `test/streak_test.dart`, `test/widget_test.dart` |

### 8 patterns (each with a 1-line plain explanation on Home)

1. **4-7-8 Relaxing** (hero, 4-7-8) · 2. **Box Breathing** (4-4-4-4) ·
3. **Equal Breathing** (4-4) · 4. **Calm Breathing** (4-6) ·
5. **Triangle Breathing** (4-4-4) · 6. **Coherent Breathing** (5-5) ·
7. **Energizing Breath** (fast 2-1-2) · 8. **Custom** (user timings, 1–30 s).

### Session screen

Animated breathing circle (grows / holds / shrinks) + big text cue
("Breathe In" / "Hold" / "Breathe Out") + countdown + cycle progress +
total elapsed. Cycles selectable (4 / 8 / 12); total duration shown on
Home before starting. Text + voice (TTS) + vibration fire together on
every phase change. No ads during a session.

### Premium gating map (enforced in UI with a locked state → Unlock screen)

| Feature | Free | Premium |
|---|---|---|
| Patterns 4-7-8, Box, Equal, Calm | ✅ | ✅ |
| Patterns Triangle, Coherent, Energizing, Custom | 🔒 | ✅ |
| Rain background sound | ✅ | ✅ |
| Ocean background sound | 🔒 | ✅ |
| Basic session (circle + cues) | ✅ | ✅ |
| Current streak display | ✅ | ✅ |
| Sleep mode (screen off) | 🔒 | ✅ |
| Home-screen widget | 🔒 | ✅ |
| Bedtime reminder | 🔒 | ✅ |
| Full streak history (per-day list) | 🔒 | ✅ |
| Ads removed (Phase 2, AdMob) | — | ✅ |

One flag only: `PremiumService.isPremium`, backed by the versioned key
`premium_unlocked_v1`. `restorePurchases()` is a stub for Phase 2
(`in_app_purchase`); it never clears the local flag. **No monthly
subscription anywhere** — Unlock screen says one-time **$3.99**, yours
forever, no hidden charges.

### Settings that never get wiped (the Prana Breath lesson)

All SharedPreferences keys are versioned (`*_v1`) with a `prefs_schema_version`
key. Nothing is ever deleted or renamed on upgrade; future migrations read
old keys first. An update can never erase settings or downgrade a paid user.

### Audio — your music is never paused

`AudioService.audioContext` is configured to **mix, never take exclusive
focus**: Android `AudioContextAndroid(audioFocus: gainTransientMayDuck)`
(other apps only duck briefly) and iOS `AVAudioSessionCategory.ambient`
with `mixWithOthers`. Verified by code inspection. Separate volume
sliders for voice cues, background sounds, and start/end sounds
(three sliders in Settings; cue volume is part of the voice path).

### Sounds

Generated offline with `tools/generate_sounds.py` (no downloads):
Rain = low-pass-filtered noise; Ocean = slow-modulated deep noise;
Chime = soft two-note bell for session start/end. All 30 s seamless
loops (crossfaded loop point), 22050 Hz mono 16-bit WAV, bundled as assets.

### Sleep mode

Premium. When on, the session deliberately holds **no wakelock**, so the
screen can turn off and the session continues on voice + vibration only.
Normal sessions enable `wakelock_plus` to keep the screen on.

### Widget

Native Android widget (`BreathingWidgetProvider`) + `home_widget` plugin.
One tap opens the app with `breathe478://start-session` and starts the
favourite pattern (4-7-8 by default; star any pattern on Home to change it).

### Streaks + stats (local only)

Current streak, best streak, total sessions, total minutes, per-day history.
Streak = consecutive calendar days with ≥1 completed session; same-day
sessions don't double-count; a missed day resets to 1.

### Bedtime reminder

`flutter_local_notifications` + `timezone`, daily at a user-chosen time,
timezone-aware (`flutter_timezone` local zone), rescheduled on change.

## Dependencies

`shared_preferences`, `audioplayers`, `flutter_tts`, `vibration`,
`flutter_local_notifications`, `timezone`, `flutter_timezone`,
`home_widget`, `wakelock_plus`, `provider`, `cupertino_icons`
(dev: `flutter_test`, `flutter_lints`). No ads / billing packages yet —
those arrive in Phase 2.

## How to run / test

```bash
source ~/.bashrc
cd ~/workspace/breathing-timer-app
flutter analyze        # 0 errors
flutter test           # 13 tests, all passing
flutter run            # on a device/emulator
```

**Do NOT run `flutter build apk` on this VM** — Java localhost TCP is
sandbox-blocked here, so local APK builds cannot work. APK building is a
Phase 2 / CI step (GitHub Actions). No keystore was created.

## Verification results (16 Nov 2026)

- `flutter analyze`: **0 errors**. 8 info-level notes only — the Flutter 3.50
  SDK flags `package:flutter/material.dart` imports as deprecated in favour
  of `material_ui`; those are SDK-generated infos, not errors, and the
  standard Material import is kept.
- `flutter test`: **13 tests, all passing** —
  engine sequencing (4-7-8 inhale 4 → hold 7 → exhale 8, 2 cycles, clean
  end; box 4 phases; progress), custom validation (accept valid; reject
  zero/negative/out-of-range), streaks (pure + stored: same-day no
  double-count, consecutive increment, missed-day reset, totals/history),
  widget smoke test (app pumps, Home renders all 8 patterns + streak).
- Package id verified: `com.breathe478.timer` in `build.gradle.kts`,
  `MainActivity.kt`, iOS bundle id. Display name verified in
  `AndroidManifest.xml` (`4-7-8 Breathing Timer`).
- Text search: no "monthly subscription" offer anywhere; no medical claims
  ("treats/cures anxiety/insomnia" — none present; copy says "helps you
  relax / fall asleep" only).

## Known limitations

- **APK not built** (see above) — needs CI/GitHub Actions; the native
  widget Kotlin and manifest entries are written but have not been
  compile-verified on-device (only `flutter analyze` for Dart).
- **Sleep mode vs Android Doze:** with no wakelock and no foreground
  service, Doze may delay TTS/vibration on some devices after long idle;
  Phase 2 should test on real devices and consider a foreground service
  if sessions get interrupted.
- **TTS availability:** voice cues need a system TTS engine; on devices
  without one (or without English voice data) voice cues silently skip —
  text + vibration cues always remain.
- **Vibration:** no-op on devices without a vibrator (checked at runtime).
- **Notifications:** if the user denies notification permission, the
  reminder silently does nothing; Settings explains enabling it in system
  settings. Exact-time delivery uses `inexactAllowWhileIdle` (battery
  friendly, may drift a few minutes).
- **Phase 2 still to do:** AdMob (banner home + interstitial after session
  end only, never during), Google Play one-time $3.99 purchase via
  `in_app_purchase` wired to `PremiumService.unlock()` /
  `restorePurchases()`, Play Store listing, real-device testing.

## v2 fix — session never started on a real device (reported 16 Nov 2026 ~22:15 PKT)

**Bug:** tapping a pattern opened the session screen, but the timer stayed
frozen at "0s of 76s" / circle on "4" (Breathe In). The user waited — nothing
advanced.

**Root cause:** `_SessionScreenState._start()` awaited a chain of
platform-channel calls (WakelockPlus.enable → TTS init → audioplayers
audio-context + background sound → chime → vibration) and only called
`_runner.start()` at the very end. On the user's phone one of those awaits
hung (never completed, never threw — most likely the TTS engine bind or the
audio-session setup), so the timer never started. `WakelockPlus.enable()` was
not even inside a try/catch.

**Fix (commits c6beea7e, 49dcac76, 9dab79ff):**
- The runner now starts FIRST, synchronously in `initState` — the countdown
  advances within 1s of the screen appearing, no matter what.
- Cue/audio setup moved to a fire-and-forget `_startCues()`; every step has
  a 2–5s timeout + try/catch, so a slow/missing TTS engine, audio session
  or vibrator can never stall or kill the session. Text cues always remain.
- Same timeout guards added inside `CueService` (TTS setLanguage/speak,
  vibration) and `AudioService` (setAudioContext, play, stop) — defence in
  depth, including moving `_ensureContext()` inside the try blocks.
- No behaviour change otherwise: same patterns, volumes, sleep mode,
  no-subscription / no-medical-claims rules all intact.

**Regression tests (`test/session_start_test.dart`, 2 new tests):**
- fake_async runner test: clock advances 3s after start, phase changes at
  the right second.
- Widget test: the session screen clock advances to "2s of 76s" and the
  phase flips to Hold at 4s even though every platform channel fails in
  the test env — this fails on the v1 code and passes on the fix.
- Full suite: 15/15 passing; `flutter analyze`: 0 errors.

---

## v3 fix (user feedback from real-phone testing, 16 Nov 2026 ~22:54 PKT)

**Issue 1 — session auto-started on tap.** The user wants a Start button:
tapping a pattern now opens the session screen in a READY state (pattern
name, phase timings as chips, cycles + total duration, chosen background
sound, big Start button). The countdown begins ONLY on Start. The widget
deep link (breathe478://start-session) lands on the same ready state.
The running screen is unchanged (End button kept). The ready layout is
wrapped in Center + SingleChildScrollView so it never overflows on short
screens.

**Issue 2 — background sound never played (screen said "Background: Rain",
no rain heard). TWO root causes, both silent:**
1. **Wrong asset path.** audioplayers resolves `AssetSource` through
   `AudioCache`, whose default prefix is `assets/` — the app passed
   `'assets/sounds/rain.wav'`, so it looked for the key
   `'assets/assets/sounds/rain.wav'`, which does not exist; `play()`
   threw and the catch swallowed it. Fixed: paths are now relative to
   the assets folder (`'sounds/rain.wav'`, `'sounds/ocean.wav'`,
   `'sounds/chime.wav'`).
2. **Invalid iOS audio context.** `AudioContextIOS(category: ambient,
   options: {mixWithOthers})` is rejected by audioplayers' own
   assertion — the `audioContext` getter threw in debug builds, so
   `_ensureContext()` failed before ANY sound could start. Fixed:
   `category: playback` + `mixWithOthers` (plays while the user's own
   music keeps playing). Android focus (`gainTransientMayDuck`) unchanged.
   The WAV files themselves were verified audible (rain peak 15122/32767,
   RMS 5911 — not silence).

**Robustness:** `AudioService.startBackground` now returns `bool` and
records `lastBackgroundError` / `backgroundStarted` instead of failing
silently; players are injectable for tests. No behaviour change otherwise:
same 8 patterns, separate volumes, sleep mode, no subscription, no
medical claims.

**Tests (21/21 passing; `flutter analyze`: 0 errors):**
- `test/audio_service_test.dart` (new, 5 tests, fake AudioPlayer):
  startBackground plays `AssetSource('sounds/rain.wav')` on loop at the
  background volume; none stops the loop; chime path; stop; the asset
  keys actually exist in the bundle. (These tests caught root cause 2 —
  the context assertion fired in the test env first.)
- `test/session_start_test.dart`: ready-state test (no countdown before
  Start, clock advances after Start even when platform setup fails) +
  Rain test (fake audio service: Start plays Rain at 0.5, End stops it).
- Test-env lesson: never construct a REAL AudioPlayer in a unit test —
  its `creatingCompleter` never completes without a platform, so any
  awaited call hangs the test ("did not complete"). Use fakes for both
  player slots. Also: the full `flutter test` run stalls between files
  on this VM (tester-process startup is extremely slow when the
  build/test_cache is stale — `rm -rf build/test_cache` fixes it);
  verify per file when the full run stalls.

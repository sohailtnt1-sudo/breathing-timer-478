# 4-7-8 Breathing Timer

Guided breathing for sleep and calm. Flutter, no login, no account, no
server — all data stays on the device.

- 8 patterns: 4-7-8 Relaxing (hero), Box, Equal, Calm, Triangle, Coherent,
  Energizing, Custom
- Animated circle + big text cues + voice (TTS) + vibration on every phase
- Separate volume sliders: voice cues, background sounds, start/end sounds
- Offline background sounds (Rain, Ocean) generated locally — see
  `tools/generate_sounds.py`
- Sleep mode, home-screen widget, bedtime reminder, streaks (Premium)
- One-time $3.99 unlock, no subscription (purchase wiring is Phase 2)

Package id: `com.breathe478.timer`

## Run / test

```bash
flutter analyze   # 0 errors
flutter test      # 13 tests
flutter run
```

Do NOT run `flutter build apk` on the dev VM (Java localhost TCP is
sandbox-blocked there) — APK builds belong in CI (GitHub Actions).

See `BUILD-REPORT-PHASE1.md` for the full Phase 1 report, premium gating
map, dependencies and known limitations.

import 'package:breathe478_timer/models/breathing_pattern.dart';
import 'package:breathe478_timer/screens/session_screen.dart';
import 'package:breathe478_timer/services/audio_service.dart';
import 'package:breathe478_timer/services/breathing_engine.dart';
import 'package:breathe478_timer/services/cue_service.dart';
import 'package:breathe478_timer/services/settings_service.dart';
import 'package:breathe478_timer/services/streak_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake audio service: records every call instead of touching a player.
class FakeAudioService extends AudioService {
  final List<String> calls = [];
  BackgroundSound? lastSound;
  double? lastVolume;
  double? lastChimeVolume;

  @override
  Future<bool> startBackground(BackgroundSound sound, double volume) async {
    calls.add('startBackground');
    lastSound = sound;
    lastVolume = volume;
    return true;
  }

  @override
  Future<void> stopBackground() async {
    calls.add('stopBackground');
  }

  @override
  Future<void> playChime(double volume) async {
    calls.add('playChime');
    lastChimeVolume = volume;
  }

  @override
  Future<void> dispose() async {}
}

/// Fake cue service: all cues are no-ops.
class FakeCueService extends CueService {
  @override
  Future<void> init() async {}

  @override
  Future<void> phaseCue(
    String label, {
    required bool voiceEnabled,
    required double voiceVolume,
    required bool vibrationEnabled,
  }) async {}

  @override
  Future<void> vibrate({bool long = false}) async {}

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<void> dispose() async {}
}

Future<(SettingsService, StreakService)> _loadServices() async {
  SharedPreferences.setMockInitialValues({});
  final settings = await SettingsService.load();
  return (settings, StreakService(settings.prefs));
}

Widget _pumpSession(
  SettingsService settings,
  StreakService streakService, {
  AudioService? audio,
  CueService? cues,
}) {
  return MaterialApp(
    home: ChangeNotifierProvider<SettingsService>.value(
      value: settings,
      child: SessionScreen(
        pattern: BreathingPattern.fourSevenEight,
        cycles: 4,
        streakService: streakService,
        audioService: audio,
        cueService: cues,
      ),
    ),
  );
}

void main() {
  group('session clock starts on Start tap', () {
    test('runner clock advances once started', () {
      fakeAsync((async) {
        var ticks = 0;
        var phases = 0;
        final runner = BreathingSessionRunner(
          pattern: BreathingPattern.fourSevenEight,
          cycles: 4,
          onPhase: (_, _) => phases++,
          onTick: () => ticks++,
          onComplete: () {},
        );
        runner.start();
        expect(runner.engine.elapsedSeconds, 0);
        async.elapse(const Duration(seconds: 3));
        expect(ticks, 3);
        expect(runner.engine.elapsedSeconds, 3);
        expect(phases, 1); // still in the 4s inhale
        async.elapse(const Duration(seconds: 1));
        expect(runner.engine.elapsedSeconds, 4);
        expect(phases, 2); // moved into the 7s hold
        runner.dispose();
      });
    });

    testWidgets('session screen waits in ready state and the clock advances '
        'only after Start, even when platform cue/audio setup fails', (
      WidgetTester tester,
    ) async {
      // REGRESSION (v1 bug, reported from a real phone 16 Nov 2026):
      // tapping a pattern opened the session screen but the timer stayed
      // at "0s of 76s" forever. The runner only started after wakelock /
      // TTS / audio setup finished, and one of those platform calls hung
      // on the device. v2 fixed that by starting the clock first; v3
      // keeps the same guarantee but gates the start on the Start
      // button (user feedback 16 Nov 2026: the session auto-started
      // on tap). In the test env every platform channel fails the same
      // way it hung on the phone, so this test fails on the old code
      // and passes on the fix.
      final (settings, streakService) = await _loadServices();

      await tester.pumpWidget(_pumpSession(settings, streakService));
      await tester.pump();

      // Ready state: no countdown yet, Start button shown.
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Ready when you are'), findsOneWidget);
      expect(find.textContaining('0s of 76s'), findsNothing);

      // Waiting does NOT start the session.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Start'), findsOneWidget);
      expect(find.textContaining('2s of 76s'), findsNothing);

      // Tapping Start begins the countdown.
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('2s of 76s'), findsOneWidget);
      // The circle countdown moved too: inhale was 4s, 2s have passed.
      expect(find.text('2'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('4s of 76s'), findsOneWidget);
      // 4s in: inhale ended, now holding.
      expect(find.text('Hold'), findsOneWidget);
    });
  });

  group('background sound plays on Start, stops on End', () {
    testWidgets('tapping Start plays Rain; tapping End stops it', (
      WidgetTester tester,
    ) async {
      final (settings, streakService) = await _loadServices();
      final audio = FakeAudioService();
      final cues = FakeCueService();

      await tester.pumpWidget(
        _pumpSession(settings, streakService, audio: audio, cues: cues),
      );
      await tester.pump();

      // Ready state: nothing has played yet.
      expect(find.text('Start'), findsOneWidget);
      expect(audio.calls, isEmpty);

      await tester.tap(find.text('Start'));
      await tester.pump();
      // In the test env the wakelock step inside _startCues hits its
      // 3s real-time timeout before the audio setup runs, so wait it
      // out in real time before checking the calls.
      await Future.delayed(const Duration(seconds: 4));
      await tester.pump();

      // The background loop started with the default sound (Rain) at
      // the default background volume (0.5).
      expect(audio.calls, contains('startBackground'));
      expect(audio.lastSound, BackgroundSound.rain);
      expect(audio.lastVolume, 0.5);

      // Ending the session stops the loop.
      await tester.tap(find.text('End'));
      await tester.pump();
      expect(audio.calls, contains('stopBackground'));
    });
  });
}

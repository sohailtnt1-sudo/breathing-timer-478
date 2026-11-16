import 'package:breathe478_timer/models/breathing_pattern.dart';
import 'package:breathe478_timer/screens/session_screen.dart';
import 'package:breathe478_timer/services/breathing_engine.dart';
import 'package:breathe478_timer/services/settings_service.dart';
import 'package:breathe478_timer/services/streak_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('session clock starts immediately', () {
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

    testWidgets(
        'session screen clock advances even when platform cue/audio '
        'setup fails', (WidgetTester tester) async {
      // REGRESSION (v1 bug, reported from a real phone 16 Nov 2026):
      // tapping a pattern opened the session screen but the timer stayed
      // at "0s of 76s" forever. The runner only started after wakelock /
      // TTS / audio setup finished, and one of those platform calls hung
      // on the device. In the test env every platform channel fails the
      // same way, so this test fails on the old code and passes on the fix.
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final streakService = StreakService(settings.prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsService>.value(
            value: settings,
            child: SessionScreen(
              pattern: BreathingPattern.fourSevenEight,
              cycles: 4,
              streakService: streakService,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('0s of 76s'), findsOneWidget);

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
}

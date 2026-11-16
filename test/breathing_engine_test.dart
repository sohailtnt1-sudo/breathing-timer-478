import 'package:breathe478_timer/models/breathing_pattern.dart';
import 'package:breathe478_timer/services/breathing_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('4-7-8 phase sequencing', () {
    test('inhale 4 -> hold 7 -> exhale 8, repeats per cycle, ends cleanly',
        () {
      final engine = BreathingEngine(
        pattern: BreathingPattern.fourSevenEight,
        totalCycles: 2,
      );

      expect(engine.currentPhase?.label, 'Breathe In');
      expect(engine.secondsRemaining, 4);
      expect(engine.currentCycle, 1);
      expect(engine.totalSeconds, 38); // (4+7+8) * 2
      expect(engine.isComplete, false);

      // 3 ticks inside inhale: still inhaling, no phase change.
      for (var i = 0; i < 3; i++) {
        expect(engine.tick(), isFalse);
      }
      expect(engine.currentPhase?.label, 'Breathe In');
      expect(engine.secondsRemaining, 1);

      // 4th tick: inhale ends -> hold starts.
      expect(engine.tick(), isTrue);
      expect(engine.currentPhase?.label, 'Hold');
      expect(engine.secondsRemaining, 7);

      // 7 ticks of hold -> exhale.
      for (var i = 0; i < 6; i++) {
        expect(engine.tick(), isFalse);
      }
      expect(engine.tick(), isTrue);
      expect(engine.currentPhase?.label, 'Breathe Out');
      expect(engine.secondsRemaining, 8);
      expect(engine.currentCycle, 1);

      // 8 ticks of exhale -> cycle 2 inhale.
      for (var i = 0; i < 7; i++) {
        expect(engine.tick(), isFalse);
      }
      expect(engine.tick(), isTrue);
      expect(engine.currentCycle, 2);
      expect(engine.currentPhase?.label, 'Breathe In');
      expect(engine.secondsRemaining, 4);

      // Finish cycle 2: 4 + 7 + 8 = 19 more ticks. The 4th tick ends
      // inhale, the 11th ends hold, the 19th completes the session.
      var changes = 0;
      for (var i = 0; i < 19; i++) {
        if (engine.tick()) changes++;
      }
      expect(changes, 3);
      expect(engine.isComplete, isTrue);
      expect(engine.currentPhase, isNull);
      expect(engine.elapsedSeconds, 38);

      // Ticking after completion is a no-op.
      expect(engine.tick(), isFalse);
      expect(engine.isComplete, isTrue);
    });

    test('box breathing has four phases and correct cycle length', () {
      final engine =
          BreathingEngine(pattern: BreathingPattern.box, totalCycles: 1);
      expect(engine.totalSeconds, 16);
      expect(engine.currentPhase?.label, 'Breathe In');
      // Walk the whole cycle and collect the phase labels in order.
      final labels = <String>[engine.currentPhase!.label];
      while (!engine.isComplete) {
        final changed = engine.tick();
        if (changed && !engine.isComplete) {
          labels.add(engine.currentPhase!.label);
        }
      }
      expect(labels, ['Breathe In', 'Hold', 'Breathe Out', 'Hold']);
    });

    test('progress and elapsed seconds track the session', () {
      final engine = BreathingEngine(
        pattern: BreathingPattern.fourSevenEight,
        totalCycles: 1,
      );
      expect(engine.progress, 0.0);
      for (var i = 0; i < 9; i++) {
        engine.tick();
      }
      expect(engine.elapsedSeconds, 9);
      expect(engine.progress, closeTo(9 / 19, 0.001));
    });
  });
}

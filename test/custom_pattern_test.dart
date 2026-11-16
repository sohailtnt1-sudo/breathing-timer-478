import 'package:breathe478_timer/models/breathing_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Custom pattern validation', () {
    test('accepts valid timings', () {
      expect(
        BreathingPattern.validateCustom(
            inhale: 4, hold: 7, exhale: 8, holdAfterExhale: 0),
        isEmpty,
      );
      expect(
        BreathingPattern.validateCustom(
            inhale: 1, hold: 0, exhale: 1, holdAfterExhale: 0),
        isEmpty,
      );
      expect(
        BreathingPattern.validateCustom(
            inhale: 30, hold: 30, exhale: 30, holdAfterExhale: 30),
        isEmpty,
      );
    });

    test('rejects zero or negative inhale / exhale', () {
      final errors = BreathingPattern.validateCustom(
          inhale: 0, hold: 0, exhale: 8, holdAfterExhale: 0);
      expect(errors, isNotEmpty);
      expect(
        BreathingPattern.validateCustom(
            inhale: -2, hold: 0, exhale: 8, holdAfterExhale: 0),
        isNotEmpty,
      );
      expect(
        BreathingPattern.validateCustom(
            inhale: 4, hold: 0, exhale: 0, holdAfterExhale: 0),
        isNotEmpty,
      );
    });

    test('rejects out-of-range timings', () {
      expect(
        BreathingPattern.validateCustom(
            inhale: 31, hold: 0, exhale: 8, holdAfterExhale: 0),
        isNotEmpty,
      );
      expect(
        BreathingPattern.validateCustom(
            inhale: 4, hold: 31, exhale: 8, holdAfterExhale: 0),
        isNotEmpty,
      );
      expect(
        BreathingPattern.validateCustom(
            inhale: 4, hold: 0, exhale: 8, holdAfterExhale: -1),
        isNotEmpty,
      );
    });

    test('custom pattern built from valid timings has the right phases',
        () {
      final pattern = BreathingPattern.custom(
          inhale: 4, hold: 7, exhale: 8, holdAfterExhale: 0);
      expect(pattern.id, 'custom');
      expect(pattern.isPremium, isTrue);
      expect(pattern.secondsPerCycle, 19);
      expect(
        pattern.activePhases.map((p) => p.label).toList(),
        ['Breathe In', 'Hold', 'Breathe Out'],
      );
    });
  });
}

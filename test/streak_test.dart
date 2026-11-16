import 'package:breathe478_timer/services/streak_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Streak counting (pure logic)', () {
    final monday = DateTime(2026, 11, 16);
    test('first session ever starts a streak of 1', () {
      expect(
        StreakService.nextStreak(
            lastSessionDay: null, currentStreak: 0, today: monday),
        1,
      );
    });

    test('same-day session does not double-count', () {
      expect(
        StreakService.nextStreak(
            lastSessionDay: monday, currentStreak: 3, today: monday),
        3,
      );
    });

    test('consecutive day increments the streak', () {
      expect(
        StreakService.nextStreak(
          lastSessionDay: monday,
          currentStreak: 3,
          today: monday.add(const Duration(days: 1)),
        ),
        4,
      );
    });

    test('a missed day resets the streak to 1', () {
      expect(
        StreakService.nextStreak(
          lastSessionDay: monday,
          currentStreak: 5,
          today: monday.add(const Duration(days: 2)),
        ),
        1,
      );
      expect(
        StreakService.nextStreak(
          lastSessionDay: monday,
          currentStreak: 5,
          today: monday.add(const Duration(days: 30)),
        ),
        1,
      );
    });
  });

  group('Streak counting (stored)', () {
    test('recordSession updates streak, best, totals and day history',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = StreakService(prefs);
      final day1 = DateTime(2026, 11, 16, 22, 30);
      final day2 = DateTime(2026, 11, 17, 7, 0);
      final day2Again = DateTime(2026, 11, 17, 22, 0);

      expect(await service.recordSession(minutes: 2, when: day1), 1);
      expect(service.currentStreak, 1);
      expect(service.bestStreak, 1);
      expect(service.totalSessions, 1);
      expect(service.totalMinutes, 2);

      expect(await service.recordSession(minutes: 3, when: day2), 2);
      expect(service.currentStreak, 2);
      expect(service.bestStreak, 2);

      // Same day again: streak stays 2, totals still grow.
      expect(await service.recordSession(minutes: 1, when: day2Again), 2);
      expect(service.totalSessions, 3);
      expect(service.totalMinutes, 6);
      expect(service.sessionDays.length, 2);

      // Missed day (skip to 19th): streak resets to 1, best stays 2.
      expect(
          await service.recordSession(
              minutes: 2, when: DateTime(2026, 11, 19)),
          1);
      expect(service.currentStreak, 1);
      expect(service.bestStreak, 2);
    });
  });
}

import 'package:shared_preferences/shared_preferences.dart';

import 'settings_service.dart';

/// Streaks and session stats, stored locally only.
///
/// A streak is consecutive calendar days with at least one completed
/// session. A second session on the same day does not double-count.
/// A missed day resets the streak to 1 on the next completed session.
/// All date comparisons use the calendar day (local time), never the clock.
class StreakService {
  StreakService(this._prefs);

  final SharedPreferences _prefs;

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Pure streak step: given the last session day and the current streak,
  /// returns the new streak after a session on [today].
  /// Returns nulls handled by callers; [lastSessionDay] may be null (first
  /// session ever -> streak becomes 1).
  static int nextStreak({
    required DateTime? lastSessionDay,
    required int currentStreak,
    required DateTime today,
  }) {
    final todayDay = _dayOf(today);
    if (lastSessionDay == null) return 1;
    final lastDay = _dayOf(lastSessionDay);
    final diff = todayDay.difference(lastDay).inDays;
    if (diff == 0) return currentStreak; // same day: no double count
    if (diff == 1) return currentStreak + 1; // consecutive day
    return 1; // missed a day (or clock moved back): reset
  }

  int get currentStreak => _prefs.getInt(SettingsService.kCurrentStreak) ?? 0;
  int get bestStreak => _prefs.getInt(SettingsService.kBestStreak) ?? 0;
  int get totalSessions => _prefs.getInt(SettingsService.kTotalSessions) ?? 0;
  int get totalMinutes => _prefs.getInt(SettingsService.kTotalMinutes) ?? 0;

  DateTime? get lastSessionDay {
    final raw = _prefs.getString(SettingsService.kLastSessionDate);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Days (YYYY-MM-DD) with at least one completed session, newest first.
  List<String> get sessionDays {
    final raw = _prefs.getStringList(SettingsService.kSessionDays) ?? [];
    final sorted = List<String>.of(raw)..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// Record a completed session of [minutes] minutes on [when] (default now).
  /// Returns the new current streak.
  Future<int> recordSession({required int minutes, DateTime? when}) async {
    final today = when ?? DateTime.now();
    final newStreak = nextStreak(
      lastSessionDay: lastSessionDay,
      currentStreak: currentStreak,
      today: today,
    );
    final best = newStreak > bestStreak ? newStreak : bestStreak;
    final days = sessionDays.toSet()..add(_dayKey(today));
    final dayList = days.toList()..sort((a, b) => b.compareTo(a));
    await _prefs.setInt(SettingsService.kCurrentStreak, newStreak);
    await _prefs.setInt(SettingsService.kBestStreak, best);
    await _prefs.setInt(SettingsService.kTotalSessions, totalSessions + 1);
    await _prefs.setInt(SettingsService.kTotalMinutes, totalMinutes + minutes);
    await _prefs.setString(
        SettingsService.kLastSessionDate, _dayKey(today));
    await _prefs.setStringList(SettingsService.kSessionDays, dayList);
    return newStreak;
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/breathing_pattern.dart';

/// App settings, stored locally with SharedPreferences.
///
/// KEY RULE (learned from Prana Breath): keys are VERSIONED and never
/// deleted or renamed on upgrade. [prefsSchemaVersion] is bumped only when
/// a migration is added; old keys keep working, and an update must never
/// erase settings or downgrade a paid user. Any future migration reads the
/// old keys first and writes the new ones — it never drops data.
class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  /// Current schema version of the stored keys.
  static const int prefsSchemaVersion = 1;

  // --- Key names (stable — do not rename) ---------------------------------
  static const String kSchemaVersion = 'prefs_schema_version';
  static const String kVoiceVolume = 'volume_voice_v1';
  static const String kCueVolume = 'volume_cues_v1';
  static const String kBackgroundVolume = 'volume_background_v1';
  static const String kStartEndVolume = 'volume_start_end_v1';
  static const String kVibrationEnabled = 'vibration_enabled_v1';
  static const String kVoiceCuesEnabled = 'voice_cues_enabled_v1';
  static const String kBackgroundSound = 'background_sound_v1';
  static const String kFavouritePattern = 'favourite_pattern_v1';
  static const String kDefaultCycles = 'default_cycles_v1';
  static const String kReminderEnabled = 'reminder_enabled_v1';
  static const String kReminderHour = 'reminder_hour_v1';
  static const String kReminderMinute = 'reminder_minute_v1';
  static const String kSleepMode = 'sleep_mode_v1';
  static const String kCustomInhale = 'custom_inhale_v1';
  static const String kCustomHold = 'custom_hold_v1';
  static const String kCustomExhale = 'custom_exhale_v1';
  static const String kCustomHoldAfter = 'custom_hold_after_v1';
  static const String kPremiumUnlocked = 'premium_unlocked_v1';
  static const String kLastSessionDate = 'streak_last_date_v1';
  static const String kCurrentStreak = 'streak_current_v1';
  static const String kBestStreak = 'streak_best_v1';
  static const String kTotalSessions = 'stats_total_sessions_v1';
  static const String kTotalMinutes = 'stats_total_minutes_v1';
  static const String kSessionDays = 'stats_session_days_v1';

  static Future<SettingsService> load() async {
    final prefs = await SharedPreferences.getInstance();
    final service = SettingsService(prefs);
    // Record the schema version; never wipe unknown/older keys.
    if (!prefs.containsKey(kSchemaVersion)) {
      await prefs.setInt(kSchemaVersion, prefsSchemaVersion);
    }
    return service;
  }

  // --- Volumes: three separate sliders, 0.0–1.0 ---------------------------
  /// Default background-sound volume. Lowered 0.5 -> 0.25 in v4 (Nov 2026):
  /// the user reported the v3 rain as too loud/irritating on his phone.
  /// The slider range is unchanged — the user can still raise it to 1.0.
  static const double kDefaultBackgroundVolume = 0.25;

  double get voiceVolume => _prefs.getDouble(kVoiceVolume) ?? 0.8;
  double get cueVolume => _prefs.getDouble(kCueVolume) ?? 0.8;
  double get backgroundVolume =>
      _prefs.getDouble(kBackgroundVolume) ?? kDefaultBackgroundVolume;
  double get startEndVolume => _prefs.getDouble(kStartEndVolume) ?? 0.8;

  Future<void> setVoiceVolume(double v) async {
    await _prefs.setDouble(kVoiceVolume, v.clamp(0.0, 1.0));
    notifyListeners();
  }

  Future<void> setCueVolume(double v) async {
    await _prefs.setDouble(kCueVolume, v.clamp(0.0, 1.0));
    notifyListeners();
  }

  Future<void> setBackgroundVolume(double v) async {
    await _prefs.setDouble(kBackgroundVolume, v.clamp(0.0, 1.0));
    notifyListeners();
  }

  Future<void> setStartEndVolume(double v) async {
    await _prefs.setDouble(kStartEndVolume, v.clamp(0.0, 1.0));
    notifyListeners();
  }

  // --- Toggles --------------------------------------------------------------
  bool get vibrationEnabled => _prefs.getBool(kVibrationEnabled) ?? true;
  bool get voiceCuesEnabled => _prefs.getBool(kVoiceCuesEnabled) ?? true;
  bool get sleepMode => _prefs.getBool(kSleepMode) ?? false;

  Future<void> setVibrationEnabled(bool v) async {
    await _prefs.setBool(kVibrationEnabled, v);
    notifyListeners();
  }

  Future<void> setVoiceCuesEnabled(bool v) async {
    await _prefs.setBool(kVoiceCuesEnabled, v);
    notifyListeners();
  }

  Future<void> setSleepMode(bool v) async {
    await _prefs.setBool(kSleepMode, v);
    notifyListeners();
  }

  // --- Background sound / favourite / cycles --------------------------------
  BackgroundSound get backgroundSound =>
      BackgroundSound.byId(_prefs.getString(kBackgroundSound) ?? 'rain');

  Future<void> setBackgroundSound(BackgroundSound s) async {
    await _prefs.setString(kBackgroundSound, s.id);
    notifyListeners();
  }

  String get favouritePatternId =>
      _prefs.getString(kFavouritePattern) ?? '478';

  Future<void> setFavouritePatternId(String id) async {
    await _prefs.setString(kFavouritePattern, id);
    notifyListeners();
  }

  int get defaultCycles => _prefs.getInt(kDefaultCycles) ?? 4;

  Future<void> setDefaultCycles(int cycles) async {
    await _prefs.setInt(kDefaultCycles, cycles.clamp(1, 20));
    notifyListeners();
  }

  // --- Bedtime reminder ------------------------------------------------------
  bool get reminderEnabled => _prefs.getBool(kReminderEnabled) ?? false;
  int get reminderHour => _prefs.getInt(kReminderHour) ?? 22;
  int get reminderMinute => _prefs.getInt(kReminderMinute) ?? 0;

  Future<void> setReminder({
    required bool enabled,
    int? hour,
    int? minute,
  }) async {
    await _prefs.setBool(kReminderEnabled, enabled);
    if (hour != null) await _prefs.setInt(kReminderHour, hour);
    if (minute != null) await _prefs.setInt(kReminderMinute, minute);
    notifyListeners();
  }

  // --- Custom pattern timings -------------------------------------------------
  int get customInhale => _prefs.getInt(kCustomInhale) ?? 4;
  int get customHold => _prefs.getInt(kCustomHold) ?? 4;
  int get customExhale => _prefs.getInt(kCustomExhale) ?? 6;
  int get customHoldAfter => _prefs.getInt(kCustomHoldAfter) ?? 0;

  Future<void> setCustomTimings({
    required int inhale,
    required int hold,
    required int exhale,
    required int holdAfterExhale,
  }) async {
    await _prefs.setInt(kCustomInhale, inhale);
    await _prefs.setInt(kCustomHold, hold);
    await _prefs.setInt(kCustomExhale, exhale);
    await _prefs.setInt(kCustomHoldAfter, holdAfterExhale);
    notifyListeners();
  }

  BreathingPattern get customPattern => BreathingPattern.custom(
        inhale: customInhale,
        hold: customHold,
        exhale: customExhale,
        holdAfterExhale: customHoldAfter,
      );

  SharedPreferences get prefs => _prefs;
}

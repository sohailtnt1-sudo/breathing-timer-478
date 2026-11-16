import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/breathing_pattern.dart';
import 'settings_service.dart';

/// Premium gating — Phase 1.
///
/// Phase 2 wires [restorePurchases] to `in_app_purchase` and adds AdMob.
/// Until then there is ONE flag, [isPremium], backed by the versioned
/// SharedPreferences key [SettingsService.kPremiumUnlocked]. The key is
/// never deleted or renamed, so an update can never downgrade a paid user.
///
/// There is NO monthly subscription anywhere in this app: the unlock is a
/// one-time $3.99 payment (Phase 2). The Unlock screen says exactly that.
///
/// GATING MAP
/// | Feature                              | Free | Premium |
/// |--------------------------------------|------|---------|
/// | Patterns 4-7-8, Box, Equal, Calm     |  yes |   yes   |
/// | Patterns Triangle, Coherent, Energ.  |  no  |   yes   |
/// | Custom pattern                       |  no  |   yes   |
/// | Rain background sound                |  yes |   yes   |
/// | Ocean background sound               |  no  |   yes   |
/// | Basic session (circle + cues)        |  yes |   yes   |
/// | Current streak display               |  yes |   yes   |
/// | Sleep mode (screen off)              |  no  |   yes   |
/// | Home-screen widget                   |  no  |   yes   |
/// | Bedtime reminder                     |  no  |   yes   |
/// | Full streak history (per-day list)   |  no  |   yes   |
/// | Ads removed (Phase 2, AdMob)         |  no  |   yes   |
class PremiumService extends ChangeNotifier {
  PremiumService(this._prefs);

  final SharedPreferences _prefs;

  /// The single source of truth for "has the user unlocked Premium".
  bool get isPremium => _prefs.getBool(SettingsService.kPremiumUnlocked) ?? false;

  /// Free patterns: the hero 4-7-8 plus Box, Equal and Calm.
  bool isPatternUnlocked(BreathingPattern pattern) =>
      isPremium || !pattern.isPremium;

  bool isSoundUnlocked(BackgroundSound sound) =>
      isPremium || !sound.isPremium;

  bool get sleepModeUnlocked => isPremium;
  bool get widgetUnlocked => isPremium;
  bool get reminderUnlocked => isPremium;
  bool get fullHistoryUnlocked => isPremium;

  /// Phase 2: sets the flag after a verified Google Play purchase.
  /// Phase 1: kept for the Unlock screen flow / local testing only.
  Future<void> unlock() async {
    await _prefs.setBool(SettingsService.kPremiumUnlocked, true);
    notifyListeners();
  }

  /// Phase 2 wires this to `in_app_purchase` (queryPastPurchases).
  /// Phase 1 stub: returns false — there is no store to restore from yet.
  /// It must NEVER clear the local flag: a failed restore keeps the
  /// current state instead of downgrading the user.
  Future<bool> restorePurchases() async {
    // TODO(phase-2): query Google Play purchases via in_app_purchase and
    // call unlock() only when a verified purchase is found.
    return isPremium;
  }
}

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/breathing_pattern.dart';

/// Audio playback for the app.
///
/// NEVER PAUSES THE USER'S MUSIC: the audio session is configured to
/// MIX with other audio (Android: `gainTransientMayDuck` focus so other
/// apps only duck briefly; iOS: `ambient` category + `mixWithOthers`).
/// We never request exclusive audio focus and never call anything that
/// stops another app's playback. Verified by code inspection — see
/// [audioContext] below.
class AudioService {
  /// [backgroundPlayer] / [chimePlayer] are injectable for tests; the
  /// app always uses the real players.
  AudioService({AudioPlayer? backgroundPlayer, AudioPlayer? chimePlayer}) {
    _backgroundPlayer = backgroundPlayer ?? AudioPlayer();
    _chimePlayer = chimePlayer ?? AudioPlayer();
  }

  late final AudioPlayer _backgroundPlayer;
  late final AudioPlayer _chimePlayer;

  bool _contextApplied = false;

  /// Last background-sound error, if starting the loop failed.
  /// Kept (instead of only a debugPrint) so a silent failure is
  /// observable — the v2 rain sound failed exactly this way and nobody
  /// could see why. Null after a successful start.
  String? lastBackgroundError;

  /// True once a background loop has started successfully.
  bool backgroundStarted = false;

  /// The shared audio context used by both players.
  static AudioContext get audioContext => AudioContext(
        android: AudioContextAndroid(
          // Duck (lower) other audio briefly instead of stopping it.
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          // playback + mixWithOthers: our sounds play while the user's
          // own music keeps playing.
          // (ambient + mixWithOthers is REJECTED by audioplayers' own
          // assertion — it throws in debug builds. v2 used ambient +
          // mixWithOthers, so _ensureContext() threw before any sound
          // could start; the error was swallowed and no audio ever
          // played. This is the second half of the v2 silent-sound bug.)
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      );

  Future<void> _ensureContext() async {
    if (_contextApplied) return;
    // Timeouts: a hung audio-session setup on some devices must never
    // block the session timer waiting on it.
    await _backgroundPlayer
        .setAudioContext(audioContext)
        .timeout(const Duration(seconds: 3));
    await _chimePlayer
        .setAudioContext(audioContext)
        .timeout(const Duration(seconds: 3));
    _contextApplied = true;
  }

  /// Start the chosen background sound on loop, at [volume] (0.0–1.0).
  /// [BackgroundSound.none] (or a null asset) stops any loop.
  /// Returns true when the loop actually started; on failure
  /// [lastBackgroundError] explains why instead of failing silently.
  Future<bool> startBackground(BackgroundSound sound, double volume) async {
    lastBackgroundError = null;
    backgroundStarted = false;
    try {
      await _ensureContext();
      final path = sound.assetPath;
      if (path == null) {
        await stopBackground();
        return true;
      }
      await _backgroundPlayer
          .setReleaseMode(ReleaseMode.loop)
          .timeout(const Duration(seconds: 3));
      await _backgroundPlayer
          .setVolume(volume.clamp(0.0, 1.0))
          .timeout(const Duration(seconds: 3));
      await _backgroundPlayer
          .play(AssetSource(path))
          .timeout(const Duration(seconds: 5));
      backgroundStarted = true;
      return true;
    } catch (e) {
      lastBackgroundError = e.toString();
      debugPrint('Background sound failed: $e');
      return false;
    }
  }

  Future<void> setBackgroundVolume(double volume) async {
    try {
      await _backgroundPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('Background volume failed: $e');
    }
  }

  Future<void> stopBackground() async {
    backgroundStarted = false;
    try {
      await _backgroundPlayer.stop().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Stop background failed: $e');
    }
  }

  /// Soft chime for session start / end, at [volume] (0.0–1.0).
  Future<void> playChime(double volume) async {
    try {
      await _ensureContext();
      await _chimePlayer
          .setVolume(volume.clamp(0.0, 1.0))
          .timeout(const Duration(seconds: 3));
      // Same prefix rule as the background sounds: the path is relative
      // to the assets folder ('sounds/chime.wav'), not 'assets/...'.
      await _chimePlayer
          .play(AssetSource('sounds/chime.wav'))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Chime failed: $e');
    }
  }

  Future<void> dispose() async {
    await _backgroundPlayer.dispose();
    await _chimePlayer.dispose();
  }
}

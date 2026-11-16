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
  AudioService() {
    _backgroundPlayer = AudioPlayer();
    _chimePlayer = AudioPlayer();
  }

  late final AudioPlayer _backgroundPlayer;
  late final AudioPlayer _chimePlayer;

  bool _contextApplied = false;

  /// The shared audio context used by both players.
  static AudioContext get audioContext => AudioContext(
        android: AudioContextAndroid(
          // Duck (lower) other audio briefly instead of stopping it.
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          // Ambient: mixes with the user's own music.
          category: AVAudioSessionCategory.ambient,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      );

  Future<void> _ensureContext() async {
    if (_contextApplied) return;
    await _backgroundPlayer.setAudioContext(audioContext);
    await _chimePlayer.setAudioContext(audioContext);
    _contextApplied = true;
  }

  /// Start the chosen background sound on loop, at [volume] (0.0–1.0).
  /// [BackgroundSound.none] (or a null asset) stops any loop.
  Future<void> startBackground(BackgroundSound sound, double volume) async {
    await _ensureContext();
    final path = sound.assetPath;
    if (path == null) {
      await stopBackground();
      return;
    }
    try {
      await _backgroundPlayer.setReleaseMode(ReleaseMode.loop);
      await _backgroundPlayer.setVolume(volume.clamp(0.0, 1.0));
      await _backgroundPlayer.play(AssetSource(path));
    } catch (e) {
      debugPrint('Background sound failed: $e');
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
    try {
      await _backgroundPlayer.stop();
    } catch (e) {
      debugPrint('Stop background failed: $e');
    }
  }

  /// Soft chime for session start / end, at [volume] (0.0–1.0).
  Future<void> playChime(double volume) async {
    await _ensureContext();
    try {
      await _chimePlayer.setVolume(volume.clamp(0.0, 1.0));
      await _chimePlayer.play(AssetSource('assets/sounds/chime.wav'));
    } catch (e) {
      debugPrint('Chime failed: $e');
    }
  }

  Future<void> dispose() async {
    await _backgroundPlayer.dispose();
    await _chimePlayer.dispose();
  }
}

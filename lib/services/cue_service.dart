import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

/// Text + voice + vibration cues, fired together on every phase change.
///
/// - Text: the Session screen shows the big phase label + countdown.
/// - Voice: flutter_tts speaks the phase label ("Breathe In", "Hold",
///   "Breathe Out") at the user's voice volume.
/// - Vibration: a short buzz on each phase change (if enabled and the
///   device has a vibrator). A longer buzz marks session start/end.
class CueService {
  CueService() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _ttsReady = false;

  Future<void> init() async {
    try {
      // Each platform call gets a timeout: on some devices the TTS
      // engine is missing or slow to bind, and a hung call must never
      // block the session timer waiting on it.
      await _tts.setLanguage('en-US').timeout(const Duration(seconds: 3));
      await _tts.setSpeechRate(0.55).timeout(const Duration(seconds: 3));
      await _tts.setPitch(1.0).timeout(const Duration(seconds: 3));
      _ttsReady = true;
    } catch (e) {
      debugPrint('TTS init failed (voice cues unavailable): $e');
      _ttsReady = false;
    }
  }

  /// Speak [text] at [volume] (0.0–1.0). No-op when voice cues are off
  /// or TTS is unavailable — the text cue on screen always remains.
  Future<void> speak(String text, {required double volume}) async {
    if (!_ttsReady) return;
    try {
      await _tts
          .setVolume(volume.clamp(0.0, 1.0))
          .timeout(const Duration(seconds: 2));
      await _tts.speak(text).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Short vibration on a phase change; [long] for start/end.
  Future<void> vibrate({bool long = false}) async {
    try {
      if (await Vibration.hasVibrator()
              .timeout(const Duration(seconds: 2)) !=
          true) {
        return;
      }
      await Vibration.vibrate(duration: long ? 400 : 120)
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Vibration failed: $e');
    }
  }

  /// Fire all three cues for a phase change (text is the caller's job).
  Future<void> phaseCue(
    String label, {
    required bool voiceEnabled,
    required double voiceVolume,
    required bool vibrationEnabled,
  }) async {
    if (voiceEnabled) {
      await speak(label, volume: voiceVolume);
    }
    if (vibrationEnabled) {
      await vibrate();
    }
  }

  Future<void> dispose() async {
    await stopSpeaking();
  }
}

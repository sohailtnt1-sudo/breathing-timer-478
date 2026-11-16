import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:breathe478_timer/models/breathing_pattern.dart';
import 'package:breathe478_timer/services/audio_service.dart';
import 'package:breathe478_timer/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal fake player (same pattern as audio_service_test.dart — never
/// construct a real AudioPlayer in a unit test, it hangs).
class _FakeAudioPlayer extends AudioPlayer {
  final List<Source> playedSources = [];
  final List<double> volumes = [];
  final List<ReleaseMode> releaseModes = [];

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    playedSources.add(source);
  }

  @override
  Future<void> setAudioContext(AudioContext ctx) async {}

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
  }

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    releaseModes.add(releaseMode);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

/// Parse the bundled rain.wav and return (rms, peak, seconds).
Future<(double, double, double)> _rainStats() async {
  final data = await rootBundle.load('assets/sounds/rain.wav');
  final bytes = data.buffer.asUint8List();
  // WAV header checks.
  expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
  final byteData = ByteData.sublistView(data);
  expect(byteData.getUint16(22, Endian.little), 1, reason: 'mono');
  expect(byteData.getUint32(24, Endian.little), 22050, reason: 'sample rate');
  expect(byteData.getUint16(34, Endian.little), 16, reason: '16-bit PCM');
  const headerSize = 44;
  final sampleCount = (bytes.length - headerSize) ~/ 2;
  var sumSq = 0.0;
  var peak = 0.0;
  var nonZero = 0;
  for (var i = 0; i < sampleCount; i++) {
    final s = byteData.getInt16(headerSize + i * 2, Endian.little) / 32768.0;
    sumSq += s * s;
    peak = math.max(peak, s.abs());
    if (s != 0) nonZero++;
  }
  final rms = math.sqrt(sumSq / sampleCount);
  expect(nonZero, greaterThan(sampleCount ~/ 2), reason: 'not silent');
  return (rms, peak, sampleCount / 22050.0);
}

void main() {
  group('v4 rain sound (user: "bht irritating he, loud b he")', () {
    testWidgets('rain.wav is a valid, soft, non-silent 30 s loop', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final (rms, peak, seconds) = await _rainStats();
      expect(seconds, closeTo(30.0, 0.01));

      // v3 measured RMS 0.1804 / peak 0.4615 with 51.5% of its energy
      // above 4 kHz (the hiss). v4 must be clearly softer and never clip.
      expect(rms, greaterThan(0.02), reason: 'audible, not silent');
      expect(rms, lessThan(0.10), reason: 'much softer than v3 (0.18)');
      expect(peak, lessThan(0.35), reason: 'headroom, never clipped');
    });

    testWidgets('default background volume is 0.25, user value still wins', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());

      SharedPreferences.setMockInitialValues({});
      final fresh = SettingsService(await SharedPreferences.getInstance());
      expect(
        fresh.backgroundVolume,
        SettingsService.kDefaultBackgroundVolume,
      );
      expect(fresh.backgroundVolume, 0.25);

      // A user who already raised the slider keeps their own value —
      // the new default must not override stored settings.
      SharedPreferences.setMockInitialValues({
        SettingsService.kBackgroundVolume: 0.7,
      });
      final stored = SettingsService(await SharedPreferences.getInstance());
      expect(stored.backgroundVolume, 0.7);

      // The other sliders are untouched.
      expect(fresh.voiceVolume, 0.8);
      expect(fresh.cueVolume, 0.8);
      expect(fresh.startEndVolume, 0.8);
    });

    testWidgets('audio service plays rain at the new default volume', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());

      final background = _FakeAudioPlayer();
      final audio = AudioService(
        backgroundPlayer: background,
        chimePlayer: _FakeAudioPlayer(),
      );

      final ok = await audio.startBackground(
        BackgroundSound.rain,
        settings.backgroundVolume,
      );
      expect(ok, isTrue);
      expect(audio.backgroundStarted, isTrue);
      expect(background.playedSources, hasLength(1));
      expect(
        (background.playedSources.single as AssetSource).path,
        'sounds/rain.wav',
      );
      expect(background.volumes, [0.25]);
      expect(background.releaseModes, [ReleaseMode.loop]);
    });
  });
}

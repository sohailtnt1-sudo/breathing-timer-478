import 'package:audioplayers/audioplayers.dart';
import 'package:breathe478_timer/models/breathing_pattern.dart';
import 'package:breathe478_timer/services/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake AudioPlayer: records every call instead of touching the platform.
class FakeAudioPlayer extends AudioPlayer {
  final List<Source> playedSources = [];
  final List<double> volumes = [];
  final List<ReleaseMode> releaseModes = [];
  int stopCalls = 0;
  int contextCalls = 0;
  int disposeCalls = 0;

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
  Future<void> setAudioContext(AudioContext ctx) async {
    contextCalls++;
  }

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
  }

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    releaseModes.add(releaseMode);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

void main() {
  group('AudioService background sound', () {
    testWidgets('startBackground plays the right asset on loop, at volume', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final background = FakeAudioPlayer();
      final chime = FakeAudioPlayer();
      final audio = AudioService(
        backgroundPlayer: background,
        chimePlayer: chime,
      );

      final ok = await audio.startBackground(BackgroundSound.rain, 0.5);
      expect(ok, isTrue);
      expect(audio.backgroundStarted, isTrue);
      expect(audio.lastBackgroundError, isNull);

      // REGRESSION (v2 bug, reported from a real phone 16 Nov 2026):
      // the screen said "Background: Rain" but no rain was heard.
      // audioplayers resolves AssetSource through AudioCache, whose
      // default prefix is 'assets/' — passing 'assets/sounds/rain.wav'
      // made it look for 'assets/assets/sounds/rain.wav', which does
      // not exist, so play() threw and the error was swallowed. The
      // path must be relative to the assets folder.
      expect(background.playedSources, hasLength(1));
      final source = background.playedSources.single;
      expect(source, isA<AssetSource>());
      expect((source as AssetSource).path, 'sounds/rain.wav');

      // Loop mode + the background-volume slider level.
      expect(background.releaseModes, [ReleaseMode.loop]);
      expect(background.volumes, [0.5]);
    });

    testWidgets('startBackground with none stops the loop', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final background = FakeAudioPlayer();
      final audio = AudioService(
        backgroundPlayer: background,
        chimePlayer: FakeAudioPlayer(),
      );

      final ok = await audio.startBackground(BackgroundSound.none, 0.5);
      expect(ok, isTrue);
      expect(background.playedSources, isEmpty);
      expect(background.stopCalls, 1);
      expect(audio.backgroundStarted, isFalse);
    });

    testWidgets('playChime plays the chime asset', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final chime = FakeAudioPlayer();
      final audio = AudioService(
        backgroundPlayer: FakeAudioPlayer(),
        chimePlayer: chime,
      );

      await audio.playChime(0.8);
      expect(chime.playedSources, hasLength(1));
      final source = chime.playedSources.single;
      expect(source, isA<AssetSource>());
      expect((source as AssetSource).path, 'sounds/chime.wav');
      expect(chime.volumes, [0.8]);
    });

    testWidgets('stopBackground stops the loop', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final background = FakeAudioPlayer();
      final audio = AudioService(
        backgroundPlayer: background,
        chimePlayer: FakeAudioPlayer(),
      );

      await audio.startBackground(BackgroundSound.ocean, 0.5);
      expect(audio.backgroundStarted, isTrue);
      await audio.stopBackground();
      expect(background.stopCalls, 1);
      expect(audio.backgroundStarted, isFalse);
    });

    testWidgets('the sound assets actually exist under the resolved keys', (
      tester,
    ) async {
      // The keys AudioCache resolves to must be real bundled assets.
      for (final path in [
        'assets/sounds/rain.wav',
        'assets/sounds/ocean.wav',
        'assets/sounds/chime.wav',
      ]) {
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(0), reason: path);
      }
    });
  });
}

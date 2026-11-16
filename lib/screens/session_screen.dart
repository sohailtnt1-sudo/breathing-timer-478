import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/breathing_pattern.dart';
import '../services/audio_service.dart';
import '../services/breathing_engine.dart';
import '../services/cue_service.dart';
import '../services/settings_service.dart';
import '../services/streak_service.dart';
import '../widgets/breathing_circle.dart';
import 'session_end_screen.dart';

/// Session screen: animated circle + big text cue + countdown + cycle
/// progress. No ads ever appear during a session.
///
/// The screen opens in a READY state: pattern, timings, cycles and the
/// chosen background sound are shown with a big Start button, and the
/// countdown begins ONLY when the user taps Start (v3, user feedback
/// 16 Nov 2026 — v2 auto-started on tap). The widget deep link
/// (breathe478://start-session) lands on the same ready state.
///
/// Sleep mode (Premium): the screen is allowed to turn off — the session
/// keeps going with voice cues + vibration only, and NO wakelock is held.
/// Normal sessions keep the screen on with a wakelock.
class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.pattern,
    required this.cycles,
    required this.streakService,
    this.audioService,
    this.cueService,
  });

  final BreathingPattern pattern;
  final int cycles;
  final StreakService streakService;

  /// Injectable for tests; the app always uses the real services.
  final AudioService? audioService;
  final CueService? cueService;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final AudioService _audio;
  late final CueService _cues;
  late final BreathingSessionRunner _runner;

  BreathPhase? _phase;
  int _remaining = 0;
  bool _finished = false;

  /// True once the user has tapped Start and the countdown is running.
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _audio = widget.audioService ?? AudioService();
    _cues = widget.cueService ?? CueService();
    _phase = widget.pattern.activePhases.first;
    _remaining = _phase!.seconds;
    _runner = BreathingSessionRunner(
      pattern: widget.pattern,
      cycles: widget.cycles,
      onPhase: _onPhase,
      onTick: () => setState(() {
        _remaining = _runner.engine.secondsRemaining;
      }),
      onComplete: _onComplete,
    );
    // Do NOT start here: the countdown begins only when the user taps
    // Start (see _onStart). The clock still starts first, before any
    // cue/audio setup, so a hung TTS/audio call can never freeze it
    // the way v1 froze at "0s".
  }

  /// User tapped Start: begin the countdown, then set up cues/audio
  /// best-effort (they can never block the timer).
  void _onStart() {
    if (_started) return;
    setState(() => _started = true);
    _runner.start();
    unawaited(_startCues());
  }

  /// Best-effort cue/audio setup. Every step is guarded SEPARATELY by a
  /// timeout and a try/catch: a slow or missing TTS engine, audio session,
  /// vibrator or wakelock must never stall or kill the session — the
  /// timer is already running and the text cue on screen always remains.
  ///
  /// v4: this used to be ONE try/catch around all steps, so a single
  /// failing step aborted the rest — when the wakelock call timed out,
  /// the background sound never started at all. Each step now fails
  /// independently and the chain continues.
  Future<void> _startCues() async {
    if (!mounted) return;
    final settings = context.read<SettingsService>();
    final sleepMode = settings.sleepMode;
    if (!sleepMode) {
      // Normal session: keep the screen on. Sleep mode: deliberately
      // no wakelock, so the screen can turn off.
      try {
        await WakelockPlus.enable().timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Wakelock failed (continuing without it): $e');
      }
    }
    try {
      await _cues.init().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Cue init failed (continuing without it): $e');
    }
    try {
      await _audio
          .startBackground(settings.backgroundSound, settings.backgroundVolume)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Background sound failed (continuing without it): $e');
    }
    try {
      await _audio
          .playChime(settings.startEndVolume)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Chime failed (continuing without it): $e');
    }
    if (settings.vibrationEnabled) {
      try {
        await _cues.vibrate(long: true).timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Vibration failed (continuing without it): $e');
      }
    }
  }

  Future<void> _onPhase(BreathPhase phase, int cycle) async {
    final settings = context.read<SettingsService>();
    setState(() {
      _phase = phase;
      _remaining = phase.seconds;
    });
    // Fire-and-forget: the runner never waits on this, and a slow or
    // stuck voice cue must never pile up behind the countdown.
    try {
      await _cues.phaseCue(
        phase.label,
        voiceEnabled: settings.voiceCuesEnabled,
        voiceVolume: settings.voiceVolume,
        vibrationEnabled: settings.vibrationEnabled,
      );
    } catch (e) {
      debugPrint('Phase cue failed: $e');
    }
  }

  Future<void> _onComplete() async {
    if (_finished) return;
    _finished = true;
    final settings = context.read<SettingsService>();
    await _audio.stopBackground();
    await _audio.playChime(settings.startEndVolume);
    if (settings.vibrationEnabled) await _cues.vibrate(long: true);
    final minutes = (widget.pattern.totalSeconds(widget.cycles) / 60).ceil();
    final streak = await widget.streakService.recordSession(minutes: minutes);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionEndScreen(
          patternName: widget.pattern.name,
          minutes: minutes,
          streak: streak,
          streakService: widget.streakService,
        ),
      ),
    );
  }

  Future<void> _endEarly() async {
    _runner.stop();
    await _audio.stopBackground();
    await _cues.stopSpeaking();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _runner.dispose();
    _audio.dispose();
    _cues.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = _runner.engine;
    final phase = _phase ?? widget.pattern.activePhases.first;
    final phaseProgress = phase.seconds == 0
        ? 0.0
        : 1.0 - (_remaining / phase.seconds);
    final settings = context.watch<SettingsService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pattern.name),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _endEarly,
            child: const Text('End', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        // Center + scroll: the ready state (circle + chips + Start) is
        // taller than the running state, and on short screens the
        // Column used to overflow by a few pixels. Centred when it fits,
        // scrollable when it doesn't.
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BreathingCircle(
                    phase: phase,
                    secondsRemaining: _remaining,
                    phaseProgress: _started
                        ? phaseProgress.clamp(0.0, 1.0)
                        : 0.0,
                  ),
                  const SizedBox(height: 40),
                  if (!_started) ...[
                    const Text(
                      'Ready when you are',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in widget.pattern.activePhases)
                          Chip(label: Text('${p.label} • ${p.seconds}s')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.cycles} cycles • '
                      '${widget.pattern.totalDurationLabel(widget.cycles)}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Background: ${settings.backgroundSound.name}'
                      '${settings.sleepMode ? ' • Sleep mode on — screen may turn off' : ''}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _onStart,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Start',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ] else ...[
                    LinearProgressIndicator(
                      value: engine.progress,
                      backgroundColor: Colors.white12,
                      color: Colors.tealAccent,
                      minHeight: 8,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cycle ${engine.currentCycle} of ${widget.cycles} • '
                      '${engine.elapsedSeconds}s of ${engine.totalSeconds}s',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Background: ${settings.backgroundSound.name}'
                      '${settings.sleepMode ? ' • Sleep mode on — screen may turn off' : ''}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

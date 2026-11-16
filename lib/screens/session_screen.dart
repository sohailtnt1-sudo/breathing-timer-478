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
/// Sleep mode (Premium): the screen is allowed to turn off — the session
/// keeps going with voice cues + vibration only, and NO wakelock is held.
/// Normal sessions keep the screen on with a wakelock.
class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.pattern,
    required this.cycles,
    required this.streakService,
  });

  final BreathingPattern pattern;
  final int cycles;
  final StreakService streakService;

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

  @override
  void initState() {
    super.initState();
    _audio = AudioService();
    _cues = CueService();
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
    _start();
  }

  Future<void> _start() async {
    final settings = context.read<SettingsService>();
    final sleepMode = settings.sleepMode;
    if (!sleepMode) {
      // Normal session: keep the screen on. Sleep mode: deliberately
      // no wakelock, so the screen can turn off.
      await WakelockPlus.enable();
    }
    await _cues.init();
    await _audio.startBackground(
        settings.backgroundSound, settings.backgroundVolume);
    await _audio.playChime(settings.startEndVolume);
    if (settings.vibrationEnabled) await _cues.vibrate(long: true);
    _runner.start();
  }

  Future<void> _onPhase(BreathPhase phase, int cycle) async {
    final settings = context.read<SettingsService>();
    setState(() {
      _phase = phase;
      _remaining = phase.seconds;
    });
    await _cues.phaseCue(
      phase.label,
      voiceEnabled: settings.voiceCuesEnabled,
      voiceVolume: settings.voiceVolume,
      vibrationEnabled: settings.vibrationEnabled,
    );
  }

  Future<void> _onComplete() async {
    if (_finished) return;
    _finished = true;
    final settings = context.read<SettingsService>();
    await _audio.stopBackground();
    await _audio.playChime(settings.startEndVolume);
    if (settings.vibrationEnabled) await _cues.vibrate(long: true);
    final minutes = (widget.pattern.totalSeconds(widget.cycles) / 60).ceil();
    final streak = await widget.streakService
        .recordSession(minutes: minutes);
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BreathingCircle(
                phase: phase,
                secondsRemaining: _remaining,
                phaseProgress: phaseProgress.clamp(0.0, 1.0),
              ),
              const SizedBox(height: 40),
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
                style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Background: ${settings.backgroundSound.name}'
                '${settings.sleepMode ? ' • Sleep mode on — screen may turn off' : ''}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

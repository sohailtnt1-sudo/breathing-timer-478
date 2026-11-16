import 'dart:async';

import '../models/breathing_pattern.dart';

/// Pure-Dart breathing timer engine.
///
/// The engine has no Flutter, audio or timer dependencies of its own:
/// [tick] advances exactly one second, so it is fully unit-testable.
/// A session runner wraps it with a [Timer.periodic] (see SessionScreen).
///
/// Sequence for a pattern: phases in order, then the next cycle, until
/// [totalCycles] cycles are done. When the last second of the last phase
/// elapses, [isComplete] becomes true and no further phase exists.
class BreathingEngine {
  BreathingEngine({required this.pattern, required this.totalCycles})
      : assert(totalCycles >= 1, 'Need at least 1 cycle'),
        _phases = pattern.activePhases {
    assert(_phases.isNotEmpty, 'Pattern needs at least one timed phase');
    _secondsRemaining = _phases.first.seconds;
  }

  final BreathingPattern pattern;
  final int totalCycles;
  final List<BreathPhase> _phases;

  int _phaseIndex = 0;
  int _cycle = 1;
  late int _secondsRemaining;
  bool _isComplete = false;

  /// Current phase (null once complete).
  BreathPhase? get currentPhase => _isComplete ? null : _phases[_phaseIndex];

  /// Seconds left in the current phase (counts down to 1, then advances).
  int get secondsRemaining => _secondsRemaining;

  /// Current cycle, 1-based.
  int get currentCycle => _cycle;

  bool get isComplete => _isComplete;

  /// Seconds elapsed since the session started.
  int get elapsedSeconds {
    if (_isComplete) return pattern.totalSeconds(totalCycles);
    var done = pattern.secondsPerCycle * (_cycle - 1);
    for (var i = 0; i < _phaseIndex; i++) {
      done += _phases[i].seconds;
    }
    done += _phases[_phaseIndex].seconds - _secondsRemaining;
    return done;
  }

  /// Total session length in seconds.
  int get totalSeconds => pattern.totalSeconds(totalCycles);

  /// 0.0–1.0 progress through the whole session.
  double get progress =>
      totalSeconds == 0 ? 1.0 : elapsedSeconds / totalSeconds;

  /// Advance one second.
  ///
  /// Returns true when the phase just changed (or the session completed),
  /// so the caller can fire text / voice / vibration cues exactly once
  /// per phase change.
  bool tick() {
    if (_isComplete) return false;
    _secondsRemaining--;
    if (_secondsRemaining > 0) return false;

    // Move to the next phase, or the next cycle, or finish.
    if (_phaseIndex + 1 < _phases.length) {
      _phaseIndex++;
      _secondsRemaining = _phases[_phaseIndex].seconds;
      return true;
    }
    if (_cycle < totalCycles) {
      _cycle++;
      _phaseIndex = 0;
      _secondsRemaining = _phases.first.seconds;
      return true;
    }
    _isComplete = true;
    _secondsRemaining = 0;
    return true;
  }
}

/// Runs a [BreathingEngine] on a one-second [Timer] and forwards events.
class BreathingSessionRunner {
  BreathingSessionRunner({
    required BreathingPattern pattern,
    required int cycles,
    required this.onPhase,
    required this.onTick,
    required this.onComplete,
  }) : engine = BreathingEngine(pattern: pattern, totalCycles: cycles);

  final BreathingEngine engine;
  final void Function(BreathPhase phase, int cycle) onPhase;
  final void Function() onTick;
  final void Function() onComplete;

  Timer? _timer;
  bool _running = false;

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    onPhase(engine.currentPhase!, engine.currentCycle);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final changed = engine.tick();
      onTick();
      if (engine.isComplete) {
        stop();
        onComplete();
      } else if (changed) {
        onPhase(engine.currentPhase!, engine.currentCycle);
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  void dispose() => stop();
}

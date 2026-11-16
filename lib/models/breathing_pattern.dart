/// Breathing patterns.
///
/// Every pattern is a list of [BreathPhase]s that repeat for one cycle.
/// Durations are whole seconds. Validation lives here so the UI, the
/// engine and the tests all agree on what a legal pattern is.
library;

/// One step of a breathing cycle, e.g. inhale for 4 seconds.
class BreathPhase {
  const BreathPhase(this.label, this.seconds, {this.isHold = false});

  /// Short cue shown on screen, e.g. "Breathe In".
  final String label;

  /// Duration in whole seconds. Must be >= 0; a 0-second phase is skipped.
  final int seconds;

  /// True for hold phases (no air moving in or out).
  final bool isHold;
}

/// A named breathing pattern with a plain one-line explanation of what it
/// is for and when to use it. No medical claims: patterns "help you relax"
/// or "help you fall asleep" — they never treat or cure anything.
class BreathingPattern {
  const BreathingPattern({
    required this.id,
    required this.name,
    required this.explanation,
    required this.phases,
    this.isPremium = false,
  });

  final String id;
  final String name;

  /// One plain line: what it is for and when to use it.
  final String explanation;

  /// Phases of one cycle, in order. Zero-second phases are skipped.
  final List<BreathPhase> phases;

  /// True when the pattern is part of the one-time Premium unlock.
  final bool isPremium;

  /// Phases with a duration > 0, in order.
  List<BreathPhase> get activePhases =>
      phases.where((p) => p.seconds > 0).toList();

  /// Seconds in one full cycle.
  int get secondsPerCycle =>
      activePhases.fold(0, (sum, p) => sum + p.seconds);

  /// Total seconds for [cycles] cycles.
  int totalSeconds(int cycles) => secondsPerCycle * cycles;

  /// Human-readable total duration, e.g. "2 min 38 sec".
  String totalDurationLabel(int cycles) {
    final total = totalSeconds(cycles);
    final m = total ~/ 60;
    final s = total % 60;
    if (m == 0) return '$s sec';
    if (s == 0) return '$m min';
    return '$m min $s sec';
  }

  // ---------------------------------------------------------------------------
  // Built-in patterns (launch set of 8 from the plan).
  // ---------------------------------------------------------------------------

  static const fourSevenEight = BreathingPattern(
    id: '478',
    name: '4-7-8 Relaxing',
    explanation:
        'Helps you relax and fall asleep — best at bedtime, 4 calm cycles.',
    phases: [
      BreathPhase('Breathe In', 4),
      BreathPhase('Hold', 7, isHold: true),
      BreathPhase('Breathe Out', 8),
    ],
  );

  static const box = BreathingPattern(
    id: 'box',
    name: 'Box Breathing',
    explanation:
        'Helps you focus and stay calm — good before work, study or a stressful moment.',
    phases: [
      BreathPhase('Breathe In', 4),
      BreathPhase('Hold', 4, isHold: true),
      BreathPhase('Breathe Out', 4),
      BreathPhase('Hold', 4, isHold: true),
    ],
  );

  static const equal = BreathingPattern(
    id: 'equal',
    name: 'Equal Breathing',
    explanation:
        'Simple and steady — a good daily calm routine, great for beginners.',
    phases: [
      BreathPhase('Breathe In', 4),
      BreathPhase('Breathe Out', 4),
    ],
  );

  static const calm = BreathingPattern(
    id: 'calm',
    name: 'Calm Breathing',
    explanation:
        'A longer exhale helps you unwind — use it when you feel tense.',
    phases: [
      BreathPhase('Breathe In', 4),
      BreathPhase('Breathe Out', 6),
    ],
  );

  static const triangle = BreathingPattern(
    id: 'triangle',
    name: 'Triangle Breathing',
    explanation:
        'A gentle three-step rhythm — a calm way to begin a quiet moment or meditation.',
    phases: [
      BreathPhase('Breathe In', 4),
      BreathPhase('Hold', 4, isHold: true),
      BreathPhase('Breathe Out', 4),
    ],
    isPremium: true,
  );

  static const coherent = BreathingPattern(
    id: 'coherent',
    name: 'Coherent Breathing',
    explanation:
        'Slow and even, about 6 breaths a minute — helps you feel steady and balanced.',
    phases: [
      BreathPhase('Breathe In', 5),
      BreathPhase('Breathe Out', 5),
    ],
    isPremium: true,
  );

  static const energizing = BreathingPattern(
    id: 'energizing',
    name: 'Energizing Breath',
    explanation:
        'A quicker rhythm to help you feel awake — best in the morning, not at bedtime.',
    phases: [
      BreathPhase('Breathe In', 2),
      BreathPhase('Hold', 1, isHold: true),
      BreathPhase('Breathe Out', 2),
    ],
    isPremium: true,
  );

  static const List<BreathingPattern> builtIns = [
    fourSevenEight,
    box,
    equal,
    calm,
    triangle,
    coherent,
    energizing,
  ];

  static BreathingPattern? byId(String id) {
    for (final p in builtIns) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Custom pattern validation.
  // ---------------------------------------------------------------------------

  /// Allowed range for any single phase, in seconds.
  static const int minPhaseSeconds = 1;
  static const int maxPhaseSeconds = 30;

  /// Validates custom timings. Returns a list of problems; empty = valid.
  /// Rules: inhale and exhale 1–30 s; holds 0–30 s (0 = skipped);
  /// total cycle 2–120 s.
  static List<String> validateCustom({
    required int inhale,
    required int hold,
    required int exhale,
    required int holdAfterExhale,
  }) {
    final errors = <String>[];
    if (inhale < minPhaseSeconds || inhale > maxPhaseSeconds) {
      errors.add('Inhale must be $minPhaseSeconds–$maxPhaseSeconds seconds.');
    }
    if (exhale < minPhaseSeconds || exhale > maxPhaseSeconds) {
      errors.add('Exhale must be $minPhaseSeconds–$maxPhaseSeconds seconds.');
    }
    if (hold < 0 || hold > maxPhaseSeconds) {
      errors.add('Hold must be 0–$maxPhaseSeconds seconds.');
    }
    if (holdAfterExhale < 0 || holdAfterExhale > maxPhaseSeconds) {
      errors.add('Hold after exhale must be 0–$maxPhaseSeconds seconds.');
    }
    final total = inhale + hold + exhale + holdAfterExhale;
    if (total < 2 || total > 120) {
      errors.add('One cycle must be 2–120 seconds in total.');
    }
    return errors;
  }

  /// Builds a custom pattern from validated timings.
  static BreathingPattern custom({
    required int inhale,
    required int hold,
    required int exhale,
    required int holdAfterExhale,
  }) {
    return BreathingPattern(
      id: 'custom',
      name: 'Custom Breathing',
      explanation:
          'Your own rhythm, your own timings — set it up once and breathe your way.',
      phases: [
        BreathPhase('Breathe In', inhale),
        BreathPhase('Hold', hold, isHold: true),
        BreathPhase('Breathe Out', exhale),
        BreathPhase('Hold', holdAfterExhale, isHold: true),
      ],
      isPremium: true,
    );
  }
}

/// Background sounds bundled with the app (offline, generated locally).
enum BackgroundSound {
  none('none', 'No sound', 'Just quiet — only the voice cues and vibration.'),
  rain('rain', 'Rain', 'Soft rain — helps you relax and fall asleep.'),
  ocean('ocean', 'Ocean', 'Slow ocean waves — a calm, steady background.');

  const BackgroundSound(this.id, this.name, this.explanation);

  final String id;
  final String name;
  final String explanation;

  /// Asset path for audioplayers' [AssetSource], or null for silence.
  ///
  /// audioplayers resolves asset sources through AudioCache, whose
  /// default prefix is 'assets/' — so the path must be RELATIVE to the
  /// assets folder ('sounds/rain.wav'), NOT 'assets/sounds/rain.wav'.
  /// Passing the full path made AudioCache look for the key
  /// 'assets/assets/sounds/rain.wav', which does not exist, so play()
  /// threw and the background sound was silently swallowed (v2 bug,
  /// reported from a real phone 16 Nov 2026: "Background: Rain" showed
  /// but no rain was heard).
  String? get assetPath => switch (id) {
        'rain' => 'sounds/rain.wav',
        'ocean' => 'sounds/ocean.wav',
        _ => null,
      };

  /// True when the sound needs the one-time Premium unlock.
  bool get isPremium => id == 'ocean';

  static BackgroundSound byId(String id) =>
      BackgroundSound.values.firstWhere((s) => s.id == id,
          orElse: () => BackgroundSound.none);
}

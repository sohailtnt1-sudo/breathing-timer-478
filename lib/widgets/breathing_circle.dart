import 'package:flutter/material.dart';

import '../models/breathing_pattern.dart';

/// The animated breathing circle.
///
/// Grows while breathing in, stays still while holding, shrinks while
/// breathing out. The [phaseProgress] (0.0–1.0 through the current phase)
/// drives the size so the circle always matches the countdown.
class BreathingCircle extends StatelessWidget {
  const BreathingCircle({
    super.key,
    required this.phase,
    required this.secondsRemaining,
    required this.phaseProgress,
  });

  final BreathPhase phase;
  final int secondsRemaining;
  final double phaseProgress;

  double get _scale {
    if (phase.isHold) return 0.85;
    if (phase.label == 'Breathe In') return 0.55 + 0.45 * phaseProgress;
    // Breathe Out (or any other phase): shrink.
    return 1.0 - 0.45 * phaseProgress;
  }

  Color get _color {
    if (phase.isHold) return Colors.amber.shade300;
    if (phase.label == 'Breathe In') return Colors.tealAccent.shade400;
    return Colors.lightBlueAccent.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 950),
          curve: Curves.easeInOut,
          width: 260 * _scale,
          height: 260 * _scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color.withValues(alpha: 0.25),
            border: Border.all(color: _color, width: 3),
            boxShadow: [
              BoxShadow(
                color: _color.withValues(alpha: 0.35),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$secondsRemaining',
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w300,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          phase.label,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

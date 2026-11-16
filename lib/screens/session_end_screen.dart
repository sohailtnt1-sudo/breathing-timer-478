import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/premium_service.dart';
import '../services/streak_service.dart';

/// Session end: "Well done" + time + streak.
/// Free users see the current streak; the full day-by-day history is
/// Premium (locked list below).
class SessionEndScreen extends StatelessWidget {
  const SessionEndScreen({
    super.key,
    required this.patternName,
    required this.minutes,
    required this.streak,
    required this.streakService,
  });

  final String patternName;
  final int minutes;
  final int streak;
  final StreakService streakService;

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumService>();
    final days = streakService.sessionDays;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle,
                  color: Colors.tealAccent, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Well done!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'You finished $patternName — $minutes min of calm breathing.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, color: Colors.grey.shade300),
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.teal.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat('$streak', 'day streak'),
                      _Stat('${streakService.totalSessions}', 'sessions'),
                      _Stat('${streakService.totalMinutes}', 'min total'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (premium.fullHistoryUnlocked) ...[
                const Text('Your practice days',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    itemCount: days.length,
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.calendar_today, size: 18),
                      title: Text(days[i]),
                    ),
                  ),
                ),
              ] else
                const Text(
                  'Full day-by-day history is part of Premium.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.amber),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey.shade300)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/breathing_pattern.dart';
import '../services/premium_service.dart';
import '../services/settings_service.dart';
import '../services/streak_service.dart';
import 'session_screen.dart';
import 'settings_screen.dart';
import 'unlock_screen.dart';

/// Home: the pattern list. One tap opens a session screen; the
/// countdown starts only when the user taps Start there.
///
/// Free: 4-7-8, Box, Equal, Calm + Rain sound + current streak.
/// Locked (Premium): Triangle, Coherent, Energizing, Custom — tapping a
/// locked pattern opens the Unlock screen instead of a session.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.streakService});

  final StreakService streakService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _cycles = 4;

  @override
  void initState() {
    super.initState();
    _cycles = context.read<SettingsService>().defaultCycles;
  }

  void _startSession(BreathingPattern pattern) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          pattern: pattern,
          cycles: _cycles,
          streakService: widget.streakService,
        ),
      ),
    );
  }

  void _openUnlock() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UnlockScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final premium = context.watch<PremiumService>();
    final patterns = [
      ...BreathingPattern.builtIns,
      settings.customPattern,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('4-7-8 Breathing Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SettingsScreen(streakService: widget.streakService),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StreakCard(streakService: widget.streakService),
          const SizedBox(height: 16),
          const Text(
            'Choose a pattern — tap to open',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...patterns.map((pattern) {
            final unlocked = premium.isPatternUnlocked(pattern);
            final isFavourite =
                settings.favouritePatternId == pattern.id;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: unlocked
                      ? Colors.teal.shade700
                      : Colors.grey.shade700,
                  child: Icon(
                    unlocked ? Icons.air : Icons.lock,
                    color: Colors.white,
                  ),
                ),
                title: Text(pattern.name),
                subtitle: Text(pattern.explanation),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!unlocked)
                      const Text('Premium',
                          style: TextStyle(color: Colors.amber)),
                    IconButton(
                      icon: Icon(
                        isFavourite ? Icons.star : Icons.star_border,
                        color: isFavourite ? Colors.amber : null,
                      ),
                      tooltip: 'Set as favourite (widget starts this one)',
                      onPressed: () =>
                          settings.setFavouritePatternId(pattern.id),
                    ),
                  ],
                ),
                onTap: () =>
                    unlocked ? _startSession(pattern) : _openUnlock(),
              ),
            );
          }),
          const SizedBox(height: 16),
          const Text(
            'Cycles per session',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 4, label: Text('4 cycles')),
              ButtonSegment(value: 8, label: Text('8 cycles')),
              ButtonSegment(value: 12, label: Text('12 cycles')),
            ],
            selected: {_cycles},
            onSelectionChanged: (selection) {
              setState(() => _cycles = selection.first);
              settings.setDefaultCycles(selection.first);
            },
          ),
          const SizedBox(height: 12),
          Text(
            'A session of 4 cycles of 4-7-8 takes about '
            '${BreathingPattern.fourSevenEight.totalDurationLabel(_cycles)}.',
            style: TextStyle(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          if (!premium.isPremium)
            FilledButton.tonal(
              onPressed: _openUnlock,
              child: const Text(
                  'Unlock everything — one-time \$3.99, no subscription'),
            ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streakService});

  final StreakService streakService;

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumService>();
    return Card(
      color: Colors.teal.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department,
                color: Colors.orange, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${streakService.currentStreak}-day streak',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Best: ${streakService.bestStreak} days • '
                    '${streakService.totalSessions} sessions • '
                    '${streakService.totalMinutes} min total',
                    style: TextStyle(color: Colors.grey.shade300),
                  ),
                  if (!premium.fullHistoryUnlocked)
                    const Text(
                      'Full day-by-day history is part of Premium.',
                      style: TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

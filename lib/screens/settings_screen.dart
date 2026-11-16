import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/breathing_pattern.dart';
import '../services/notification_service.dart';
import '../services/premium_service.dart';
import '../services/settings_service.dart';
import '../services/streak_service.dart';
import 'unlock_screen.dart';

/// Settings: separate volume sliders, vibration, voice cues, background
/// sound, default cycles, sleep mode, bedtime reminder, custom timings,
/// restore purchase.
///
/// Locked Premium items show a lock and open the Unlock screen — they are
/// never silently hidden, so users always know what exists.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.streakService});

  final StreakService streakService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _inhale;
  late int _hold;
  late int _exhale;
  late int _holdAfter;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsService>();
    _inhale = s.customInhale;
    _hold = s.customHold;
    _exhale = s.customExhale;
    _holdAfter = s.customHoldAfter;
  }

  void _openUnlock() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UnlockScreen()),
    );
  }

  Widget _volumeSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Slider(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _lockedTile({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          trailing,
          const SizedBox(width: 8),
          const Icon(Icons.lock, color: Colors.amber),
        ],
      ),
      onTap: _openUnlock,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final premium = context.watch<PremiumService>();
    final notifications = context.read<NotificationService>();
    final errors = BreathingPattern.validateCustom(
      inhale: _inhale,
      hold: _hold,
      exhale: _exhale,
      holdAfterExhale: _holdAfter,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Volumes — each one separate',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          _volumeSlider(
            label: 'Voice cues',
            value: settings.voiceVolume,
            onChanged: settings.setVoiceVolume,
          ),
          _volumeSlider(
            label: 'Background sounds',
            value: settings.backgroundVolume,
            onChanged: settings.setBackgroundVolume,
          ),
          _volumeSlider(
            label: 'Start / end sounds',
            value: settings.startEndVolume,
            onChanged: settings.setStartEndVolume,
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Voice cues'),
            subtitle: const Text('Hear "Breathe In", "Hold", "Breathe Out"'),
            value: settings.voiceCuesEnabled,
            onChanged: settings.setVoiceCuesEnabled,
          ),
          SwitchListTile(
            title: const Text('Vibration'),
            subtitle: const Text('A gentle buzz on every phase change'),
            value: settings.vibrationEnabled,
            onChanged: settings.setVibrationEnabled,
          ),
          const Divider(),
          const Text('Background sound',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ...BackgroundSound.values.map((sound) {
            final unlocked = premium.isSoundUnlocked(sound);
            return RadioGroup<BackgroundSound>(
              groupValue: settings.backgroundSound,
              onChanged: (s) {
                if (s == null) return;
                if (premium.isSoundUnlocked(s)) {
                  settings.setBackgroundSound(s);
                } else {
                  _openUnlock();
                }
              },
              child: ListTile(
                title: Text(sound.name),
                subtitle: Text(sound.explanation),
                leading: Radio<BackgroundSound>(value: sound),
                trailing: unlocked
                    ? null
                    : const Icon(Icons.lock, color: Colors.amber),
                onTap: unlocked
                    ? () => settings.setBackgroundSound(sound)
                    : _openUnlock,
              ),
            );
          }),
          const Divider(),
          const Text('Default cycles per session',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 4, label: Text('4')),
              ButtonSegment(value: 8, label: Text('8')),
              ButtonSegment(value: 12, label: Text('12')),
            ],
            selected: {settings.defaultCycles},
            onSelectionChanged: (s) => settings.setDefaultCycles(s.first),
          ),
          const Divider(),
          if (premium.sleepModeUnlocked)
            SwitchListTile(
              title: const Text('Sleep mode'),
              subtitle: const Text(
                  'Session continues with the screen off, guided by voice and vibration only'),
              value: settings.sleepMode,
              onChanged: settings.setSleepMode,
            )
          else
            _lockedTile(
              title: 'Sleep mode',
              subtitle:
                  'Session continues with the screen off — Premium feature',
              trailing: const Text('Premium',
                  style: TextStyle(color: Colors.amber)),
            ),
          if (premium.reminderUnlocked)
            SwitchListTile(
              title: const Text('Bedtime reminder'),
              subtitle: Text(
                  'Daily reminder at ${settings.reminderHour.toString().padLeft(2, '0')}:${settings.reminderMinute.toString().padLeft(2, '0')}'),
              value: settings.reminderEnabled,
              onChanged: (enabled) async {
                await settings.setReminder(enabled: enabled);
                if (enabled) {
                  await notifications.scheduleDailyReminder(
                    hour: settings.reminderHour,
                    minute: settings.reminderMinute,
                  );
                } else {
                  await notifications.cancelReminder();
                }
              },
            )
          else
            _lockedTile(
              title: 'Bedtime reminder',
              subtitle: 'A daily reminder at your chosen time — Premium feature',
              trailing: const Text('Premium',
                  style: TextStyle(color: Colors.amber)),
            ),
          if (premium.reminderUnlocked && settings.reminderEnabled)
            ListTile(
              title: const Text('Reminder time'),
              trailing: Text(
                '${settings.reminderHour.toString().padLeft(2, '0')}:${settings.reminderMinute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 18),
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                      hour: settings.reminderHour,
                      minute: settings.reminderMinute),
                );
                if (picked != null) {
                  await settings.setReminder(
                      enabled: true, hour: picked.hour, minute: picked.minute);
                  await notifications.scheduleDailyReminder(
                      hour: picked.hour, minute: picked.minute);
                }
              },
            ),
          const Divider(),
          const Text('Custom pattern (Premium)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Text(
            'Set your own timings. Inhale and exhale are 1–30 seconds; holds are 0–30 seconds.',
            style: TextStyle(color: Colors.grey),
          ),
          _timingSlider('Inhale', _inhale, premium.isPremium,
              (v) => setState(() => _inhale = v.round())),
          _timingSlider('Hold', _hold, premium.isPremium,
              (v) => setState(() => _hold = v.round())),
          _timingSlider('Exhale', _exhale, premium.isPremium,
              (v) => setState(() => _exhale = v.round())),
          _timingSlider('Hold after exhale', _holdAfter, premium.isPremium,
              (v) => setState(() => _holdAfter = v.round())),
          if (errors.isNotEmpty)
            ...errors.map((e) => Text(e,
                style: const TextStyle(color: Colors.redAccent))),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: !premium.isPremium
                ? _openUnlock
                : errors.isEmpty
                    ? () async {
                        await settings.setCustomTimings(
                          inhale: _inhale,
                          hold: _hold,
                          exhale: _exhale,
                          holdAfterExhale: _holdAfter,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Custom pattern saved')),
                          );
                        }
                      }
                    : null,
            child: Text(premium.isPremium
                ? 'Save custom pattern'
                : 'Custom pattern — Premium'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Restore purchase'),
            subtitle: const Text(
                'Already paid? Restore your one-time unlock here.'),
            trailing: const Icon(Icons.restore),
            onTap: () async {
              final restored = await premium.restorePurchases();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(restored
                        ? 'Premium restored. Thank you!'
                        : 'No purchase found yet. In-app purchase arrives in Phase 2.'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Your data stays on your phone. No login, no account, no server.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _timingSlider(
    String label,
    int value,
    bool enabled,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value sec',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 30,
          divisions: 30,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

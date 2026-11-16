import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Bedtime reminder: one daily local notification at the user's chosen
/// time, scheduled timezone-aware so it fires at the right local time
/// even after travel or a daylight-saving change.
///
/// Local only — no server, no account. If notifications are denied by
/// the OS, scheduling silently does nothing and the Settings screen
/// explains that the user can enable them in system settings.
class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const int _reminderId = 478;

  Future<void> init() async {
    try {
      tz.initializeTimeZones();
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName.identifier));
    } catch (e) {
      debugPrint('Timezone init failed, using UTC: $e');
      tz.setLocalLocation(tz.UTC);
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings =
        InitializationSettings(android: android, iOS: ios);
    try {
      await _plugin.initialize(settings: settings);
      _ready = true;
    } catch (e) {
      debugPrint('Notifications init failed: $e');
    }
  }

  /// Schedule (or reschedule) the daily bedtime reminder.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (!_ready) return;
    try {
      final now = tz.TZDateTime.now(tz.local);
      var when = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, hour, minute);
      if (when.isBefore(now)) when = when.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: _reminderId,
        title: 'Time to breathe',
        body:
            'A few calm breaths before bed can help you relax and fall asleep.',
        scheduledDate: when,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'bedtime_reminder',
            'Bedtime reminder',
            channelDescription: 'Daily reminder to do a breathing session',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Schedule reminder failed: $e');
    }
  }

  Future<void> cancelReminder() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _reminderId);
    } catch (e) {
      debugPrint('Cancel reminder failed: $e');
    }
  }
}

import 'package:breathe478_timer/main.dart';
import 'package:breathe478_timer/services/notification_service.dart';
import 'package:breathe478_timer/services/premium_service.dart';
import 'package:breathe478_timer/services/settings_service.dart';
import 'package:breathe478_timer/services/streak_service.dart';
import 'package:breathe478_timer/services/widget_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app pumps and Home renders the pattern list',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    final premium = PremiumService(settings.prefs);
    final streakService = StreakService(settings.prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<PremiumService>.value(value: premium),
          Provider<NotificationService>.value(
              value: NotificationService()),
          Provider<WidgetService>.value(value: WidgetService()),
        ],
        child: BreathingTimerApp(
          streakService: streakService,
          startFavouriteFromWidget: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4-7-8 Breathing Timer'), findsWidgets);
    expect(find.text('4-7-8 Relaxing'), findsOneWidget);
    expect(find.text('Box Breathing'), findsOneWidget);
    expect(find.text('Equal Breathing'), findsOneWidget);
    expect(find.text('Calm Breathing'), findsOneWidget);
    expect(find.textContaining('day streak'), findsOneWidget);
    // The rest of the list is below the fold in the test viewport.
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Triangle Breathing'), findsOneWidget);
    expect(find.text('Coherent Breathing'), findsOneWidget);
    expect(find.text('Energizing Breath'), findsOneWidget);
    expect(find.text('Custom Breathing'), findsOneWidget);
    // Locked premium patterns show a lock.
    expect(find.byIcon(Icons.lock), findsWidgets);
  });
}

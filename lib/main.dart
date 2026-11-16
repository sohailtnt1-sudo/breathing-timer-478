import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/breathing_pattern.dart';
import 'screens/home_screen.dart';
import 'screens/session_screen.dart';
import 'services/notification_service.dart';
import 'services/premium_service.dart';
import 'services/settings_service.dart';
import 'services/streak_service.dart';
import 'services/widget_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = await SettingsService.load();
  final premium = PremiumService(settings.prefs);
  final streakService = StreakService(settings.prefs);
  final notifications = NotificationService();
  await notifications.init();
  final widgetService = WidgetService();
  await widgetService.init();

  // If the app was launched from the home-screen widget, start the
  // favourite session once the first frame is ready.
  final launchedFromWidget = await widgetService.initiallyLaunchedFromWidget;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<PremiumService>.value(value: premium),
        Provider<NotificationService>.value(value: notifications),
        Provider<WidgetService>.value(value: widgetService),
      ],
      child: BreathingTimerApp(
        streakService: streakService,
        startFavouriteFromWidget: launchedFromWidget != null,
      ),
    ),
  );
}

class BreathingTimerApp extends StatefulWidget {
  const BreathingTimerApp({
    super.key,
    required this.streakService,
    required this.startFavouriteFromWidget,
  });

  final StreakService streakService;
  final bool startFavouriteFromWidget;

  @override
  State<BreathingTimerApp> createState() => _BreathingTimerAppState();
}

class _BreathingTimerAppState extends State<BreathingTimerApp> {
  bool _widgetSessionStarted = false;

  @override
  void initState() {
    super.initState();
    // Widget taps while the app is already running.
    context.read<WidgetService>().widgetClicked.listen((uri) {
      if (uri != null && uri.toString() == WidgetService.startSessionUri) {
        _startFavouriteSession();
      }
    });
    if (widget.startFavouriteFromWidget) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startFavouriteSession();
      });
    }
  }

  void _startFavouriteSession() {
    if (_widgetSessionStarted) return;
    _widgetSessionStarted = true;
    final settings = context.read<SettingsService>();
    final premium = context.read<PremiumService>();
    final pattern = BreathingPattern.byId(settings.favouritePatternId) ??
        BreathingPattern.fourSevenEight;
    if (!premium.isPatternUnlocked(pattern)) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          pattern: pattern,
          cycles: settings.defaultCycles,
          streakService: widget.streakService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '4-7-8 Breathing Timer',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B1D2A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B1D2A),
          foregroundColor: Colors.white,
        ),
      ),
      home: HomeScreen(streakService: widget.streakService),
    );
  }
}

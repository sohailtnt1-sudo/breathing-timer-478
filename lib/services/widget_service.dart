import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Home-screen widget (Premium feature).
///
/// One tap on the widget opens the app and starts the user's favourite
/// pattern (4-7-8 by default). The native Android widget lives in
/// android/app/src/main/kotlin/com/breathe478/timer/
/// BreathingWidgetProvider.kt + res/layout/breathing_widget.xml.
/// The widget talks to Dart through the `home_widget` plugin: the tap
/// sends the URI `breathe478://start-session`, which main.dart listens
/// for via [HomeWidget.widgetClicked].
class WidgetService {
  static const String startSessionUri = 'breathe478://start-session';
  static const String _favouriteKey = 'favourite_pattern_id';

  Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId('group.com.breathe478.timer');
    } catch (e) {
      debugPrint('Home widget init failed: $e');
    }
  }

  /// Save the favourite pattern so the native widget can show its name,
  /// then ask Android to redraw the widget.
  Future<void> updateWidget({required String favouritePatternId}) async {
    try {
      await HomeWidget.saveWidgetData<String>(
          _favouriteKey, favouritePatternId);
      await HomeWidget.updateWidget(
        name: 'BreathingWidgetProvider',
        androidName: 'BreathingWidgetProvider',
        qualifiedAndroidName:
            'com.breathe478.timer.BreathingWidgetProvider',
      );
    } catch (e) {
      debugPrint('Update widget failed: $e');
    }
  }

  /// Stream of widget taps (URI the widget was tapped with).
  Stream<Uri?> get widgetClicked => HomeWidget.widgetClicked;

  Future<Uri?> get initiallyLaunchedFromWidget =>
      HomeWidget.initiallyLaunchedFromHomeWidget();
}

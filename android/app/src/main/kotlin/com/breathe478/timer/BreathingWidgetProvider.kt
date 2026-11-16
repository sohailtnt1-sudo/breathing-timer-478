package com.breathe478.timer

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget (Premium feature).
 * One tap opens the app with the URI `breathe478://start-session`, which
 * main.dart listens for and turns into a session with the user's
 * favourite pattern (4-7-8 by default).
 */
class BreathingWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.breathing_widget).apply {
            // Open the app and start the favourite session on tap.
            val pendingIntent =
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("breathe478://start-session"),
                )
            setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            val favourite = widgetData.getString("favourite_pattern_id", null)
            setTextViewText(
                R.id.widget_title,
                "4-7-8 Breathing Timer",
            )
            setTextViewText(
                R.id.widget_subtitle,
                "Tap to start • ${favourite ?: "4-7-8 Relaxing"}",
            )
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}

package com.seloasa.seloasa_evidencias

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import com.seloasa.seloasa_evidencias.R

class SosWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.sos_widget_layout).apply {
                // PendingIntent para abrir directamente la ruta de emergencia SOS
                val intentSos = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("seloasa://app/sos")
                )
                setOnClickPendingIntent(R.id.sos_widget_container, intentSos)
                setOnClickPendingIntent(R.id.sos_icon, intentSos)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

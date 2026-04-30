package com.seloasa.seloasa_evidencias

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import com.seloasa.seloasa_evidencias.R

class SeloasaWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // Leer título dinámico desde Flutter
                val title = widgetData.getString("route_title", "SELOASA • REPORTE RÁPIDO")
                setTextViewText(R.id.widget_title, title)
                
                // Botón Mecánica
                val intentMecanica = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, Uri.parse("seloasa://app/incident?type=MECANICA&auto=true")
                )
                setOnClickPendingIntent(R.id.btn_mecanica, intentMecanica)

                // Botón Tráfico
                val intentTrafico = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, Uri.parse("seloasa://app/incident?type=TRAFICO&auto=true")
                )
                setOnClickPendingIntent(R.id.btn_trafico, intentTrafico)

                // Botón Emergencia
                val intentEmergencia = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, Uri.parse("seloasa://app/incident?type=EMERGENCIA&auto=true")
                )
                setOnClickPendingIntent(R.id.btn_emergencia, intentEmergencia)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

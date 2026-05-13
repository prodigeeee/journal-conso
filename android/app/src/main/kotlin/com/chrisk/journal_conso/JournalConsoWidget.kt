package com.chrisk.journal_conso

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Widget d'accueil Journal Conso
 *
 * Un clic sur le bouton "+" lance l'application et navigue directement
 * vers l'écran d'ajout de consommation via l'extra INTENT_ACTION_ADD.
 *
 * Configuration :
 *  - showTitle : passer à false pour masquer le texte "Journal Conso"
 */
class JournalConsoWidget : AppWidgetProvider() {

    companion object {
        /** Action custom envoyée à MainActivity pour déclencher l'ajout rapide */
        const val INTENT_ACTION_ADD = "com.chrisk.journal_conso.ACTION_ADD_CONSUMPTION"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.journal_conso_widget)

        // Plus de titre, le layout contient uniquement l'image PNG centrée

        // ── Intent de clic : ouvre l'app et demande l'ajout d'une conso ────
        val intent = Intent(context, MainActivity::class.java).apply {
            action = INTENT_ACTION_ADD
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        views.setOnClickPendingIntent(R.id.widget_button, pendingIntent)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}

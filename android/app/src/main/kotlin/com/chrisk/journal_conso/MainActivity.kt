package com.chrisk.journal_conso

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity – Journal Conso
 *
 * Gère l'intent ACTION_ADD_CONSUMPTION envoyé par le widget d'accueil.
 * Quand l'app est ouverte via ce clic, elle envoie un signal Flutter
 * pour naviguer automatiquement vers l'écran d'ajout de consommation.
 */
class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.chrisk.journal_conso/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "checkAndClearWidgetIntent") {
                val prefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
                val openAddScreen = prefs.getBoolean("open_add_screen", false)
                if (openAddScreen) {
                    prefs.edit().putBoolean("open_add_screen", false).apply()
                }
                result.success(openAddScreen)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleWidgetIntent(intent)
    }

    private fun handleWidgetIntent(intent: Intent?) {
        if (intent?.action == JournalConsoWidget.INTENT_ACTION_ADD) {
            // On sauvegarde le signal dans les SharedPreferences natives
            // pour que Flutter puisse le lire au démarrage via home_widget
            val prefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
            prefs.edit().putBoolean("open_add_screen", true).apply()
        }
    }
}

import 'dart:ui' show Color;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'helpers.dart';
import '../models/models.dart';

/// Service de notifications locales pour l'app Journal Conso.
///
/// Gère une unique notification "retour au vert" (ID 42) :
/// - Programmée quand le BAC dépasse le seuil après une nouvelle conso
/// - Annulée si le BAC repasse sous le seuil
/// - Remplacée à chaque nouvelle conso si déjà en cours
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// ID fixe pour la notification "retour au vert" (une seule à la fois)
  static const int _sobrietyNotifId = 42;

  /// Canal Android pour les notifications de sobriété
  static const String _channelId = 'sobriety_alert';
  static const String _channelName = 'Alerte alcoolémie';
  static const String _channelDesc =
      "Notification quand le taux d'alcoolémie repasse dans la zone verte";

  static bool _initialized = false;

  /// À appeler dans initState() principal de l'app.
  static Future<void> init() async {
    if (kIsWeb || _initialized) return;

    // Initialisation du fuseau horaire local (requis par zonedSchedule)
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Crée le canal Android (requis Android 8+)
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
  }

  /// Calcule l'heure à laquelle le BAC repassera sous [threshold] pour le
  /// profil donné, puis programme ou annule la notification.
  ///
  /// Retourne [true] si une notification a été programmée, [false] sinon.
  static Future<bool> scheduleOrCancelSobrietyNotification({
    required String gender,
    required int weight,
    required List<Consumption> consumptions,
    required double threshold,
    required String profileName,
  }) async {
    if (kIsWeb || !_initialized) return false;

    final now = DateTime.now();
    final currentBac = calculateBACAt(gender, weight, consumptions, now);

    // Déjà sobre → on annule toute notification existante
    if (currentBac <= threshold) {
      await cancelSobrietyNotification();
      return false;
    }

    // Simulation du futur (pas de 5 min, max 24h = 288 pas)
    DateTime? sobrietyTime;
    for (int i = 1; i <= 288; i++) {
      final futureTime = now.add(Duration(minutes: i * 5));
      final futureBac =
          calculateBACAt(gender, weight, consumptions, futureTime);
      if (futureBac <= threshold) {
        sobrietyTime = futureTime;
        break;
      }
    }

    // Cas extrêmes : BAC jamais repassé sous le seuil en 24h → on annule
    if (sobrietyTime == null) {
      await cancelSobrietyNotification();
      return false;
    }

    // Annuler l'ancienne notification avant d'en programmer une nouvelle
    await cancelSobrietyNotification();

    final thresholdStr = threshold.toStringAsFixed(1);

    // Convertir en TZDateTime (fuseau local) requis par zonedSchedule
    final tzSobrietyTime = tz.TZDateTime.from(sobrietyTime, tz.local);

    try {
      await _plugin.zonedSchedule(
        _sobrietyNotifId,
        '🟢 Taux d\'alcoolémie dans le vert !',
        'Votre taux est repassé sous $thresholdStr g/L. Bonne route, $profileName !',
        tzSobrietyTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF4CAF50),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // Le plugin natif n'était pas encore prêt — on réinitialise pour le prochain appel
      _initialized = false;
      debugPrint('NotificationService: schedule failed: $e');
      return false;
    }

    return true;
  }

  /// Annule la notification de sobriété si elle existe.
  static Future<void> cancelSobrietyNotification() async {
    if (kIsWeb || !_initialized) return;
    try {
      await _plugin.cancel(_sobrietyNotifId);
    } catch (e) {
      _initialized = false;
      debugPrint('NotificationService: cancel failed: $e');
    }
  }
}

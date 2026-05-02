import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;
import 'dart:convert';
import 'l10n_service.dart';
import '../models/models.dart';

/// Calcule la quantité maximale d'alcool apportée par une conso en g/L de sang.
/// Formule de Widmark : Alcool(g) / (poids(kg) × r)
/// vol en cl, deg en %, densité alcool = 0.789 g/ml ≈ 0.8 g/ml (arrondi usuel)
double _getDrinkMaxBAC(Consumption c, double weight, double r) {
  String vStr = c.volume.toLowerCase().replaceAll('cl', '').replaceAll('ml', '').trim();
  double vol = double.tryParse(vStr) ?? 0;
  // Conversion ml → cl si nécessaire
  if (c.volume.toLowerCase().contains('ml')) vol = vol / 10.0;
  // vol en cl → grammes d'alcool pur : vol(cl) × 10(ml/cl) × (deg/100) × 0.789(g/ml)
  double alcoholGrams = vol * 10.0 * (c.degree / 100.0) * 0.789;
  return alcoholGrams / (weight * r);
}

/// Fonction sigmoïde normalisée pour modéliser l'absorption gastrique.
/// Retourne la fraction absorbée [0..1] à t minutes après ingestion.
/// La courbe est rapide au départ (absorption intestinale) et ralentit progressivement.
/// Basée sur une sigmoïde de Hill avec n=2, pic à mi-parcours.
double _sigmoidAbsorption(double t, double tMax) {
  if (t <= 0) return 0.0;
  if (t >= tMax) return 1.0;
  // Sigmoïde symétrique : f(x) = x² / (x² + (1-x)²) avec x = t/tMax
  final x = t / tMax;
  return (x * x) / (x * x + (1 - x) * (1 - x));
}

/// Calcule l'alcoolémie estimée [g/L] à un instant donné.
///
/// Modèle scientifique basé sur Widmark avec améliorations :
/// - Facteur de distribution r : Homme 0.68, Femme 0.55 (médianes de Widmark 1932,
///   confirmées par Watson 1981 et Seidl 2000)
/// - Taux d'élimination : 0.12–0.15 g/L/h (on utilise 0.13, médiane pour un adulte sain)
/// - Absorption gastro-intestinale modélisée par une courbe sigmoïde sur 45 min
///   (vs 30 min linéaire précédemment) — pic à 45-90 min selon la littérature (NIH, CEREMA)
/// - Simulation par pas de 1 minute pour une précision accrue
///
/// IMPORTANT : Ce calcul reste une ESTIMATION. L'alcoolémie réelle varie selon
/// l'état de santé, la prise alimentaire, la génétique et l'état du foie.
/// Ne jamais utiliser ce résultat pour prendre une décision de conduite.
double calculateBACAt(
  String gender,
  int weight,
  List<Consumption> consumptions,
  DateTime targetTime,
) {
  // --- Paramètres de Widmark affinés ---
  // r = rapport eau corporelle / poids total
  // Homme : médiane 0.68 (plage 0.60–0.85), Femme : médiane 0.55 (plage 0.44–0.70)
  final double r = gender == 'Homme' ? 0.68 : 0.55;

  // Poids effectif : fallback si données absurdes
  final double activeWeight =
      weight > 40 ? weight.toDouble() : (gender == 'Homme' ? 75.0 : 60.0);

  // Taux d'élimination moyen : 0.13 g/L/h (fourchette 0.10–0.20)
  // 0.15 était conservateur (haut de fourchette). 0.13 est plus réaliste.
  const double eliminationPerHour = 0.13;

  // Durée d'absorption : 45 minutes (pic à ~45–60 min à jeun, 90 min en mangeant)
  // On prend la valeur intermédiaire pour une estimation équilibrée.
  const double absorptionMinutes = 45.0;

  // --- Filtrage des consos pertinentes ---
  final int targetMs = targetTime.millisecondsSinceEpoch;
  final relevantConsos = consumptions.where((c) {
    final int cMs = c.date.millisecondsSinceEpoch;
    // Consos des dernières 24h qui précèdent ou sont simultanées à targetTime
    return (targetMs - cMs) < (24 * 3600 * 1000) && cMs <= targetMs;
  }).toList();

  if (relevantConsos.isEmpty) return 0.0;
  relevantConsos.sort((a, b) => a.date.compareTo(b.date));

  // --- Simulation par pas de 1 minute (précision accrue vs 5 min) ---
  double currentBAC = 0.0;
  DateTime currentTime = relevantConsos.first.date;

  while (currentTime.isBefore(targetTime)) {
    DateTime nextTime = currentTime.add(const Duration(minutes: 1));
    if (nextTime.isAfter(targetTime)) nextTime = targetTime;

    final double stepHours =
        nextTime.difference(currentTime).inSeconds / 3600.0;

    // 1. Élimination enzymatique (cinétique d'ordre 0 — taux constant)
    //    L'élimination ne commence qu'une fois que l'alcool entre dans le sang.
    if (currentBAC > 0.001) {
      currentBAC -= stepHours * eliminationPerHour;
      if (currentBAC < 0) currentBAC = 0.0;
    }

    // 2. Absorption progressive de chaque verre (courbe sigmoïde)
    for (final c in relevantConsos) {
      // Skip les consos futures par rapport à la fenêtre courante
      if (c.date.isAfter(nextTime)) continue;

      final double startMin =
          currentTime.difference(c.date).inSeconds / 60.0;
      final double endMin =
          nextTime.difference(c.date).inSeconds / 60.0;

      // Hors de la fenêtre d'absorption → rien à faire
      if (startMin >= absorptionMinutes || endMin <= 0) continue;

      final double drinkMaxBAC = _getDrinkMaxBAC(c, activeWeight, r);

      // Fraction absorbée en début et fin de pas (via courbe sigmoïde)
      final double fracStart = _sigmoidAbsorption(startMin.clamp(0, absorptionMinutes), absorptionMinutes);
      final double fracEnd = _sigmoidAbsorption(endMin.clamp(0, absorptionMinutes), absorptionMinutes);

      final double absorbedInStep = (fracEnd - fracStart) * drinkMaxBAC;
      if (absorbedInStep > 0) currentBAC += absorbedInStep;
    }

    currentTime = nextTime;
  }

  return currentBAC > 0 ? currentBAC : 0.0;
}

String cleanDisplay(String? text) {
  if (text == null) return '';
  return text
      .replaceAll("´e", "é")
      .replaceAll("`e", "è")
      .replaceAll("^e", "ê")
      .replaceAll("Ã©", "é")
      .replaceAll("Ã¨", "è")
      .replaceAll("`a", "à");
}

bool belongsToLogicalDay(DateTime consumptionDate, DateTime dayInCalendar) {
  DateTime logical = consumptionDate.hour < 6
      ? consumptionDate.subtract(const Duration(days: 1))
      : consumptionDate;
  return logical.year == dayInCalendar.year &&
      logical.month == dayInCalendar.month &&
      logical.day == dayInCalendar.day;
}

ImageProvider? getProfileImage(String? imagePath) {
  if (imagePath == null || imagePath.isEmpty) {
    return null; 
  }
  
  if (imagePath.startsWith('data:image') || imagePath.length > 1000) {
    try {
      final base64String = imagePath.contains(',') ? imagePath.split(',').last : imagePath;
      return MemoryImage(base64Decode(base64String));
    } catch (e) {
      return const AssetImage('assets/images/title.png');
    }
  }

  if (kIsWeb) {
    return NetworkImage(imagePath);
  } else {
    try {
      return FileImage(File(imagePath));
    } catch (e) {
      return const AssetImage('assets/images/title.png');
    }
  }
}

String getMomentFromTime(TimeOfDay time) {
  int h = time.hour;
  if (h >= 6 && h < 11) return L10n.s('moments.morning');
  if (h >= 11 && h < 15) return L10n.s('moments.noon');
  if (h >= 15 && h < 18) return L10n.s('moments.afternoon');
  if (h >= 18 && h < 21) return L10n.s('moments.evening');
  return L10n.s('moments.night');
}

int calculateSobrietyStreak(List<Consumption> consos) {
  if (consos.isEmpty) return 0;
  final now = DateTime.now();
  
  Set<String> drinkDays = consos.map((c) {
     DateTime logical = c.date.hour < 6 ? c.date.subtract(const Duration(days: 1)) : c.date;
     return DateFormat('yyyyMMdd').format(logical);
  }).toSet();
  
  int streak = 0;
  DateTime checkDate = now;
  
  for (int i = 0; i < 365; i++) {
    DateTime logical = checkDate.hour < 6 ? checkDate.subtract(const Duration(days: 1)) : checkDate;
    String key = DateFormat('yyyyMMdd').format(logical);
    if (drinkDays.contains(key)) break;
    streak++;
    checkDate = checkDate.subtract(const Duration(days: 1));
  }
  return streak;
}

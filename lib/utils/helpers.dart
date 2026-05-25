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

/// Fonction sigmoïde légèrement asymétrique pour modéliser l'absorption gastrique.
/// Retourne la fraction absorbée [0..1] à t minutes après le début de l'absorption.
/// La montée est plus rapide que la décroissance (fidèle aux courbes empiriques).
/// Hill n=2 asymétrique : monte vite, plateau progressif.
double _sigmoidAbsorption(double t, double tMax) {
  if (t <= 0) return 0.0;
  if (t >= tMax) return 1.0;
  // Sigmoïde asymétrique : montée rapide (Hill n=3), plateau doux
  // x = t/tMax ∈ [0,1]
  final x = t / tMax;
  final x3 = x * x * x;
  return x3 / (x3 + (1 - x) * (1 - x));
}

/// Calcule l'alcoolémie estimée [g/L] à un instant donné.
///
/// Modèle pharmacocinétique basé sur Widmark avec améliorations validées :
///
/// • Facteur de distribution r : Homme 0.68, Femme 0.55
///   (Widmark 1932, confirmé NHTSA, Forrest 1986, Posey & Mozayani 2007)
///
/// • Phase de latence (t-lag) : 10 min avant absorption
///   Correspond au temps de vidange gastrique avant absorption intestinale
///   (Norberg et al. 2003, Jones & Jonsson 1994 — plage typique 5–20 min)
///
/// • Absorption sigmoïde sur 40 min après le t-lag
///   Pic d'alcoolémie atteint ~40–60 min après consommation à jeun
///   (Jones 1993, Frezza et al. 1990, NIH)
///
/// • Taux d'élimination : 0.15 g/L/h (cinétique d'ordre 0)
///   Médiane établie pour un adulte sain non alcoolique
///   (Jones 2010, Dubowski 1985, NHTSA — plage réelle 0.10–0.20 g/L/h)
///   Note : l'ancienne valeur 0.13 sous-estimait l'élimination et décalait
///   la sobriété affichée d'environ 45 min (scénario 3 verres).
///
/// • Simulation par pas de 1 minute (précision vs approche analytique)
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
  // --- Paramètres Widmark calibrés ---
  // r = rapport eau corporelle / poids total
  // Homme : 0.68 (médiane, plage 0.60–0.85) — Widmark 1932, NHTSA
  // Femme : 0.55 (médiane, plage 0.44–0.70) — les femmes ont moins d'eau corporelle
  final double r = gender == 'Homme' ? 0.68 : 0.55;

  // Poids effectif : fallback si données absurdes (< 40 kg)
  final double activeWeight =
      weight > 40 ? weight.toDouble() : (gender == 'Homme' ? 75.0 : 60.0);

  // Taux d'élimination hépatique (cinétique d'ordre 0) : 0.15 g/L/h
  // Médiane validée par Jones (2010), Dubowski (1985), NHTSA
  // L'enzyme alcool déshydrogénase (ADH) travaille à vitesse constante à saturation.
  const double eliminationPerHour = 0.15;

  // Phase de latence (t-lag) : 10 minutes avant le début de l'absorption
  // Correspond au temps de vidange gastrique → duodénum → absorption intestinale
  // Norberg et al. (2003) : t-lag moyen = 6–15 min selon l'estomac et le repas
  const double lagMinutes = 10.0;

  // Durée de la fenêtre d'absorption sigmoïde (après t-lag) : 40 minutes
  // Pic d'alcoolémie typiquement atteint 40–60 min après consommation à jeun
  const double absorptionMinutes = 40.0;

  // --- Filtrage des consos pertinentes ---
  final int targetMs = targetTime.millisecondsSinceEpoch;
  final relevantConsos = consumptions.where((c) {
    final int cMs = c.date.millisecondsSinceEpoch;
    // Consos des dernières 24h qui précèdent ou sont simultanées à targetTime
    return (targetMs - cMs) < (24 * 3600 * 1000) && cMs <= targetMs;
  }).toList();

  if (relevantConsos.isEmpty) return 0.0;
  relevantConsos.sort((a, b) => a.date.compareTo(b.date));

  // --- Simulation par pas de 1 minute ---
  double currentBAC = 0.0;
  DateTime currentTime = relevantConsos.first.date;

  while (currentTime.isBefore(targetTime)) {
    DateTime nextTime = currentTime.add(const Duration(minutes: 1));
    if (nextTime.isAfter(targetTime)) nextTime = targetTime;

    final double stepHours =
        nextTime.difference(currentTime).inSeconds / 3600.0;

    // 1. Élimination hépatique (cinétique d'ordre 0 — taux constant)
    //    Ne s'applique qu'une fois l'alcool présent dans le sang.
    if (currentBAC > 0.001) {
      currentBAC -= stepHours * eliminationPerHour;
      if (currentBAC < 0) currentBAC = 0.0;
    }

    // 2. Absorption progressive (courbe sigmoïde avec t-lag)
    for (final c in relevantConsos) {
      if (c.date.isAfter(nextTime)) continue;

      // Temps écoulé depuis la consommation (en minutes)
      final double tStart =
          currentTime.difference(c.date).inSeconds / 60.0;
      final double tEnd =
          nextTime.difference(c.date).inSeconds / 60.0;

      // Encore en phase de latence → pas d'absorption
      if (tEnd <= lagMinutes) continue;

      // Après la fenêtre complète d'absorption → tout est absorbé
      if (tStart >= lagMinutes + absorptionMinutes) continue;

      // Position dans la fenêtre d'absorption [0, absorptionMinutes]
      final double absStart =
          (tStart - lagMinutes).clamp(0.0, absorptionMinutes);
      final double absEnd =
          (tEnd - lagMinutes).clamp(0.0, absorptionMinutes);

      if (absEnd <= absStart) continue;

      final double drinkMaxBAC = _getDrinkMaxBAC(c, activeWeight, r);
      final double fracStart =
          _sigmoidAbsorption(absStart, absorptionMinutes);
      final double fracEnd =
          _sigmoidAbsorption(absEnd, absorptionMinutes);

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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;
import 'dart:convert';
import 'l10n_service.dart';
import '../models/models.dart';

double _getDrinkMaxBAC(Consumption c, double weight, double r) {
  double vol = 0;
  String vStr = c.volume.toLowerCase().replaceAll('cl', '').replaceAll('ml', '').trim();
  vol = double.tryParse(vStr) ?? 0;
  if (c.volume.toLowerCase().contains('ml')) vol = vol / 10.0;
  double deg = c.degree;
  double alcoholGrams = (vol * 10) * (deg / 100) * 0.8;
  return alcoholGrams / (weight * r);
}

double calculateBACAt(String gender, int weight, List<Consumption> consumptions, DateTime targetTime) {
  double r = gender == 'Homme' ? 0.7 : 0.6;
  double activeWeight = weight > 40 ? weight.toDouble() : (gender == 'Homme' ? 75.0 : 60.0);
  
  const double eliminationPerHour = 0.15;
  const double absorptionMinutes = 30.0; 

  final int targetMs = targetTime.millisecondsSinceEpoch;
  final relevantConsos = consumptions.where((c) {
    final int cMs = c.date.millisecondsSinceEpoch;
    // On garde les consos des dernières 24h qui précèdent ou égalent targetTime
    return (targetMs - cMs) < (24 * 3600 * 1000) && cMs <= targetMs;
  }).toList();

  if (relevantConsos.isEmpty) return 0.0;
  relevantConsos.sort((a, b) => a.date.compareTo(b.date));

  double currentBAC = 0.0;
  DateTime currentTime = relevantConsos.first.date;
  
  // Simulation par pas de 5 minutes pour une courbe réaliste
  while (currentTime.isBefore(targetTime)) {
    DateTime nextTime = currentTime.add(const Duration(minutes: 5));
    if (nextTime.isAfter(targetTime)) nextTime = targetTime;
    
    double stepHours = nextTime.difference(currentTime).inSeconds / 3600.0;
    
    // 1. Élimination (seulement si BAC > 0)
    if (currentBAC > 0) {
      currentBAC -= stepHours * eliminationPerHour;
      if (currentBAC < 0) currentBAC = 0.0;
    }
    
    // 2. Absorption progressive de chaque verre
    for (var c in relevantConsos) {
      if (c.date.isAfter(nextTime)) break;
      
      double drinkMaxBAC = _getDrinkMaxBAC(c, activeWeight, r);
      double startMin = currentTime.difference(c.date).inSeconds / 60.0;
      double endMin = nextTime.difference(c.date).inSeconds / 60.0;
      
      if (startMin < absorptionMinutes) {
        double startAbs = startMin < 0 ? 0 : startMin;
        double endAbs = endMin > absorptionMinutes ? absorptionMinutes : endMin;
        
        if (endAbs > startAbs) {
          double absorbedInStep = ((endAbs - startAbs) / absorptionMinutes) * drinkMaxBAC;
          currentBAC += absorbedInStep;
        }
      }
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

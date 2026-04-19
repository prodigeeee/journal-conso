import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;
import 'dart:convert';
import 'l10n_service.dart';
import '../models/models.dart';

double calculateBACAt(String gender, int weight, List<Consumption> consumptions, DateTime targetTime) {
  double r = gender == 'Homme' ? 0.7 : 0.6;
  double activeWeight = weight > 30 ? weight.toDouble() : 70.0;
  
  final int targetMs = targetTime.millisecondsSinceEpoch;
  final relevantConsos = consumptions.where((c) {
    final int cMs = c.date.millisecondsSinceEpoch;
    return (targetMs - cMs) < (24 * 3600 * 1000) && cMs <= targetMs;
  }).toList();

  if (relevantConsos.isEmpty) return 0.0;

  relevantConsos.sort((a, b) => a.date.compareTo(b.date));
  
  double currentBAC = 0.0;
  const double eliminationPerHour = 0.15;
  int currentStepMs = relevantConsos.first.date.millisecondsSinceEpoch;
  
  for (int i = 0; i < relevantConsos.length; i++) {
      var c = relevantConsos[i];
      final int cMs = c.date.millisecondsSinceEpoch;
      
      double diffHoursBeforeDrink = (cMs - currentStepMs) / 3600000.0;
      if (diffHoursBeforeDrink > 0) {
          currentBAC -= diffHoursBeforeDrink * eliminationPerHour;
          if (currentBAC < 0) currentBAC = 0.0;
      }
      currentStepMs = cMs;

      double vol = 0;
      String vStr = c.volume.toLowerCase().replaceAll('cl', '').replaceAll('ml', '').trim();
      vol = double.tryParse(vStr) ?? 0;
      if (c.volume.toLowerCase().contains('ml')) vol = vol / 10.0; 
      double deg = c.degree;
      double alcoholGrams = (vol * 10) * (deg / 100) * 0.8;
      double drinkMaxBAC = alcoholGrams / (activeWeight * r);
      
      currentBAC += drinkMaxBAC;
  }

  double timeSinceLastEvent = (targetMs - currentStepMs) / 3600000.0;
  if (timeSinceLastEvent > 0) {
    currentBAC -= timeSinceLastEvent * eliminationPerHour;
    if (currentBAC < 0) currentBAC = 0.0;
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

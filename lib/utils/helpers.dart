import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;

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

ImageProvider getProfileImage(String? imagePath) {
  if (imagePath == null || imagePath.isEmpty) {
    // On retourne une image transparente ou un asset existant
    return const AssetImage('assets/images/title.png'); 
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

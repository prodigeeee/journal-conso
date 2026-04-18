import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class StorageService {
  static const String _keyProfiles = 'profiles';
  static const String _keyContexts = 'momentsContexts';
  static const String _keyConsumptions = 'consumptions';
  static const String _keyActiveUserId = 'active_user_id';
  static const String _keyDarkMode = 'isDarkMode';
  static const String _keyFirstLaunch = 'isFirstLaunch';
  static const String _keyYoungDriver = 'isYoungDriver';
  static const String _keyUnitMl = 'unitMl';
  static const String _keySyncId = 'syncId';

  static Future<void> saveAll({
    required List<UserProfile> profiles,
    required Map<String, String> contexts,
    required List<Consumption> consumptions,
    required String activeUserId,
    String? syncId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfiles, jsonEncode(profiles.map((e) => e.toJson()).toList()));
    await prefs.setString(_keyContexts, jsonEncode(contexts));
    await prefs.setString(_keyConsumptions, jsonEncode(consumptions.map((e) => e.toJson()).toList()));
    await prefs.setString(_keyActiveUserId, activeUserId);
    if (syncId != null) {
      await prefs.setString(_keySyncId, syncId);
    }

    // Sauvegarde physique JSON (Sécurité supplémentaire hors Web)
    if (!kIsWeb) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/alcohol_tracker_local_backup.json');
        final fullData = {
          'profiles': profiles.map((e) => e.toJson()).toList(),
          'momentsContexts': contexts,
          'consumptions': consumptions.map((e) => e.toJson()).toList(),
          'active_user_id': activeUserId,
          'last_save': DateTime.now().toIso8601String(),
        };
        await file.writeAsString(jsonEncode(fullData));
      } catch (e) {
        debugPrint("Erreur lors de la sauvegarde physique : $e");
      }
    }
  }

  static Future<Map<String, dynamic>> loadAppData() async {
    final prefs = await SharedPreferences.getInstance();
    
    List<UserProfile> profiles = [];
    try {
      String? profilesStr = prefs.getString(_keyProfiles);
      if (profilesStr != null && profilesStr.isNotEmpty) {
        profiles = (jsonDecode(profilesStr) as List)
            .map((i) => UserProfile.fromJson(i))
            .toList();
      }
    } catch (_) {}
        
    // On charge le premier profil par défaut au démarrage (profil prioritaire)
    String activeUserId = (profiles.isNotEmpty ? profiles.first.id : (prefs.getString(_keyActiveUserId) ?? '1'));
    String? syncId = prefs.getString(_keySyncId);
    
    Map<String, String> contexts = {};
    try {
      String? contextStr = prefs.getString(_keyContexts);
      if (contextStr != null && contextStr.isNotEmpty) {
        contexts = Map<String, String>.from(jsonDecode(contextStr));
      }
    } catch (_) {}
    
    List<Consumption> consumptions = [];
    try {
      String? consoStr = prefs.getString(_keyConsumptions);
      if (consoStr != null && consoStr.isNotEmpty) {
        consumptions = (jsonDecode(consoStr) as List)
            .map((i) => Consumption.fromJson(i))
            .toList();
      }
    } catch (_) {}

    bool isDarkMode = prefs.getBool(_keyDarkMode) ?? true;
    bool isFirstLaunch = prefs.getBool(_keyFirstLaunch) ?? true;
    bool isYoungDriver = prefs.getBool(_keyYoungDriver) ?? false;
    bool unitMl = prefs.getBool(_keyUnitMl) ?? false;
    
    if (profiles.isNotEmpty) {
      isFirstLaunch = false;
    }

    return {
      'profiles': profiles,
      'activeUserId': activeUserId,
      'contexts': contexts,
      'consumptions': consumptions,
      'syncId': syncId,
      'isDarkMode': isDarkMode,
      'isFirstLaunch': isFirstLaunch,
      'isYoungDriver': isYoungDriver,
      'unitMl': unitMl,
    };
  }

  static Future<void> setFirstLaunchDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstLaunch, false);
  }

  static Future<void> saveTheme(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, isDarkMode);
  }

  static Future<void> savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProfiles);
    await prefs.remove(_keyContexts);
    await prefs.remove(_keyConsumptions);
    await prefs.remove(_keyActiveUserId);
    await prefs.remove(_keySyncId);
    await prefs.remove(_keyFirstLaunch);
  }
}

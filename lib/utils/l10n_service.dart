import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class L10n {
  static Map<dynamic, dynamic> _localizedValues = {};

  static Future<void> load() async {
    try {
      String yamlString = await rootBundle.loadString('assets/lang/fr.yaml');
      final dynamic yamlMap = loadYaml(yamlString);
      _localizedValues = _convertYamlMapToMap(yamlMap);
      print("✅ Langue chargée : ${_localizedValues.length} clés trouvées.");
    } catch (e) {
      print("⚠️ Erreur chargement langue : $e");
      _localizedValues = {};
    }
  }

  static Map<String, dynamic> _convertYamlMapToMap(dynamic yamlMap) {
    if (yamlMap is YamlMap) {
      return yamlMap.map((key, value) => MapEntry(key.toString(), _convertYamlMapToMap(value)));
    } else if (yamlMap is YamlList) {
      return yamlMap.map((value) => _convertYamlMapToMap(value)).toList().asMap().map((key, value) => MapEntry(key.toString(), value));
    } else {
      return yamlMap;
    }
  }

  static String s(String key, {Map<String, String>? args}) {
    List<String> keys = key.split('.');
    dynamic value = _localizedValues;

    for (var k in keys) {
      if (value is Map && value.containsKey(k)) {
        value = value[k];
      } else {
        return key; // Retourne la clé si non trouvé
      }
    }

    if (value is String) {
      String result = value;
      if (args != null) {
        args.forEach((k, v) {
          result = result.replaceAll('{$k}', v);
        });
      }
      return result;
    }

    return key;
  }
}

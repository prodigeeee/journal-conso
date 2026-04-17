import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'dart:developer' as dev;

class L10n {
  static Map<String, dynamic> _localizedValues = {};

  static Future<void> load() async {
    try {
      final String yamlString = await rootBundle.loadString('assets/lang/fr.yaml');
      final dynamic yamlMap = loadYaml(yamlString);
      
      if (yamlMap is YamlMap) {
        _localizedValues = _yamlToMap(yamlMap);
        dev.log("✅ L10n: Loaded ${_localizedValues.length} top-level keys");
      } else {
        dev.log("⚠️ L10n: Yaml is not a Map");
        _localizedValues = {};
      }
    } catch (e) {
      dev.log("❌ L10n Error: $e");
      _localizedValues = {};
    }
  }

  static Map<String, dynamic> _yamlToMap(YamlMap yamlMap) {
    final Map<String, dynamic> map = {};
    yamlMap.forEach((key, value) {
      if (value is YamlMap) {
        map[key.toString()] = _yamlToMap(value);
      } else if (value is YamlList) {
        map[key.toString()] = value.map((e) => e is YamlMap ? _yamlToMap(e) : e).toList();
      } else {
        map[key.toString()] = value;
      }
    });
    return map;
  }

  static String s(String key, {Map<String, String>? args}) {
    if (_localizedValues.isEmpty) return key;

    List<String> keys = key.split('.');
    dynamic value = _localizedValues;

    for (var k in keys) {
      if (value is Map && value.containsKey(k)) {
        value = value[k];
      } else {
        return key;
      }
    }

    if (value != null) {
      String result = value.toString();
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

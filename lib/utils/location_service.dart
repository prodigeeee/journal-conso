import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Service de géolocalisation inverse.
/// Retourne un nom de lieu lisible (bar, restaurant, adresse) ou null.
class LocationService {
  static const _timeout = Duration(seconds: 5);

  /// Point d'entrée principal.
  /// Retourne null silencieusement si la localisation est impossible
  /// (GPS désactivé, permission refusée, pas de réseau, etc.).
  static Future<String?> getPlaceName() async {
    // La géolocalisation n'est pas supportée sur le web dans ce contexte
    if (kIsWeb) return null;

    try {
      // 1. Vérifier si le service de localisation est activé
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      // 2. Vérifier / demander la permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      // 3. Obtenir la position courante
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // Économique en batterie
          timeLimit: Duration(seconds: 8),
        ),
      ).timeout(_timeout);

      // 4. Reverse geocoding via Nominatim (OSM)
      return await _reverseGeocode(position.latitude, position.longitude);
    } catch (_) {
      // Timeout, erreur réseau, permission refusée en runtime : silence total
      return null;
    }
  }

  /// Appelle l'API Nominatim pour convertir des coordonnées en nom de lieu.
  static Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lon&format=json&zoom=17&accept-language=fr',
      );

      final response = await http
          .get(
            uri,
            headers: {
              // Politique Nominatim : User-Agent identifiable obligatoire
              'User-Agent': 'JournalConso/1.2 (contact@journal-conso.app)',
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _extractPlaceName(data);
    } catch (_) {
      return null;
    }
  }

  /// Extrait le nom de lieu le plus pertinent de la réponse Nominatim.
  /// Ordre de priorité :
  ///   1. Nom d'un commerce/lieu (bar, café, restaurant, etc.)
  ///   2. Adresse approximative (rue + ville)
  static String? _extractPlaceName(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) return null;

    // 1. Chercher un lieu nommé (bar, café, restaurant, hôtel, etc.)
    final amenityName = data['name'] as String?;
    if (amenityName != null && amenityName.isNotEmpty) {
      return amenityName;
    }

    // 2. Fallback : adresse approximative (rue + ville)
    final road = address['road'] as String?;
    final suburb = address['suburb'] as String?;
    final city =
        address['city'] as String? ??
        address['town'] as String? ??
        address['village'] as String?;

    final parts = <String>[];
    if (road != null) parts.add(road);
    if (city != null && city != road) {
      // Préférer le quartier si disponible et différent de la ville entière
      if (suburb != null && suburb != city) {
        parts.add(suburb);
      } else {
        parts.add(city);
      }
    }

    if (parts.isNotEmpty) return parts.join(', ');
    return null;
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  static final _supabase = Supabase.instance.client;

  // -- SYNCHRONISATION DES PROFILS --
  static Future<void> syncProfiles(List<UserProfile> profiles, String ownerId) async {
    try {
      for (var p in profiles) {
        await _supabase.from('profiles').upsert({
          'id': p.id,
          'owner_id': ownerId, // On lie au compte
          'name': p.name,
          'gender': p.gender,
          'age': p.age,
          'weight': p.weight,
          'color_value': p.colorValue,
          'image_path': p.imagePath,
        });
      }
    } catch (e) {
      print('Erreur sync profil: $e');
    }
  }

  // -- SYNCHRONISATION DES CONSOMMATIONS --
  static Future<void> syncConsumptions(List<Consumption> consumptions, String ownerId) async {
    try {
      final data = consumptions.map((c) => {
        'id': c.id,
        'owner_id': ownerId, // On lie au compte
        'profile_id': c.userId,
        'date': c.date.toIso8601String(),
        'moment': c.moment,
        'type': c.type,
        'volume': c.volume,
        'degree': c.degree,
      }).toList();

      if (data.isNotEmpty) {
        await _supabase.from('consumptions').upsert(data);
      }
    } catch (e) {
      print('Erreur sync conso: $e');
    }
  }

  // -- RÉCUPÉRATION FILTRÉE --
  static Future<Map<String, dynamic>> fetchAllData(String ownerId) async {
    try {
      final profileData = await _supabase.from('profiles').select().eq('owner_id', ownerId);
      final consumptionData = await _supabase.from('consumptions').select().eq('owner_id', ownerId);

      final profiles = (profileData as List).map((json) {
        return UserProfile(
          id: json['id'],
          name: json['name'] ?? '',
          gender: json['gender'] ?? 'Homme',
          age: (json['age'] as num).toInt(),
          weight: (json['weight'] as num?)?.toInt() ?? 70,
          colorValue: json['color_value'] ?? 0xFFEA9216,
          imagePath: json['image_path'],
        );
      }).toList().cast<UserProfile>();

      final consumptions = (consumptionData as List).map((json) {
        return Consumption(
          id: json['id'],
          date: DateTime.parse(json['date']),
          moment: json['moment'] ?? 'Soir',
          type: json['type'],
          volume: json['volume'],
          degree: (json['degree'] as num).toDouble(),
          userId: json['profile_id'] ?? '1',
        );
      }).toList().cast<Consumption>();

      return {
        'profiles': profiles,
        'consumptions': consumptions,
      };
    } catch (e) {
      print('Erreur fetch: $e');
      return {'profiles': [], 'consumptions': []};
    }
  }
}

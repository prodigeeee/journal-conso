import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  static final _supabase = Supabase.instance.client;
  static const String _profilesBucket = 'profile_images';

  static Future<Map<String, String?>> uploadProfileImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final ext = imageFile.name.contains('.') ? imageFile.name.split('.').last.toLowerCase() : 'jpg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999)}.$ext';
      
      await _supabase.storage.from(_profilesBucket).uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(cacheControl: '3600', contentType: 'image/$ext', upsert: false),
      );

      final String publicUrl = _supabase.storage.from(_profilesBucket).getPublicUrl(fileName);
      return {'url': publicUrl, 'error': null};
    } catch (e) {
      return {'url': null, 'error': e.toString()};
    }
  }

  // -- SYNCHRONISATION DES PROFILS --
  static Future<void> syncProfiles(List<UserProfile> profiles, String ownerId) async {
    // Éliminer les doublons d'ID localement avant l'envoi
    final uniqueProfiles = { for (var p in profiles) p.id : p }.values.toList();
    
    for (var p in uniqueProfiles) {
      await _supabase.from('profiles').upsert({
        'id': p.id,
        'owner_id': ownerId,
        'email': _supabase.auth.currentUser?.email, // On ajoute l'email de l'auth
        'name': p.name,
        'gender': p.gender,
        'age': p.age,
        'weight': p.weight,
        'color_value': p.colorValue,
        'image_path': p.imagePath,
      });
    }
  }

  // -- SYNCHRONISATION DES CONSOMMATIONS --
  static Future<void> syncConsumptions(List<Consumption> consumptions, String ownerId) async {
    // Éliminer les doublons d'ID pour éviter l'erreur Postgres 21000
    final uniqueConsos = { for (var c in consumptions) c.id : c }.values.toList();

    final data = uniqueConsos.map((c) => {
      'id': c.id,
      'owner_id': ownerId,
      'profile_id': c.userId,
      'date': c.date.toUtc().toIso8601String(),
      'moment': c.moment,
      'type': c.type,
      'volume': c.volume,
      'degree': c.degree,
    }).toList();

    if (data.isNotEmpty) {
      await _supabase.from('consumptions').upsert(data);
    }
  }

  // -- SYNCHRONISATION DES CONTEXTES --
  static Future<void> syncContexts(Map<String, String> contexts, String ownerId) async {
    final data = contexts.entries.map((e) => {
      'id': e.key,
      'owner_id': ownerId,
      'content': e.value,
    }).toList();

    if (data.isNotEmpty) {
      await _supabase.from('moments_contexts').upsert(data);
    }
  }

  static Future<void> syncSingleContext(String key, String content, String ownerId) async {
    await _supabase.from('moments_contexts').upsert({
      'id': key,
      'owner_id': ownerId,
      'content': content,
    });
  }

  static Future<void> deleteContext(String key, String ownerId) async {
    await _supabase.from('moments_contexts').delete().match({'id': key, 'owner_id': ownerId});
  }

  // -- SUPPRESSIONS --
  static Future<void> deleteProfile(String profileId, String ownerId) async {
    await _supabase.from('profiles').delete().match({'id': profileId, 'owner_id': ownerId});
    // Supprimer aussi les consommations liées à ce profil
    await _supabase.from('consumptions').delete().match({'profile_id': profileId, 'owner_id': ownerId});
  }

  static Future<void> deleteConsumption(String id, String ownerId) async {
    await _supabase.from('consumptions').delete().match({'id': id, 'owner_id': ownerId});
  }

  static Future<void> deleteAllUserData(String ownerId) async {
    await _supabase.from('profiles').delete().eq('owner_id', ownerId);
    await _supabase.from('consumptions').delete().eq('owner_id', ownerId);
    await _supabase.from('moments_contexts').delete().eq('owner_id', ownerId);
  }

  // -- RÉCUPÉRATION FILTRÉE --
  static Future<Map<String, dynamic>> fetchAllData(String ownerId) async {
    final profileData = await _supabase.from('profiles').select().eq('owner_id', ownerId);
    final consumptionData = await _supabase.from('consumptions').select().eq('owner_id', ownerId);
    final contextData = await _supabase.from('moments_contexts').select().eq('owner_id', ownerId);

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
        date: DateTime.parse(json['date']).toLocal(),
        moment: json['moment'] ?? 'Soir',
        type: json['type'],
        volume: json['volume'],
        degree: (json['degree'] as num).toDouble(),
        userId: json['profile_id'] ?? '1',
      );
    }).toList().cast<Consumption>();

    final contexts = { for (var item in (contextData as List)) item['id'].toString() : item['content']?.toString() ?? '' };

    return {
      'profiles': profiles,
      'consumptions': consumptions,
      'contexts': contexts,
    };
  }
}

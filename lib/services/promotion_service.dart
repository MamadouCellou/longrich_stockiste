import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/promotion.dart';
import '../models/promotion_challenge.dart';
import '../models/challenge_product.dart';

class PromotionService {
  static final _client = Supabase.instance.client;

  /// 🔹 Récupérer toutes les promotions avec challenges et produits
  static Future<List<Promotion>> getPromotions() async {
    try {
      final response = await _client
          .from('promotion_full_json')
          .select()
          .order('start_date', ascending: true);

      // 🔹 Affichage pour debug
      print("DEBUG - raw response from promotion_full_json: $response");

      // Vérifie que les données ne sont pas nulles
      if (response == null) {
        throw Exception('Aucune donnée reçue de Supabase');
      }

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Promotion.fromJson(json)).toList();
    } catch (e, st) {
      print("StackTrace: $st");
      throw Exception('Erreur récupération promotions : $e');
    }
  }



  /// 🔹 Ajouter une promotion avec challenges et produits
  static Future<void> addPromotion(Map<String, dynamic> promoData) async {
    try {
      // 1️⃣ Créer la promotion
      final response = await _client.from('promotions').insert({
        'name': promoData['name'],
        'image_url': promoData['image_url'],
        'start_date': promoData['start_date'],
        'end_date': promoData['end_date'],
      }).select();

      final promoId = response[0]['id'] as String;

      // 2️⃣ Ajouter les challenges
      final challenges = promoData['challenges'] as List<dynamic>;
      for (final c in challenges) {
        final challengeResponse = await _client.from('promotion_challenges').insert({
          'promotion_id': promoId,
          'pv_condition': c['pv_condition'],
        }).select();

        final challengeId = challengeResponse[0]['id'] as String;

        // 3️⃣ Ajouter les produits pour ce challenge
        final products = c['products'] as List<dynamic>;
        if (products.isNotEmpty) {
          final productInserts = products.map((p) => {
            'challenge_id': challengeId,
            'product_id': p['product_id'],
            'quantity': p['quantity'],
          }).toList();

          await _client.from('challenge_products').insert(productInserts);
        }
      }
    } catch (e) {
      throw Exception('Erreur ajout promotion : $e');
    }
  }

  /// 🔹 Mettre à jour une promotion avec challenges et produits
  static Future<void> updatePromotion(String promoId, Map<String, dynamic> promoData) async {
    try {
      // 1️⃣ Mettre à jour la promotion
      await _client.from('promotions').update({
        'name': promoData['name'],
        'image_url': promoData['image_url'],
        'start_date': promoData['start_date'],
        'end_date': promoData['end_date'],
      }).eq('id', promoId);

      // 2️⃣ Supprimer les anciens challenges et produits liés
      final oldChallenges = await _client.from('promotion_challenges')
          .select('id')
          .eq('promotion_id', promoId) as List<dynamic>;

      for (final c in oldChallenges) {
        await _client.from('challenge_products').delete()
            .eq('challenge_id', c['id']);
      }

      await _client.from('promotion_challenges').delete()
          .eq('promotion_id', promoId);

      // 3️⃣ Ajouter les nouveaux challenges et leurs produits
      final challenges = promoData['challenges'] as List<dynamic>;
      for (final c in challenges) {
        final challengeResponse = await _client.from('promotion_challenges').insert({
          'promotion_id': promoId,
          'pv_condition': c['pv_condition'],
        }).select();

        final challengeId = challengeResponse[0]['id'] as String;

        final products = c['products'] as List<dynamic>;
        if (products.isNotEmpty) {
          final productInserts = products.map((p) => {
            'challenge_id': challengeId,
            'product_id': p['product_id'],
            'quantity': p['quantity'],
          }).toList();
          await _client.from('challenge_products').insert(productInserts);
        }
      }
    } catch (e) {
      throw Exception('Erreur mise à jour promotion : $e');
    }
  }

  /// 🔹 Supprimer une promotion et tous ses challenges & produits
  static Future<void> deletePromotion(String promoId) async {
    try {
      // Supprimer produits
      final challenges = await _client.from('promotion_challenges')
          .select('id')
          .eq('promotion_id', promoId) as List<dynamic>;

      for (final c in challenges) {
        await _client.from('challenge_products').delete()
            .eq('challenge_id', c['id']);
      }

      // Supprimer challenges
      await _client.from('promotion_challenges').delete()
          .eq('promotion_id', promoId);

      // Supprimer promotion
      await _client.from('promotions').delete()
          .eq('id', promoId);
    } catch (e) {
      throw Exception('Erreur suppression promotion : $e');
    }
  }
}

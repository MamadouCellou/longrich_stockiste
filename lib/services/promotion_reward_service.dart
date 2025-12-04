// services/promotion_reward_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/purchase_promotion_reward.dart';
import '../models/promotion.dart';
import '../models/promotion_challenge.dart';
import '../models/challenge_product.dart';

class PromotionRewardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // 🔥 1. Récupère la promotion active via la vue JSON complète
  // ============================================================
  Future<List<Promotion>> getActivePromotions() async {
    final response = await _supabase.rpc('get_active_promotions');

    if (response == null) {
      print("Aucune promo actuve disponible !");
      return [];
    }

    final list = response as List<dynamic>;

    print("Pormotions trouvé(s) : ${list.length}");

    return list
        .map((p) => Promotion.fromJson(p as Map<String, dynamic>))
        .toList();

  }



  // =========================================================================
  // 🔥 2. Trouve automatiquement le challenge correspondant au total PV
  // =========================================================================
  PromotionChallenge? getMatchingChallenge(Promotion promotion, double totalPv) {
    final challenges = promotion.challenges;

    if (challenges.isEmpty) return null;

    // Trier décroissant pour prendre le challenge le plus haut applicable
    challenges.sort((a, b) => b.pvCondition.compareTo(a.pvCondition));

    for (final c in challenges) {
      if (totalPv >= c.pvCondition) return c;
    }

    return null;
  }

  // ========================================================================
  // 🔥 3. Retourne les produits promo sous forme prête pour purchase_items
  // ========================================================================
  List<Map<String, dynamic>> buildPromoItems(PromotionChallenge challenge) {
    return challenge.products.map((p) {
      return {
        "product_id": p.productId,
        "product_name": p.productName,
        "unit_price": 0, // Gratuit
        "unit_pv": 0,
        "quantity_total": p.quantity,
        "quantity_received": p.quantity,
        "quantity_missing": 0,
        "quantity_paid": 0,
        "quantity_remained": 0,
        "montant_total_du": 0,
        "montant_paid": 0,
        "montant_remaining": 0,
        "is_promo": true,
      };
    }).toList();
  }

  // =====================================================================
  // 🔥 4. Méthode principale : crée la récompense + retourne items promo
  // =====================================================================
  Future<Map<String, dynamic>?> getPromoReward({
    required double totalPv,
  }) async {
    // 1️⃣ Récupérer toutes les promotions actives
    final promotions = await getActivePromotions();
    if (promotions.isEmpty) return null;

    List<dynamic> matchedChallenges = [];
    List<dynamic> allPromoItems = [];

    // 2️⃣ Pour chaque promotion → chercher le challenge applicable
    for (final promo in promotions) {
      final challenge = getMatchingChallenge(promo, totalPv);
      if (challenge == null) continue;

      matchedChallenges.add({
        "promotion": promo,
        "challenge": challenge,
      });

      // 3️⃣ Construire les items promo pour ce challenge
      final promoItems = buildPromoItems(challenge);
      allPromoItems.addAll(promoItems);
    }

    // ⚠️ Aucun challenge trouvé parmi les promotions
    if (matchedChallenges.isEmpty) return null;

    return {
      "promotions": promotions,
      "challenges": matchedChallenges,
      "items": allPromoItems,
    };
  }


  // ============================================================================
  // 🔥 5. Version améliorée de createReward (pour ton ancienne table reward)
  // => OPTIONNEL. Tu peux continuer à l'utiliser. Ne casse rien.
  // ============================================================================
  Future<PurchasePromotionReward?> createReward({
    required String purchaseId,
    required double totalPv,
  }) async {
    final promoData = await getPromoReward(totalPv: totalPv);
    if (promoData == null) return null;

    final promo = promoData["promotion"] as Promotion;
    final challenge = promoData["challenge"] as PromotionChallenge;

    // ⏺️ Créer la récompense
    final rewardInsert = await _supabase
        .from('purchase_promotion_rewards')
        .insert({
      'purchase_id': purchaseId,
      'promotion_id': promo.promotionId,
      'challenge_id': challenge.challengeId,
      'total_pv': totalPv,
    })
        .select()
        .single();

    final rewardId = rewardInsert['id'] as String;

    // ⏺️ Ajouter les produits du challenge dans reward_products
    final rewardProducts = challenge.products.map((p) {
      return {
        "reward_id": rewardId,
        "product_id": p.productId,
        "quantity_total": p.quantity,
        "quantity_received": 0,
      };
    }).toList();

    if (rewardProducts.isNotEmpty) {
      await _supabase.from('reward_products').insert(rewardProducts);
    }

    return PurchasePromotionReward(
      id: rewardId,
      purchaseId: purchaseId,
      promotionId: promo.promotionId,
      challengeId: challenge.challengeId,
      totalPv: totalPv,
      createdAt: DateTime.now(),
    );
  }
}

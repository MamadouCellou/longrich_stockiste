// models/purchase_promotion_reward_model.dart

import 'package:longrich_stockiste/models/reward_product.dart';

class PurchasePromotionReward {
  final String id;
  final String purchaseId;
  final String promotionId;
  final String challengeId;
  final double totalPv;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<RewardProduct> products;

  PurchasePromotionReward({
    required this.id,
    required this.purchaseId,
    required this.promotionId,
    required this.challengeId,
    required this.totalPv,
    required this.createdAt,
    this.updatedAt,
    this.products = const [],
  });

  factory PurchasePromotionReward.fromJson(Map<String, dynamic> json) {
    return PurchasePromotionReward(
      id: json['id'] as String,
      purchaseId: json['purchase_id'] as String,
      promotionId: json['promotion_id'] as String,
      challengeId: json['challenge_id'] as String,
      totalPv: (json['total_pv'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      products: (json['products'] as List<dynamic>?)
          ?.map((e) => RewardProduct.fromJson(e))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'promotion_id': promotionId,
      'challenge_id': challengeId,
      'total_pv': totalPv,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

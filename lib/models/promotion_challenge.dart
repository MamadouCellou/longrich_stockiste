import 'challenge_product.dart';

class PromotionChallenge {
  final String challengeId;
  final int pvCondition;
  final List<ChallengeProduct> products;

  PromotionChallenge({
    required this.challengeId,
    required this.pvCondition,
    required this.products,
  });

  factory PromotionChallenge.fromJson(Map<String, dynamic> json) => PromotionChallenge(
    challengeId: json['challenge_id'] as String,
    pvCondition: json['pv_condition'] as int,
    products: (json['products'] as List?)
        ?.map((p) => ChallengeProduct.fromJson(p as Map<String, dynamic>))
        .toList()
        ?? [],
  );


  Map<String, dynamic> toJson() => {
    'challenge_id': challengeId,
    'pv_condition': pvCondition,
    'products': products.map((e) => e.toJson()).toList(),
  };

  PromotionChallenge copyWith({
    String? challengeId,
    int? pvCondition,
    List<ChallengeProduct>? products,
  }) =>
      PromotionChallenge(
        challengeId: challengeId ?? this.challengeId,
        pvCondition: pvCondition ?? this.pvCondition,
        products: products ?? this.products.map((e) => e.copyWith()).toList(),
      );
}

import 'promotion_challenge.dart';

class Promotion {
  final String promotionId;
  final String promotionName;
  final String promotionUrlImage;
  final DateTime startDate;
  final DateTime endDate;
  final List<PromotionChallenge> challenges;

  Promotion({
    required this.promotionId,
    required this.promotionName,
    required this.promotionUrlImage,
    required this.startDate,
    required this.endDate,
    required this.challenges,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
    promotionId: json['promotion_id'] as String,
    promotionName: json['promotion_name'] as String,
    promotionUrlImage: json['image_url'] as String,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    challenges: (json['challenges'] as List?)
        ?.map((e) => PromotionChallenge.fromJson(e as Map<String, dynamic>))
        .toList()
        ?? [],
  );


  Map<String, dynamic> toJson() => {
    'promotion_id': promotionId,
    'promotion_name': promotionName,
    'promotion_url_image': promotionUrlImage,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'challenges': challenges.map((e) => e.toJson()).toList(),
  };

  Promotion copyWith({
    String? promotionId,
    String? promotionName,
    String? promotionUrlImage,
    DateTime? startDate,
    DateTime? endDate,
    List<PromotionChallenge>? challenges,
  }) =>
      Promotion(
        promotionId: promotionId ?? this.promotionId,
        promotionName: promotionName ?? this.promotionName,
        promotionUrlImage: promotionUrlImage ?? this.promotionUrlImage,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        challenges: challenges ?? this.challenges.map((e) => e.copyWith()).toList(),
      );
}

// models/reward_product_model.dart

class RewardProduct {
  final String id;
  final String rewardId;
  final String productId;
  final String? productName;
  final int quantityTotal;
  final int quantityReceived;
  int get quantityRemaining => quantityTotal - quantityReceived;
  final DateTime createdAt;
  final DateTime? updatedAt;

  RewardProduct({
    required this.id,
    required this.rewardId,
    required this.productId,
    this.productName,
    required this.quantityTotal,
    required this.quantityReceived,
    required this.createdAt,
    this.updatedAt,
  });

  factory RewardProduct.fromJson(Map<String, dynamic> json) {
    return RewardProduct(
      id: json['id'] as String,
      rewardId: json['reward_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String?,
      quantityTotal: json['quantity_total'] ?? json['quantity'] ?? 0,
      quantityReceived: json['quantity_received'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt:
      json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reward_id': rewardId,
      'product_id': productId,
      'quantity_total': quantityTotal,
      'quantity_received': quantityReceived,
    };
  }
}

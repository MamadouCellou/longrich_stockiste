class ChallengeProduct {
  final String productId;
  final String productName;
  final int quantity;

  ChallengeProduct({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  factory ChallengeProduct.fromJson(Map<String, dynamic> json) => ChallengeProduct(
    productId: json['product_id'] as String,
    productName: json['product_name'] as String,
    quantity: json['quantity'] as int,
  );

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
  };

  ChallengeProduct copyWith({
    String? productId,
    String? productName,
    int? quantity,
  }) =>
      ChallengeProduct(
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        quantity: quantity ?? this.quantity,
      );
}

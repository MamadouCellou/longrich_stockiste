class PurchaseItem {
  final String? id;
  final String? purchaseId;
  final String productId;
  final String productName;
  final double unitPrice;
  final double unitPv;
  final int quantityTotal;
  final int quantityReceived;
  final int quantityMissing;
  final int quantityPaid;
  final bool isPromo; // 🔥 Nouveau champ

  const PurchaseItem({
    this.id,
    this.purchaseId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.unitPv,
    required this.quantityTotal,
    this.quantityReceived = 0,
    this.quantityMissing = 0,
    this.quantityPaid = 0,
    this.isPromo = false, // 🔥 valeur par défaut
  });

  // 🔹 Calculs dérivés
  double get montantTotalDu => unitPrice * quantityTotal;
  int get quantityRemained => quantityTotal - quantityPaid;
  double get montantPaid => unitPrice * quantityPaid;
  double get montantRemaining => montantTotalDu - montantPaid;

  // 🔹 Conversion depuis Map Supabase
  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'] as String?,
      purchaseId: map['purchase_id'] as String?,
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? '',
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      unitPv: (map['unit_pv'] as num?)?.toDouble() ?? 0,
      quantityTotal: map['quantity_total'] as int? ?? 0,
      quantityReceived: map['quantity_received'] as int? ?? 0,
      quantityMissing: map['quantity_missing'] as int? ?? 0,
      quantityPaid: map['quantity_paid'] as int? ?? 0,
      isPromo: map['is_promo'] == true, // 🔥 lecture stockée
    );
  }

  // 🔹 Conversion vers Map pour Supabase
  Map<String, dynamic> toMap() {
    return {
      if (id != null && id!.trim().isNotEmpty) 'id': id,
      if (purchaseId != null) 'purchase_id': purchaseId,
      'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'unit_pv': unitPv,
      'quantity_total': quantityTotal,
      'quantity_received': quantityReceived,
      'quantity_missing': quantityMissing,
      'quantity_paid': quantityPaid,
      'is_promo': isPromo, // 🔥 sauvegarde
    };
  }

  // 🔹 Copie avec modifications
  PurchaseItem copyWith({
    String? id,
    String? purchaseId,
    String? productId,
    String? productName,
    double? unitPrice,
    double? unitPv,
    int? quantityTotal,
    int? quantityReceived,
    int? quantityMissing,
    int? quantityPaid,
    bool? isPromo,
  }) {
    return PurchaseItem(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      unitPv: unitPv ?? this.unitPv,
      quantityTotal: quantityTotal ?? this.quantityTotal,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      quantityMissing: quantityMissing ?? this.quantityMissing,
      quantityPaid: quantityPaid ?? this.quantityPaid,
      isPromo: isPromo ?? this.isPromo, // 🔥 copie
    );
  }

  // 🔹 Pour debug
  @override
  String toString() {
    return '''
PurchaseItem{
  id: $id,
  purchaseId: $purchaseId,
  productName: $productName,
  unitPrice: $unitPrice,
  unitPv: $unitPv,
  quantityTotal: $quantityTotal,
  quantityReceived: $quantityReceived,
  quantityMissing: $quantityMissing,
  quantityPaid: $quantityPaid,
  isPromo: $isPromo,
  montantPaid: $montantPaid,
  montantRemaining: $montantRemaining
}''';
  }
}

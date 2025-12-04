class Product {
  final String? id; // nullable -> généré par Supabase
  final String name;
  final double pricePartner;
  final double pv;
  final String? description;
  final DateTime? createdAt;
  final String? categoryId; // Nouvelle propriété
  final bool isPromo; // 🔹 nouveau champ

  Product({
    this.id,
    required this.name,
    required this.pricePartner,
    required this.pv,
    this.description,
    this.createdAt,
    this.categoryId,
    this.isPromo = false, // valeur par défaut false
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: (map['id'] as String?)?.isNotEmpty == true ? map['id'] as String : null,
      name: map['name'] as String,
      pricePartner: (map['price_partner'] as num).toDouble(),
      pv: (map['pv'] as num).toDouble(),
      description: map['description'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      categoryId: map['category_id'] as String?, // récupère l'id de la catégorie
      isPromo: map['is_promo'] as bool? ?? false, // 🔹 récupère isPromo
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null && id!.trim().isNotEmpty) 'id': id,
      'name': name,
      'price_partner': pricePartner,
      'pv': pv,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
      'category_id': categoryId, // ajoute l'id de catégorie
      'is_promo': isPromo, // 🔹 ajoute isPromo
    };
  }
}

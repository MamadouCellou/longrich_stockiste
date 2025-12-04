import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';


extension StringNormalize on String {
  String normalize() => trim().toLowerCase();
}

class ProductService {
  final SupabaseClient supabase;

  ProductService({required this.supabase});

  /// 🔹 Récupérer tous les produits
  Future<List<Product>> getAllProducts() async {
    try {
      final res = await supabase
          .from('products')
          .select()
          .order('created_at', ascending: false);

      if (res != null) {
        return List<Map<String, dynamic>>.from(res)
            .map((m) => Product.fromMap(m))
            .toList();
      }
      return [];
    } catch (e) {
      print("Erreur getAllProducts: $e");
      return [];
    }
  }

  /// 🔹 Récupérer uniquement les produits promo
  Future<List<Product>> getPromoProducts() async {
    try {
      final res = await supabase
          .from('products')
          .select()
          .eq('is_promo', true) // 🔹 filtre uniquement les promos
          .order('created_at', ascending: false);

      if (res != null) {
        return List<Map<String, dynamic>>.from(res)
            .map((m) => Product.fromMap(m))
            .toList();
      }
      return [];
    } catch (e) {
      print("Erreur getPromoProducts: $e");
      return [];
    }
  }


  /// 🔹 Ajouter un produit
  Future<Product?> createProduct(Product product) async {
    try {
      final res = await supabase
          .from('products')
          .insert(product.toMap())
          .select()
          .maybeSingle();

      if (res != null) return Product.fromMap(res as Map<String, dynamic>);
      return null;
    } catch (e) {
      print("Erreur createProduct: $e");
      return null;
    }
  }

  /// 🔹 Mettre à jour un produit
  Future<Product?> updateProduct(Product product) async {
    if (product.id == null) return null;

    try {
      final res = await supabase
          .from('products')
          .update(product.toMap())
          .eq('id', product.id!) // safe grâce au check précédent
          .select()
          .maybeSingle();

      if (res != null) return Product.fromMap(res as Map<String, dynamic>);
      return null;
    } catch (e) {
      print("Erreur updateProduct: $e");
      return null;
    }
  }

  /// 🔹 Supprimer un produit
  Future<bool> deleteProduct(String id) async {
    try {
      final res = await supabase
          .from('products')
          .delete()
          .eq('id', id)
          .select(); // pour récupérer le résultat et savoir si supprimé

      return res != null && (res as List).isNotEmpty;
    } catch (e) {
      print("Erreur deleteProduct: $e");
      return false;
    }
  }

  /// 🔹 Stream Realtime pour tous les produits
  Stream<List<Product>> productsRealtime() {
    final controller = StreamController<List<Product>>();

    // Écoute les changements sur la table "products"
    final subscription = supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .listen((data) {
      final products = List<Map<String, dynamic>>.from(data)
          .map((m) => Product.fromMap(m))
          .toList();
      controller.add(products);
    });

    // Gestion de l'arrêt du stream
    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }

  /// 🔍 Recherche de produits par mot-clé (nom, description, prix, pv)
  Future<List<Product>> searchProducts(String keyword) async {
    try {
      final kw = keyword.trim().toLowerCase();

      // Vérifie si l'entrée est un nombre
      final parsedNumber = double.tryParse(kw);

      List<Map<String, dynamic>> res;

      if (parsedNumber != null) {
        // 🔹 Si c’est un nombre, on charge tous les produits (filtrage côté client)
        res = await supabase
            .from('products')
            .select()
            .order('created_at', ascending: false);
      } else {
        // 🔹 Recherche textuelle côté serveur
        res = await supabase
            .from('products')
            .select()
            .or('name.ilike.%$kw%, description.ilike.%$kw%')
            .order('created_at', ascending: false);
      }

      final products = List<Map<String, dynamic>>.from(res)
          .map((m) => Product.fromMap(m))
          .toList();

      // 🔹 Filtrage supplémentaire côté client (nom, description, prix, pv)
      return products.where((p) {
        final matchText = p.name.toLowerCase().contains(kw) ||
            (p.description?.toLowerCase().contains(kw) ?? false);

        final matchNumber = parsedNumber != null &&
            (p.pricePartner.toString().contains(kw) ||
                p.pv.toString().contains(kw));

        return matchText || matchNumber;
      }).toList();
    } catch (e) {
      print("Erreur searchProducts: $e");
      return [];
    }
  }

  /// 🔹 Dupliquer un produit (copie avec prix partenaire et PV à 0)
  /// 🔹 Dupliquer un produit et récupérer son ID
  Future<String?> duplicateProduct(String originalId) async {
    try {
      final result = await supabase.rpc(
        'duplicate_product',
        params: {'original_id': originalId},
      );

      // Supabase retourne ici l'UUID en String
      return result as String?;
    } catch (e) {
      print("Erreur duplicateProduct: $e");
      return null;
    }
  }

}

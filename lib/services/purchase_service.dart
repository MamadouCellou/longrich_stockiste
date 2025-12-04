import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchase.dart';

class PurchaseService {
  final SupabaseClient supabase;

  PurchaseService({required this.supabase});


  /// ✅ Créer une commande
  Future<Purchase?> createPurchase(Purchase purchase) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final res = await supabase
        .from('purchases')
        .insert({
      ...purchase.toMap(),
      'user_id': userId, // 🔹 Ajout de l'user
    })
        .select()
        .maybeSingle();

    if (res != null) return Purchase.fromMap(res as Map<String, dynamic>);
    return null;
  }

  /// ✅ Récupérer toutes les commandes de l'utilisateur
  Future<List<Purchase>> getAllPurchases() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final res = await supabase
        .from('purchases')
        .select('*')
        .eq('user_id', userId) // 🔹 Filtrer par utilisateur
        .order('created_at', ascending: false);

    if (res == null) return [];
    return List<Map<String, dynamic>>.from(res)
        .map((m) => Purchase.fromMap(m))
        .toList();
  }

  /// ✅ Récupérer une commande par ID (vérifie l'utilisateur)
  Future<Purchase?> getPurchaseById(String id) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final res = await supabase
        .from('purchases')
        .select('*')
        .eq('id', id)
        .eq('user_id', userId) // 🔹
        .maybeSingle();

    if (res != null) return Purchase.fromMap(res as Map<String, dynamic>);
    return null;
  }

  /// ✅ Mettre à jour une commande
  Future<Purchase?> updatePurchase(Purchase purchase) async {
    if (purchase.id == null) return null;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final res = await supabase
        .from('purchases')
        .update(purchase.toMap())
        .eq('id', purchase.id!)
        .eq('user_id', userId) // 🔹 Sécurité
        .select()
        .maybeSingle();

    if (res != null) return Purchase.fromMap(res as Map<String, dynamic>);
    return null;
  }

  /// ✅ Supprimer une commande
  Future<bool> deletePurchase(String id) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final res = await supabase
        .from('purchases')
        .delete()
        .eq('id', id)
        .eq('user_id', userId)
        .select();
    return res != null;
  }

  /// ✅ Stream realtime pour l'utilisateur
  Stream<List<Purchase>> purchasesRealtime() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return supabase
        .from('purchases_with_total')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId) // 🔹 Filtrer par utilisateur
        .map((data) {
      return List<Map<String, dynamic>>.from(data)
          .map((m) => Purchase.fromMap(m))
          .toList();
    });
  }

  /// 🔹 Marquer comme positionnée
  Future<bool> markPositioned(String purchaseId) async {
    try {
      await supabase
          .from('purchases')
          .update({'positioned': true})
          .eq('id', purchaseId);
      return true;
    } catch (e) {
      print("Erreur positionner: $e");
      return false;
    }
  }

  /// 🔹 Marquer comme depositionnée
  Future<bool> unmarkPositioned(String purchaseId) async {
    try {
      await supabase
          .from('purchases')
          .update({'positioned': false})
          .eq('id', purchaseId);
      return true;
    } catch (e) {
      print("Erreur de depositionnement: $e");
      return false;
    }
  }

  /// 🔹 Marquer comme validée
  Future<bool> markValidated(String purchaseId) async {
    try {
      await supabase
          .from('purchases')
          .update({'validated': true})
          .eq('id', purchaseId);
      return true;
    } catch (e) {
      print("Erreur validation: $e");
      return false;
    }
  }

  /// Annule la validation
  Future<bool> unmarkValidated(String purchaseId) async {
    try {
      await supabase
          .from('purchases')
          .update({'validated': false})
          .eq('id', purchaseId);
      return true;
    } catch (e) {
      print("Erreur d'invalidation: $e");
      return false;
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/custumer_account.dart';

class CustomerAccountService {
  final _client = Supabase.instance.client;

  Future<void> createAccount(CustomerAccount account) async {
    try {
      final response = await _client
          .from('customer_accounts')
          .insert(account.toJson())
          .select();

      if (response.isEmpty) {
        throw Exception("Échec de l’enregistrement du compte.");
      }
    } on PostgrestException catch (e) {
      // Gestion spécifique de la contrainte unique
      if (e.code == '23505') {
        throw Exception("Un compte avec ce type et ce numéro de carte existe déjà.");
      }
      // Pour toutes les autres erreurs Postgres

    } catch (e) {
      // Toutes les autres erreurs
      throw Exception("Erreur inconnue : $e");
    }
  }

  /// 🔹 Récupération des comptes appartenant à un user donné
  Future<List<CustomerAccount>> fetchAccounts(String userId) async {
    print("Le user_id : $userId");
    final response = await _client
        .from('customer_accounts')
        .select()
        .eq('user_id', userId) // ✅ filtre par user_id
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => CustomerAccount.fromJson(e))
        .toList();
  }

  /// 🔹 Stream temps réel des comptes du user connecté
  Stream<List<CustomerAccount>> streamAccounts(String userId) {
    return _client
        .from('customer_accounts')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId) // ✅ filtre aussi sur user_id
        .order('created_at', ascending: false)
        .map((event) => event.map((e) => CustomerAccount.fromJson(e)).toList());
  }


  Future<void> updateAccount(CustomerAccount account) async {
    if (account.id == null) throw Exception("ID du compte manquant");
    try {
      final response = await _client
          .from('customer_accounts')
          .update(account.toJson())
          .eq('id', account.id!)
          .select();

      if (response.isEmpty) {
        throw Exception("Échec de la mise à jour du compte.");
      }
    } catch (e) {
      throw Exception("Erreur mise à jour : $e");
    }
  }

  Future<void> deleteAccount(String id) async {
    try {
      final response = await _client
          .from('customer_accounts')
          .delete()
          .eq('id', id)
          .select();
      if (response.isEmpty) {
        throw Exception("Échec de la suppression du compte.");
      }
    } catch (e) {
      throw Exception("Erreur suppression : $e");
    }
  }
}

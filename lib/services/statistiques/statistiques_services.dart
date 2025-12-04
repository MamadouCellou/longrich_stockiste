import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

/// ✅ Récupère les stats payées pour le user connecté
Future<Map<String, dynamic>> getPaidPurchasesStats() async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('Utilisateur non connecté');
  }

  final response = await supabase
      .from('paid_purchases_summary')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  if (response == null) {
    return {
      'total_amount_paid': 0,
      'total_pv_paid': 0,
      'products': [],
    };
  }

  return {
    'total_amount_paid': response['total_amount_paid'] ?? 0,
    'total_pv_paid': response['total_pv_paid'] ?? 0,
    'products': List<Map<String, dynamic>>.from(response['products'] ?? []),
  };
}

/// ✅ Récupère les stats en dette pour le user connecté
Future<Map<String, dynamic>> getDebtPurchasesStats() async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('Utilisateur non connecté');
  }

  final response = await supabase
      .from('debt_purchases_summary')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  if (response == null) {
    return {
      'total_amount_due': 0,
      'total_pv_due': 0,
      'products': [],
    };
  }

  return {
    'total_amount_due': response['total_amount_due'] ?? 0,
    'total_pv_due': response['total_pv_due'] ?? 0,
    'products': List<Map<String, dynamic>>.from(response['products'] ?? []),
  };
}

/// ✅ Méthode combinée (si tu veux tout d’un coup)
Future<Map<String, dynamic>> getAllPurchasesStats() async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('Utilisateur non connecté');
  }

  final paidResponse = await supabase
      .from('paid_purchases_summary')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  final debtResponse = await supabase
      .from('debt_purchases_summary')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  return {
    'paid': {
      'total_amount_paid': paidResponse?['total_amount_paid'] ?? 0,
      'total_pv_paid': paidResponse?['total_pv_paid'] ?? 0,
      'products': List<Map<String, dynamic>>.from(paidResponse?['products'] ?? []),
    },
    'debt': {
      'total_amount_due': debtResponse?['total_amount_due'] ?? 0,
      'total_pv_due': debtResponse?['total_pv_due'] ?? 0,
      'products': List<Map<String, dynamic>>.from(debtResponse?['products'] ?? []),
    }
  };
}

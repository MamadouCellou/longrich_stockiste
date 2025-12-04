import 'package:flutter/material.dart';
import 'package:longrich_stockiste/services/statistiques/statistiques_services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/licence.dart';

/// 🧩 Service complet pour la gestion des licences Supabase
class LicenceService {
  final SupabaseClient _client = Supabase.instance.client;

  // ----------------------------------------------------
  // 🔹 CRÉATION D’UNE LICENCE
  // ----------------------------------------------------
  Future<LicenceModel?> createLicence(String code, DateTime expiresAt, {String? userId}) async {
    try {
      final response = await _client.from('licences').insert({
        'code': code,
        'user_id': userId,              // null si pas d’utilisateur au départ
        'expires_at': expiresAt.toIso8601String(),
        'used': false,
        'used_at': null,
      }).select().maybeSingle();

      if (response == null) return null;
      return LicenceModel.fromMap(response);
    } catch (e) {
      debugPrint("Erreur lors de la création de la licence : $e");
      return null;
    }
  }


  // ----------------------------------------------------
  // 🔹 RÉCUPÉRATION DES LICENCES (avec info utilisateur)
  // ----------------------------------------------------
  Future<List<LicenceModel>> getLicences() async {
    final data = await _client
        .from('licences')
        .select('*, users(email)')
        .order('created_at', ascending: false);

    return (data as List)
        .map((item) => LicenceModel.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  // ----------------------------------------------------
  // 🔹 SUPPRESSION D’UNE LICENCE
  // ----------------------------------------------------
  Future<void> deleteLicence(String id) async {
    await _client.from('licences').delete().eq('id', id);
  }

  // ----------------------------------------------------
  // 🔹 ÉCOUTE EN TEMPS RÉEL (avec user joint)
  // ----------------------------------------------------
  Stream<List<LicenceModel>> listenLicences() {
    final stream = _client
        .from('licences')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
        .map((r) => LicenceModel.fromMap(r as Map<String, dynamic>))
        .toList());

    return stream;
  }

// ----------------------------------------------------
// 🔹 STREAM de la licence d’un utilisateur en temps réel (broadcast)
// ----------------------------------------------------
  Stream<LicenceModel?> listenUserLicence(String userId) {
    return _client
        .from('licences')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
      if (rows.isEmpty) return null;
      return LicenceModel.fromMap(rows.first);
    })
    // 🔹 Transforme le stream en broadcast pour pouvoir le réécouter
        .asBroadcastStream();
  }


  // ----------------------------------------------------
  // 🔹 ATTRIBUER UNE LICENCE À UN UTILISATEUR
  // ----------------------------------------------------
  Future<void> assignLicence(String licenceId, String userId) async {
    await _client.from('licences').update({
      'user_id': userId,
      'used': true,
      'used_at': DateTime.now().toIso8601String(),
    }).eq('id', licenceId);
  }

  // ----------------------------------------------------
  // 🔹 VÉRIFIER SI UN CODE EST VALIDE
  // ----------------------------------------------------
  Future<bool> checkLicenceCode(String code) async {
    final result = await _client
        .from('licences')
        .select()
        .eq('code', code)
        .eq('used', false)
        .maybeSingle();

    return result != null;
  }

  // ----------------------------------------------------
  // 🔹 RPC : VALIDATION & UTILISATION D’UNE LICENCE
  // ----------------------------------------------------
  Future<bool> validateAndRedeem(String code, String userId) async {
    try {
      final result = await _client.rpc(
        'validate_and_redeem',
        params: {
          'p_code': code,
          'p_user': userId,
        },
      );

      if (result == null) return false;

      if (result is bool) return result;
      if (result is Map && result.containsKey('validate_and_redeem')) {
        return result['validate_and_redeem'] == true;
      }
      if (result is List && result.isNotEmpty) {
        final dynamic r = result.first;
        if (r is bool) return r;
        if (r is Map && r.containsKey('validate_and_redeem')) {
          return r['validate_and_redeem'] == true;
        }
      }

      return false;
    } catch (e) {
      print('❌ Erreur validateAndRedeem : $e');
      return false;
    }
  }

  // ----------------------------------------------------
  // 🔹 LICENCE LOCALE (session utilisateur)
  // ----------------------------------------------------
  Future<bool> hasLocalLicence() async {
    final session = _client.auth.currentSession;
    return session != null;
  }

  Future<void> assignLicenceToUser(String licenceId, String userId) async {
    await supabase.from('licences').update({
      'user_id': userId,
      'used': true,
      'used_at': DateTime.now().toIso8601String(),
    }).eq('id', licenceId);
  }

  Future<void> revokeLicence(String licenceId) async {
    await supabase.from('licences').update({
      'user_id': null,
      'used': false,
      'used_at': null,
    }).eq('id', licenceId);
  }

  Future<LicenceModel?> getLicenceByUserId(String userId) async {
    final res = await supabase.from('licences').select().eq('user_id', userId).maybeSingle();
    if (res == null) return null;
    return LicenceModel.fromMap(res);
  }

  Future<void> prolongLicence(String licenceId, int additionalDays) async {
    final licence = await getLicenceById(licenceId);
    if (licence == null) return;

    final newDate = licence.expiresAt.add(Duration(days: additionalDays));

    await supabase
        .from('licences')
        .update({'expires_at': newDate.toIso8601String()})
        .eq('id', licenceId);

    print("Licence prolongée jusqu’à $newDate ✅");
  }

  // 🧠 Récupérer une licence précise (celle qu’on veut prolonger)
  Future<LicenceModel?> getLicenceById(String licenceId) async {
    final data =
    await supabase.from('licences').select().eq('id', licenceId).maybeSingle();
    if (data == null) return null;
    return LicenceModel.fromMap(data);
  }

  Future<void> updateLicenceExpiry(String licenceId, DateTime newExpiry) async {
    final response = await supabase
        .from('licences')
        .update({'expires_at': newExpiry.toIso8601String()})
        .eq('id', licenceId);

    if (response.error != null) {
      throw Exception('Erreur lors de la mise à jour de la date : ${response.error!.message}');
    }
  }

}

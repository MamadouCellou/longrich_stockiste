import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _table = 'users';

  // =========================================================
  // 🔥 REALTIME : Stream utilisateur en temps réel
  // =========================================================
  Stream<UserModel?> getUserStream(String userId) {
    final controller = StreamController<UserModel?>();

    if (userId.isEmpty) {
      controller.add(null);
      return controller.stream;
    }

    getUserById(userId).then((user) => controller.add(user));


    // 2️⃣ Activer l'écoute en temps réel sur la table users
    final channel = _supabase.channel(
      'user-changes-$userId',
      opts: const RealtimeChannelConfig(
        self: false,
        ack: false,
      ),
    )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: _table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: userId,
        ),
        callback: (payload) {
          print("♻️ Mise à jour utilisateur détectée : $payload");

          if (payload.newRecord != null) {
            controller.add(UserModel.fromMap(payload.newRecord!));
          } else {
            // Si suppression → renvoyer null
            controller.add(null);
          }
        },
      )
      ..subscribe();

    // 3️⃣ Cleanup
    controller.onCancel = () {
      _supabase.removeChannel(channel);
    };

    return controller.stream;
  }


  // =========================================================
  // 🔹 CRUD Utilisateur
  // =========================================================

  Future<UserModel?> createUser(UserModel user) async {
    final res = await _supabase.from(_table).insert(user.toMap()).select();
    if (res.isNotEmpty) {
      return UserModel.fromMap(res[0]);
    }
    return null;
  }

  Future<UserModel?> getUserById(String id) async {
    final res = await _supabase.from(_table).select().eq('id', id).maybeSingle();
    if (res != null) return UserModel.fromMap(res);
    return null;
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final res = await _supabase.from(_table).select().eq('email', email).maybeSingle();
    if (res == null) return null;
    return UserModel.fromMap(res);
  }

  Future<UserModel?> updateUser(UserModel user) async {
    final res = await _supabase
        .from(_table)
        .update(user.toMap())
        .eq('id', user.id)
        .select();

    if (res.isNotEmpty) return UserModel.fromMap(res[0]);

    return null;
  }

  Future<bool> deleteUser(String id) async {
    final res = await _supabase.from(_table).delete().eq('id', id);
    return res != null;
  }

  Future<List<UserModel>> getAllUsers() async {
    final res = await _supabase.from(_table).select();
    return (res as List).map((e) => UserModel.fromMap(e)).toList();
  }

  // =========================================================
  // 🔹 Gestion du FCM Token
  // =========================================================

  Future<void> updateFcmToken(String userId, String fcmToken) async {
    await _supabase
        .from(_table)
        .update({'fcm_token': fcmToken}).eq('id', userId);
  }

  Future<String?> getFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      print("🔔 FCM Token: $token");
      return token;
    } catch (e) {
      print("Erreur récupération FCM token: $e");
      return null;
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  // ─────────────────────────────────────────────
  // 🔐 SIGN UP (Email + MDP)
  // ─────────────────────────────────────────────
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      return res.user; // retour identique à Firebase
    } on AuthException catch (e) {
      print("Erreur signUp Supabase : ${e.message}");
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // 🔐 SIGN IN (Email + MDP)
  // ─────────────────────────────────────────────
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return res.user;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (_) {
      throw const AuthException(
        "Une erreur inconnue est survenue.",
      );
    }
  }

  // ─────────────────────────────────────────────
  // 🔵 GOOGLE LOGIN (OAuth)
  // ─────────────────────────────────────────────
  /*Future<User?> signInWithGoogle() async {
    try {
      /// IMPORTANT :
      /// Pour mobile :
      /// - créer provider dans Supabase
      /// - configurer URL de redirection
      final res = await _supabase.auth.signInWithOAuth(
        Provider.google,
        redirectTo: "io.supabase.flutter://callback",
      );

      // ⚠️ En Supabase, signInWithOAuth ne retourne PAS user directement !
      // Le user revient automatiquement via auth.onAuthStateChange()

      return _supabase.auth.currentUser;
    } catch (e) {
      print("Erreur login Google Supabase : $e");
      return null;
    }
  }*/

  // ─────────────────────────────────────────────
  // 🔐 RÉINITIALISATION MOT DE PASSE
  // ─────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      print("Erreur reset password Supabase: $e");
    }
  }

  // ─────────────────────────────────────────────
  // 🚪 SIGN OUT
  // ─────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      print("Erreur logout Supabase : $e");
    }
  }

  // ─────────────────────────────────────────────
  // ❌ SUPPRESSION COMPTE
  // ─────────────────────────────────────────────
  Future<bool> deleteAccount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase.auth.admin.deleteUser(user.id);

      return true;
    } catch (e) {
      print("Erreur suppression compte Supabase : $e");
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // 🔥 Sauvegarde du FCM Token dans Supabase
  // ─────────────────────────────────────────────
  Future<void> saveFcmToken(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('users').update({
      'fcm_token': token,
    }).eq('id', user.id);
  }
}

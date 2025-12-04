import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../pages/login_page.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';

class UserController extends GetxController {
  // -----------------------------------------------------------
  // 🔥 OBSERVABLES
  // -----------------------------------------------------------
  Rxn<UserModel> currentUser = Rxn<UserModel>();
  RxBool isLoadingUser = false.obs;

  StreamSubscription<UserModel?>? _userSubscription;

  final _supabase = Supabase.instance.client;

  // -----------------------------------------------------------
  // 🏁 INIT
  // -----------------------------------------------------------
  @override
  void onInit() {
    super.onInit();
    _restoreUserFromLocal();
    _listenSupabaseAuth();
  }

  // -----------------------------------------------------------
  // 📌 1) Restaurer utilisateur local (instantané)
  // -----------------------------------------------------------

  Future<void> _restoreUserFromLocal() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonString = prefs.getString("local_user");
    if (jsonString != null) {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      currentUser.value = UserModel.fromJson(data);
      print("📦 Utilisateur restauré depuis local storage");
    }
  }
  // -----------------------------------------------------------
  // 📌 2) Écouter login/logout Supabase
  // -----------------------------------------------------------
  void _listenSupabaseAuth() {
    _supabase.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      if (session == null) {
        print("🚪 Déconnexion détectée");
        clearUser();
      } else {
        print("🔐 Connexion détectée : ${session.user.id}");
        loadUser(session.user.id);
      }
    });
  }

  // -----------------------------------------------------------
  // 🔥 Charger l’utilisateur et activer le realtime
  // -----------------------------------------------------------
  Future<void> loadUser(String userId) async {
    isLoadingUser.value = true;

    // Stop previous stream
    _userSubscription?.cancel();

    // Charger depuis la DB
    final user = await UserService().getUserById(userId);

    if (user != null) {
      _setUser(user);
    }

    // Ecoute temps réel
    _userSubscription =
        UserService().getUserStream(userId).listen((updatedUser) {
          if (updatedUser != null) {
            print("♻️ User mis à jour en realtime");
            _setUser(updatedUser);
          }
        });

    isLoadingUser.value = false;
  }

  // -----------------------------------------------------------
  // ✨ Setter centralisé (stockage local + observable)
  // -----------------------------------------------------------
  Future<void> _setUser(UserModel user) async {
    currentUser.value = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("local_user", jsonEncode(user.toJson()));

    update();
  }

  // -----------------------------------------------------------
  // 🧹 Supprimer toutes infos utilisateur
  // -----------------------------------------------------------
  Future<void> clearUser() async {
    _userSubscription?.cancel();
    currentUser.value = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("local_user");

    update();
  }

  // -----------------------------------------------------------
  // 🔁 Mise à jour user
  // -----------------------------------------------------------
  Future<void> updateUser(UserModel user) async {
    await UserService().updateUser(user);
    await _setUser(user);
  }

  // -----------------------------------------------------------
  // ❌ LOGOUT COMPLET
  // -----------------------------------------------------------

  void logout(BuildContext context) async {
    try {
      Get.offAll(LoginPage());
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('licence_code'); // 🔹 tu peux même vider la licence
      await Supabase.instance.client.auth.signOut();
      await clearUser();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la déconnexion")),
      );
    }
  }

  // -----------------------------------------------------------
  // ✔️ GETTERS PRATIQUES
  // -----------------------------------------------------------
  String get userId => currentUser.value?.id ?? "";
  String get nom => currentUser.value?.nom ?? "";
  String get prenom => currentUser.value?.prenom ?? "";
  String get fullName => "$prenom $nom";
  String get email => currentUser.value?.email ?? "";
  String get telephone => currentUser.value?.tel ?? "";
  String get matricule => currentUser.value?.matricule ?? "";
  bool get isAdmin => currentUser.value?.isAdmin ?? false;
  String get confirmCode => currentUser.value?.confirmCode ?? "";
}

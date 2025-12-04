import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/user_service.dart';
import '../models/user_model.dart';
import '../utils/snackbars.dart';
import '../widgets/code_form_widget.dart';
import '../utils/utils.dart';
import '../pages/login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final UserService _userService = UserService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _telController = TextEditingController();
  final _adresseController = TextEditingController();
  final _matriculeController = TextEditingController();
  final _codeController = TextEditingController();

  DateTime? _dateNaissance;
  bool inputTelValidation = false;

  bool _loading = false;
  int _currentStep = 0;

  // ---------------- SIGN UP ----------------
  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (!_allFieldsFilled()) {
      showErrorSnackbar(
          context: context, message: "Veuillez remplir tous les champs.");
      return;
    }

    if (!inputTelValidation) {
      showErrorSnackbar(
          context: context, message: "Numéro de téléphone invalide.");
      return;
    }

    if (!_isValidEmail(email)) {
      showErrorSnackbar(context: context, message: "Email invalide.");
      return;
    }

    if (password.length < 6) {
      showErrorSnackbar(context: context, message: "Mot de passe trop court.");
      return;
    }

    if (password != confirmPassword) {
      showErrorSnackbar(
          context: context, message: "Les mots de passe ne correspondent pas.");
      return;
    }

    setState(() => _loading = true);

    try {
      final authRes =
          await _supabase.auth.signUp(email: email, password: password);

      final user = authRes.user;
      if (user == null) throw Exception("Erreur d'inscription.");

      await _saveFcmToken();

      final userModel = UserModel(
        id: user.id,
        nom: _nomController.text.trim(),
        prenom: _prenomController.text.trim(),
        email: email,
        tel: _telController.text.trim(),
        adresse: _adresseController.text.trim(),
        matricule: _matriculeController.text.trim(),
        dateNaissance: _dateNaissance,
        fcmToken: null,
        confirmCode: _codeController.text.trim(),
        isAdmin: false,
      );

      await _userService.createUser(userModel);

      showInfoSnackbar(
          context: context,
          message: "Inscription réussie. Vérifiez vos emails.");
      Get.offAll(() => const LoginPage());
    } catch (e) {
      showErrorSnackbar(context: context, message: "Erreur : $e");
    }

    if (mounted) setState(() => _loading = false);
  }

  // ---- save token ----
  Future<void> _saveFcmToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    final user = _supabase.auth.currentUser;

    if (token != null && user != null) {
      await _supabase
          .from('users')
          .update({'fcm_token': token}).eq('id', user.id);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _allFieldsFilled() {
    return _nomController.text.isNotEmpty &&
        _prenomController.text.isNotEmpty &&
        _telController.text.isNotEmpty &&
        _adresseController.text.isNotEmpty &&
        _matriculeController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _codeController.text.isNotEmpty &&
        _dateNaissance != null;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onWillPop(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Inscription"),
        ),
        body: _buildStepperForm(),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Abandonner l'inscription"),
        content: const Text(
            "Êtes-vous sûr(e) de vouloir quitter ? Toutes les données entrées seront perdues."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text("Non"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Oui, quitter"),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  Widget _buildStepperForm() {
    return Stepper(
      currentStep: _currentStep,
      type: StepperType.vertical,

      // --- Bouton CONTINUE ---
      onStepContinue: () async {
        if (_currentStep == 2) {
          // dernière étape → inscription
          await _signUp();
        } else {
          setState(() => _currentStep++);
        }
      },

      // --- Bouton CANCEL ---
      onStepCancel: () {
        if (_currentStep > 0) {
          setState(() => _currentStep--);
        } else {
          Get.off(() => const LoginPage());
        }
      },

      controlsBuilder: (context, details) {
        final isLastStep = _currentStep == 2;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ---- BOUTON PRÉCÉDENT ----
            ElevatedButton(
              onPressed: _currentStep == 0 ? null : details.onStepCancel,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: const Text("Précédent"),
            ),

            // ---- BOUTON SUIVANT / S'INSCRIRE ----
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: ElevatedButton(
                onPressed: details.onStepContinue,
                child: Text(isLastStep ? "S'inscrire" : "Suivant"),
              ),
            ),
          ],
        );
      },

      steps: [
        Step(
          title: const Text("Infos personnelles"),
          isActive: _currentStep >= 0,
          content: Column(
            children: [
              TextField(
                  controller: _nomController,
                  decoration: const InputDecoration(labelText: "Nom")),
              TextField(
                  controller: _prenomController,
                  decoration: const InputDecoration(labelText: "Prénom")),
              const SizedBox(height: 20),
              InternationalPhoneNumberInput(
                onInputChanged: (PhoneNumber number) {
                  // Tu peux garder vide ou logger si tu veux
                },
                onInputValidated: (bool value) {
                  setState(() => inputTelValidation = value); // ✅ vrai ou faux
                },
                countries: COUNTRIES_CODES,
                searchBoxDecoration: const InputDecoration(labelText: "Recherchez par pays"),
                selectorConfig: const SelectorConfig(
                  selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                ),
                textFieldController: _telController,
                inputDecoration: InputDecoration(
                  labelText: "Numéro de téléphone",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  errorText: _telController.text.isEmpty
                      ? null
                      : !inputTelValidation
                      ? "Numéro invalide"
                      : null,
                ),
                errorMessage: "Numéro invalide",
              ),
              const SizedBox(height: 5),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _dateNaissance = date);
                  }
                },
                child: AbsorbPointer(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: "Date de naissance",
                      hintText: "Choisir votre date de naissance",
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    controller: TextEditingController(
                      text: _dateNaissance == null
                          ? ''
                          : _dateNaissance!.toLocal().toString().split(' ')[0],
                    ),
                    readOnly: true,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              TextField(
                  controller: _adresseController,
                  decoration: const InputDecoration(labelText: "Adresse")),
              const SizedBox(height: 15),
              CodeFormField(
                  controller: _matriculeController,
                  label: "Matricule",
                  isStockiste: true,
                  maxLength: 6),
            ],
          ),
        ),
        Step(
          title: const Text("Identifiants"),
          isActive: _currentStep >= 1,
          content: Column(
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  errorText: _emailController.text.isEmpty
                      ? null
                      : !_isValidEmail(_emailController.text)
                      ? "Adresse email invalide"
                      : null,
                  suffixIcon: _emailController.text.isEmpty
                      ? null
                      : _isValidEmail(_emailController.text)
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.error, color: Colors.red),
                ),
                onChanged: (_) {
                  setState(() {}); // ✅ Met à jour la vérification en direct
                },
              ),

              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Mot de passe",
                  errorText: _passwordController.text.isEmpty
                      ? null
                      : _passwordController.text.length < 6
                      ? "Le mot de passe doit contenir au moins 6 caractères"
                      : null,
                  suffixIcon: _passwordController.text.isEmpty
                      ? null
                      : _passwordController.text.length >= 6
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.error, color: Colors.red),
                ),
                onChanged: (_) {
                  setState(() {}); // ✅ Vérifie et met à jour en direct
                },
              ),

              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Confirmer le mot de passe",
                  errorText: _confirmPasswordController.text.isEmpty
                      ? null
                      : _confirmPasswordController.text != _passwordController.text
                      ? "Les mots de passe ne correspondent pas"
                      : null,
                ),
                onChanged: (_) {
                  setState(() {}); // ✅ Met à jour la vérification en direct
                },
              ),
              const SizedBox(height: 10),
              if (_confirmPasswordController.text.isNotEmpty &&
                  _confirmPasswordController.text == _passwordController.text)
                Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 5),
                    Text(
                      "Les mots de passe correspondent ✔",
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Step(
          title: const Text("Code de confirmation"),
          isActive: _currentStep >= 2,
          content: Column(
            children: [
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: "Code de confirmation"),
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
              const SizedBox(height: 10),
              const Text(
                "Ce code sera utilisé plus tard pour les validations et positionnements de commandes.",
              ),
            ],
          ),
        ),
      ],
    );
  }
}

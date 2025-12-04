import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:longrich_stockiste/pages/signup_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import '../utils/snackbars.dart';
import 'licence_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final UserService _userService = UserService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _passwordVisible = false;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _loading = true);

    try {
      final res = await _supabase.auth
          .signInWithPassword(email: email, password: password);

      final user = res.user;

      if (user == null) {
        showErrorSnackbar(
            context: context, message: "Email ou mot de passe incorrect.");
        return;
      }

      final userModel = await _userService.getUserById(user.id);

      if (userModel == null) {
        showErrorSnackbar(
            context: context, message: "Utilisateur introuvable.");
        return;
      }

      Get.offAll(() =>
          UserLicencePage(userId: userModel.id, userPrenom: userModel.prenom));
    } on AuthApiException catch (e) {
      String errorMessage = "Erreur de connexion (${e.statusCode}).";

      switch (e.code) {
        case "invalid_credentials":
          errorMessage = "Email ou mot de passe incorrect.";
          break;
        case "email_not_confirmed":
          errorMessage = "Veuillez confirmer votre email.";
          break;
        case "invalid_email":
          errorMessage = "Format d'email invalide.";
          break;
        default:
          print("Erreur auth: $e");
          errorMessage = e.message ?? "Erreur inconnue.";
      }

      showErrorSnackbar(context: context, message: errorMessage);
    } catch (e) {
      print("Erreur inattendue: $e");
      showErrorSnackbar(
        context: context,
        message: "Erreur réseau. Vérifiez votre connexion.",
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Connexion"),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 10),

                // 📨 Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Veuillez entrer votre email.";
                    }
                    if (!value.contains("@") || !value.contains(".")) {
                      return "Entrez un email valide.";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 15),

                // 🔐 Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    labelText: "Mot de passe",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),

                    // 👁 Icône afficher / masquer
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Veuillez entrer votre mot de passe.";
                    }
                    if (value.length < 6) {
                      return "Le mot de passe doit contenir au moins 6 caractères.";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 25),

                // 🔵 Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _loading ? "Connexion..." : "Se connecter",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 🔗 SignUp link
                TextButton(
                  onPressed: () => Get.to(() => SignupPage()),
                  child: const Text(
                    "Pas encore de compte ? S'inscrire",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: () => showResetPasswordSheet(context),
                  child: const Text(
                    "Mot de passe oublié ?",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final _resetFormKey = GlobalKey<FormState>();
  final _resetEmailController = TextEditingController();

  bool _sendingReset = false;
  Map<String, DateTime> _resetCooldown = {};

  void showResetPasswordSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    _resetEmailController.text = _emailController.text;

    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: theme.dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        "Réinitialiser le mot de passe",
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Form(
                        key: _resetFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _resetEmailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: "Email",
                                prefixIcon: Icon(Icons.email,
                                    color: colorScheme.primary),
                                filled: true,
                                fillColor: theme.canvasColor.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Veuillez entrer votre email";
                                }
                                if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$")
                                    .hasMatch(value)) {
                                  return "Email invalide";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _sendingReset
                                  ? null
                                  : () async {
                                      final email =
                                          _resetEmailController.text.trim();

                                      if (!(_resetFormKey.currentState
                                              ?.validate() ??
                                          false)) {
                                        return;
                                      }

                                      // 🟡 Cooldown anti spam
                                      if (_resetCooldown.containsKey(email)) {
                                        final last = _resetCooldown[email]!;
                                        final since = DateTime.now()
                                            .difference(last)
                                            .inSeconds;

                                        if (since < 120) {
                                          Navigator.pop(context);
                                          showErrorSnackbar(
                                            context: context,
                                            message:
                                                "Veuillez attendre 2 minutes avant de réessayer.",
                                          );
                                          return;
                                        }
                                      }

                                      setModalState(() => _sendingReset = true);

                                      try {
                                        // ✅ Vérifier si user existe dans la table "users"
                                        final userExists = await _userService
                                            .getUserByEmail(email);

                                        if (userExists == null) {
                                          Navigator.pop(context);
                                          showErrorSnackbar(
                                            context: context,
                                            message:
                                                "Aucun utilisateur trouvé avec cet email.",
                                          );
                                          return;
                                        }

                                        // 🔵 SUPABASE : Envoi du lien de reset
                                        await Supabase.instance.client.auth
                                            .resetPasswordForEmail(email);

                                        _resetCooldown[email] = DateTime.now();

                                        Navigator.pop(context);
                                        showSucessSnackbar(
                                          context: context,
                                          message:
                                              "Un lien de réinitialisation a été envoyé à votre email.",
                                        );
                                      } on AuthApiException catch (e) {
                                        Navigator.pop(context);
                                        showErrorSnackbar(
                                          context: context,
                                          message:
                                              e.message ?? "Erreur inconnue.",
                                        );
                                      } catch (e) {
                                        Navigator.pop(context);
                                        showErrorSnackbar(
                                          context: context,
                                          message: "Erreur réseau, réessayez.",
                                        );
                                      } finally {
                                        setModalState(
                                            () => _sendingReset = false);
                                      }
                                    },
                              child: Text(_sendingReset
                                  ? "Envoi en cours..."
                                  : "Envoyer le lien"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

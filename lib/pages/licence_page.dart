import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/user_controller.dart';
import '../utils/snackbars.dart';
import '../widgets/licence_code_formatter.dart';
import 'list_des_commandes.dart';

class UserLicencePage extends StatefulWidget {
  final String userId;
  final String userPrenom;
  const UserLicencePage({super.key, required this.userId, required this.userPrenom});

  @override
  State<UserLicencePage> createState() => _UserLicencePageState();
}

class _UserLicencePageState extends State<UserLicencePage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _codeController = TextEditingController();
  bool _loading = false;


  Future<void> _validateAndSaveLicence() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      showErrorSnackbar(context: context, message: "Veuillez entrer un code licence.");
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await supabase.rpc('validate_and_redeem', params: {
        'p_code': code,
        'p_user': widget.userId,
      });

      bool success = false;
      String message = 'Erreur inconnue';

      if (result is List && result.isNotEmpty) {
        final first = result.first;
        if (first is Map) {
          success = first['success'] == true;
          message = first['message'] ?? message;
        }
      }

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('licence_code', code);
        showSucessSnackbar(
          context: context,
          message: "Bienvenue Leader ${widget.userPrenom}",
        );


        Get.offAll(() => const PurchasesListPage());
      } else {
        showErrorSnackbar(context: context, message: message);
      }
    } catch (e) {
      showErrorSnackbar(context: context, message: "Erreur lors de la validation.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Activation de licence"), actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: IconButton(icon: Icon(Icons.logout),onPressed: () => UserController().logout(context),),
        )
      ],),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black, // garde ton style normal
                  fontSize: 16,
                ),
                children: [
                  const TextSpan(text: "Leader "),
                  TextSpan(
                    text: widget.userPrenom,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, // 🔥 le prénom en gras
                    ),
                  ),
                ],
              ),
            ),

            const Text(
              "Veuillez saisir votre code de licence pour activer votre compte.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              inputFormatters: [LicenceCodeFormatter(),
                LengthLimitingTextInputFormatter(19)
              ],
              decoration: const InputDecoration(
                labelText: "Code de licence",
                hintText: "XXXX-XXXX-XXXX-XXXX",
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loading ? null : _validateAndSaveLicence,
              icon: const Icon(Icons.verified_user),
              label: Text(_loading ? "Vérification..." : "Valider la licence"),
            ),
          ],
        ),
      ),
    );
  }
}

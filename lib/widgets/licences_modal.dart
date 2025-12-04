// lib/pages/licence_modal.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/licences_services.dart';

class LicenceModal extends StatefulWidget {
  final void Function() onValidated;
  const LicenceModal({super.key, required this.onValidated});

  @override
  State<LicenceModal> createState() => _LicenceModalState();
}

class _LicenceModalState extends State<LicenceModal> {
  final TextEditingController _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  Future<void> _validateCode() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = "Aucun utilisateur connecté.";
        _loading = false;
      });
      return;
    }

    final service = LicenceService();
    final success = await service.validateAndRedeem(_codeCtrl.text.trim(), user.id);

    if (success) {
      Navigator.pop(context);
      widget.onValidated();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Licence activée avec succès !')),
      );
    } else {
      setState(() {
        _errorMessage = "Code invalide ou expiré.";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "🔒 Vérification de la licence",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              "Veuillez entrer votre code de licence pour activer l'application.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeCtrl,
              decoration: InputDecoration(
                labelText: "Code licence (ex: ABCD-EFGH-IJKL-MNOP)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _errorMessage,
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 19,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _validateCode,
              icon: _loading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_loading ? 'Vérification...' : 'Valider'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

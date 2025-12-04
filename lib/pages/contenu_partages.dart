// FULL FILE: SharedContentPage with proper no-user handling

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/custumer_account.dart';
import '../services/customer_account_service.dart';
import '../services/cloudinary_service.dart';
import '../utils/utils.dart';
import '../widgets/code_form_widget.dart';

class SharedContentPage extends StatefulWidget {
  final String? sharedText;
  final List<String> sharedPaths;

  const SharedContentPage({
    super.key,
    required this.sharedText,
    required this.sharedPaths,
  });

  @override
  State<SharedContentPage> createState() => _SharedContentPageState();
}

class _SharedContentPageState extends State<SharedContentPage> {
  final CustomerAccountService _service = CustomerAccountService();

  List<CustomerAccount> _accounts = [];
  bool _loadingAccounts = true;

  // 🔥 Nouveau : savoir si aucun utilisateur n'est connecté
  bool _noUser = false;

  Map<String, bool> _uploadingMap = {};

  /// Assignation express
  bool _expressMode = true;
  bool uplodingExpres = false;
  final TextEditingController _prenomCtrl = TextEditingController();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _matriculeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();

    if (widget.sharedText != null && widget.sharedText!.trim().isNotEmpty) {
      final parsed = extraireNomPrenom(widget.sharedText!.trim());
      _prenomCtrl.text = parsed['prenom'] ?? "";
      _nomCtrl.text = parsed['nom'] ?? "";
    }

    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      setState(() {
        _noUser = true;
        _loadingAccounts = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Utilisateur non connecté. Connectez-vous et réessayez !"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Chargement des comptes
    final allAccounts = await _service.fetchAccounts(user.id);

    setState(() {
      _accounts = allAccounts
          .where((a) => a.imageUrl == null || a.imageUrl!.isEmpty)
          .toList();
      _loadingAccounts = false;
    });
  }

  Future<String?> _uploadImageToCloudinary(File file) async {
    try {
      return await CloudinaryService.uploadImageToCloudinary(
          file, 'preset_infos_compte');
    } catch (e) {
      print('Erreur upload Cloudinary: $e');
      return null;
    }
  }

  Future<void> _assignImageToAccount(
      CustomerAccount account, String imagePath) async {
    setState(() => _uploadingMap[account.id!] = true);

    final url = await _uploadImageToCloudinary(File(imagePath));
    if (url != null) {
      final updated = account.copyWith(
        imageUrl: url,
        updatedAt: DateTime.now(),
      );

      await _service.updateAccount(updated);
      await _loadAccounts();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Image assignée à ${account.firstName} ${account.lastName}')),
      );
    }

    setState(() => _uploadingMap[account.id!] = false);
  }


  /// --- ASSIGNATION EXPRESS ---
  Future<void> _submitExpressAccount() async {
    setState(() {
      uplodingExpres = true;
    });
    if (_nomCtrl.text.trim().isEmpty || _prenomCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le nom ou le prenom est obligatoire")),
      );
      return;
    }

    if (widget.sharedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucune image reçue")),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final url = await CloudinaryService.uploadImageToCloudinary(
      File(widget.sharedPaths.first),
      "preset_infos_compte",
    );

    final newAccount = CustomerAccount(
      id: null,
      user_id: user.id,
      firstName: _prenomCtrl.text.trim(),
      lastName: _nomCtrl.text.trim(),
      matricule: _matriculeCtrl.text.trim(),
      createdAt: DateTime.now(),
      imageUrl: url,
      country: "GN",
      gender: "masculin",
      birthDate: DateTime.parse("2000-01-01"),
      idNumber: generateUniqueIdNumber(),
      idType: "social_security",
      phone: "00000000",
      province: "",
      city: "",
      neighborhood: "",
    );


    print("Le compte avant : ${newAccount.toJson()}");

    await _service.createAccount(newAccount);

    await _loadAccounts();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Assignation express réussie !")),
    );
setState(() {
  _expressMode = false;
  uplodingExpres = false;

});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assignation comptes membre')),
      body: _noUser
          ? const Center(
              child: Text(
                "Aucun utilisateur connecté,\nconnectez-vous et réessayez !",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
            )
          : _loadingAccounts
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // EXPRESS MODE
                      if (_expressMode) ...[
                        const SizedBox(height: 20),
                        TextField(
                          controller: _prenomCtrl,
                          decoration:
                              const InputDecoration(labelText: "Prénom"),
                        ),
                        TextField(
                          controller: _nomCtrl,
                          decoration: const InputDecoration(labelText: "Nom"),
                        ),
                        const SizedBox(height: 10),
                        CodeFormField(
                          controller: _matriculeCtrl,
                          label: "Code du membre",
                          requis: false,
                        ),
                        const SizedBox(height: 20),
                        if (widget.sharedPaths.isNotEmpty)
                          ...widget.sharedPaths.map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Expanded(
                                  child: InteractiveViewer(
                                      panEnabled: true,
                                      minScale: 0.5,
                                      maxScale: 4.0,
                                      child: Image.file(File(p),
                                          height: 400, width: 400)),
                                ),
                              )),
                        ElevatedButton(
                          onPressed:
                              !uplodingExpres ? _submitExpressAccount : null,
                          child: Text(!uplodingExpres
                              ? "Assigner rapidement"
                              : "Assignation rapide en cours..."),
                        ),
                        const Divider(height: 30),
                      ],

                      // LISTE DES COMPTES
                      if (_accounts.isEmpty)
                        const Center(
                          child: Text(
                            "Tous les comptes ont déjà une image assignée.",
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Comptes non créés :",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            ..._accounts.map((acc) => Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: ListTile(
                                    title: Text(
                                        '${acc.firstName} ${acc.lastName}'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Téléphone: ${acc.phone ?? ""}'),
                                        if (acc.imageUrl != null &&
                                            acc.imageUrl!.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Image.network(acc.imageUrl!),
                                          ),
                                      ],
                                    ),
                                    trailing: _uploadingMap[acc.id] == true
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : ElevatedButton(
                                            onPressed: () async {
                                              if (widget
                                                  .sharedPaths.isNotEmpty) {
                                                await _assignImageToAccount(acc,
                                                    widget.sharedPaths.first);
                                              }
                                            },
                                            child: const Text('Assigner'),
                                          ),
                                  ),
                                )),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
}

/// Découpe un displayName en prénom + nom
Map<String, String> extraireNomPrenom(String displayName) {
  List<String> mots = displayName.trim().split(RegExp(r'\s+'));

  if (mots.length == 1) {
    return {'prenom': mots[0], 'nom': ''};
  }

  String nom = mots.removeLast();
  String prenom = mots.join(' ');

  return {'prenom': prenom, 'nom': nom};
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/licence.dart';
import '../services/licences_services.dart';
import '../services/user_service.dart';
import '../utils/snackbars.dart';
import '../widgets/licence_code_formatter.dart';

class LicenceActions {
  final LicenceService _service = LicenceService();
  final UserService _userService = UserService();

  /// Génère un code du type XXXX-XXXX-XXXX-XXXX
  String generateLicenceCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(4, (_) {
      return List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    }).join('-');
  }

  /// Boîte de dialogue : création d’une licence
  Future<void> showCreateDialog(BuildContext context) async {
    final TextEditingController codeController = TextEditingController();
    final TextEditingController daysController =
    TextEditingController(text: '30');

    bool isLoading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Créer une licence'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Code licence',
                  hintText: "XXXX-XXXX-XXXX-XXXX",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.autorenew),
                    tooltip: 'Générer un code',
                    onPressed: () {
                      codeController.text = generateLicenceCode();
                    },
                  ),
                ),
                inputFormatters: [
                  LicenceCodeFormatter(),
                  LengthLimitingTextInputFormatter(19),
                ],
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: daysController,
                decoration: const InputDecoration(
                  labelText: 'Durée (jours)',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () async {
                setState(() => isLoading = true);
                await createLicence(
                  context: context,
                  codeController: codeController,
                  daysController: daysController,
                );
                setState(() => isLoading = false);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.add_circle_outline),
              label: isLoading
                  ? const Text('Création en cours...')
                  : const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Création d’une nouvelle licence
  Future<void> createLicence({
    required BuildContext context,
    required TextEditingController codeController,
    required TextEditingController daysController,
  }) async {
    final code = codeController.text.trim();
    final days = int.tryParse(daysController.text.trim()) ?? 30;

    if (code.isEmpty) {
      showErrorSnackbar(
        context: context,
        message: "Veuillez entrer ou générer un code",
      );
      return;
    }

    final expiresAt = DateTime.now().add(Duration(days: days));
    await _service.createLicence(code, expiresAt);

    codeController.clear();
    daysController.text = '30';

    showSucessSnackbar(
      context: context,
      message: "Licence créée avec succès ✅",
    );
  }

  void showAssignLicenceDialog(BuildContext context, LicenceModel licence) {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Pour que le clavier ne masque pas le champ
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attribuer la licence ${licence.code}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: "Email de l’utilisateur",
                          hintText: "ex: exemple@gmail.com",
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez entrer un email';
                          }
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailRegex.hasMatch(value)) {
                            return 'Email invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: isLoading
                              ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.person_add_alt_1),
                          label: Text(
                            isLoading
                                ? "Attribution en cours..."
                                : "Attribuer",
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                            if (!formKey.currentState!.validate()) return;

                            setModalState(() => isLoading = true);

                            try {
                              final email = emailController.text.trim();
                              final user = await _userService.getUserByEmail(email);

                              if (user == null) {
                                showErrorSnackbar(
                                  context: context,
                                  message: "Utilisateur non trouvé ❌",
                                );
                                return;
                              }

                              final existingLicence =
                              await _service.getLicenceByUserId(user.id);

                              if (existingLicence != null) {
                                final dateExp = DateFormat('dd/MM/yyyy')
                                    .format(existingLicence.expiresAt);
                                final isExpired = existingLicence.expiresAt
                                    .isBefore(DateTime.now());

                                if (!isExpired) {
                                  showErrorSnackbar(
                                    context: context,
                                    message:
                                    "${user.prenom} ${user.nom} possède déjà une licence active (expire le $dateExp) ❗",
                                  );
                                  return;
                                } else {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Licence expirée"),
                                      content: Text(
                                        "${user.prenom} ${user.nom} avait une licence expirée le $dateExp.\nSouhaitez-vous la remplacer ?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text("Annuler"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text("Remplacer"),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                  await _service.revokeLicence(existingLicence.id);
                                }
                              }

                              await _service.assignLicenceToUser(licence.id, user.id);
                              showSucessSnackbar(
                                context: context,
                                message:
                                "Licence attribuée à ${user.prenom} ${user.nom} ✅",
                              );
                              Navigator.pop(context); // ferme le modal
                            } catch (e) {
                              showErrorSnackbar(
                                context: context,
                                message: "Erreur : $e",
                              );
                            } finally {
                              setModalState(() => isLoading = false);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }


  /// Révoquer une licence
  Future<void> revokeLicence(BuildContext context, String licenceId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Révocation en cours..."),
          ],
        ),
      ),
    );

    await _service.revokeLicence(licenceId);
    Navigator.pop(context);
    showSucessSnackbar(context: context, message: "Licence révoquée avec succès 🔁");
  }

  /// Supprimer une licence
  Future<void> deleteLicence(BuildContext context, String id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Suppression en cours..."),
          ],
        ),
      ),
    );

    await _service.deleteLicence(id);
    Navigator.pop(context);
    showSucessSnackbar(context: context, message: "Licence supprimée ✅");
  }

  /// Prolonger ou modifier la date d’expiration
  Future<void> showProlongDialog(
      BuildContext context,
      String licenceId,
      DateTime currentExpiry,
      String licenceCode,
      ) async {
    final formKey = GlobalKey<FormState>();
    final TextEditingController daysController = TextEditingController();
    DateTime selectedDate = currentExpiry;
    String selectedAction = 'prolong';
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Form(
                key: formKey,
                child: Wrap(
                  children: [
                    const Center(
                      child: Divider(indent: 120, endIndent: 120, thickness: 4),
                    ),
                    const SizedBox(height: 20),
                    Text('Licence : $licenceCode',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      'Expire le ${DateFormat('dd/MM/yyyy').format(currentExpiry)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Prolonger'),
                            value: 'prolong',
                            groupValue: selectedAction,
                            onChanged: (v) => setState(() => selectedAction = v!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Modifier la date'),
                            value: 'modify',
                            groupValue: selectedAction,
                            onChanged: (v) => setState(() => selectedAction = v!),
                          ),
                        ),
                      ],
                    ),

                    if (selectedAction == 'prolong') ...[
                      TextFormField(
                        controller: daysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de jours à ajouter',
                          prefixIcon: Icon(Icons.add_circle_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Entrez un nombre';
                          final n = int.tryParse(v);
                          if (n == null || n <= 0) return 'Nombre invalide';
                          return null;
                        },
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(Icons.date_range_outlined,
                              color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Nouvelle date : ${DateFormat('dd/MM/yyyy').format(selectedDate)}",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null)
                                setState(() => selectedDate = picked);
                            },
                            child: const Text("Modifier"),
                          ),
                        ],
                      ),
                    ],

                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          'Modification en cours...',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ),

                    const SizedBox(height: 25),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                          setState(() => isLoading = true);
                          if (selectedAction == 'prolong') {
                            if (!formKey.currentState!.validate()) return;
                            final days = int.parse(daysController.text);
                            await _service.prolongLicence(licenceId, days);
                            showSucessSnackbar(
                              context: context,
                              message: "Licence prolongée de $days jours ✅",
                            );
                          } else {
                            await _service.updateLicenceExpiry(
                                licenceId, selectedDate);
                            showSucessSnackbar(
                              context: context,
                              message:
                              "Nouvelle date d’expiration : ${DateFormat('dd/MM/yyyy').format(selectedDate)} ✅",
                            );
                          }
                          setState(() => isLoading = false);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Valider'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/licence.dart';
import '../models/user_model.dart';
import '../services/licences_services.dart';
import '../services/user_service.dart';
import '../utils/widget_en_image.dart';
import '../widgets/licence_code_formatter.dart';
import '../widgets/licences_actions.dart';

class LicencesPage extends StatefulWidget {
  const LicencesPage({super.key});

  @override
  State<LicencesPage> createState() => _LicencesPageState();
}

class _LicencesPageState extends State<LicencesPage> {
  final LicenceService _service = LicenceService();
  late Stream<List<LicenceModel>> _licencesStream;

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _daysController =
      TextEditingController(text: '30');
  final TextEditingController _emailController = TextEditingController();

  final _actions = LicenceActions();

  @override
  void initState() {
    super.initState();
    _licencesStream = _service.listenLicences();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Licences'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouvelle licence',
            onPressed: () => _actions.showCreateDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<LicenceModel>>(
        stream: _licencesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Erreur : ${snapshot.error}"));
          }

          final licences = snapshot.data ?? [];
          if (licences.isEmpty) {
            return const Center(child: Text("Aucune licence trouvée."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: licences.length,
            itemBuilder: (context, i) {
              final licence = licences[i];
              final expired = licence.expiresAt.isBefore(DateTime.now());
              final dateExp =
                  DateFormat('dd/MM/yyyy').format(licence.expiresAt);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(
                    expired ? Icons.error_outline : Icons.verified,
                    color: expired ? Colors.red : Colors.green,
                    size: 30,
                  ),
                  title: Text(
                    licence.code,
                    style: TextStyle(
                      color: expired ? Colors.redAccent : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expired ? 'Expirée le $dateExp' : 'Expire le $dateExp',
                        style: TextStyle(
                            color:
                                expired ? Colors.redAccent : Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      licence.userId != null
                          ? FutureBuilder<UserModel?>(
                              future: UserService()
                                  .getUserById(licence.userId!),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Text(
                                      'Chargement utilisateur...');
                                }
                                if (snapshot.hasError) {
                                  return const Text(
                                      'Erreur de chargement utilisateur ❌');
                                }
                                final user = snapshot.data;
                                if (user == null)
                                  return const Text('Utilisateur inconnu');
                                return Text(
                                    '👤 ${user.prenom} ${user.nom} (${user.email})');
                              },
                            )
                          : const Text('🕓 Non attribuée',
                              style: TextStyle(color: Colors.orange)),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Supprimer la licence"),
                            content: Text(
                                "Voulez-vous vraiment supprimer la licence ${licence.code} ?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Annuler"),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Supprimer"),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await _actions.deleteLicence(context, licence.id);
                        }
                      } else if (value == 'assign') {
                        _actions.showAssignLicenceDialog(context, licence);
                      }
                      else if (value == 'copie' && licence.userId != null) {
                        final user = await UserService().getUserById(licence.userId!);
                        if (user != null) {
                          await LicenceShare.copyLicenceToClipboard(
                            context: context,
                            licence: licence,
                            user: user,
                          );
                        }
                      }
                      else if (value == 'revoke') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Révoquer la licence"),
                            content: Text(
                                "Souhaitez-vous vraiment révoquer la licence ${licence.code} ?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Annuler"),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Révoquer"),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await _actions.revokeLicence(context, licence.id);
                        }
                      } else if (value == 'prolong') {
                        await _actions.showProlongDialog(
                          context,
                          licence.id,
                          licence.expiresAt,
                          licence.code,
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      if (licence.userId == null)
                        const PopupMenuItem(
                          value: 'assign',
                          child: Text('Attribuer'),
                        )
                      else
                        const PopupMenuItem(
                          value: 'revoke',
                          child: Text('Révoquer'),
                        ),
                      const PopupMenuItem(
                        value: 'prolong',
                        child: Text("Date d'expiration"),
                      ),
                      const PopupMenuItem(
                        value: 'copie',
                        child: Text('Copier le reçu'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Supprimer'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

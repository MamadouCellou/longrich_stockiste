import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/licence.dart';
import '../models/user_model.dart';
import 'copy_helper.dart';

class LicenceShare {
  /// Copier le reçu de licence sous forme de texte dans le presse-papiers
  static Future<void> copyLicenceToClipboard({
    required BuildContext context,
    required LicenceModel licence,
    required UserModel user,
  }) async {
    final String receipt = '''
Licence pour l’application Longrich Stockiste

Infos Licence :
Code licence : ${licence.code}
Date de création : ${DateFormat('dd – MM – yyyy HH:mm').format(licence.createdAt)}
Date d’expiration : ${DateFormat('dd – MM – yyyy HH:mm').format(licence.expiresAt)}

Utilisateur propriétaire :
Nom complet : ${user.prenom} ${user.nom}
Email : ${user.email}
Code stockiste : ${user.matricule ?? "N/A"}

Reçu généré le ${DateFormat('dd – MM – yyyy HH:mm').format(DateTime.now())} | L’équipe Longrich Stockiste
''';


    try {
        CopyHelper.copyText(
          context: context,
          text: receipt,
          name: "Reçu",
        );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la copie : $e'),
        ),
      );
    }
  }
}

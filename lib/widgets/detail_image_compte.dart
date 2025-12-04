import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart'; // NEW
import 'package:flutter/services.dart'; // pour Uint8List

import '../models/custumer_account.dart';
import '../services/download_service.dart';

/// 🔹 Affiche une fiche détaillée du compte client dans une BottomSheet
void showAccountModal(BuildContext context, CustomerAccount account) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      final mediaQuery = MediaQuery.of(context);
      return GestureDetector(
        onTap: () {}, // empêche la fermeture en touchant à l'intérieur
        child: Container(
          height: mediaQuery.size.height,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 🔹 Barre de titre
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 24),
                      Expanded(
                        child: Text(
                          '${account.firstName} ${account.lastName}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      Row(
                        children: [
                          // 🔹 Bouton de téléchargement
                          if (account.imageUrl != null &&
                              account.imageUrl!.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () async {
                                if (account.imageUrl != null && account.imageUrl!.isNotEmpty) {
                                  await DownloadService.downloadImage(
                                    context,
                                    account.imageUrl!,
                                    "du compte de ${account.firstName} ${account.lastName}",
                                  );
                                }
                              },
                            ),

                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 🔹 Image avec cache et zoom
                  if (account.imageUrl != null && account.imageUrl!.isNotEmpty)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: InteractiveViewer(
                          panEnabled: true,
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: CachedNetworkImage(
                            imageUrl: account.imageUrl!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Center(
                              child: Text(
                                'Erreur chargement de l\'image',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 🔹 Infos du compte
                  _infoRow('Matricule du membre', account.matricule!),
                  _infoRow('Téléphone', account.phone!),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// 🔸 Widget réutilisable pour une ligne d’information
Widget _infoRow(String label, String value) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

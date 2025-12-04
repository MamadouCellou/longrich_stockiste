import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'notification_service.dart';

class DownloadService {
  /// 🔹 Télécharger et enregistrer une image
  static Future<void> downloadImage(
      BuildContext context, String imageUrl, String fullName) async {
    try {
      // Permissions (Android)
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Permission refusée.")),
          );
          return;
        }
      }

      final dio = Dio();

      // Téléchargement avec progression
      final response = await dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) async {
          if (total > 0) {
            int progress = ((received / total) * 100).toInt();
            await NotificationService.showDownloadProgress(progress);
          }
        },
      );

      final Uint8List data = Uint8List.fromList(response.data!);

      // Sauvegarde dans la galerie
      final result = await ImageGallerySaverPlus.saveImage(
        data,
        name: "image_${DateTime.now().millisecondsSinceEpoch}",
        quality: 100,
      );

      // Succès
      await NotificationService.showDownloadSuccess(
        "Image $fullName enregistrée dans la galerie",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image enregistrée dans la galerie ✔️")),
      );
    } catch (e) {
      await NotificationService.showError(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur téléchargement : $e")),
      );
    }
  }
}

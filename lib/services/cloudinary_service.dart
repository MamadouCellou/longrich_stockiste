import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:crypto/crypto.dart';

import 'package:dio/dio.dart';

class CloudinaryService {
  static const String cloudName = "dzz2a3smq"; // Remplace par ton cloud name
  static const String apiKey = "775435895981613"; // Remplace par ta clé API
  static const String apiSecret =
      "R4pFl6sGi-Go6hjAWpKSWmwX31A"; // Remplace par ton secret API
  static const String dossier =
      "formations"; // Remplace par le nom de ton dossier

  Future<bool> checkIfResourceExistsFromUrl(String cloudinaryUrl) async {
    try {
      final publicId =
          extractPublicId(cloudinaryUrl); // Peut lancer une exception

      final expression = 'public_id:"$publicId"';
      final url =
          'https://api.cloudinary.com/v1_1/$cloudName/resources/search?expression=${Uri.encodeComponent(expression)}';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$apiKey:$apiSecret'))}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List resources = data['resources'];
        return resources.isNotEmpty;
      } else {
        print(
            '❌ Erreur lors de la requête Cloudinary : ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ URL invalide ou autre erreur : $e');
      return false;
    }
  }

  static Future<List<Map<String, String>>> fetchPowerPointFiles() async {
    final url =
        "https://api.cloudinary.com/v1_1/$cloudName/resources/search?expression=resource_type:raw AND folder:$dossier";

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$apiKey:$apiSecret'))}',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> resources = data['resources']; // Cast explicite

      // Filtrer uniquement les fichiers .pptx et convertir les valeurs en String
      List<Map<String, String>> pptxFiles = resources
          .where((file) => file['format'] == 'pptx')
          .map((file) => {
                'name': (file['public_id'] as String)
                    .split('/')
                    .last, // Converti en String
                'url': file['secure_url'] as String, // Converti en String
              })
          .toList();

      return pptxFiles;
    } else {
      throw Exception('Erreur lors de la récupération des fichiers PowerPoint');
    }
  }

  /// Supprime plusieurs ressources Cloudinary en les traitant une par une
  Future<void> deleteMultipleResources(List<String> urls) async {
    for (String url in urls) {
      await deleteCloudinaryResource(url);
    }
  }

  Future<void> deleteCloudinaryResource(String urlRess) async {
    String publicId = extractPublicId(urlRess);
    int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    String signatureRaw = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
    String signature = sha1.convert(utf8.encode(signatureRaw)).toString();

    String resourceType = detectResourceType(urlRess);

    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/destroy');

    print("L'id public : $publicId");
    print("Type de ressource : $resourceType");
    print("Signature : $signature");
    print("Timestamp : $timestamp");

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'public_id': publicId,
        'timestamp': timestamp.toString(),
        'api_key': apiKey,
        'signature': signature,
      },
    );

    if (response.statusCode == 200) {
      print('✅ Ressource supprimée : ${response.body}');
    } else {
      print('❌ Erreur suppression : ${response.statusCode}');
      print('Détails : ${response.body}');
    }
  }

  String detectResourceType(String cloudinaryUrl) {
    Uri uri = Uri.parse(cloudinaryUrl);
    List<String> segments = uri.pathSegments;

    if (segments.contains('image')) return 'image';
    if (segments.contains('video')) return 'video';
    if (segments.contains('raw')) return 'raw';

    // Par défaut image
    return 'image';
  }

  String extractPublicId(String cloudinaryUrl) {
    final uri = Uri.tryParse(cloudinaryUrl);
    if (uri == null || !cloudinaryUrl.contains('/upload/')) {
      throw Exception("URL invalide : 'upload' manquant");
    }

    final parts = cloudinaryUrl.split('/upload/');
    if (parts.length < 2) {
      throw Exception("URL invalide : impossible d’extraire le public_id");
    }

    final path = parts[1];
    final publicIdWithExtension = path.split('/').last;
    final publicId = publicIdWithExtension.split('.').first;

    return publicId;
  }

  // ☁️ Uploader une image simple sur Cloudinary et récupérer l'URL
  static Future<String?> uploadImageToCloudinary(
      File imageFile, String uploadPreset) async {
    const cloudName = "dzz2a3smq"; // Remplace avec ton Cloudinary cloud name
    final url =
        Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

    var request = http.MultipartRequest("POST", url);
    request.fields["upload_preset"] = uploadPreset;
    request.files
        .add(await http.MultipartFile.fromPath("file", imageFile.path));

    var response = await request.send();
    if (response.statusCode == 200 || response.statusCode == 201) {
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);
      return jsonResponse["secure_url"];
    } else {
      return null;
    }
  }

  /// ☁️ Uploader plusieurs images sur Cloudinary et récupérer les URLs
  static Future<List<String>> uploadImagesToCloudinary(
      List<File> imageFiles, String uploadPreset) async {
    List<String> imageUrls = [];
    for (var imageFile in imageFiles) {
      final url = await uploadImageToCloudinary(imageFile, uploadPreset);
      if (url != null) imageUrls.add(url);
    }
    return imageUrls;
  }

  /// ☁️ Uploader une image sur Cloudinary avec barre de progression
  static Future<String?> uploadImageToCloudinaryWithProgress(
    File file,
    String preset, {
    required void Function(int sentBytes, int totalBytes) onProgress,
  }) async {
    const cloudName = "dzz2a3smq"; // Remplace avec ton Cloudinary cloud name
    final url = "https://api.cloudinary.com/v1_1/$cloudName/image/upload";

    FormData data = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path),
      "upload_preset": preset,
    });

    Dio dio = Dio();
    Response response = await dio.post(
      url,
      data: data,
      onSendProgress: onProgress,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.data['secure_url'];
    } else {
      return null;
    }
  }
}

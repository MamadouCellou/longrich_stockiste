import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ville_api.dart';

/// Récupère la liste des villes (niveau 1) d’un pays
Future<List<VillesAPiModel>> fetchCities(String countryCode) async {
  final url =
      "https://mcellou.pythonanywhere.com/api/villes/?pays=$countryCode";

  print("Code pays reçu : $countryCode");

  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      if (jsonData is List) {
        return jsonData
            .map((e) => VillesAPiModel.fromJson(e))
            .toList();
      } else {
        throw Exception("Format inattendu des données reçues.");
      }
    } else {
      return [];
      throw Exception(
          "Erreur ${response.statusCode}: ${response.reasonPhrase}\nBody: ${response.body}");
    }
  } catch (e) {
    throw Exception("Erreur inconnue : $e");
  }
}

/// Récupère la liste des communes (niveau 2) d’une ville d’un pays
Future<List<VillesAPiModel>> fetchChildren(String countryCode, int villeId) async {
  final url =
      "https://mcellou.pythonanywhere.com/api/communes/?pays=$countryCode&ville_id=$villeId";

  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      if (jsonData is List) {
        return jsonData
            .map((e) => VillesAPiModel.fromJson(e))
            .toList();
      } else {
        throw Exception("Format inattendu des données reçues.");
      }
    } else {
      throw Exception(
          "Erreur ${response.statusCode}: ${response.reasonPhrase}\nBody: ${response.body}");
    }
  } on SocketException {
    throw Exception("Aucune connexion Internet.");
  } on FormatException {
    throw Exception("Réponse JSON invalide.");
  } on http.ClientException catch (e) {
    throw Exception("Erreur HTTP : ${e.message}");
  } on TimeoutException {
    throw Exception("Le serveur met trop de temps à répondre.");
  } catch (e) {
    throw Exception("Erreur inconnue : $e");
  }
}

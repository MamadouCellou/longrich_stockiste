import 'dart:math';

import 'package:intl/intl.dart';

final NumberFormat currencyFormat = NumberFormat("#,###", "fr_FR");

String getPaymentMethodLabel(String? value) {
  if (value == null || value.isEmpty) return "Non défini";

  switch (value.toLowerCase()) {
    case 'cash':
      return "Tout reglé en Cash";
    case 'semi_cash':
      return "Sémi Cash";
    case 'om':
      return "Tout reglé par Orange Money";
    case 'semi_orange_money':
      return "Sémi Orange Money";
    case 'ecash':
      return "Tout reglé par Ecash";
    case 'semi_ecash':
      return "Sémi Ecash";
    case 'debt':
      return "Dette";
    default:
      return value; // au cas où un nouveau mode non encore géré
  }
}

String getSemiMode(String? value) {
  if (value == null || value.isEmpty) return "Non défini";

  switch (value.toLowerCase()) {
    case 'cash':
      return "semi_cash";
    case 'om':
      return "semi_orange_money";
    case 'ecash':
      return "semi_ecash";
    default:
      return value; // au cas où un nouveau mode non encore géré
  }
}

String getSemiMode2(String? value) {
  if (value == null || value.isEmpty) return "Non défini";

  switch (value.toLowerCase()) {
    case 'semi_cash':
      return "ecash";
    case 'semi_orange_money':
      return "om";
    case 'semi_ecash':
      return "ecash";
    case 'debt':
      return "debt";
    default:
      return value; // au cas où un nouveau mode non encore géré
  }
}

final cycleRetail = [
  "Cycle Actuel",
  "Cycle 1",
  "Cycle 2",
  "Cycle 3",
  "Cycle 4",
  "Cycle 5",
  "Cycle 6",
  "Cycle 7",
  "Cycle 8",
  "Cycle 9",
  "Cycle 10",
  "Cycle 11",
  "Cycle 12",
  "Cycle 13",
];

final standardPaymentMethods = ['cash', 'om', 'ecash', 'debt'];

String formatDate(DateTime? dateTime) {
  if (dateTime == null) return '';
  return DateFormat('EEEE dd MMM yyyy, HH:mm', 'fr_FR')
      .format(dateTime.toLocal());
}


final countries = {
  "GN": "Guinée",
  "GM": "Gambie",
  "MR": "Mauritanie",
  "LR": "Liberia",
  "GW": "Guinée-Bissau",
};
final COUNTRIES_CODES = ["GN", "GM", "MR", "LR", "GW"];

Map<String, String> extraireNomPrenom(String displayName) {
  List<String> mots = displayName.trim().split(RegExp(r'\s+')); // Séparer par espace(s)

  if (mots.length == 1) {
    return {'prenom': mots[0], 'nom': ''}; // Si un seul mot, c'est le prénom
  }

  String nom = mots.removeLast(); // Dernier mot = Nom
  String prenom = mots.join(' '); // Le reste = Prénom

  return {'prenom': prenom, 'nom': nom};
}

String generateUniqueIdNumber() {
  final now = DateTime.now();
  final timestamp = "${now.year}"
      "${now.month.toString().padLeft(2, '0')}"
      "${now.day.toString().padLeft(2, '0')}"
      "${now.hour.toString().padLeft(2, '0')}"
      "${now.minute.toString().padLeft(2, '0')}"
      "${now.second.toString().padLeft(2, '0')}"
      "${now.millisecond.toString().padLeft(3, '0')}";

  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random.secure();

  final random3 = List.generate(3, (_) => chars[rand.nextInt(chars.length)]).join();

  return "$timestamp$random3"; // ex: 20251115231745123X9BFTQ
}


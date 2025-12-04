import 'package:flutter/services.dart';

/// Formatter pour un code licence de type XXXX-XXXX-XXXX-XXXX
class LicenceCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Supprimer tout caractère qui n'est pas lettre ou chiffre
    String text = newValue.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

    // Ajouter les tirets après chaque 4 caractères
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i != text.length - 1) {
        buffer.write('-');
      }
    }

    final formatted = buffer.toString();

    // Calculer la position du curseur
    int selectionIndex = formatted.length;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

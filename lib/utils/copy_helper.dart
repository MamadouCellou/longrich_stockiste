import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyHelper {
  static Future<void> copyText({
    required BuildContext context,
    required String text,
    required String name,
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name copié dans le presse-papiers ✅'),
        ),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeFormField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool requis;
  final bool isStockiste;
  final int maxLength;

  const CodeFormField({
    super.key,
    required this.controller,
    required this.label,
    this.requis = true, this.maxLength = 10, this.isStockiste = false,
  });

  @override
  State<CodeFormField> createState() => _CodeFormFieldState();
}

class _CodeFormFieldState extends State<CodeFormField> {
  late String exemple;
  @override
  Widget build(BuildContext context) {

    String exemple = !widget.isStockiste ? "GN01234567" : "GN0123";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: widget.label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          hintText: "Ex: $exemple",
          hintStyle: const TextStyle(color: Colors.grey),
        ),
        maxLength: widget.maxLength,
        inputFormatters: [
          LengthLimitingTextInputFormatter(widget.isStockiste ? 6 : 10),
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        ],
        textCapitalization: TextCapitalization.characters,
        validator: (v) {
          if (!widget.requis) return null;

          if (v == null || v.isEmpty) {
            return "${widget.label} requis";
          }

          final regex = widget.isStockiste
              ? RegExp(r'^[A-Z]{2}[0-9]{4}$')  // 2 lettres + 4 chiffres
              : RegExp(r'^[A-Z]{2}[0-9]{8}$'); // 2 lettres + 8 chiffres

          if (!regex.hasMatch(v.toUpperCase())) {
            return "${widget.label} invalide (2 lettres + ${widget.isStockiste ? '4' : '8'} chiffres, ex: $exemple)";
          }

          return null;
        },
        onChanged: (v) {
          final upper = v.toUpperCase();
          if (upper != v) {
            widget.controller.value = widget.controller.value.copyWith(
              text: upper,
              selection: TextSelection.collapsed(offset: upper.length),
            );
          }
        },
      ),
    );
  }
}

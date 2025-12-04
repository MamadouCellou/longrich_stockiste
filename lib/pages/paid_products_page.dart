import 'package:flutter/material.dart';

import '../utils/utils.dart';

class PaidProductsPage extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final double total_montant;
  final String titlePage;
  final double total_pv;
  final String periodeString;

  const PaidProductsPage({
    super.key,
    required this.products,
    required this.total_montant,
    required this.total_pv,
    required this.titlePage, required this.periodeString,
  });

  @override
  State<PaidProductsPage> createState() => _PaidProductsPageState();
}

class _PaidProductsPageState extends State<PaidProductsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.titlePage,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.periodeString,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: widget.products.isEmpty
            ? const Center(child: Text('Aucun produit trouvé.'))
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...widget.products.map((item) {
                final name = item['product_name'] ?? '';
                final total = (item['total_quantity'] ?? 0) as num;
                final rec = (item['quantity_received'] ?? 0) as num;
                final miss = (item['quantity_missing'] ?? (total - rec)) as num;


                // 🔸 Détermination du statut
                String subtitle;
                if (rec == 0) {
                  subtitle = 'Rien livré';
                } else if (rec >= total) {
                  subtitle = 'Tous livrés';
                } else {
                  subtitle = '${rec.toInt()} livrés, manque ${miss.toInt()}';
                }

                return Padding(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: Text(
                      "$total",
                      style: const TextStyle(
                          fontSize: 20,),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                          fontSize: 18,),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitle.contains('Rien')
                            ? Colors.red
                            : (subtitle.contains('manque')
                            ? Colors.orange
                            : Colors.green),
                        fontStyle: FontStyle.italic, fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                );
              }),

              const Divider(),
              const SizedBox(height: 8),
              Text(
                  "💰 Total montant : ${currencyFormat.format(widget.total_montant)} GNF",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text("⭐ Total PV : ${widget.total_pv}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

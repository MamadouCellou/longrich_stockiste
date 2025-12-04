import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/purchase.dart';
import '../utils/utils.dart';

class PurchaseCorbeillePage extends StatefulWidget {
  final String userId;

  const PurchaseCorbeillePage({super.key, required this.userId});

  @override
  State<PurchaseCorbeillePage> createState() => _PurchaseCorbeillePageState();
}

class _PurchaseCorbeillePageState extends State<PurchaseCorbeillePage> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  Map<String, List<Map<String, dynamic>>> _groupedHistory = {};

  final _currencyFormat = NumberFormat("#,##0", "fr_FR");

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('purchase_corbeille_view')
          .select()
          .eq('user_id', widget.userId) // 🔹 filtrer par utilisateur
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(res);

      // Regrouper les lignes par corbeille_id
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var row in data) {
        final id = row['corbeille_id'] as String;
        grouped.putIfAbsent(id, () => []).add(row);
      }

      setState(() {
        _groupedHistory = grouped;
        _loading = false;
      });
    } catch (e) {
      print("❌ Erreur chargement corbeille: $e");
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors du chargement de la corbeille")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_groupedHistory.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Corbeille des commandes")),
        body: Center(child: Text("Corbeille vide, aucune commande présente")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Corbeille des commandes")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: _groupedHistory.entries.map((entry) {
          final items = entry.value;
          final info = items.first;

          // Création d'un objet Purchase pour plus de clarté
          final purchase = Purchase(
            id: info['corbeille_id'],
            buyerName: info['buyer_name'],
            gn: info['gn'],
            purchaseType: info['purchase_type'],
            cycleRetail: info['cycle_retail'],
            paymentMethod: info['payment_method'],
            totalAmount: (info['total_amount'] as num?)?.toDouble() ?? 0.0,
            totalPv: (info['total_pv'] as num?)?.toDouble() ?? 0.0,
            totalPaid: (info['total_paid'] as num?)?.toDouble() ?? 0.0,
            totalRemaining: (info['total_remaining'] as num?)?.toDouble() ?? 0.0,
            totalPvPaid: (info['total_pv_paid'] as num?)?.toDouble() ?? 0.0,
            totalPvRemaining: (info['total_pv_remaining'] as num?)?.toDouble() ?? 0.0,
            comment: info['comment'],
            positioned: info['positioned'] ?? false,
            validated: info['validated'] ?? false,createdAt: info['created_at'] != null
              ? DateTime.parse(info['created_at'] as String)
              : null,

          );

          return ExpansionTile(
            title: Text(purchase.buyerName),
            subtitle: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(purchase.gn, overflow: TextOverflow.ellipsis),
                ),
                SizedBox(
                  width: 120,
                  child: Text(purchase.purchaseType == 'Retail' && purchase.cycleRetail != null && purchase.cycleRetail!.isNotEmpty
                      ? '${purchase.purchaseType} (${purchase.cycleRetail})'
                      : purchase.purchaseType
                    ,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),

                ),
                Text(formatDate(
                    purchase.createdAt)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets
                          .symmetric(
                          horizontal:
                          6,
                          vertical:
                          2),
                      decoration:
                      BoxDecoration(
                        color: purchase
                            .positioned
                            ? Colors
                            .green
                            : Colors
                            .red,
                        borderRadius:
                        BorderRadius
                            .circular(
                            12),
                      ),
                      child: Text(
                        purchase.positioned
                            ? "Positionné"
                            : "Non positionné",
                        style: const TextStyle(
                            fontSize:
                            8,
                            color: Colors
                                .white),
                      ),
                    ),
                    SizedBox(
                      width: 5,
                    ),
                    // Badge Validé
                    Container(
                      padding: const EdgeInsets
                          .symmetric(
                          horizontal:
                          6,
                          vertical:
                          2),
                      decoration:
                      BoxDecoration(
                        color: purchase
                            .validated
                            ? Colors
                            .green
                            : Colors
                            .red,
                        borderRadius:
                        BorderRadius
                            .circular(
                            12),
                      ),
                      child: Text(
                        purchase.validated
                            ? "Validée"
                            : "Non validée",
                        style: const TextStyle(
                            fontSize:
                            8,
                            color: Colors
                                .white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Total: ${_currencyFormat.format(purchase.totalAmount)} GNF"),
                Text("PV: ${purchase.totalPv}"),
                Text(getPaymentMethodLabel(purchase.paymentMethod)),

              ],
            ),
            children: [
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Aucun produit"),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.map((item) {
                      final quantityTotal = (item['quantity_total'] as num?)?.toInt() ?? 0;
                      final quantityReceived = (item['quantity_received'] as num?)?.toInt() ?? 0;
                      final quantityPaid = (item['quantity_paid'] as num?)?.toInt() ?? 0;
                      final manquant = quantityTotal - quantityReceived;
                      final restant = quantityTotal - quantityPaid;
                      final isPromo = (item['is_promo'] as bool?) ?? false;



                      // Partie réception
                      String recuText;
                      if (quantityReceived == quantityTotal) {
                        recuText = "Tout reçu ✅";
                      } else if (quantityReceived == 0) {
                        recuText = "Aucun reçu";
                      } else {
                        recuText =
                        "$quantityReceived reçu${quantityReceived > 1 ? 's' : ''}, $manquant manquant${manquant > 1 ? 's' : ''}";
                      }

                      // Partie paiement
                      String payeText;
                      if (quantityPaid == quantityTotal) {
                        payeText = "Tout payé 💰";
                      } else if (quantityPaid == 0) {
                        payeText = "Rien payé";
                      } else {
                        payeText =
                        "$quantityPaid payé${quantityPaid > 1 ? 's' : ''}, reste $restant";
                      }

                      return Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          key: ValueKey(item['product_id']),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                          childrenPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                          title: Text("$quantityTotal ${item['product_name']}", style: TextStyle(color: isPromo ? Colors.blueAccent : null)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                              child: Text(
                                "$recuText  ${isPromo ? "" : "- $payeText"}",
                                style:
                                const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // 🔹 Champs payés / restants
              Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "Payé: ${_currencyFormat.format(purchase.totalPaid)} - reste : ${_currencyFormat.format(purchase.totalRemaining)}"),
                      Text(
                          "PV Payés: ${purchase.totalPvPaid} - reste : ${purchase.totalPvRemaining}"),

                    ],
                  ),
                ),
              ),

              // Commentaire si présent
              if (purchase.comment !=
                  null &&
                  purchase.comment!
                      .isNotEmpty)
                Padding(
                  padding:
                  const EdgeInsets
                      .all(16.0),
                  child: Align(
                    alignment: Alignment
                        .centerLeft,
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          "Commentaires :",
                          style: TextStyle(
                              fontStyle:
                              FontStyle.italic),
                        ),
                        Container(
                          padding: const EdgeInsets
                              .symmetric(
                              horizontal:
                              6,
                              vertical:
                              2),
                          decoration:
                          BoxDecoration(
                            color: Colors
                                .blueGrey,
                            borderRadius:
                            BorderRadius.circular(
                                12),
                          ),
                          child: Text(
                            purchase
                                .comment!,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: const TextStyle(
                                fontSize:
                                12,
                                color:
                                Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
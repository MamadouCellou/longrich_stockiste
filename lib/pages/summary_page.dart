// lib/pages/summary_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:longrich_stockiste/pages/promotion_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/purchase_item.dart';
import '../services/promotion_reward_service.dart';
import '../utils/utils.dart';

class SummaryPage extends StatefulWidget {
  final String buyer;
  final String gn;
  final String paymentMethod;
  final String purchaseType;
  final String? cycleRetail;
  final List<Product> products;
  final List<PurchaseItem>
      items; // liste MUTABLE passée (mais on retourne aussi)
  final Map<String, int> missingQuantities;
  final NumberFormat currencyFormat;
  final Future<void> Function()? onSubmit;
  final bool loading;
  final bool isModification;
  final String commentaire;

  const SummaryPage({
    super.key,
    required this.buyer,
    required this.gn,
    required this.paymentMethod,
    required this.purchaseType,
    this.cycleRetail,
    required this.products,
    required this.items,
    required this.missingQuantities,
    required this.currencyFormat,
    this.onSubmit,
    this.loading = false,
    this.isModification = true,
    required this.commentaire,
  });

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  final Map<String, TextEditingController> _missingControllers = {};
  final Map<String, TextEditingController> _promoMissingControllers = {};


  final Map<String, TextEditingController> _nonPaidControllers = {};
  bool _loading = false;

  bool _checkingProduitsPromo = false;

  late TextEditingController _commentaireController = TextEditingController();

  bool _allReceived = false;
  bool _allPaid = false;

  // Sauvegardes pour restaurer après décochage
  Map<String, int> _originalMissing = {};
  Map<String, int> _originalNonPaid = {};

  String _paymentMethod = 'cash';

  void _toggleAllReceived(bool value) {
    setState(() {
      _allReceived = value;

      if (value) {
        // 👉 Tout reçu : aucune pièce manquante
        _originalMissing = {
          for (var i in widget.items) i.productId: i.quantityMissing
        };

        for (final item in widget.items) {
          final idx = widget.items.indexOf(item);
          widget.items[idx] = item.copyWith(
            quantityReceived: item.quantityTotal,
            quantityMissing: 0,
          );
          _missingControllers[item.productId]?.text = '0';
        }
      } else {
        // 👉 Rien reçu : tout est manquant
        for (final item in widget.items) {
          final idx = widget.items.indexOf(item);
          widget.items[idx] = item.copyWith(
            quantityReceived: 0,
            quantityMissing: item.quantityTotal,
          );
          _missingControllers[item.productId]?.text =
              item.quantityTotal.toString();
        }
      }
    });
  }

  void _toggleAllPaid(bool value) {
    setState(() {
      _allPaid = value;

      if (value) {
        // 👉 Tout payé
        _originalNonPaid = {
          for (var i in widget.items)
            i.productId: (i.quantityTotal - i.quantityPaid)
        };

        if(_paymentMethod == "debt") {
          _paymentMethod = "cash";
        }

        for (final item in widget.items) {
          final idx = widget.items.indexOf(item);
          widget.items[idx] = item.copyWith(quantityPaid: item.quantityTotal);
          _nonPaidControllers[item.productId]?.text = '0';
        }
      } else {
        // 👉 Rien payé
        for (final item in widget.items) {
          final idx = widget.items.indexOf(item);
          widget.items[idx] = item.copyWith(quantityPaid: 0);
          _nonPaidControllers[item.productId]?.text =
              item.quantityTotal.toString();
        }

      }
    });
  }

  List<PurchaseItem>? promoItems;
  String? promoMessage; // message d’erreur ou d’info
  bool promoDisponible = false;

  @override
  void initState() {
    super.initState();

    print("Mode de paiement reçu : ${_paymentMethod}");
    _checkPromo(totalPv: totalPV);

    !widget.isModification
        ? {_toggleAllPaid(true), _toggleAllReceived(true)}
        : _commentaireController =
            TextEditingController(text: widget.commentaire);

    if(widget.isModification){
      _paymentMethod = widget.paymentMethod;
    }

    for (final item in widget.items) {
      final initialPaid = item.quantityPaid.clamp(0, item.quantityTotal);
      final nonPaid =
          (item.quantityTotal - initialPaid).clamp(0, item.quantityTotal);

      _missingControllers[item.productId] =
          TextEditingController(text: item.quantityMissing.toString());

      _nonPaidControllers[item.productId] =
          TextEditingController(text: nonPaid.toString());

      final idx = widget.items.indexWhere((i) => i.productId == item.productId);
      if (idx != -1) {
        widget.items[idx] = item.copyWith(
          quantityPaid: initialPaid,
          quantityMissing: item.quantityMissing,
        );
      }
    }
  }

  /// Mets à jour la quantité payée à partir d'une quantité non-payée saisie
  void _updateNonPaid(String productId, int qtyNonPaid) {
    final idx = _indexOf(productId);
    if (idx == -1) return;

    final item = widget.items[idx];
    final safeQtyNonPaid = qtyNonPaid.clamp(0, item.quantityTotal);

    // quantityPaid = quantityTotal - nonPaid
    final newPaid =
        (item.quantityTotal - safeQtyNonPaid).clamp(0, item.quantityTotal);

    // Mettre à jour l'item
    widget.items[idx] = item.copyWith(quantityPaid: newPaid);

    // Mettre à jour le controller de nonPaid pour garder l'UI synchrone
    _nonPaidControllers[productId]?.text = safeQtyNonPaid.toString();
    _nonPaidControllers[productId]?.selection = TextSelection.fromPosition(
        TextPosition(offset: _nonPaidControllers[productId]!.text.length));
  }

  @override
  void dispose() {
    for (final c in _missingControllers.values) c.dispose();
    for (final c in _nonPaidControllers.values) c.dispose();
    super.dispose();
  }

// 💰 --- Paiement ---
  double get totalPreview =>
      widget.items.fold(0, (sum, i) => sum + i.montantTotalDu);

  double get totalPV =>
      widget.items.fold(0, (sum, i) => sum + (i.unitPv * i.quantityTotal));

  double get totalPaye => widget.items.fold(0, (sum, i) => sum + i.montantPaid);

  double get totalRestant =>
      widget.items.fold(0, (sum, i) => sum + i.montantRemaining);

// 📦 --- Réception des produits ---
  int get totalProduitsCommandes =>
      widget.items.fold(0, (sum, i) => sum + i.quantityTotal);

  int get totalProduitsRecus =>
      widget.items.fold(0, (sum, i) => sum + i.quantityReceived);

  int get totalProduitsManquants =>
      widget.items.fold(0, (sum, i) => sum + i.quantityMissing);

  double get montantTotalRecu => widget.items
      .fold(0, (sum, i) => sum + (i.unitPrice * i.quantityReceived));

  double get montantTotalManquant =>
      widget.items.fold(0, (sum, i) => sum + (i.unitPrice * i.quantityMissing));

  int _indexOf(String productId) =>
      widget.items.indexWhere((i) => i.productId == productId);

// 🔹 Getter pour l'affichage
  String get autoPaymentMethodPourAffichage {
    return getPaymentMethodLabel(autoPaymentMethodPourSupabase);
  }

// 🔹 Getter pour la valeur à sauvegarder dans Supabase
  String get autoPaymentMethodPourSupabase {
    print(_paymentMethod);
    if (totalPaye >= totalPreview) {
      return getSemiMode2(_paymentMethod);
    } else if (totalPaye == 0) {
      return 'debt'; // sauvegarde directement comme dette
    } else {
      return getSemiMode(_paymentMethod);
    }
  }

  Future<void> _checkPromo({
    required double totalPv,
  }) async {
    setState(() {
      _checkingProduitsPromo = true;
      promoDisponible = false;
      promoMessage = null;
      promoItems = null;
    });

    final result = await PromotionRewardService().getPromoReward(
      totalPv: totalPv,
    );

    // ❌ Aucun résultat → pas qualifié OU aucune promo
    if (result == null) {
      final promos = await PromotionRewardService().getActivePromotions();

      if (promos.isEmpty) {
        setState(() {
          promoDisponible = true;
          promoMessage = "❌ Aucune promotion en cours.";
          _checkingProduitsPromo = false;
        });
      } else {
        setState(() {
          promoDisponible = true;
          promoMessage = "⚠️ Votre commande n’atteint pas le challenge requis. Cliquez pour voir.";
          _checkingProduitsPromo = false;
        });
      }

      return;
    }

    // ✅ Promo OK
    promoItems = (result["items"] as List<dynamic>)
        .map((m) => PurchaseItem.fromMap(m as Map<String, dynamic>))
        .toList();

    // fusion des items …
    for (final promo in promoItems!) {
      final idx = widget.items.indexWhere((e) => e.productId == promo.productId);

      if (idx == -1) {
        widget.items.add(promo);
        _promoMissingControllers[promo.productId] =
            TextEditingController(text: promo.quantityMissing.toString());
      } else {
        widget.items[idx] = widget.items[idx].copyWith(
          quantityTotal: promo.quantityTotal,
          quantityMissing: promo.quantityMissing,
          quantityReceived: promo.quantityReceived,
          unitPrice: promo.unitPrice,
          unitPv: promo.unitPv,
        );
      }
    }

    // ⭐ Très important : ici aussi on active l’affichage !
    setState(() {
      promoDisponible = true;
      promoMessage = "🎁 Félicitations ! Promotion disponible. Cliquez pour voir.";
      _checkingProduitsPromo = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Résumé de la commande")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Acheteur : ${widget.buyer}",
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text("Matricule : ${widget.gn}"),
          const SizedBox(height: 4),
          Text(
              "Type d'achat : ${widget.purchaseType} ${widget.cycleRetail ?? ""}"),
          const SizedBox(height: 4),
          Text("Mode de paiement : $autoPaymentMethodPourAffichage"),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total PV :",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text("${totalPV.toStringAsFixed(2)} PV",
                  style: const TextStyle(
                      color: Colors.purple, fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total dû :"),
              Text("${widget.currencyFormat.format(totalPreview)} GNF"),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total payé :"),
              Text("${widget.currencyFormat.format(totalPaye)} GNF"),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total restant :"),
              Text("${widget.currencyFormat.format(totalRestant)} GNF"),
            ],
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                // 🔹 Switch "Tout reçu"
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Rien reçu / Tout reçu",
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    value: totalProduitsManquants == 0 ? true : false,
                    onChanged: _toggleAllReceived,
                    activeColor: Colors.green,
                    dense: true,
                  ),
                ),

                SizedBox(
                  width: 15,
                ),

                // 🔹 Switch "Tout payé"
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Dette / Tout payé",
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    value: totalRestant == 0 ? true : false,
                    onChanged: _toggleAllPaid,
                    activeColor: Colors.green,
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _allPaid || _paymentMethod != "debt" ?
          DropdownButtonFormField<String>(
            value: getSemiMode2(_paymentMethod),
            items: [
              const DropdownMenuItem(value: 'cash', child: Text("Cash")),
              const DropdownMenuItem(value: 'om', child: Text("Orange Money")),
              const DropdownMenuItem(value: 'ecash', child: Text("Ecash")),
            ],
            onChanged: (v) => setState(() => _paymentMethod = v!),
            decoration: const InputDecoration(labelText: "Mode de paiement"),
          ) : SizedBox(),
          const Divider(height: 24),
          ...widget.items.map((item) {
            final product = widget.products.firstWhere(
              (p) => p.id == item.productId,
              orElse: () => Product(
                id: item.productId,
                name: item.productName,
                pricePartner: item.unitPrice,
                pv: item.unitPv,
                description: null,
                createdAt: null,
              ),
            );

            // 🌟 SÉCURISATION : créer les controllers manquants si besoin
            _missingControllers.putIfAbsent(
              product.id!,
                  () => TextEditingController(text: item.quantityMissing.toString()),
            );

            _nonPaidControllers.putIfAbsent(
              product.id!,
                  () => TextEditingController(text: item.quantityRemained.toString()),
            );


            final missingCtrl = _missingControllers[product.id]!;
            final nonPaidCtrl = _nonPaidControllers[product.id]!;

            final isFullyPaid = item.quantityRemained == 0;

            return ExpansionTile(
              key: ValueKey(product.id),
              title: Row(
                children: [
                  Expanded(
                      child: Text("${item.quantityTotal}  ${product.name}", style: TextStyle(color: item.isPromo ? CupertinoColors.activeBlue : null),)),
                  const SizedBox(width: 8),
                  !item.isPromo ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          "${widget.currencyFormat.format(item.montantTotalDu)} GNF"),
                      Text(
                          "PV: ${(item.unitPv * item.quantityTotal).toStringAsFixed(2)}"),
                    ],
                  ) : SizedBox()
                ],
              ),
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // Quantité manquante
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: missingCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: InputDecoration(
                                labelText:
                                    "Quantité manquante (Max: ${item.quantityTotal})",
                              ),
                              onChanged: (val) {
                                int m = int.tryParse(val) ?? 0;
                                m = m.clamp(0, item.quantityTotal);

                                setState(() {
                                  // Trouver l'index de l'item correspondant
                                  final idx = widget.items.indexWhere(
                                      (element) =>
                                          element.productId == product.id);
                                  if (idx != -1) {
                                    final oldItem = widget.items[idx];

                                    // Mettre à jour quantityMissing et quantityReceived en même temps
                                    widget.items[idx] = oldItem.copyWith(
                                      quantityMissing: m,
                                      quantityReceived: item.quantityTotal - m,
                                    );

                                    // Mettre à jour le champ texte pour être sûr qu'il reste cohérent
                                    missingCtrl.text = m.toString();
                                    missingCtrl.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                          offset: missingCtrl.text.length),
                                    );

                                    //print("Quantité manquante saisie : $m");

                                    print(widget.items.toString());
                                  }
                                });
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Quantité non payée
                      !item.isPromo ?
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: nonPaidCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: InputDecoration(
                                labelText:
                                    "Quantité non payée (max ${item.quantityTotal})",
                              ),
                              onChanged: (val) {
                                int nonPaid = int.tryParse(val) ?? 0;
                                nonPaid = nonPaid.clamp(0, item.quantityTotal);
                                _updateNonPaid(product.id!, nonPaid);
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isFullyPaid
                                    ? "Tout payé 💰"
                                    : "${item.quantityRemained} non payé(s)",
                                style: TextStyle(
                                  color: isFullyPaid
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ) : SizedBox(),
                      const SizedBox(height: 12),
                      !item.isPromo ? Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Montant payé :",
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                  "${widget.currencyFormat.format(item.montantPaid)} GNF"),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Montant restant :",
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                  "${widget.currencyFormat.format(item.montantRemaining)} GNF",
                                  style: const TextStyle(color: Colors.orange)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Quantité restante :"),
                              Text("${item.quantityRemained}"),
                            ],
                          ),
                        ],
                      ) : SizedBox()
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
          promoDisponible ?
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PromotionPage(readOnly: true,),)),
              child: Text(
                promoMessage!,
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                  decorationThickness: 1,       // optionnel : rend le soulignement plus visible
                ),
              )

            ),
          ) : SizedBox(),
          const SizedBox(height: 24),
          TextFormField(
            controller: _commentaireController,
            decoration: const InputDecoration(labelText: "Commentaires"),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading
                ? null
                : () async {
              setState(() => _loading = true);
              try {
                if (widget.onSubmit != null) {
                  await widget.onSubmit!();
                }

                // 🔥 1️⃣ Fusionner manquants normaux + manquants promo
                final fullMissingQuantities = <String, int>{};

                fullMissingQuantities.addAll(widget.missingQuantities);

                for (final it in widget.items) {
                  fullMissingQuantities[it.productId] = it.quantityMissing ?? 0;
                }

                print("Total items : ${widget.items.toList()}");

                if (mounted) {
                  Navigator.of(context).pop({
                    'items': widget.items,
                    'missingQuantities': fullMissingQuantities,
                    'paymentMethod': autoPaymentMethodPourSupabase,
                    'commentaire': _commentaireController.text.trim(),
                  });
                }
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },

            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    "Confirmer et enregistrer",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}

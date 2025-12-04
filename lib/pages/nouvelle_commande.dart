// lib/pages/new_purchase_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:longrich_stockiste/pages/summary_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../services/category_service.dart';
import '../services/product_service.dart';
import '../services/promotion_reward_service.dart';
import '../utils/snackbars.dart';
import '../utils/utils.dart';

class NewPurchasePage extends StatefulWidget {
  final Purchase? purchase;
  final List<PurchaseItem>? purchaseItems;

  const NewPurchasePage({super.key, this.purchase, this.purchaseItems});

  @override
  State<NewPurchasePage> createState() => _NewPurchasePageState();
}

class _NewPurchasePageState extends State<NewPurchasePage> {
  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _buyerController = TextEditingController();
  String _paymentMethod = 'cash';

  final TextEditingController _gnController = TextEditingController();
  String _purchaseType = 'Rehaussement';

  String _selectedCycle = 'Cycle Actuel';

  Map<String, int> _quantities = {};

  late TextEditingController _commentaire = TextEditingController();

  Map<String, int> _missingQuantities = {};
  List<Product> _products = [];
  bool _loading = false;

  Category? _selectedCategory;
  List<Category> _allCategorie = [];

  late final CategoryService _categoryService;
  late final ProductService _productService;

  // Si SummaryPage retourne une liste d'items modifiée, on la stocke ici avant d'appeler _submit
  List<PurchaseItem>? _summaryUpdatedItems;
  List<PurchaseItem>? _purchaseItemsReceived;

  @override
  void initState() {
    super.initState();

    _loadProducts();
    _productService = ProductService(supabase: Supabase.instance.client);
    _categoryService = CategoryService(supabase: Supabase.instance.client);

    _categoryService.categoriesRealtime().listen((list) {
      setState(() {
        _allCategorie = list;
        if (list.isNotEmpty && _selectedCategory == null) {
          _selectedCategory = list.first;
        }
      });
    });

    // Écoute en temps réel
    _productService.productsRealtime().listen((list) {
      setState(() {
        _products = list;
      });
    });

    _purchaseItemsReceived = widget.purchaseItems?.where((item) => !item.isPromo) // 🔥 exclut items promo !
        .toList();

    if (widget.purchase != null && _purchaseItemsReceived != null) {
      final purchase = widget.purchase!;

      _buyerController.text = purchase.buyerName;
      _paymentMethod = purchase.paymentMethod;
      _gnController.text = purchase.gn ?? '';

      // 🟦 Garder uniquement les items NON promo
      _summaryUpdatedItems = _purchaseItemsReceived;


      _purchaseType = purchase.purchaseType;
      _selectedCycle = purchase.cycleRetail ?? _selectedCycle;
      _commentaire = TextEditingController(text: purchase.comment);

      for (var item in _purchaseItemsReceived!) {
        _quantities[item.productId] = item.quantityTotal;
        _missingQuantities[item.productId] = item.quantityMissing;
      }
    } else {
      _purchaseType = 'Rehaussement';
      _gnController.text = '';
    }
  }

  Future<void> _loadProducts() async {
    final res = await supabase
        .from('products')
        .select()
        .order('name', ascending: true); // 🔹 tri alphabétique croissant

    setState(() {
      _products = List<Map<String, dynamic>>.from(res)
          .map((m) => Product.fromMap(m))
          .toList();
    });
    }


  double computeTotalPreview() {
    return _products.fold(
      0,
      (sum, p) => sum + (p.pricePartner * (_quantities[p.id] ?? 0)),
    );
  }

  double computeTotalPV() {
    return _products.fold(
      0,
      (sum, p) => sum + (p.pv * (_quantities[p.id] ?? 0)),
    );
  }

  // Build items initial (avant édition dans SummaryPage)
  List<PurchaseItem> buildItemsFromSelections(List<Product> products) {
    return _quantities.entries.where((e) => e.value > 0).map((e) {
      final product = products.firstWhere((p) => p.id == e.key);
      final qtyTotal = e.value;
      final missing = _missingQuantities[e.key] ?? 0;

      return PurchaseItem(
        id: null,
        productId: product.id!,
        productName: product.name,
        unitPrice: product.pricePartner,
        unitPv: product.pv,
        quantityTotal: qtyTotal,
        quantityReceived: qtyTotal - missing,
        quantityMissing: missing,
        quantityPaid: 0, // par défaut 0, modifiable dans SummaryPage
      );
    }).toList();
  }

  Future<void> _handleSubmit() async {
    setState(() => _loading = true);
    await _submit();
    setState(() => _loading = false);
  }

  // ⤵️ Ouvre la SummaryPage et ATTEND la liste d'items modifiée
  Future<void> _showSummaryBottomSheet() async {
    // 1) Construire la "base" d'items (copie, pour ne pas muter les originaux)
    List<PurchaseItem> baseItems = [];

    if (_summaryUpdatedItems != null) {
      // Si on a déjà un résumé modifié local, on le réutilise
      baseItems = _summaryUpdatedItems!.map((e) => e.copyWith()).toList();
    } else if (widget.purchase != null && _purchaseItemsReceived != null) {
      // Sinon si on édite une commande existante, partir des items de la commande
      baseItems = _purchaseItemsReceived!.map((e) => e.copyWith()).toList();
    } else {
      // Sinon (nouvelle commande) on part d'une liste vide — on appliquera les _quantities
      baseItems = [];
    }

    // 2) Mettre en map pour accès rapide par productId
    final Map<String, PurchaseItem> itemsByProduct = {
      for (var it in baseItems) it.productId: it
    };

    // 3) Appliquer les sélections courantes (_quantities) : ajouter / mettre à jour / supprimer
    //    - si qty <= 0  => on supprime l'item (l'utilisateur l'a remis à 0)
    //    - sinon on met à jour ou on crée un nouvel item en conservant les valeurs utiles
    _quantities.forEach((productId, qty) {
      final int safeQty = (qty ?? 0).clamp(0, 1 << 30); // protection
      if (safeQty <= 0) {
        // Supprimer si présent
        itemsByProduct.remove(productId);
        return;
      }

      final existing = itemsByProduct[productId];

      // retrouver le product pour infos (prix, pv, nom)
      final product = _products.firstWhere(
        (p) => p.id == productId,
        orElse: () => Product(
          id: productId,
          name: existing?.productName ?? 'Produit',
          pricePartner: existing?.unitPrice ?? 0.0,
          pv: existing?.unitPv ?? 0.0,
          description: null,
          createdAt: null,
        ),
      );

      // déterminer missing (priorité : _missingQuantities si défini, sinon existing.quantityMissing, sinon 0)
      int missing =
          (_missingQuantities[productId] ?? existing?.quantityMissing ?? 0)
              .clamp(0, safeQty);

      // received = total - missing
      final received = (safeQty - missing).clamp(0, safeQty);

      // déterminer quantityPaid :
      // - si existing existe -> conserver quantityPaid mais clamp à safeQty
      // - sinon -> new item : mettre quantityPaid = 0 (par choix : SummaryPage interpretera 0 -> tout payé si c'est le comportement que tu as défini)
      final paid =
          existing != null ? (existing.quantityPaid).clamp(0, safeQty) : 0;

      // construire l'item mis à jour
      final updated = (existing != null)
          ? existing.copyWith(
              quantityTotal: safeQty,
              quantityMissing: missing,
              quantityReceived: received,
              quantityPaid: paid,
              unitPrice: product.pricePartner,
              unitPv: product.pv,
              productName: product.name,
            )
          : PurchaseItem(
              id: null,
              purchaseId: null,
              productId: productId,
              productName: product.name,
              unitPrice: product.pricePartner,
              unitPv: product.pv,
              quantityTotal: safeQty,
              quantityReceived: received,
              quantityMissing: missing,
              quantityPaid: paid!,
            );

      itemsByProduct[productId] = updated;
    });

    // 4) Résultat final à envoyer à la SummaryPage
    final mergedItems = itemsByProduct.values.toList();

    // 5) Ouvrir la SummaryPage et attendre le résultat (Map contenant 'items' et 'paymentMethod')
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryPage(
          buyer: _buyerController.text,
          gn: _gnController.text,
          paymentMethod: _paymentMethod,
          purchaseType: _purchaseType,
          cycleRetail: _purchaseType == "Retail" ? _selectedCycle : null,
          products: _products,
          items: mergedItems,
          missingQuantities: _missingQuantities,
          currencyFormat: currencyFormat,
          loading: _loading,
          isModification: widget.purchase != null ? true : false,
          commentaire: _commentaire.text.trim(),
        ),
      ),
    );

    // 6) Traiter le retour : mettre à jour _summaryUpdatedItems et éventuellement _paymentMethod puis submit
    if (result != null) {
      final updatedItems = result['items'] as List<PurchaseItem>?;
      final updatedPaymentMethod = result['paymentMethod'] as String?;
      final updatedCommentaire = result['commentaire'] as String?; // ✅ récupère ici

      if (updatedItems != null) {
        _summaryUpdatedItems = updatedItems;
      }

      if (updatedPaymentMethod != null) {
        _paymentMethod = updatedPaymentMethod;
      }

      if (updatedCommentaire != null) {
        _commentaire.text = updatedCommentaire; // ✅ met à jour ton champ
      }

      await _handleSubmit();
    }

  }

  // =================== _submit() : utilise _summaryUpdatedItems si présent ===================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return showErrorSnackbar(
        context: context,
        message: "Tous les champs sont obligatoires",
      );
    }

    final items = _summaryUpdatedItems ?? buildItemsFromSelections(_products);
    if (items.isEmpty) {
      return showErrorSnackbar(
        context: context,
        message: "Veuillez ajouter au moins un produit",
      );
    }

    setState(() => _loading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception("Utilisateur non connecté");

      final supabase = Supabase.instance.client;

      // 🔹 Calcul des totaux
      final totalAmount =
      items.fold<double>(0, (sum, i) => sum + i.montantTotalDu);
      final totalPv =
      items.fold<double>(0, (sum, i) => sum + (i.unitPv * i.quantityTotal));

      // =====================================================
      // 🔥 🔥 🔥 CAS 1 : MODIFICATION D’UNE COMMANDE EXISTANTE
      // =====================================================
      if (widget.purchase != null) {
        final purchaseId = widget.purchase!.id!;

        // -----------------------------------------------------
        // 🧩 ÉTAPE 1 : Historisation (sauvegarde ancien état)
        // -----------------------------------------------------
        final oldPurchase = await supabase
            .from('purchases')
            .select()
            .eq('id', purchaseId)
            .maybeSingle();

        if (oldPurchase != null) {
          final oldItems = await supabase
              .from('purchase_items')
              .select()
              .eq('purchase_id', purchaseId);

          final insertedHistory = await supabase
              .from('purchase_history')
              .insert({
            'parent_purchase_id': purchaseId,
            'buyer_name': oldPurchase['buyer_name'],
            'payment_method': oldPurchase['payment_method'],
            'gn': oldPurchase['gn'],
            'positioned': oldPurchase['positioned'],
            'validated': oldPurchase['validated'],
            'purchase_type': oldPurchase['purchase_type'],
            'cycle_retail': oldPurchase['cycle_retail'],
            'total_amount': oldPurchase['total_amount'],
            'total_pv': oldPurchase['total_pv'],
            'user_id': oldPurchase['user_id'],
            'comment': oldPurchase['comment'],
          }).select().single();

          final historyId = insertedHistory['id'] as String;

          if (oldItems.isNotEmpty) {
            final historyItems = oldItems.map((item) {
              return {
                'history_id': historyId,
                'product_id': item['product_id'],
                'product_name': item['product_name'],
                'unit_price': item['unit_price'],
                'unit_pv': item['unit_pv'],
                'is_promo': item['is_promo'],
                'quantity_total': item['quantity_total'],
                'quantity_received': item['quantity_received'],
                'quantity_missing': item['quantity_missing'],
                'quantity_paid': item['quantity_paid'],
                'montant_total_du': item['montant_total_du'],
                'montant_paid': item['montant_paid'],
                'montant_remaining': item['montant_remaining'],
              };
            }).toList();

            await supabase.from('purchase_history_items').insert(historyItems);
          }
        }

        // -----------------------------------------------------
        // 🧩 ÉTAPE 2 : Mise à jour réelle de la commande
        // -----------------------------------------------------

        // Supprimer tous les anciens items
        await supabase
            .from('purchase_items')
            .delete()
            .eq('purchase_id', purchaseId);

        // Réinsérer les nouveaux
        final itemsMap = items.map((item) {
          final product = _products.firstWhere((p) => p.id == item.productId);
          return {
            'purchase_id': purchaseId,
            'product_id': product.id,
            'product_name': product.name,
            'unit_price': product.pricePartner,
            'unit_pv': product.pv,
            'quantity_total': item.quantityTotal,
            'is_promo': item.isPromo,
            'quantity_received': item.quantityReceived,
            'quantity_missing': item.quantityMissing,
            'quantity_paid': item.quantityPaid,
            'montant_total_du': item.montantTotalDu,
            'quantity_remained': item.quantityRemained,
            'montant_paid': item.montantPaid,
            'montant_remaining': item.montantRemaining,
          };
        }).toList();

        await supabase.from('purchase_items').insert(itemsMap);

        await supabase.from('purchases').update({
          'buyer_name': _buyerController.text.trim(),
          'payment_method': _paymentMethod,
          'gn': _gnController.text.trim(),
          'purchase_type': _purchaseType,
          'cycle_retail': _selectedCycle,
          'user_id': userId,
          'total_amount': totalAmount,
          'total_pv': totalPv,
          'comment': _commentaire.text.trim(),
        }).eq('id', purchaseId);

        // =====================================================
        // 🔥 🔥 🔥 ÉTAPE 3 : Vérification des promotions
        // =====================================================


        showSucessSnackbar(context: context, message: "Achat modifié ✅");
        _resetForm();
      }

      // =====================================================
      // 🔥 🔥 🔥 CAS 2 : CRÉATION D’UNE NOUVELLE COMMANDE
      // =====================================================
      else {
        final purchaseMap = {
          'buyer_name': _buyerController.text.trim(),
          'payment_method': _paymentMethod,
          'gn': _gnController.text.trim(),
          'purchase_type': _purchaseType,
          'cycle_retail': _selectedCycle,
          'user_id': userId,
          'total_amount': totalAmount,
          'total_pv': totalPv,
          'positioned': false,
          'validated': false,
          'comment': _commentaire.text.trim(),
        };

        final insertedPurchase = await supabase
            .from('purchases')
            .insert(purchaseMap)
            .select()
            .single();

        final newPurchaseId = insertedPurchase['id'] as String;

        final itemsMap = items.map((item) {
          final product = _products.firstWhere((p) => p.id == item.productId);
          return {
            'purchase_id': newPurchaseId,
            'product_id': product.id,
            'product_name': product.name,
            'unit_price': product.pricePartner,
            'unit_pv': product.pv,
            'is_promo': item.isPromo,
            'quantity_total': item.quantityTotal,
            'quantity_received': item.quantityReceived,
            'quantity_missing': item.quantityMissing,
            'quantity_paid': item.quantityPaid,
            'montant_total_du': item.montantTotalDu,
            'quantity_remained': item.quantityRemained,
            'montant_paid': item.montantPaid,
            'montant_remaining': item.montantRemaining,
          };
        }).toList();

        await supabase.from('purchase_items').insert(itemsMap);

        // =====================================================
        // 🔥 🔥 🔥 ÉTAPE 3 : Vérification des promotions
        // =====================================================


        showSucessSnackbar(context: context, message: "Achat créé ✅");
        _resetForm();
      }

      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      print("❌ Erreur: $e");
      print("StackTrace: $st");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.purchase != null
            ? "Erreur lors de la modification : $e"
            : "Erreur lors de l'ajout : $e"),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _onWillPop() async {
    bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.purchase != null
            ? "Abandonner la modification de l'achat"
            : "Abandonner la création de l'achat"),
        content: const Text(
            "Êtes-vous sûr(e) de vouloir quitter ? Toutes les données entrées seront perdues."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text("Non"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Oui, quitter"),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _buyerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalPreview = computeTotalPreview();
    final totalPV = computeTotalPV();

    return WillPopScope(
      onWillPop: () => _onWillPop(),
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(widget.purchase != null ? "Modifier Achat" : "Nouvel Achat"),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.transparent),
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  color: Colors.blueGrey,
                ),
                child: Text(
                  "Total montant: ${currencyFormat.format(totalPreview)} — Total PV: ${totalPV.toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        body: _products.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: PageView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      widgetInfosPartenaire(), // suppose que tu as ces widgets
                      widgetProduits() // suppose que tu as ces widgets
                    ],
                  ),
                ),
              ),
        bottomSheet: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
              ),
              onPressed: _loading
                  ? null
                  : () {
                      if (_currentPage == 0) {
                        if (!_formKey.currentState!.validate() ||
                            _buyerController.text.trim().isEmpty ||
                            _gnController.text.trim().isEmpty) {
                          showErrorSnackbar(
                            context: context,
                            message: "Tous les champs sont obligatoires",
                          );
                          return;
                        }
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        final items = buildItemsFromSelections(_products);
                        if (items.isEmpty) {
                          showErrorSnackbar(
                            context: context,
                            message: "Veuillez ajouter au moins un produit",
                          );
                          return;
                        }
                        if (!_formKey.currentState!.validate() ||
                            _buyerController.text.trim().isEmpty ||
                            _gnController.text.trim().isEmpty) {
                          showErrorSnackbar(
                            context: context,
                            message:
                                "Veuillez remplir correctement le formulaire",
                          );
                          _pageController.jumpToPage(0);
                          setState(() {
                            _currentPage = 0;
                          });
                          return;
                        }

                        // on ouvre SummaryPage et attend le résultat (items modifiés)
                        _showSummaryBottomSheet();
                      }
                    },
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      children: [
                        _currentPage == 1
                            ? IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _pageController.jumpToPage(0);
                                    _currentPage = 0;
                                  });
                                },
                              )
                            : const SizedBox(),
                        Text(
                          _currentPage == 0
                              ? "Continuer à sélectionner les produits"
                              : (widget.purchase != null
                                  ? "Résumé et modification"
                                  : "Résumé et ajout"),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    _pageController.jumpToPage(0);
    setState(() {
      _currentPage = 0;
      _formKey.currentState?.reset();
      _buyerController.clear();
      _gnController.clear();
      _paymentMethod = 'cash';
      _purchaseType = 'Rehaussement';
      _quantities.clear();
      _missingQuantities.clear();
      _summaryUpdatedItems = null;
    });
  }

  // --- TODO: tes widgets widgetInfosPartenaire() et widgetProduits() restent inchangés ---

  Widget widgetProduits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Produits",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Confirmation"),
                    content: const Text(
                      "Voulez-vous vraiment réinitialiser la quantité de tous les produits à 0 ?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(false), // Annuler
                        child: const Text("Annuler"),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(true), // Confirmer
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade300),
                        child: const Text("Oui, réinitialiser"),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  setState(() {
                    for (var p in _products) {
                      _quantities[p.id!] = 0;
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text("Toutes les quantités ont été réinitialisées ✅"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Text(
                "Tout à zéro",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 🔹 Liste horizontale des catégories
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _allCategorie.length,
            itemBuilder: (context, index) {
              final cat = _allCategorie[index];
              final isSelected = _selectedCategory?.id == cat.id;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // 🔹 Liste des produits filtrée par catégorie
        SizedBox(
          height: 480, // hauteur fixe pour éviter Expanded dans ListView
          child: _selectedCategory == null
              ? Center(
                  child: Text(
                    "Veuillez sélectionner une catégorie",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: ListView.builder(
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _products
                          .where((p) => p.categoryId == _selectedCategory!.id && !p.isPromo)
                          .length,
                      itemBuilder: (context, index) {
                        final product = _products
                            .where((p) => p.categoryId == _selectedCategory!.id && !p.isPromo)
                            .toList()[index];
                        final qty = _quantities[product.id] ?? 0;
                        final controller =
                            TextEditingController(text: qty.toString());

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(product.name),
                            subtitle: Text(
                                "GNF: ${currencyFormat.format(product.pricePartner)} — PV: ${product.pv}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: qty > 0
                                      ? () => setState(() =>
                                          _quantities[product.id!] = qty - 1)
                                      : null,
                                ),
                                SizedBox(
                                  width: 60,
                                  child: TextField(
                                    controller: controller,
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 4),
                                    ),
                                    onSubmitted: (val) {
                                      final newQty = int.tryParse(val) ?? qty;
                                      setState(() =>
                                          _quantities[product.id!] = newQty);
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () => setState(
                                      () => _quantities[product.id!] = qty + 1),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
        SizedBox(
          height: 16,
        )
      ],
    );
  }

  Widget widgetInfosPartenaire() {
    return Column(
      children: [
        TextFormField(
          controller: _buyerController,
          maxLength: 40,
          decoration: const InputDecoration(labelText: "Nom de l'acheteur"),
          validator: (v) => v == null || v.isEmpty ? "Nom requis" : null,
        ),
        _buildCodeField(_gnController, "Code matricule"),

        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _purchaseType,
          items: const [
            DropdownMenuItem(
                value: 'Rehaussement', child: Text("Rehaussement")),
            DropdownMenuItem(value: 'Retail', child: Text("Retail")),
          ],
          onChanged: (val) => setState(() => _purchaseType = val!),
          decoration: const InputDecoration(labelText: "Type d'achat"),
          validator: (val) {
            if (val == null || val.isEmpty) {
              return 'Veuillez choisir un type d\'achat';
            }
            return null;
          },
        ),const SizedBox(height: 15),
        _purchaseType == "Retail" ?

        _buildGradeDropdown() :
            SizedBox()
      ],
    );
  }

  Widget _buildGradeDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: "Choisir le cycle"),
      value: _selectedCycle,
      items: cycleRetail.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCycle = value!;
        });
      },
    );
  }

  Widget _buildCodeField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
            labelText: label,
            hintText: "Ex: GN01234567",
            hintStyle: TextStyle(color: Colors.grey)),
        maxLength: 10,
        inputFormatters: [
          LengthLimitingTextInputFormatter(10), // max 10 caractères
          FilteringTextInputFormatter.allow(
              RegExp(r'[A-Za-z0-9]')), // lettres et chiffres
        ],
        textCapitalization: TextCapitalization.characters, // force majuscules
        validator: (v) {
          if (v == null || v.isEmpty) return "$label requis";
          if (!RegExp(r'^[A-Z]{2}[0-9]{8}$').hasMatch(v.toUpperCase())) {
            return "$label invalide (2 lettres + 8 chiffres, ex: GN01234567)";
          }
          return null;
        },
        onChanged: (v) {
          // Optionnel : transformer en majuscules en temps réel
          final text = v.toUpperCase();
          if (text != v) {
            ctrl.value = ctrl.value.copyWith(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            );
          }
        },
      ),
    );
  }
}

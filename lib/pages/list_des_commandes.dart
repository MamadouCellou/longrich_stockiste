import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:longrich_stockiste/pages/promotion_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controllers/user_controller.dart';
import '../models/licence.dart';
import '../services/licences_services.dart';
import '../services/purchase_service.dart';
import '../services/statistiques/statistiques_services.dart';
import '../utils/copy_helper.dart';
import '../utils/snackbars.dart';
import '../utils/utils.dart';
import '../widgets/bottom_modal.dart';
import '../widgets/promo_manager_sheet.dart';
import '../widgets/statistique_widget.dart';
import 'Accounts_list.dart';
import 'corbeille_commandes.dart';
import 'edit_profil_page.dart';
import 'gestion_produits.dart';
import 'historique_commande.dart';
import 'licence_page_manager.dart';
import 'login_page.dart';
import 'nouvelle_commande.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchasesListPage extends StatefulWidget {
  const PurchasesListPage({super.key});

  @override
  State<PurchasesListPage> createState() => _PurchasesListPageState();
}

/// 🔹 Enum des différents tris possibles
enum PurchaseSortOption {
  buyerNameAsc,
  buyerNameDesc,
  createdAtNewest,
  createdAtOldest,
  updatedAtNewest,
  updatedAtOldest,
  totalAmountHighToLow,
  totalAmountLowToHigh,
  totalPvHighToLow,
  totalPvLowToHigh,
}

enum PurchaseFilterOption {
  // Toutes
  all,
  rehaussementAll,
  retailAll,
  dettes,
  fullyPaid,
  semiPaid,
  all_not_pos_not_valid,
  all_pos_not_valid,
  all_pos_valid,

  // Rehaussement détaillé
  rh_not_pos_not_valid,
  rh_pos_not_valid,
  rh_pos_valid,

  // Retail détaillé
  rt_not_pos_not_valid,
  rt_pos_not_valid,
  rt_pos_valid,
}

class _PurchasesListPageState extends State<PurchasesListPage> {
  final supabase = Supabase.instance.client;

  List<Purchase> _purchases = [];
  List<Purchase> _filteredPurchases = [];

  Map<String, List<PurchaseItem>> _itemsCache = {};

  bool _loading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  int _page = 0;
  final int _limit = 10;

  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;

  PurchaseSortOption _currentSort = PurchaseSortOption.createdAtNewest;
  PurchaseFilterOption _currentFilter = PurchaseFilterOption.all;

  final SupabaseClient _client = Supabase.instance.client;
  final LicenceService _licenceService = LicenceService();

  late UserController userController;

  Stream<LicenceModel?>? _licenceStream;

  @override
  void initState() {
    super.initState();

    userController = Get.find<UserController>();
    _licenceStream =
        LicenceService().listenUserLicence(_client.auth.currentUser!.id);
    _loadPurchases(reset: true);
  }

  Stream<LicenceModel?> fetchLicenceStreamWithRetry() async* {
    while (true) {
      try {
        yield* _licenceStream!; // ton stream original
        await Future.delayed(const Duration(seconds: 5)); // retry si terminé
      } catch (e) {
        print("Erreur de stream, retry dans 5s : $e");
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  /// 🔹 Charger les achats (pagination depuis la vue purchases_with_total)
  Future<void> _loadPurchases({bool reset = false}) async {
    if (_isLoadingMore) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (reset) {
      _page = 0;
      _purchases.clear();
      _filteredPurchases.clear();
      _hasMore = true;
      _itemsCache.clear();
      setState(() => _loading = true);
    }

    setState(() => _isLoadingMore = true);

    try {
      final res = await supabase
          .from('purchases_with_total')
          .select()
          .eq('user_id', userId) // 🔹 filtrer par utilisateur
          .order('created_at', ascending: false)
          .range(_page * _limit, (_page + 1) * _limit - 1);

      final newPurchases = List<Map<String, dynamic>>.from(res)
          .map((m) => Purchase.fromMap(m))
          .toList();

      // Précharger les items associés
      for (var purchase in newPurchases) {
        await _preloadItems(purchase.id!);
      }

      setState(() {
        _purchases.addAll(newPurchases);
        _filteredPurchases.addAll(newPurchases);
        _hasMore = newPurchases.length == _limit;
        if (_hasMore) _page++;
      });
    } catch (e) {
      print("Erreur pagination: $e");
    } finally {
      setState(() {
        _loading = false;
        _isLoadingMore = false;
      });
    }
  }

  /// 🔹 Précharge les items d’un achat donné
  Future<void> _preloadItems(String purchaseId) async {
    try {
      final itemsRes = await supabase
          .from('purchase_items')
          .select()
          .eq('purchase_id', purchaseId);

      if (itemsRes != null) {
        _itemsCache[purchaseId] = List<Map<String, dynamic>>.from(itemsRes)
            .map((m) => PurchaseItem.fromMap(m))
            .toList();
      }
    } catch (e) {
      print("Erreur preload items: $e");
    }
  }

  Future<List<PurchaseItem>> _loadItems(String purchaseId) async {
    return _itemsCache[purchaseId] ?? [];
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _applySearch(""); // reset
      FocusScope.of(context).unfocus();
    });
  }

  List<Purchase> _applyFilter(List<Purchase> purchases) {
    switch (_currentFilter) {
      // 🔵 GROUPE TOUTES
      case PurchaseFilterOption.all:
        return purchases;

      case PurchaseFilterOption.rehaussementAll:
        return purchases
            .where((p) => p.purchaseType == "Rehaussement")
            .toList();

      case PurchaseFilterOption.retailAll:
        return purchases.where((p) => p.purchaseType == "Retail").toList();

      case PurchaseFilterOption.dettes:
        return purchases.where((p) => p.totalRemaining > 0).toList();

      case PurchaseFilterOption.fullyPaid:
        return purchases.where((p) => p.totalRemaining == 0).toList();

      case PurchaseFilterOption.semiPaid:
        return purchases
            .where((p) => p.totalRemaining > 0 && p.totalPaid > 0)
            .toList();

      case PurchaseFilterOption.all_not_pos_not_valid:
        return purchases
            .where((p) => !p.positioned && !p.validated)
            .toList();
      case PurchaseFilterOption.all_pos_not_valid:
        return purchases
            .where((p) => p.positioned && !p.validated)
            .toList();
      case PurchaseFilterOption.all_pos_valid:
        return purchases
            .where((p) => p.positioned && p.validated)
            .toList();

      // 🟠 GROUPE REHAUSSEMENT
      case PurchaseFilterOption.rh_not_pos_not_valid:
        return purchases
            .where((p) =>
                p.purchaseType == "Rehaussement" &&
                !p.positioned &&
                !p.validated)
            .toList();

      case PurchaseFilterOption.rh_pos_not_valid:
        return purchases
            .where((p) =>
                p.purchaseType == "Rehaussement" &&
                p.positioned &&
                !p.validated)
            .toList();

      case PurchaseFilterOption.rh_pos_valid:
        return purchases
            .where((p) =>
                p.purchaseType == "Rehaussement" && p.positioned && p.validated)
            .toList();

      // 🟢 GROUPE RETAIL
      case PurchaseFilterOption.rt_not_pos_not_valid:
        return purchases
            .where((p) =>
                p.purchaseType == "Retail" && !p.positioned && !p.validated)
            .toList();

      case PurchaseFilterOption.rt_pos_not_valid:
        return purchases
            .where((p) =>
                p.purchaseType == "Retail" && p.positioned && !p.validated)
            .toList();

      case PurchaseFilterOption.rt_pos_valid:
        return purchases
            .where((p) =>
                p.purchaseType == "Retail" && p.positioned && p.validated)
            .toList();
    }
  }

  void _applySorting() {
    setState(() {
      _filteredPurchases.sort((a, b) {
        switch (_currentSort) {
          case PurchaseSortOption.buyerNameAsc:
            return a.buyerName
                .toLowerCase()
                .compareTo(b.buyerName.toLowerCase());
          case PurchaseSortOption.buyerNameDesc:
            return b.buyerName
                .toLowerCase()
                .compareTo(a.buyerName.toLowerCase());
          case PurchaseSortOption.createdAtNewest:
            return (b.createdAt ?? DateTime(0))
                .compareTo(a.createdAt ?? DateTime(0));
          case PurchaseSortOption.createdAtOldest:
            return (a.createdAt ?? DateTime(0))
                .compareTo(b.createdAt ?? DateTime(0));
          case PurchaseSortOption.updatedAtNewest:
            return (b.updatedAt ?? DateTime(0))
                .compareTo(a.updatedAt ?? DateTime(0));
          case PurchaseSortOption.updatedAtOldest:
            return (a.updatedAt ?? DateTime(0))
                .compareTo(b.updatedAt ?? DateTime(0));
          case PurchaseSortOption.totalAmountHighToLow:
            return b.totalAmount.compareTo(a.totalAmount);
          case PurchaseSortOption.totalAmountLowToHigh:
            return a.totalAmount.compareTo(b.totalAmount);
          case PurchaseSortOption.totalPvHighToLow:
            return b.totalPv.compareTo(a.totalPv);
          case PurchaseSortOption.totalPvLowToHigh:
            return a.totalPv.compareTo(b.totalPv);
        }
      });
    });
  }

  // 🔹 Filtrage local
  void _applySearch(String keyword) {
    final kw = keyword.trim().toLowerCase();

    if (kw.isEmpty) {
      _filteredPurchases = List.from(_purchases); // reset complet
    } else {
      final parsedNumber = double.tryParse(kw);

      _filteredPurchases = _purchases.where((p) {
        // 🔹 filtre sur la source (_purchases)
        final matchText = p.buyerName.toLowerCase().contains(kw) ||
            p.gn.toLowerCase().contains(kw) ||
            (p.comment?.toLowerCase().contains(kw) ?? false);

        final matchNumber = parsedNumber != null &&
            (p.totalPv.toString().contains(kw) ||
                p.totalAmount.toString().contains(kw));

        return matchText || matchNumber;
      }).toList();
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async {
        if (_isSearching) {
          _closeSearch();
          return false;
        }
        return true;
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            bottom: TabBar(
              dividerHeight: 0,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.textTheme.bodyMedium?.color,
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              tabs: [
                Tab(text: 'Achats'.tr),
                Tab(text: 'Creation compte'.tr),
              ],
            ),
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _applySearch,
                    maxLength: 20,
                    decoration: InputDecoration(
                      hintText: "Rechercher par nom, prix, pv, ou description",
                      focusedBorder: InputBorder.none,
                      border: InputBorder.none,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onBackground.withOpacity(0.6),
                      ),
                      suffixIcon: IconButton(
                        icon:
                            Icon(Icons.close, color: colorScheme.onBackground),
                        onPressed: _closeSearch,
                      ),
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onBackground,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // -----------------------------
                      //   INFOS STOCKISTE
                      // -----------------------------
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "STOCKISTE ${userController.matricule ?? ''}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            userController.fullName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),

                      // -----------------------------
                      //   BOUTON RECHERCHE
                      // -----------------------------
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isSearching = true;
                          });
                        },
                        icon: Icon(
                          Icons.search,
                          color: colorScheme.onBackground,
                        ),
                      ),
                    ],
                  ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'sort':
                      _showSortModal();
                      break;
                    case 'filter':
                      _showFilterModal();
                      break;
                    case 'statisques':
                      showPurchasesStatsBottomSheet(context);
                      break;
                    case 'licence':
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => LicencesPage()));
                      break;
                    case 'produits':
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => GestionProduits()));
                      break;
                    case 'corbeille':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PurchaseCorbeillePage(
                            userId: _client.auth.currentUser!.id,
                          ),
                        ),
                      );
                      break;
                      case 'profil':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfilePage()
                        ),
                      );
                      break;
                    case 'promotion':
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PromotionPage(
                                    readOnly:
                                        userController.isAdmin ? false : true,
                                  )));
                      break;
                    case 'logout':
                      _showBottomLogout();
                      break;
                  }
                },
                itemBuilder: (context) {
                  final isAdmin = userController.isAdmin;

                  final List<PopupMenuEntry<String>> items = [
                    const PopupMenuItem(
                      value: 'sort',
                      child: Text("Trier"),
                    ),
                    const PopupMenuItem(
                      value: 'filter',
                      child: Text("Filtrer"),
                    ),
                    const PopupMenuItem(
                      value: 'statisques',
                      child: Text("Voir statisques"),
                    ),
                    PopupMenuItem(
                      value: 'promotion',
                      child: Text(isAdmin
                          ? "Gerer les promotions"
                          : "Tiroire des promotions"),
                    ),
                  ];

                  // 🟦 — Options admin uniquement
                  if (isAdmin) {
                    items.addAll([
                      const PopupMenuItem(
                        value: 'licence',
                        child: Text("Gerer les licences"),
                      ),
                      const PopupMenuItem(
                        value: 'produits',
                        child: Text("Gerer les produits"),
                      ),

                    ]);
                  }

                  items.add( const PopupMenuItem(
                    value: 'corbeille',
                    child: Text("Corbeille"),
                  ),);

                  items.add(const PopupMenuDivider());

                  items.add(
                      const PopupMenuItem(
                        value: 'profil',
                        child: Text("Modifier profil"),
                      )
                  );

                  items.add(const PopupMenuDivider());
                  items.add(
                    const PopupMenuItem(
                      value: 'logout',
                      child: Text("Se déconnecter"),
                    ),
                  );
                  return items;
                },
              )
            ],
          ),
          body: _licenceStream == null
              ? const Center(
                  child: Text(
                    "Aucune session utilisateur trouvée.",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : StreamBuilder(
                  stream: _licenceStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      // ✅ Vérifier si c'est une erreur réseau ou Timeout
                      final error = snapshot.error;
                      String errorMessage = "Erreur inattendue";
                      if (error is RealtimeSubscribeException) {
                        errorMessage =
                            "Impossible de se connecter au serveur. Vérifiez votre connexion internet.";
                      } else if (error is SocketException) {
                        errorMessage =
                            "Erreur réseau, verifiez votre connectivité.";
                      } else if (error.toString().contains("Timeout")) {
                        errorMessage =
                            "La connexion a expiré. Veuillez réessayer.";
                      } else {
                        errorMessage = error.toString();
                      }

                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              errorMessage,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _licenceStream =
                                      _licenceService.listenUserLicence(
                                          _client.auth.currentUser!.id);
                                });
                              },
                              child: const Text("Réessayer"),
                            )
                          ],
                        ),
                      );
                    }

                    final licence = snapshot.data;

                    if (licence == null || licence.userId == null) {
                      return const Center(
                        child: Text(
                          "❌ Aucune licence trouvée pour cet utilisateur.",
                          style: TextStyle(fontSize: 16, color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final now = DateTime.now();
                    final isExpired = licence.expiresAt.isBefore(now);
                    final dateExp =
                        DateFormat('dd MMMM yyyy').format(licence.expiresAt);

                    if (isExpired) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isExpired
                                        ? Icons.error_outline
                                        : Icons.verified,
                                    color:
                                        isExpired ? Colors.red : Colors.green,
                                    size: 60,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    isExpired
                                        ? "🔴 Votre licence a expiré le $dateExp"
                                        : "✅ Licence active jusqu’au $dateExp",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: isExpired
                                          ? Colors.red
                                          : Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    "Code licence : ${licence.code}",
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.blueGrey),
                                  ),
                                  const SizedBox(height: 20),
                                  if (isExpired)
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.refresh),
                                      label:
                                          const Text("Renouveler la licence"),
                                      onPressed: () {
                                        // 👉 Naviguer vers une page de renouvellement
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    } else {
                      return TabBarView(children: [
                        _loading
                            ? const Center(child: CircularProgressIndicator())
                            : RefreshIndicator(
                                onRefresh: () => _loadPurchases(reset: true),
                                // 🔹 Le RefreshIndicator doit entourer TOUT le contenu
                                child:
                                    _isSearching && _filteredPurchases.isEmpty
                                        ? Center(
                                            child: Text(
                                              "Aucun achat de (${_getFilterOptionLabel(_currentFilter)}) correspondant pour ${_searchController.text}",
                                              style:
                                                  const TextStyle(fontSize: 16),
                                              textAlign: TextAlign.center,
                                            ),
                                          )
                                        : _filteredPurchases.isEmpty
                                            ? ListView(
                                                // 🔹 Important : permet de tirer même sans contenu
                                                physics:
                                                    const AlwaysScrollableScrollPhysics(),
                                                children: [
                                                  SizedBox(height: 250),
                                                  Center(
                                                    child: Text(
                                                      "Aucun achat de (${_getFilterOptionLabel(_currentFilter)}) pour l'instant, tirer vers le bas pour actualiser",
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Builder(
                                                builder: (context) {
                                                  final filteredPurchases =
                                                      _applyFilter(
                                                          _filteredPurchases);
                                                  PurchaseService
                                                      purchaseService =
                                                      PurchaseService(
                                                          supabase: supabase);

                                                  return ListView.builder(
                                                    physics:
                                                        const AlwaysScrollableScrollPhysics(),
                                                    itemCount: filteredPurchases
                                                            .length +
                                                        (_hasMore ? 1 : 0),
                                                    itemBuilder:
                                                        (context, index) {
                                                      if (index ==
                                                          filteredPurchases
                                                              .length) {
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(16.0),
                                                          child: Center(
                                                            child:
                                                                ElevatedButton(
                                                              onPressed: _isLoadingMore
                                                                  ? null
                                                                  : () => _loadPurchases(
                                                                      reset:
                                                                          false),
                                                              child:
                                                                  _isLoadingMore
                                                                      ? const SizedBox(
                                                                          width:
                                                                              20,
                                                                          height:
                                                                              20,
                                                                          child:
                                                                              CircularProgressIndicator(
                                                                            strokeWidth:
                                                                                2,
                                                                          ),
                                                                        )
                                                                      : const Text(
                                                                          "Afficher plus"),
                                                            ),
                                                          ),
                                                        );
                                                      }

                                                      final purchase =
                                                          filteredPurchases[
                                                              index];
                                                      final items = _itemsCache[
                                                              purchase.id] ??
                                                          [];

                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 6.0),
                                                        child: Slidable(
                                                            key: ValueKey(
                                                                purchase.id),
                                                            startActionPane:
                                                                ActionPane(
                                                              motion:
                                                                  const DrawerMotion(),
                                                              extentRatio: 0.25,
                                                              children: [
                                                                SlidableAction(
                                                                  onPressed: (context) async {
                                                                    try {
                                                                      // 1️⃣ Vérification : commandes incomplètes ne peuvent PAS être positionnées
                                                                      if (purchase.paymentMethod == "debt" ||
                                                                          purchase.paymentMethod == "semi_cash" ||
                                                                          purchase.paymentMethod == "semi_orange_money" ||
                                                                          purchase.paymentMethod == "semi_ecash") {
                                                                        showErrorSnackbar(
                                                                          context: context,
                                                                          message: "Payer complètement la commande avant de positionner.",
                                                                        );
                                                                        return;
                                                                      }

                                                                      // 2️⃣ CAS : on veut DÉPOSITIONNER → mais la commande est validée
                                                                      if (purchase.positioned && purchase.validated) {
                                                                        showErrorSnackbar(
                                                                          context: context,
                                                                          message: "Invalider la commande avant de dépositionner !",
                                                                        );
                                                                        return; // ⛔ On stoppe avant le code PIN
                                                                      }

                                                                      // 3️⃣ On demande le code PIN SEULEMENT SI l’action est autorisée
                                                                      final confirmed = await showPinConfirmationDialog(context);
                                                                      if (!confirmed) return;

                                                                      // 4️⃣ Exécution
                                                                      if (!purchase.positioned) {
                                                                        // 👉 Positionner
                                                                        final success = await purchaseService.markPositioned(purchase.id!);
                                                                        if (!mounted) return;
                                                                        if (success) {
                                                                          setState(() => purchase.positioned = true);
                                                                          showSucessSnackbar(
                                                                            context: context,
                                                                            message: "Commande positionnée 📌",
                                                                          );
                                                                        }
                                                                      } else {
                                                                        // 👉 Dépositionner (ici déjà validé = impossible, car filtré plus haut)
                                                                        final success = await purchaseService.unmarkPositioned(purchase.id!);
                                                                        if (!mounted) return;
                                                                        if (success) {
                                                                          setState(() => purchase.positioned = false);
                                                                          showSucessSnackbar(
                                                                            context: context,
                                                                            message: "Commande dépositionnée ❌",
                                                                          );
                                                                        }
                                                                      }

                                                                    } catch (e) {
                                                                      if (!mounted) return;
                                                                      print("Erreur inattendue ❌ : $e");
                                                                      showErrorSnackbar(
                                                                        context: context,
                                                                        message: "Erreur inattendue ❌ : $e",
                                                                      );
                                                                    }
                                                                  },

                                                                  backgroundColor:
                                                                  purchase.positioned ? Colors.orange : Colors.blue,
                                                                  foregroundColor: Colors.white,
                                                                  icon: purchase.positioned ? Icons.undo : Icons.push_pin,
                                                                  label: purchase.positioned ? "Déposition" : "Positionner",
                                                                ),

                                                              ],
                                                            ),
                                                            endActionPane:
                                                                ActionPane(
                                                              motion:
                                                                  const DrawerMotion(),
                                                              extentRatio: 0.25,
                                                              children: [
                                                                SlidableAction(
                                                                  onPressed: (context) async {
                                                                    final parentContext = this.context; // 👈 Le bon contexte

                                                                    try {
                                                                      // 1️⃣ Commande doit être positionnée avant validation
                                                                      if (!purchase.positioned) {
                                                                        showErrorSnackbar(
                                                                          context: parentContext,
                                                                          message: "Positionner d'abord avant de valider.",
                                                                        );
                                                                        return;
                                                                      }

                                                                      // 2️⃣ Vérification PIN
                                                                      final pinConfirmed = await showPinConfirmationDialog(parentContext);
                                                                      if (!pinConfirmed) return;

                                                                      if (!purchase.validated) {
                                                                        // 3️⃣ Validation
                                                                        final success = await purchaseService.markValidated(purchase.id!);
                                                                        if (!mounted) return;

                                                                        if (success) {
                                                                          setState(() => purchase.validated = true);
                                                                          showSucessSnackbar(
                                                                            context: parentContext,
                                                                            message: "Commande validée ✅",
                                                                          );
                                                                        }
                                                                      } else {
                                                                        // 4️⃣ Invalidation → 2 vérifications

                                                                        final confirmed = await showConfirmationBottomSheet(
                                                                          context: parentContext,
                                                                          action: "Invalider",
                                                                          correctName: purchase.buyerName,
                                                                          correctMatricule: purchase.gn,
                                                                        );
                                                                        if (confirmed != true) return;

                                                                        final success = await purchaseService.unmarkValidated(purchase.id!);
                                                                        if (!mounted) return;

                                                                        if (success) {
                                                                          setState(() => purchase.validated = false);
                                                                          showSucessSnackbar(
                                                                            context: parentContext,
                                                                            message: "Commande invalidée ❌",
                                                                          );
                                                                        }
                                                                      }

                                                                    } catch (e) {
                                                                      if (!mounted) return;

                                                                      print("Erreur inattendue ❌ : $e");
                                                                      showErrorSnackbar(
                                                                        context: parentContext,
                                                                        message: "Erreur inattendue ❌ : $e",
                                                                      );
                                                                    }
                                                                  },

                                                                  backgroundColor: purchase
                                                                          .validated
                                                                      ? Colors
                                                                          .orange
                                                                      : Colors
                                                                          .blue,
                                                                  foregroundColor:
                                                                      Colors
                                                                          .white,
                                                                  icon: purchase
                                                                          .validated
                                                                      ? Icons
                                                                          .undo
                                                                      : Icons
                                                                          .check_circle,
                                                                  label: purchase
                                                                          .validated
                                                                      ? "Invalider"
                                                                      : "Valider",
                                                                ),
                                                              ],
                                                            ),
                                                            child: // 🔹 ExpansionTile inchangé (affichage de la commande, badges, items, etc.)
                                                                GestureDetector(
                                                                  onLongPress: () => CopyHelper.copyText(
                                                                    context: context,
                                                                    text: purchase.gn,
                                                                    name: "Matricule",
                                                                  ),
                                                                  child: ExpansionTile(
                                                                                                                                title: Text(purchase
                                                                    .buyerName),
                                                                                                                                subtitle: Wrap(
                                                                  spacing: 6,
                                                                  runSpacing: 4,
                                                                  crossAxisAlignment:
                                                                      WrapCrossAlignment
                                                                          .center,
                                                                  children: [
                                                                    // Matricule / GN
                                                                    SizedBox(
                                                                      width: 120,
                                                                      child: Text(
                                                                        purchase
                                                                            .gn,
                                                                        overflow:
                                                                            TextOverflow
                                                                                .ellipsis,
                                                                      ),
                                                                    ),
                                                                    // Type de commande
                                                                    SizedBox(
                                                                      width: 120,
                                                                      child: Text(
                                                                        purchase.purchaseType == 'Retail' &&
                                                                                purchase.cycleRetail != null &&
                                                                                purchase.cycleRetail!.isNotEmpty
                                                                            ? '${purchase.purchaseType} (${purchase.cycleRetail})'
                                                                            : purchase.purchaseType,
                                                                        style: const TextStyle(
                                                                            fontStyle:
                                                                                FontStyle.italic),
                                                                      ),
                                                                    ),
                                                                    // Badge Positionné
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
                                                                            color: purchase.positioned
                                                                                ? Colors.green
                                                                                : Colors.red,
                                                                            borderRadius:
                                                                                BorderRadius.circular(12),
                                                                          ),
                                                                          child:
                                                                              Text(
                                                                            purchase.positioned
                                                                                ? "Positionné"
                                                                                : "Non positionné",
                                                                            style: const TextStyle(
                                                                                fontSize: 10,
                                                                                color: Colors.white),
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              6,
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
                                                                            color: purchase.validated
                                                                                ? Colors.green
                                                                                : Colors.red,
                                                                            borderRadius:
                                                                                BorderRadius.circular(12),
                                                                          ),
                                                                          child:
                                                                              Text(
                                                                            purchase.validated
                                                                                ? "Validée"
                                                                                : "Non validée",
                                                                            style: const TextStyle(
                                                                                fontSize: 10,
                                                                                color: Colors.white),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                                                                                ),
                                                                                                                                trailing: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .end,
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Text(
                                                                        "Total: ${currencyFormat.format(purchase.totalAmount)} GNF"),
                                                                    Text(
                                                                        "PV: ${purchase.totalPv}"),
                                                                    Text(getPaymentMethodLabel(
                                                                        purchase
                                                                            .paymentMethod))
                                                                  ],
                                                                                                                                ),
                                                                                                                                children: [
                                                                  if (items
                                                                      .isEmpty)
                                                                    const Padding(
                                                                      padding:
                                                                          EdgeInsets.all(
                                                                              8.0),
                                                                      child: Text(
                                                                          "Aucun produit"),
                                                                    )
                                                                  else
                                                                    Padding(
                                                                      padding: const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              40.0,
                                                                          right:
                                                                              16),
                                                                      child:
                                                                          Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment
                                                                                .start,
                                                                        children:
                                                                            items.map(
                                                                                (item) {
                                                                          final manquant =
                                                                              item.quantityTotal -
                                                                                  item.quantityReceived;
                                                                          final restant =
                                                                              item.quantityTotal -
                                                                                  item.quantityPaid;
                                                                          final isPromo =
                                                                              item.isPromo;

                                                                          // Texte réception
                                                                          String
                                                                              recuText;
                                                                          if (item.quantityReceived ==
                                                                              item
                                                                                  .quantityTotal) {
                                                                            recuText =
                                                                                "Tout reçu ✅";
                                                                          } else if (item.quantityReceived ==
                                                                              0) {
                                                                            recuText =
                                                                                "Aucun reçu";
                                                                          } else {
                                                                            recuText =
                                                                                "${item.quantityReceived} reçu${item.quantityReceived > 1 ? 's' : ''}, $manquant manquant${manquant > 1 ? 's' : ''}";
                                                                          }

                                                                          // Texte paiement
                                                                          String
                                                                              payeText;
                                                                          if (item.quantityPaid ==
                                                                              item
                                                                                  .quantityTotal) {
                                                                            payeText =
                                                                                "Tout payé 💰";
                                                                          } else if (item.quantityPaid ==
                                                                              0) {
                                                                            payeText =
                                                                                "Rien payé";
                                                                          } else {
                                                                            payeText =
                                                                                "${item.quantityPaid} payé${item.quantityPaid > 1 ? 's' : ''}, reste $restant";
                                                                          }

                                                                          return Theme(
                                                                            data:
                                                                                Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                                                            child:
                                                                                ExpansionTile(
                                                                              key:
                                                                                  ValueKey(item.productId),
                                                                              tilePadding:
                                                                                  const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                                                                              childrenPadding:
                                                                                  const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                                                                              title:
                                                                                  Text(
                                                                                "${item.quantityTotal} ${item.productName}",
                                                                                style: TextStyle(color: isPromo ? Colors.blueAccent : null),
                                                                              ),
                                                                              children: [
                                                                                Text(
                                                                                  "$recuText  ${isPromo ? "" : "- $payeText"}",
                                                                                  style: const TextStyle(fontSize: 14),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          );
                                                                        }).toList(),
                                                                      ),
                                                                    ),

                                                                  SizedBox(
                                                                      height: 16),

                                                                  // 🔹 Totaux paiement & PV
                                                                  Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .only(
                                                                            left:
                                                                                16.0),
                                                                    child: Align(
                                                                      alignment:
                                                                          Alignment
                                                                              .centerLeft,
                                                                      child:
                                                                          Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment
                                                                                .start,
                                                                        children: [
                                                                          Text(
                                                                              "Payé: ${currencyFormat.format(purchase.totalPaid)} - reste : ${currencyFormat.format(purchase.totalRemaining)}"),
                                                                          Text(
                                                                              "PV Payés: ${purchase.totalPvPaid} - reste : ${purchase.totalPvRemaining}"),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),

                                                                  // 🔹 Commentaire
                                                                  if (purchase.comment !=
                                                                          null &&
                                                                      purchase
                                                                          .comment!
                                                                          .isNotEmpty)
                                                                    Padding(
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .all(
                                                                              16.0),
                                                                      child:
                                                                          Align(
                                                                        alignment:
                                                                            Alignment
                                                                                .centerLeft,
                                                                        child:
                                                                            Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            Text(
                                                                              "Commentaires :",
                                                                              style:
                                                                                  TextStyle(fontStyle: FontStyle.italic),
                                                                            ),
                                                                            Container(
                                                                              padding:
                                                                                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                              decoration:
                                                                                  BoxDecoration(
                                                                                color: Colors.blueGrey,
                                                                                borderRadius: BorderRadius.circular(12),
                                                                              ),
                                                                              child:
                                                                                  Text(
                                                                                purchase.comment!,
                                                                                overflow: TextOverflow.ellipsis,
                                                                                style: const TextStyle(fontSize: 12, color: Colors.white),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),

                                                                  // 🔹 Ligne bas (date + menu)
                                                                  Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .spaceBetween,
                                                                    children: [
                                                                      Padding(
                                                                        padding: const EdgeInsets
                                                                            .only(
                                                                            left:
                                                                                16.0),
                                                                        child: Text(
                                                                            formatDate(
                                                                                purchase.createdAt)),
                                                                      ),
                                                                      Row(
                                                                        children: [
                                                                          purchase.updatedAt !=
                                                                                  null
                                                                              ? IconButton(
                                                                                  icon: const Icon(Icons.edit_calendar),
                                                                                  onPressed: () {
                                                                                    Navigator.push(
                                                                                      context,
                                                                                      MaterialPageRoute(
                                                                                        builder: (_) => PurchaseHistoryPage(purchaseId: purchase.id!),
                                                                                      ),
                                                                                    );
                                                                                  },
                                                                                )
                                                                              : const SizedBox(),

                                                                          // ------------------------------------------------
                                                                          // 🔥 AJOUT VERSION FINALE : hasPromoProduits
                                                                          // ------------------------------------------------
                                                                          Builder(builder:
                                                                              (context) {
                                                                            bool hasPromoProduits = items.any((item) =>
                                                                                item.isPromo ==
                                                                                true);

                                                                            return PopupMenuButton<
                                                                                String>(
                                                                              icon:
                                                                                  const Icon(Icons.more_vert),
                                                                              onSelected:
                                                                                  (value) async {
                                                                                if (value == 'promo') {
                                                                                  final itemsRes = await _loadItems(purchase.id!);

                                                                                  _openPromoManager(context, purchase, itemsRes);
                                                                                } else if (value == 'edit') {
                                                                                  final itemsRes = await _loadItems(purchase.id!);
                                                                                  await Navigator.push(
                                                                                    context,
                                                                                    MaterialPageRoute(
                                                                                      builder: (_) => NewPurchasePage(
                                                                                        purchase: purchase,
                                                                                        purchaseItems: itemsRes,
                                                                                      ),
                                                                                    ),
                                                                                  );
                                                                                  _loadPurchases(reset: true);
                                                                                } else if (value == 'delete') {
                                                                                  final confirm = await showDialog<bool>(
                                                                                    context: context,
                                                                                    builder: (_) => AlertDialog(
                                                                                      title: const Text("Confirmer la suppression"),
                                                                                      content: const Text("Voulez-vous vraiment supprimer cet achat ?"),
                                                                                      actions: [
                                                                                        TextButton(
                                                                                          child: const Text("Annuler"),
                                                                                          onPressed: () => Navigator.pop(context, false),
                                                                                        ),
                                                                                        TextButton(
                                                                                          child: const Text("Supprimer"),
                                                                                          onPressed: () => Navigator.pop(context, true),
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  );

                                                                                  if (confirm == true) {
                                                                                    try {
                                                                                      final insertedCorbeille = await supabase
                                                                                          .from('purchase_corbeille')
                                                                                          .insert({
                                                                                            'parent_purchase_id': purchase.id,
                                                                                            'buyer_name': purchase.buyerName,
                                                                                            'payment_method': purchase.paymentMethod,
                                                                                            'gn': purchase.gn,
                                                                                            'positioned': purchase.positioned,
                                                                                            'validated': purchase.validated,
                                                                                            'purchase_type': purchase.purchaseType,
                                                                                            'cycle_retail': purchase.cycleRetail,
                                                                                            'total_amount': purchase.totalAmount,
                                                                                            'total_pv': purchase.totalPv,
                                                                                            'user_id': purchase.userId,
                                                                                            'comment': purchase.comment,
                                                                                          })
                                                                                          .select()
                                                                                          .single();

                                                                                      final corbeilleId = insertedCorbeille['id'] as String;

                                                                                      final corbeilleItems = items.map((item) {
                                                                                        return {
                                                                                          'corbeille_id': corbeilleId,
                                                                                          'product_id': item.productId,
                                                                                          'product_name': item.productName,
                                                                                          'unit_price': item.unitPrice,
                                                                                          'unit_pv': item.unitPv,
                                                                                          'is_promo': item.isPromo,
                                                                                          'quantity_total': item.quantityTotal,
                                                                                          'quantity_received': item.quantityReceived,
                                                                                          'quantity_missing': item.quantityMissing,
                                                                                          'quantity_paid': item.quantityPaid,
                                                                                          'montant_total_du': item.montantTotalDu,
                                                                                          'montant_paid': item.montantPaid,
                                                                                          'montant_remaining': item.montantRemaining,
                                                                                        };
                                                                                      }).toList();

                                                                                      await supabase.from('purchase_corbeille_items').insert(corbeilleItems);

                                                                                      await supabase.from('purchases').delete().eq('id', purchase.id!);

                                                                                      setState(() {
                                                                                        _purchases.removeWhere((p) => p.id == purchase.id);
                                                                                        _filteredPurchases.removeWhere((p) => p.id == purchase.id);
                                                                                        _itemsCache.remove(purchase.id);
                                                                                      });

                                                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                                                        SnackBar(
                                                                                          content: Text("Commande de ${purchase.buyerName} supprimée ✅"),
                                                                                        ),
                                                                                      );
                                                                                    } catch (e) {
                                                                                      print("Erreur suppression: $e");
                                                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                                                        const SnackBar(
                                                                                          content: Text("Erreur lors de la suppression ❌"),
                                                                                        ),
                                                                                      );
                                                                                    }
                                                                                  }
                                                                                }
                                                                              },
                                                                              itemBuilder: (context) =>
                                                                                  [
                                                                                if (hasPromoProduits)
                                                                                  PopupMenuItem(
                                                                                    value: 'promo',
                                                                                    child: Text("Gérer produits promo"),
                                                                                  ),
                                                                                PopupMenuItem(
                                                                                  value: 'edit',
                                                                                  enabled: purchase.validated || purchase.positioned ? false : true,
                                                                                  child: Text("Modifier"),
                                                                                ),
                                                                                PopupMenuItem(
                                                                                  value: 'delete',
                                                                                  child: Text("Supprimer"),
                                                                                ),
                                                                              ],
                                                                            );
                                                                          }),
                                                                        ],
                                                                      ),
                                                                    ],
                                                                  ),
                                                                                                                                ],
                                                                                                                              ),
                                                                )),
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                              ),
                        AccountsListPage(
                          isSearching: _isSearching,
                          searchController: _searchController,
                        ),
                      ]);
                    }
                  },
                ),
          floatingActionButton: FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () => showOptionsBottomSheetModal(context),
          ),
        ),
      ),
    );
  }

  void _openPromoManager(
      BuildContext context, Purchase purchase, List<PurchaseItem> items) async {
    final promoItems = items.where((i) => i.isPromo).toList();

    if (promoItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Aucun produit promo dans cette commande.")),
      );
      return;
    }

    final updatedItems = await showModalBottomSheet<List<PurchaseItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => PromoManagerSheet(
        purchase: purchase,
        promoItems: promoItems,
      ),
    );

    // Si l’utilisateur a sauvegardé
    if (updatedItems != null) {
      setState(() {
        // Mise à jour locale (simule le realtime)
        for (final item in updatedItems) {
          final index = items.indexWhere((x) => x.id == item.id);
          if (index != -1) {
            items[index] = item;
          }
        }
      });
    }
  }

  Future<bool?> showConfirmationBottomSheet({
    required BuildContext context,
    required String action, // "Deposition" ou "Invalider"
    required String correctName, // Nom exact de la commande
    required String correctMatricule, // Matricule exact de la commande
  }) async {
    final _formKey = GlobalKey<FormState>();
    String enteredName = '';
    String enteredMatricule = '';

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$action la commande",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: "Nom",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? "Champ requis" : null,
                  onSaved: (value) => enteredName = value!.trim(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: "Matricule",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? "Champ requis" : null,
                  onSaved: (value) => enteredMatricule = value!.trim(),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();

                      // ✅ Vérification que les infos saisies correspondent exactement
                      if (enteredName == correctName &&
                          enteredMatricule == correctMatricule) {
                        Navigator.of(context).pop(true); // Confirme l'action
                      } else {
                        // ❌ Affiche un message si incorrect
                        showErrorSnackbar(
                            context: context,
                            message:
                                "Nom ou matricule incorrect. Vérifiez vos saisies ❌");
                      }
                    }
                  },
                  child: const Text("Confirmer"),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> showPinConfirmationDialog(BuildContext context) async {
    final TextEditingController _pinCtrl = TextEditingController();

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false, // impossible de fermer sans répondre
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: const Text(
                "Code de confirmation",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      "Veuillez saisir le code de confirmation à 4 chiffres :"),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      hintText: "****",
                      counterText: "",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_pinCtrl.text.trim() == userController.confirmCode) {
                      Navigator.pop(context, true);
                    } else {
                      showErrorSnackbar(
                          context: context, message: "❌ Code incorrect");
                    }
                  },
                  child: const Text("Confirmer"),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showSortModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return ListView(
          shrinkWrap: true,
          children: PurchaseSortOption.values.map((option) {
            return ListTile(
              title: Text(_getSortOptionLabel(option)),
              trailing: _currentSort == option
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                setState(() {
                  _currentSort = option;
                  _applySorting();
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  String _getFilterOptionLabel(PurchaseFilterOption option) {
    switch (option) {
      case PurchaseFilterOption.all:
        return "Toutes les commandes";

      // --- GROUPE TOUTES ---
      case PurchaseFilterOption.rehaussementAll:
        return "Commandes en rehaussement";
      case PurchaseFilterOption.retailAll:
        return "Commandes en retail";
      case PurchaseFilterOption.dettes:
        return "Commandes en dettes";
      case PurchaseFilterOption.fullyPaid:
        return "Commandes totalement payées";
      case PurchaseFilterOption.semiPaid:
        return "Commandes semi payées";
      case PurchaseFilterOption.all_not_pos_not_valid:
        return "Commandes non positionnées / non validées";
      case PurchaseFilterOption.all_pos_not_valid:
        return "Commandes positionnées / non validées";
      case PurchaseFilterOption.all_pos_valid:
        return "Commandes positionnées / validées";

      // --- GROUPE REHAUSSEMENT ---
      case PurchaseFilterOption.rh_not_pos_not_valid:
        return "Rehaussement - non positionnées / non validées";
      case PurchaseFilterOption.rh_pos_not_valid:
        return "Rehaussement - positionnées / non validées";
      case PurchaseFilterOption.rh_pos_valid:
        return "Rehaussement - positionnées / validées";

      // --- GROUPE RETAIL ---
      case PurchaseFilterOption.rt_not_pos_not_valid:
        return "Retail - non positionnées / non validées";
      case PurchaseFilterOption.rt_pos_not_valid:
        return "Retail - positionnées / non validées";
      case PurchaseFilterOption.rt_pos_valid:
        return "Retail - positionnées / validées";
    }
  }

  String _getSortOptionLabel(PurchaseSortOption option) {
    switch (option) {
      case PurchaseSortOption.buyerNameAsc:
        return "Nom acheteur (A-Z)";
      case PurchaseSortOption.buyerNameDesc:
        return "Nom acheteur (Z-A)";
      case PurchaseSortOption.createdAtNewest:
        return "Date création (récentes)";
      case PurchaseSortOption.createdAtOldest:
        return "Date création (anciennes)";
      case PurchaseSortOption.updatedAtNewest:
        return "Date modification (récentes)";
      case PurchaseSortOption.updatedAtOldest:
        return "Date modification (anciennes)";
      case PurchaseSortOption.totalAmountHighToLow:
        return "Montant (du + grand au + petit)";
      case PurchaseSortOption.totalAmountLowToHigh:
        return "Montant (du + petit au + grand)";
      case PurchaseSortOption.totalPvHighToLow:
        return "PV (du + grand au + petit)";
      case PurchaseSortOption.totalPvLowToHigh:
        return "PV (du + petit au + grand)";
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SingleChildScrollView(
          child: Column(
            children: [
              // 🔵 GROUPE 1 : Toutes
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: const Text(
                    "Toutes les commandes",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: [
                    _filterItem(
                        "Toutes les commandes", PurchaseFilterOption.all),
                    _filterItem("Commandes en rehaussement",
                        PurchaseFilterOption.rehaussementAll),
                    _filterItem(
                        "Commandes en retail", PurchaseFilterOption.retailAll),
                    Divider(),
                    _filterItem(
                        "Commandes en dettes", PurchaseFilterOption.dettes),
                    _filterItem("Commandes totalement payées",
                        PurchaseFilterOption.fullyPaid),
                    _filterItem(
                        "Commandes semi payées", PurchaseFilterOption.semiPaid),
                    Divider(),
                    _filterItem("Non positionnées et non validées",
                        PurchaseFilterOption.all_not_pos_not_valid),
                    _filterItem("Positionnées et non validées",
                        PurchaseFilterOption.all_pos_not_valid),
                    _filterItem("Positionnées et validées",
                        PurchaseFilterOption.all_pos_valid),
                  ],
                ),
              ),

              // 🟠 GROUPE 2 : Rehaussement
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: const Text(
                    "Commandes en Rehaussement",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: [
                    _filterItem("Non positionnées et non validées",
                        PurchaseFilterOption.rh_not_pos_not_valid),
                    _filterItem("Positionnées et non validées",
                        PurchaseFilterOption.rh_pos_not_valid),
                    _filterItem("Positionnées et validées",
                        PurchaseFilterOption.rh_pos_valid),
                  ],
                ),
              ),

              // 🟢 GROUPE 3 : Retail
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: const Text(
                    "Commandes en Retail",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: [
                    _filterItem("Non positionnées et non validées",
                        PurchaseFilterOption.rt_not_pos_not_valid),
                    _filterItem("Positionnées et non validées",
                        PurchaseFilterOption.rt_pos_not_valid),
                    _filterItem("Positionnées et validées",
                        PurchaseFilterOption.rt_pos_valid),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Widget helper
  Widget _filterItem(String label, PurchaseFilterOption option) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: ListTile(
        title: Text(label),
        trailing: _currentFilter == option
            ? const Icon(Icons.check, color: Colors.blue)
            : null,
        onTap: () {
          setState(() => _currentFilter = option);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showBottomLogout() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Voulez-vous vraiment vous deconnecter ?",
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Annuler")),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      userController.logout(context);
                    },
                    child: Text("Se deconnecter".tr,
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../models/custumer_account.dart';
import '../services/cloudinary_service.dart';
import '../services/customer_account_service.dart';
import '../utils/copy_helper.dart';
import '../widgets/detail_image_compte.dart';
import 'nouveau_membre.dart';

class AccountsListPage extends StatefulWidget {
  final TextEditingController searchController;
  final bool isSearching;

  const AccountsListPage({super.key, required this.searchController, this.isSearching = false});

  @override
  State<AccountsListPage> createState() => _AccountsListPageState();
}

class _AccountsListPageState extends State<AccountsListPage>
    with AutomaticKeepAliveClientMixin {
  final CustomerAccountService _service = CustomerAccountService();
  final _client = Supabase.instance.client;

  List<CustomerAccount> _accounts = [];
  List<CustomerAccount> _filteredAccounts = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  final ImagePicker _picker = ImagePicker();

  @override
  bool get wantKeepAlive => true;

  /// 🔹 Chargement initial
  Future<void> _loadInitialData() async {
    try {
      final data = await _service.fetchAccounts(_client.auth.currentUser!.id);
      print("Le user_id avant : ${_client.auth.currentUser!.id}");
      if (!mounted) return;
      setState(() {
        _accounts = data;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement : $e')),
      );
    }
  }

  /// 🔹 Rafraîchissement manuel
  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    try {
      final data = await _service.fetchAccounts(_client.auth.currentUser!.id);
      if (!mounted) return;
      setState(() {
        _accounts = data;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de rafraîchissement : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  /// 🔹 Filtrage local selon le texte du controller
  void _onSearchChanged() {
    if (!mounted) return;
    _applyFilter();
  }

  void _applyFilter() {
    final query = widget.searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      _filteredAccounts = List.from(_accounts);
    } else {
      _filteredAccounts = _accounts.where((acc) {
        return acc.firstName.toLowerCase().contains(query) ||
            acc.lastName.toLowerCase().contains(query) ||
            acc.matricule!.toLowerCase().contains(query) ||
            acc.phone!.toLowerCase().contains(query) ||
            (acc.placementCode?.toLowerCase().contains(query) ?? false) ||
            (acc.sponsorCode?.toLowerCase().contains(query) ?? false) ||
            acc.idNumber!.toLowerCase().contains(query);
      }).toList();
    }
    setState(() {});
  }

  /// 🔹 Mise à jour en temps réel Supabase
  void _listenRealtime() {
    _subscription = _client
        .from('customer_accounts')
        .stream(primaryKey: ['id'])
        .eq('user_id', _client.auth.currentUser!.id)
        .order('created_at', ascending: false)
        .listen((event) {
          if (!mounted) return;
          _accounts = event.map((e) => CustomerAccount.fromJson(e)).toList();
          _applyFilter();
        });
  }

  /// 📸 Sélectionner une image depuis la galerie
  Future<File?> _pickImageFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) return File(pickedFile.path);
    return null;
  }

  late final _authSub;

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);

    _loadInitialData();
    _listenRealtime();

    // 🔹 Écoute les changements de connexion
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _loadInitialData(); // recharge les comptes du nouvel utilisateur
      } else {
        setState(() {
          _accounts.clear();
          _filteredAccounts.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    _subscription?.cancel();
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: widget.isSearching && _filteredAccounts.isEmpty
                  ? Center(
                child: Text(
                  "Aucun compte correspondant pour ${widget.searchController.text}",
                  style: TextStyle(
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
                  :

              _filteredAccounts.isEmpty
                  ? ListView(
                      // 🔹 Important : permet de tirer même sans contenu
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 250),
                        Center(
                          child: Text(
                            "Aucun compte pour l'instant, tirer vers le bas pour actualiser",
                            style: TextStyle(fontSize: 16,),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredAccounts.length,
                      itemBuilder: (context, index) {
                        final account = _filteredAccounts[index];
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          child: GestureDetector(
                            onLongPress: () => CopyHelper.copyText(
                              context: context,
                              text: account.matricule!,
                              name: "Matricule",
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              title: Text(
                                '${account.firstName} ${account.lastName}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              trailing: account.imageUrl != null &&
                                      account.imageUrl!.isNotEmpty
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : const Text(
                                      "Non créé",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                              subtitle: Text(
                                  '${account.matricule} • ${account.phone}\n${account.idType!.toUpperCase()}'),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 5),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _infoRow(
                                        label: 'Date de naissance',
                                        value: DateFormat('yyyy-MM-dd').format(account.birthDate),
                                        canCopy: true
                                      ),
                                      _infoRow(label: 'Pays', value: account.country),
                                      _infoRow(label: 'Province', value: account.province ?? '-'),
                                      _infoRow(label: 'Ville', value: account.city ?? '-'),
                                      _infoRow(label: 'Quartier', value: account.neighborhood ?? '-', canCopy: true),
                                      _infoRow(label: 'Téléphone', value: account.phone, canCopy: true),
                                      _infoRow(label: 'Genre', value: account.gender),
                                      _infoRow(label: 'Code sponsor', value: account.sponsorCode ?? '-', canCopy: true),
                                      _infoRow(label: 'Code placement', value: account.placementCode ?? '-', canCopy: true),
                                      _infoRow(
                                        label: 'Status',
                                        value: (account.imageUrl != null && account.imageUrl!.isNotEmpty)
                                            ? 'Créé'
                                            : 'Non créé',
                                      ),
                                      _infoRow(
                                        label: 'Créé le',
                                        value: account.createdAt != null
                                            ? DateFormat('yyyy-MM-dd HH:mm').format(account.createdAt!)
                                            : '-',
                                      ),
                                      _infoRow(
                                        label: 'Mis à jour le',
                                        value: account.updatedAt != null
                                            ? DateFormat('yyyy-MM-dd HH:mm').format(account.updatedAt!)
                                            : '-',
                                      ),

                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          const SizedBox(width: 8),
                                          account.imageUrl == null ||
                                                  account.imageUrl!.isEmpty
                                              ? ElevatedButton(
                                                  child: const Text('Assigner'),
                                                  onPressed: () async {
                                                    // Ouvrir modal sheet pour choisir une image
                                                    final selectedFile =
                                                        await _pickImageFromGallery();
                                                    if (selectedFile != null) {
                                                      _showAssignImageModal(
                                                          account, selectedFile);
                                                    }
                                                  })
                                              : ElevatedButton(
                                                  child:
                                                      const Text('Voir l\'image'),
                                                  onPressed: () {
                                                    // Ouvrir modal sheet pour voir l'image + infos
                                                    showAccountModal(
                                                        context, account);
                                                  },
                                                ),
                                          Row(
                                            children: [
                                              Text("Plus"),
                                              PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert),
                                                onSelected: (value) async {
                                                  if (value == 'edit') {
                                                    final updated =
                                                        await Navigator.push<
                                                            CustomerAccount>(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            AddAccountPage(
                                                                account: account),
                                                      ),
                                                    );
                                                    if (updated != null &&
                                                        mounted) {
                                                      final index = _accounts
                                                          .indexWhere((a) =>
                                                              a.id == updated.id);
                                                      if (index != -1)
                                                        _accounts[index] =
                                                            updated;
                                                      _applyFilter();
                                                    }
                                                  } else if (value == 'delete') {
                                                    final confirm =
                                                        await showDialog<bool>(
                                                      context: context,
                                                      builder: (_) => AlertDialog(
                                                        title: const Text(
                                                            "Confirmer la suppression"),
                                                        content: const Text(
                                                            "Voulez-vous vraiment supprimer ce compte ?"),
                                                        actions: [
                                                          TextButton(
                                                            child: const Text(
                                                                "Annuler"),
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context,
                                                                    false),
                                                          ),
                                                          TextButton(
                                                            child: const Text(
                                                                "Supprimer"),
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context,
                                                                    true),
                                                          ),
                                                        ],
                                                      ),
                                                    );

                                                    if (confirm == true) {
                                                      try {
                                                        // 🔹 1) Afficher le loader
                                                        showLoadingSnackBar(
                                                            "Suppression en cours...");



                                                        // 🔹 3) Supprime sur Cloudinary si image présente
                                                        if (account.imageUrl !=
                                                                null &&
                                                            account.imageUrl!
                                                                .isNotEmpty) {
                                                          await CloudinaryService()
                                                              .deleteCloudinaryResource(
                                                                  account
                                                                      .imageUrl!);
                                                        }

                                                        // 🔹 2) Supprime en base
                                                  await _service
                                                      .deleteAccount(
                                                  account.id!);

                                                        if (!mounted) return;

                                                        // 🔹 4) Mise à jour de la liste à l'écran
                                                        setState(() {
                                                          _accounts.removeWhere(
                                                              (a) =>
                                                                  a.id ==
                                                                  account.id);
                                                          _applyFilter();
                                                        });

                                                        // 🔹 5) Remplacer le SnackBar par un message de succès
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .hideCurrentSnackBar();
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                                "Compte supprimé avec succès ✅"),
                                                            duration: Duration(
                                                                seconds: 2),
                                                          ),
                                                        );
                                                      } catch (e) {
                                                        if (!mounted) return;

                                                        // 🔹 Remplacer par message d’erreur
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .hideCurrentSnackBar();
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(SnackBar(
                                                                content: Text(
                                                                    "Erreur suppression : $e ❌")));
                                                      }
                                                    }
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(
                                                      value: 'edit',
                                                      child: Text("Modifier")),
                                                  const PopupMenuItem(
                                                      value: 'delete',
                                                      child: Text("Supprimer")),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Future<void> _assignImageToAccount(
      CustomerAccount account, String imagePath, String matricule) async {
    try {
      // 2️⃣ Charger le fichier depuis le path
      final file = File(imagePath);

      // 3️⃣ Upload sur Cloudinary
      final uploadedUrl = await CloudinaryService.uploadImageToCloudinary(
        file,
        "preset_infos_compte", // Remplace par ton upload preset Cloudinary
      );

      if (uploadedUrl == null) {
        throw Exception("Erreur lors de l'upload sur Cloudinary");
      }

      // 4️⃣ Créer une copie du compte avec l'imageUrl mise à jour
      final updatedAccount = account.copyWith(
        imageUrl: uploadedUrl,
        matricule: matricule,
        updatedAt: DateTime.now(),
      );

      await _service.updateAccount(updatedAccount);


      // 7️⃣ Snackbar de confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Image assignée à ${account.firstName} ${account.lastName} ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l’assignation : $e ❌')),
        );
      }
    }
  }

  void _showAssignImageModal(CustomerAccount account, File selectedFile) {
    TextEditingController matriculeCtr = TextEditingController();
    bool isValidMatricule = false;
    bool isAssigning = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final mediaQuery = MediaQuery.of(context);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              child: Container(
                height: mediaQuery.size.height,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // ------------ TITRE -----------------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 24),
                            Expanded(
                              child: Text(
                                'Assignation d\'image pour ${account.firstName}',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                                softWrap: true,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ------------ IMAGE -----------------
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            selectedFile,
                            height: 300,
                            width: 300,
                            fit: BoxFit.cover,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ------------ CHAMP MATRICULE -----------------
                        TextFormField(
                          controller: matriculeCtr,
                          decoration: InputDecoration(
                            labelText: "Matricule du nouveau partenaire",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            hintText: "Ex: GN01234567",
                            hintStyle: const TextStyle(color: Colors.grey),
                          ),
                          maxLength: 10,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(10),
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                          ],
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (value) {
                            final upper = value.toUpperCase();

                            if (upper != value) {
                              matriculeCtr.value = matriculeCtr.value.copyWith(
                                text: upper,
                                selection: TextSelection.collapsed(offset: upper.length),
                              );
                            }

                            // Vérification en direct
                            final valid = RegExp(r'^[A-Z]{2}[0-9]{8}$')
                                .hasMatch(upper.trim());

                            setModalState(() => isValidMatricule = valid);
                          },
                        ),

                        const SizedBox(height: 10),

                        // ------------ BOUTON ASSIGNATION -----------------
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: (!isValidMatricule || isAssigning)
                              ? null
                              : () async {
                            setModalState(() => isAssigning = true);

                            await _assignImageToAccount(
                              account,
                              selectedFile.path,
                              matriculeCtr.text.trim(),
                            );

                            if (context.mounted) Navigator.pop(context);
                          },
                          icon: isAssigning
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.cloud_upload),
                          label: Text(
                            isAssigning
                                ? "Assignation en cours..."
                                : "Uploader et assigner",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  void showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration:
            const Duration(minutes: 1), // Long pour éviter qu'il disparaisse
        content: Row(
          children: [
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Helper pour afficher une ligne info propre
  Widget _infoRow({required String label, required String value, bool canCopy = false}) {
    return GestureDetector(
      onLongPress: () => canCopy ?      CopyHelper.copyText(
        context: context,
        text: value,
        name: label,
      ) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

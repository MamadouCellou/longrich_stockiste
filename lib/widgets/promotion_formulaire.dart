import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/promotion.dart';
import '../models/promotion_challenge.dart';
import '../models/challenge_product.dart';
import '../models/product.dart';
import '../services/cloudinary_service.dart';
import '../services/image_service.dart';
import '../services/promotion_service.dart';
import '../services/product_service.dart';

class PromotionFormPage extends StatefulWidget {
  final Promotion? promotion;
  const PromotionFormPage({super.key, this.promotion});

  @override
  State<PromotionFormPage> createState() => _PromotionFormPageState();
}

class _PromotionFormPageState extends State<PromotionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  DateTime? _startDateTime;
  DateTime? _endDateTime;

  List<PromotionChallenge> _challenges = [];
  List<Product> _allProducts = [];

  bool _loadingProducts = true;
  bool _saving = false;

  File? _imageFile;              // nouvelle image choisie
  bool _removeExistingImage = false; // indique si on veut supprimer l’image actuelle

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.promotion?.promotionName ?? '');
    _startDateTime = widget.promotion?.startDate;
    _endDateTime = widget.promotion?.endDate;
    _challenges = widget.promotion?.challenges.map((e) => e.copyWith()).toList() ?? [];
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final prods = await ProductService(supabase: Supabase.instance.client).getPromoProducts();
      setState(() {
        _allProducts = prods;
        _loadingProducts = false;
      });
    } catch (e) {
      setState(() => _loadingProducts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des produits : $e')),
      );
    }
  }

  Future<void> _selectImage() async {
    File? image = await ImageService.pickGalleryImage();
    if (image != null) {
      setState(() => _imageFile = image);
    }
  }

  Future<DateTime?> _pickDateTime({
    required String label,
    DateTime? initialDateTime,
  }) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialDateTime != null
          ? TimeOfDay.fromDateTime(initialDateTime)
          : const TimeOfDay(hour: 9, minute: 0),
    );

    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  void _addChallenge() {
    setState(() {
      _challenges.add(PromotionChallenge(
        challengeId: '',
        pvCondition: 0,
        products: [],
      ));
    });
  }

  void _removeChallenge(int index) {
    setState(() => _challenges.removeAt(index));
  }

  // 🧠 Sélection des produits pour un défi
  Future<void> _showProductSelector(int challengeIdx) async {
    final challenge = _challenges[challengeIdx];
    final selectedProducts = List<ChallengeProduct>.from(challenge.products);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Sélectionner les produits",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _allProducts.length,
                      itemBuilder: (context, index) {
                        final prod = _allProducts[index];
                        final existing = selectedProducts.firstWhere(
                              (p) => p.productId == prod.id,
                          orElse: () => ChallengeProduct(productId: '', productName: '', quantity: 0),
                        );
                        final qty = existing.quantity;

                        return ListTile(
                          title: Text(prod.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: qty > 0
                                    ? () {
                                  setModalState(() {
                                    if (qty - 1 <= 0) {
                                      selectedProducts.removeWhere((p) => p.productId == prod.id);
                                    } else {
                                      final idx = selectedProducts.indexWhere((p) => p.productId == prod.id);
                                      selectedProducts[idx] =
                                          existing.copyWith(quantity: qty - 1);
                                    }
                                  });
                                }
                                    : null,
                              ),
                              Text(qty.toString()),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  setModalState(() {
                                    if (existing.productId.isEmpty) {
                                      selectedProducts.add(
                                        ChallengeProduct(
                                          productId: prod.id!,
                                          productName: prod.name,
                                          quantity: 1,
                                        ),
                                      );
                                    } else {
                                      final idx = selectedProducts.indexWhere((p) => p.productId == prod.id);
                                      selectedProducts[idx] =
                                          existing.copyWith(quantity: qty + 1);
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text("Valider la sélection"),
                    onPressed: () {
                      setState(() {
                        _challenges[challengeIdx] =
                            challenge.copyWith(products: selectedProducts);
                      });
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _startDateTime == null || _endDateTime == null) {
      return;
    }

    setState(() => _saving = true);

    try {
      // 🔹 Gestion de l'image
      String? imageUrl = widget.promotion?.promotionUrlImage;

      // 1️⃣ Supprimer l'ancienne image si demandé
      if (_removeExistingImage && widget.promotion?.promotionUrlImage != null) {
        await CloudinaryService().deleteCloudinaryResource(widget.promotion!.promotionUrlImage);
        imageUrl = null;
      }

      // 2️⃣ Upload d'une nouvelle image si sélectionnée
      if (_imageFile != null) {
        // Supprimer l'image existante si elle existe et que l'utilisateur n'a pas coché "remove"
        if (widget.promotion?.promotionUrlImage != null && !_removeExistingImage) {
          await CloudinaryService().deleteCloudinaryResource(widget.promotion!.promotionUrlImage);
        }

        imageUrl = await CloudinaryService.uploadImageToCloudinary(
          _imageFile!,
          "preset_promotion",
        );
      }

      // 🔹 Préparer les données à sauvegarder
      final data = {
        'name': _nameController.text.trim(),
        'start_date': _startDateTime!.toIso8601String(),
        'end_date': _endDateTime!.toIso8601String(),
        'image_url': imageUrl, // IMPORTANT : ajout de l'image dans la DB
        'challenges': _challenges.map((c) => {
          'pv_condition': c.pvCondition,
          'products': c.products.map((p) => {
            'product_id': p.productId,
            'quantity': p.quantity,
          }).toList(),
        }).toList(),
      };
      // 🔹 Ajouter ou mettre à jour selon le contexte
      if (widget.promotion == null) {
        await PromotionService.addPromotion(data);
      } else {
        await PromotionService.updatePromotion(widget.promotion!.promotionId, data);
      }

      // 🔹 Feedback utilisateur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promotion enregistrée avec succès!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur sauvegarde: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.promotion == null ? "Nouvelle promotion" : "Modifier la promotion"),
      ),
      body: _loadingProducts
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Nom de la promotion"),
              validator: (v) => (v == null || v.isEmpty) ? "Obligatoire" : null,
            ),
            const SizedBox(height: 12),
            // 🕓 Choix date + heure début
            TextButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(_startDateTime != null
                  ? "Début : ${dateFormat.format(_startDateTime!)}"
                  : "Choisir date et heure de début"),
              onPressed: () async {
                final dateTime = await _pickDateTime(
                  label: "Date début",
                  initialDateTime: _startDateTime,
                );
                if (dateTime != null) setState(() => _startDateTime = dateTime);
              },
            ),
            // 🕓 Choix date + heure fin
            TextButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(_endDateTime != null
                  ? "Fin : ${dateFormat.format(_endDateTime!)}"
                  : "Choisir date et heure de fin"),
              onPressed: () async {
                final dateTime = await _pickDateTime(
                  label: "Date fin",
                  initialDateTime: _endDateTime,
                );
                if (dateTime != null) setState(() => _endDateTime = dateTime);
              },
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () async {
                    // si une image est supprimée, mais qu’on en sélectionne une autre → annuler la suppression
                    if (_removeExistingImage) {
                      setState(() => _removeExistingImage = false);
                    }
                    await _selectImage();
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _imageFile != null
                        ? Image.file(_imageFile!, width: 230, height: 260, fit: BoxFit.cover)

                    // ► CAS : image supprimée volontairement
                        : (widget.promotion?.promotionUrlImage!= null &&
                        widget.promotion!.promotionUrlImage.isNotEmpty &&
                        !_removeExistingImage)
                        ? CachedNetworkImage(
                      imageUrl: widget.promotion!.promotionUrlImage,
                      placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                      width: 230,
                      height: 260,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      width: 200,
                      height: 260,
                      decoration:
                      BoxDecoration(border: Border.all(color: Colors.grey)),
                      child: const Icon(Icons.add_a_photo, color: Colors.grey),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // BOUTON ACTION IMAGE
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_imageFile != null) {
                        // → on annule la sélection
                        _imageFile = null;
                      } else if (!_removeExistingImage &&
                          widget.promotion?.promotionUrlImage!= null) {
                        // → supprimer l’ancienne image
                        _removeExistingImage = true;
                      } else {
                        // → réactiver l’ancienne image (undo)
                        _removeExistingImage = false;
                      }
                    });
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.redAccent,
                    child: Icon(
                      _imageFile != null
                          ? Icons.close              // annuler la nouvelle image
                          : (_removeExistingImage
                          ? Icons.undo           // restaurer l'ancienne
                          : Icons.delete),       // supprimer ancienne
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            )
            ,

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Défis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(onPressed: _addChallenge, icon: const Icon(Icons.add_circle)),
              ],
            ),
            const SizedBox(height: 10),
            ..._challenges.asMap().entries.map((entry) {
              final idx = entry.key;
              final challenge = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: challenge.pvCondition.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: "PV de qualification"),
                              onChanged: (v) => setState(() => _challenges[idx] =
                                  challenge.copyWith(pvCondition: int.tryParse(v) ?? 0)),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeChallenge(idx),
                            icon: const Icon(Icons.delete, color: Colors.red),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Produits associés :", style: TextStyle(fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () => _showProductSelector(idx),
                            icon: const Icon(Icons.add),
                            label: const Text("Gérer"),
                          ),
                        ],
                      ),
                      if (challenge.products.isEmpty)
                        const Text("Aucun produit sélectionné", style: TextStyle(color: Colors.grey))
                      else
                        Wrap(
                          spacing: 8,
                          children: challenge.products.map((p) {
                            return Chip(
                              label: Text("${p.productName} (${p.quantity})"),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            _saving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text("Enregistrer la promotion"),
            ),
          ],
        ),
      ),
    );
  }
}

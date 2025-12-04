import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/promotion.dart';
import '../services/cloudinary_service.dart';
import '../services/promotion_service.dart';
import '../widgets/promotion_formulaire.dart';
import 'images_view.dart';

class PromotionPage extends StatefulWidget {
  final bool readOnly;
  const PromotionPage({super.key, this.readOnly = false});

  @override
  State<PromotionPage> createState() => _PromotionPageState();
}

class _PromotionPageState extends State<PromotionPage> {
  late Future<List<Promotion>> _promotionsFuture;

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  void _loadPromotions() {
    _promotionsFuture = PromotionService.getPromotions();
  }

  void _refresh() {
    setState(() {
      _loadPromotions();
    });
  }

  // 📝 Ajouter / Modifier une promotion
  Future<void> _showPromotionForm({Promotion? promotion}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PromotionFormPage(promotion: promotion),
      ),
    );

    if (result == true) _refresh();
  }

  // 🗑️ Supprimer une promotion
  Future<void> _deletePromotion(Promotion promotion) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmer la suppression ?"),
        content: Text(
            "Voulez-vous vraiment supprimer « ${promotion.promotionName} » ?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annuler")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Supprimer")),
        ],
      ),
    );

    if (confirm == true) {
      await CloudinaryService()
          .deleteCloudinaryResource(promotion.promotionUrlImage);
      await PromotionService.deletePromotion(promotion.promotionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Promotion supprimée avec succès")),
        );
      }
      _refresh();
    }
  }

  // 🔹 Liste des défis et produits
  Widget _buildChallenges(Promotion promotion) {
    return Column(
      children: promotion.challenges.map((c) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: Colors.grey[100],
          child: ExpansionTile(
            collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            title: Text("${c.pvCondition} PV"),
            children: c.products.map((p) {
              return ListTile(
                title: Text("${p.quantity} ${p.productName}"),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readOnly ? "Tiroirs des promotions" : "Gestion des Promotions"),
        actions: [
          !widget.readOnly ?
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showPromotionForm(),
          ) :
              SizedBox()
        ],
      ),
      body: FutureBuilder<List<Promotion>>(
        future: _promotionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            print("Erreur: ${snapshot.error}");
            return Center(child: Text("Erreur: ${snapshot.error}"));
          } else if (snapshot.data == null || snapshot.data!.isEmpty) {
            return const Center(child: Text("Aucune promotion trouvée"));
          }

          final promotions = snapshot.data!;
          return ListView.builder(
            itemCount: promotions.length,
            itemBuilder: (context, index) {
              final promo = promotions[index];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: ExpansionTile(
                  collapsedShape:
                      const RoundedRectangleBorder(side: BorderSide.none),
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  title: Text(promo.promotionName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${DateFormat('yyyy-MM-dd HH:mm').format(promo.startDate)} → "
                        "${DateFormat('yyyy-MM-dd HH:mm').format(promo.endDate)}",
                      ),

                      const SizedBox(height: 4),

                      // 🟢 ACTIVE / 🔴 EXPIREE
                      Text(
                        promo.endDate.isAfter(DateTime.now())
                            ? "Active"
                            : "Expirée",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: promo.endDate.isAfter(DateTime.now())
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),

                  trailing: !widget.readOnly ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showPromotionForm(promotion: promo);
                      } else if (value == 'delete') {
                        _deletePromotion(promo);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Modifier'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Supprimer'),
                          ],
                        ),
                      ),
                    ],
                  ) : SizedBox(),

                  // 🔥🔥🔥 Le PageView que TU VEUX exactement
                  children: [
                    SizedBox(
                      height: 250, // OBLIGATOIRE sinon crash
                      child: PageView(
                        children: [
                          // 🟦 PAGE 1 : LES CHALLENGES
                          SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: _buildChallenges(promo),
                            ),
                          ),

                          // 🟩 PAGE 2 : L’IMAGE
                          if (promo.promotionUrlImage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ImageFullScreenPage(
                                          images: [
                                            ImageItem(
                                              path: promo.promotionUrlImage,
                                              isLocal: false,
                                            ),
                                          ],
                                          initialIndex: 0,
                                              message: promo.promotionName,
                                        ),
                                      ),
                                    );
                                  },
                                  child: InteractiveViewer(
                                    panEnabled: true,
                                    minScale: 0.5,
                                    maxScale: 3.0,
                                    child: CachedNetworkImage(
                                      placeholder: (context, url) => Center(
                                          child: CircularProgressIndicator()),
                                      imageUrl: promo.promotionUrlImage,
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const Center(
                              child: Text(
                                "Aucune image disponible",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

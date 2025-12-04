import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchase_item.dart';
import '../models/purchase.dart';
import 'package:flutter/services.dart';

class PromoManagerSheet extends StatefulWidget {
  final Purchase purchase;
  final List<PurchaseItem> promoItems;

  const PromoManagerSheet({
    super.key,
    required this.purchase,
    required this.promoItems,
  });

  @override
  State<PromoManagerSheet> createState() => _PromoManagerSheetState();
}

class _PromoManagerSheetState extends State<PromoManagerSheet> {
  final SupabaseClient supabase = Supabase.instance.client;

  late List<PurchaseItem> editableItems;
  final Map<String, TextEditingController> _totalCtrls = {};
  final Map<String, TextEditingController> _receivedCtrls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    editableItems = widget.promoItems.map((e) => e.copyWith()).toList();

    for (final it in editableItems) {
      _totalCtrls[it.productId] =
          TextEditingController(text: it.quantityTotal.toString());

      _receivedCtrls[it.productId] =
          TextEditingController(text: it.quantityReceived.toString());
    }
  }

  @override
  void dispose() {
    for (final c in _totalCtrls.values) c.dispose();
    for (final c in _receivedCtrls.values) c.dispose();
    super.dispose();
  }

  void _updateItemField(int index, {int? total, int? received}) {
    final old = editableItems[index];
    final newItem = old.copyWith(
      quantityTotal: total ?? old.quantityTotal,
      quantityReceived: received ?? old.quantityReceived,
    );
    setState(() => editableItems[index] = newItem);
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);

    try {
      final toReturn = <PurchaseItem>[];

      for (final it in editableItems) {
        final payload = {
          'quantity_total': it.quantityTotal,
          'quantity_received': it.quantityReceived,
          'quantity_missing': it.quantityMissing,
        };

        if (it.id != null && it.id!.trim().isNotEmpty) {
          await supabase
              .from('purchase_items')
              .update(payload)
              .eq('id', it.id!);
        } else {
          await supabase.from('purchase_items').insert({
            'purchase_id': widget.purchase.id,
            'product_id': it.productId,
            'product_name': it.productName,
            ...payload,
            'is_promo': true,
          });
        }

        toReturn.add(it);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Produits promo mis à jour ✔️")),
        );
        Navigator.of(context).pop(toReturn); // renvoie la liste modifiée
      }
    } catch (e, st) {
      print("Erreur update promo: $e\n$st");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la mise à jour : $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: media.viewInsets.bottom + 16,
          top: 12,
        ),
        child: SizedBox(
          height: media.size.height * 0.75,
          child: Column(
            children: [
              Container(
                width: 60,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                "Gestion des Produits Promo",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView.separated(
                  itemCount: editableItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final item = editableItems[index];

                    final totalCtrl = _totalCtrls[item.productId]!;
                    final recCtrl = _receivedCtrls[item.productId]!;

                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),

                            // TOTAL
                            Row(
                              children: [
                                const Expanded(child: Text("Quantité totale")),
                                SizedBox(
                                  width: 90,
                                  child: TextFormField(
                                    controller: totalCtrl,
                                    keyboardType: TextInputType.number,
                                    enabled: false,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    onChanged: (v) {
                                      final val = int.tryParse(v) ?? 0;
                                      _updateItemField(index, total: val);
                                    },
                                    decoration:
                                    const InputDecoration(isDense: true),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // RECEIVED
                            Row(
                              children: [
                                const Expanded(child: Text("Quantité reçue")),
                                SizedBox(
                                  width: 90,
                                  child: TextFormField(
                                    controller: recCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    onChanged: (v) {
                                      final val = int.tryParse(v) ?? 0;
                                      final capped = val.clamp(
                                        0,
                                        int.tryParse(totalCtrl.text) ?? val,
                                      );
                                      recCtrl.text = capped.toString();
                                      _updateItemField(index,
                                          received: capped);
                                    },
                                    decoration:
                                    const InputDecoration(isDense: true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _saveChanges,
                icon: _saving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.save),
                label: const Text("Enregistrer"),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/paid_products_page.dart';
import '../utils/utils.dart';

class PurchasesStatsBottomSheet extends StatefulWidget {
  const PurchasesStatsBottomSheet({super.key});

  @override
  State<PurchasesStatsBottomSheet> createState() =>
      _PurchasesStatsBottomSheetState();
}

class _PurchasesStatsBottomSheetState extends State<PurchasesStatsBottomSheet> {
  Map<String, dynamic>? paidStats;
  Map<String, dynamic>? debtStats;
  Map<String, dynamic>? nonPosNonValStats;
  bool isLoading = true;

  DateTime startDate = _getLastSundayAt16();
  DateTime endDate = DateTime.now();

  static DateTime _getLastSundayAt16() {
    final now = DateTime.now();
    int daysToSubtract = now.weekday % 7; // dimanche = 7
    final lastSunday = now.subtract(Duration(days: daysToSubtract));
    return DateTime(
        lastSunday.year, lastSunday.month, lastSunday.day, 16, 0, 0);
  }

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) throw Exception('Utilisateur non connecté');

      // 🔹 Fonction utilitaire pour convertir en double
      double toDouble(dynamic value) {
        if (value == null) return 0.0;
        if (value is double) return value;
        if (value is int) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      }

      // 🔹 Fonction utilitaire pour fusionner plusieurs lignes
      Map<String, dynamic> mergeStats(List<Map<String, dynamic>> rows,
          {required String amountKey, required String pvKey}) {
        double totalAmount = 0.0;
        double totalPv = 0.0;
        List<Map<String, dynamic>> products = [];

        for (var row in rows) {
          totalAmount += toDouble(row[amountKey]);
          totalPv += toDouble(row[pvKey]);
          products
              .addAll(List<Map<String, dynamic>>.from(row['products'] ?? []));
        }

        return {
          'total_amount': totalAmount,
          'total_pv': totalPv,
          'products': products,
        };
      }

      // 🔹 1️⃣ Commandes payées
      final paidResponse = await supabase
          .from('paid_purchases_summary')
          .select()
          .eq('user_id', userId)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: true);

      final paidList = List<Map<String, dynamic>>.from(paidResponse);
      final mergedPaid = mergeStats(
        paidList,
        amountKey: 'total_amount_paid',
        pvKey: 'total_pv_paid',
      );

      // 🔹 2️⃣ Commandes en dette
      final debtResponse = await supabase
          .from('debt_purchases_summary')
          .select()
          .eq('user_id', userId)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: true);

      final debtList = List<Map<String, dynamic>>.from(debtResponse);
      final mergedDebt = mergeStats(
        debtList,
        amountKey: 'total_amount_due',
        pvKey: 'total_pv_due',
      );

      // 🔹 3️⃣ Commandes payées et non positionnées
      final nonPosNonValResponse = await supabase
          .from('non_pos_non_val_purchases_summary')
          .select()
          .eq('user_id', userId)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: true);

      final nonPosNonValList =
          List<Map<String, dynamic>>.from(nonPosNonValResponse);
      final mergedNonPosNonVal = mergeStats(
        nonPosNonValList,
        amountKey: 'total_amount_paid',
        pvKey: 'total_pv_paid',
      );

      // 🔹 Mise à jour de l'état
      setState(() {
        paidStats = {
          'total_amount_paid': mergedPaid['total_amount'],
          'total_pv_paid': mergedPaid['total_pv'],
          'products': mergedPaid['products'],
        };

        debtStats = {
          'total_amount_due': mergedDebt['total_amount'],
          'total_pv_due': mergedDebt['total_pv'],
          'products': mergedDebt['products'],
        };

        nonPosNonValStats = {
          'total_amount_paid': mergedNonPosNonVal['total_amount'],
          'total_pv_paid': mergedNonPosNonVal['total_pv'],
          'products': mergedNonPosNonVal['products'],
        };

        isLoading = false;
      });
    } catch (e, stack) {
      print('⚠️ Erreur Supabase : $e');
      print('🧩 Stacktrace : $stack');
      setState(() {
        isLoading = false;
        paidStats = {'error': e.toString()};
        debtStats = {'error': e.toString()};
        nonPosNonValStats = {'error': e.toString()};
      });
    }
  }

  Widget _buildSection({
    required String title,
    required String totalLabel,
    required double totalAmount,
    required String pvLabel,
    required String titlePage,
    required double totalPv,
    required List<Map<String, dynamic>> products,
  }) {
    final bool isEmptySection =
        (totalAmount == 0 && totalPv == 0 && products.isEmpty);

    String emptyMessage = "Aucune donnée disponible.";
    if (title.contains("validée") || title.contains("validés")) {
      emptyMessage =
          "Aucune commande validée dans cette période pour le moment.";
    } else if (title.contains("dette")) {
      emptyMessage =
          "Aucune commande en dette dans cette période pour le moment.";
    } else if (title.contains("non positionnée") || title.contains("non pos")) {
      emptyMessage =
          "Aucun produit non positionné dans cette période pour le moment.";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (isEmptySection)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(totalLabel),
              Text('${currencyFormat.format(totalAmount)} GNF',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(pvLabel),
              Text('$totalPv PV',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              if (products.isNotEmpty) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaidProductsPage(
                        products: products,
                        total_montant: totalAmount,
                        total_pv: totalPv,
                        periodeString:
                            "${startDate.day}/${startDate.month}/${startDate.year} ${startDate.hour}:${startDate.minute.toString().padLeft(2, '0')} "
                            "au "
                            "${endDate.day}/${endDate.month}/${endDate.year} ${endDate.hour}:${endDate.minute.toString().padLeft(2, '0')}",
                        // 🔹 Reformulation du titlePage
                        titlePage: titlePage
                            .replaceFirst("Voir les ", "")
                            .replaceFirstMapped(RegExp(r'^\w'),
                                (match) => match.group(0)!.toUpperCase()),
                      ),
                    ));
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(titlePage,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, color: Colors.blueAccent)),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const Divider(),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(startDate),
                        );
                        if (time != null) {
                          setState(() {
                            startDate = DateTime(date.year, date.month,
                                date.day, time.hour, time.minute);
                            isLoading = true;
                          });
                          _loadStats();
                        }
                      }
                    },
                    child: Text(
                        'Date début : ${startDate.toString().substring(0, 16)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(endDate),
                        );
                        if (time != null) {
                          setState(() {
                            endDate = DateTime(date.year, date.month, date.day,
                                time.hour, time.minute);
                            isLoading = true;
                          });
                          _loadStats();
                        }
                      }
                    },
                    child: Text(
                        'Date fin : ${endDate.toString().substring(0, 16)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Chargement des statistiques...'),
                    ],
                  ),
                ),
              )
            else if ((paidStats != null && paidStats!.containsKey('error')) ||
                (debtStats != null && debtStats!.containsKey('error')))
              const Text(
                'Erreur lors du chargement des données',
                style: TextStyle(color: Colors.red),
              )
            else ...[
              _buildSection(
                title: '🟡 Commandes payées et non positionnées',
                totalLabel: 'Montant total payé :',
                totalAmount: nonPosNonValStats!['total_amount_paid'],
                pvLabel: 'Total PV :',
                totalPv: nonPosNonValStats!['total_pv_paid'],
                products: nonPosNonValStats!['products'],
                titlePage: "Voir les produits payés non positionnés",
              ),
              _buildSection(
                title: '🔴 Commandes en dette',
                totalLabel: 'Montant total dû :',
                totalAmount: debtStats!['total_amount_due'],
                pvLabel: 'Total PV dû :',
                totalPv: debtStats!['total_pv_due'],
                products: debtStats!['products'],
                titlePage: "Voir les produits en dette",
              ),
              _buildSection(
                title: '🟢 Commandes validées',
                totalLabel: 'Montant total payé :',
                totalAmount: paidStats!['total_amount_paid'],
                pvLabel: 'Total PV :',
                totalPv: paidStats!['total_pv_paid'],
                products: paidStats!['products'],
                titlePage: "Voir les produits validés",
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ListTile(
                  title: Text(
                    "Les commandes partiellement payées ne sont pas pris en comptes et pas affichées",
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                  leading: Icon(Icons.info),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}

void showPurchasesStatsBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const PurchasesStatsBottomSheet(),
  );
}

import 'package:flutter/material.dart';

import '../pages/nouveau_membre.dart';
import '../pages/nouvelle_commande.dart';

void showOptionsBottomSheetModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Que souhaitez-vous effectuer ?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.add_box_outlined,
                  color: Colors.blue), // Catégorie : Ajouter une boîte
              title: Text("Ajouter un achat"),
              onTap: () {
                Navigator.pop(context); // Fermer le BottomSheet
                Navigator.push(context, MaterialPageRoute(builder: (context) => NewPurchasePage(),));
              },
            ),
            ListTile(
              leading: Icon(Icons.production_quantity_limits_outlined,
                  color: Colors
                      .orange), // Produit standard : Quantité de production
              title: Text("Ajouter un membre"),

              onTap: () {
                Navigator.pop(context); // Fermer le BottomSheet
                Navigator.push(context, MaterialPageRoute(builder: (context) => AddAccountPage(),));
              },
            ),
          ],
        ),
      );
    },
  );
}
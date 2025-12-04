class VillesAPiModel {
  final String nom;
  final int villeID;

  VillesAPiModel({
    required this.nom,
    required this.villeID,
  });

  factory VillesAPiModel.fromJson(Map<String, dynamic> json) {
    return VillesAPiModel(
      nom: json["nom"],
      villeID: json["id"],
    );
  }
}

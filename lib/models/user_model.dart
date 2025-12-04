class UserModel {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String? tel;
  final String? fcmToken;
  final String? adresse;
  final DateTime? dateNaissance;
  final String? matricule;

  final bool isAdmin;
  final String confirmCode;

  UserModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    this.tel,
    this.fcmToken,
    this.adresse,
    this.dateNaissance,
    this.matricule,
    this.isAdmin = false,
    required this.confirmCode,
  });

  // -------------------------------------------
  // 🔹 Convertir JSON -> UserModel
  // -------------------------------------------
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      email: map['email'] ?? '',
      tel: map['tel'],
      fcmToken: map['fcm_token'],
      adresse: map['adresse'],
      matricule: map['matricule'],
      dateNaissance: map['date_naissance'] != null
          ? DateTime.tryParse(map['date_naissance'])
          : null,
      isAdmin: map['is_admin'] ?? false,
      confirmCode: map['confirm_code'] ?? '',
    );
  }

  // -------------------------------------------
  // 🔹 Alias pour le JSON venant de SharedPrefs
  // -------------------------------------------
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel.fromMap(json);
  }

  // -------------------------------------------
  // 🔹 User vide
  // -------------------------------------------
  factory UserModel.empty() {
    return UserModel(
      id: '',
      nom: '',
      prenom: '',
      email: '',
      tel: '',
      fcmToken: '',
      adresse: '',
      dateNaissance: null,
      matricule: '',
      isAdmin: false,
      confirmCode: '',
    );
  }

  // -------------------------------------------
  // 🔹 Convertir UserModel -> Map
  // -------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'tel': tel,
      'fcm_token': fcmToken,
      'adresse': adresse,
      'matricule': matricule,
      'date_naissance':
      dateNaissance != null ? dateNaissance!.toIso8601String() : null,
      'is_admin': isAdmin,
      'confirm_code': confirmCode,
    };
  }

  // Alias JSON pour SharedPrefs
  Map<String, dynamic> toJson() => toMap();
}

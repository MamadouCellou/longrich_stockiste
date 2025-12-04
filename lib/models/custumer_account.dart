class CustomerAccount {
  final String? id;
  final String user_id;
  final String firstName;
  final String lastName;
  final String idType;
  final String idNumber;
  final DateTime birthDate;
  final String country;
  final String? province;
  final String? city;
  final String? matricule;
  final String? neighborhood;
  final String phone;
  final String gender;
  final String? sponsorCode;
  final String? placementCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? imageUrl; // ← nouveau champ

  CustomerAccount({
    this.id,
    required this.user_id,
    required this.firstName,
    required this.lastName,
    required this.idType,
    required this.idNumber,
    required this.birthDate,
    required this.country,
    this.province,
    this.city,
    this.matricule,
    this.neighborhood,
    required this.phone,
    required this.gender,
    this.sponsorCode,
    this.placementCode,
    this.createdAt,
    this.updatedAt,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'id_type': idType,
    'id_number': idNumber,
    'birth_date': birthDate.toIso8601String(),
    'country': country,
    'province': province,
    'city': city,
    'matricule': matricule == "" ? "Aucun matricule" : matricule,
    'user_id': user_id,
    'neighborhood': neighborhood,
    'phone': phone,
    'gender': gender,
    'sponsor_code': sponsorCode,
    'placement_code': placementCode,
    'image_url': imageUrl, // ← nouveau champ
  };

  // ✅ COPYWITH — mise à jour partielle optimisée
  CustomerAccount copyWith({
    String? imageUrl,
    String? matricule,
    String? province,
    String? city,
    String? neighborhood,
    DateTime? updatedAt,
  }) {
    return CustomerAccount(
      id: id,
      user_id: user_id,
      firstName: firstName,
      lastName: lastName,
      idType: idType,
      idNumber: idNumber,
      birthDate: birthDate,
      country: country,
      province: province ?? this.province,
      city: city ?? this.city,
      matricule: matricule ?? this.matricule,
      neighborhood: neighborhood ?? this.neighborhood,
      phone: phone,
      gender: gender,
      sponsorCode: sponsorCode,
      placementCode: placementCode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
  factory CustomerAccount.fromJson(Map<String, dynamic> json) {
    return CustomerAccount(
      id: json['id'],
      user_id: json['user_id'],
      firstName: json['first_name'] ?? 'Aucun nom',
      lastName: json['last_name'] ?? 'Aucun prenom',
      idType: json['id_type'] ?? 'Aucun type de carte',
      idNumber: json['id_number'] ?? 'Aucun ID de carte',
      birthDate: DateTime.tryParse(json['birth_date'] ?? '') ?? DateTime.now(),
      country: json['country'] ?? 'GN',
      province: json['province'] ?? 'Conakry',
      city: json['city'] ?? 'Ratoma',
      matricule: json['matricule'] ?? 'Aucun matricule',
      neighborhood: json['neighborhood'] ?? 'Aucune adresse',
      phone: json['phone'] ?? 'Aucun numero',
      gender: json['gender'] ?? 'masculin',
      sponsorCode: json['sponsor_code'] ?? "Aucun code sponsor",
      placementCode: json['placement_code'] ?? "Aucun code placement",
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      imageUrl: json['image_url'], // ← récupérer le lien
    );
  }
}

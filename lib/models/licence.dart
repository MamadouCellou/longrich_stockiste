class LicenceModel {
  final String id;
  final String code;
  final String? userId;      // UUID de l’utilisateur associé
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool used;
  final DateTime? usedAt;

  LicenceModel({
    required this.id,
    required this.code,
    this.userId,
    required this.createdAt,
    required this.expiresAt,
    required this.used,
    this.usedAt,
  });

  // 🔹 Création depuis un map (Supabase)
  factory LicenceModel.fromMap(Map<String, dynamic> map) {
    return LicenceModel(
      id: map['id'].toString(),
      code: map['code'] ?? '',
      userId: map['user_id'] as String?,
      createdAt: DateTime.parse(map['created_at']),
      expiresAt: DateTime.parse(map['expires_at']),
      used: map['used'] == true,
      usedAt: map['used_at'] != null ? DateTime.parse(map['used_at']) : null,
    );
  }

  // 🔹 Conversion vers map (pour insertion ou update)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'used': used,
      'used_at': usedAt?.toIso8601String(),
    };
  }
}

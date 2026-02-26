class User {
  final String id;
  final String email;
  final String? phone;
  final String displayName;
  final String? avatarUrl;
  final String preferredLocale;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    this.phone,
    required this.displayName,
    this.avatarUrl,
    this.preferredLocale = 'en',
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      preferredLocale: json['preferred_locale'] as String? ?? 'en',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'preferred_locale': preferredLocale,
      'created_at': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? displayName,
    String? phone,
    String? avatarUrl,
    String? preferredLocale,
  }) {
    return User(
      id: id,
      email: email,
      phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferredLocale: preferredLocale ?? this.preferredLocale,
      createdAt: createdAt,
    );
  }
}

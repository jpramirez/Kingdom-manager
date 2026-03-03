class FamilyProfile {
  final String id;
  final String householdId;
  final String name;
  final String role;
  final int? age;
  final String preferredLang;
  final List<String> dietaryPrefs;
  final List<String> allergies;
  final Map<String, String> mealTimes;
  final String? avatarUrl;
  final String? linkedUserId;
  final String? linkedMemberId;
  final String? inviteEmail;
  final String? invitePhone;
  final bool isAdmin;
  final String? linkedUserEmail;
  final String? linkedUserDisplayName;
  final String? linkedUserAvatarUrl;
  final DateTime createdAt;

  FamilyProfile({
    required this.id,
    required this.householdId,
    required this.name,
    required this.role,
    this.age,
    this.preferredLang = 'en',
    this.dietaryPrefs = const [],
    this.allergies = const [],
    this.mealTimes = const {},
    this.avatarUrl,
    this.linkedUserId,
    this.linkedMemberId,
    this.inviteEmail,
    this.invitePhone,
    this.isAdmin = false,
    this.linkedUserEmail,
    this.linkedUserDisplayName,
    this.linkedUserAvatarUrl,
    required this.createdAt,
  });

  bool get isLinked => linkedUserId != null;
  bool get canManage => role == 'family_adult' || isAdmin;
  bool get hasPendingInvite =>
      !isLinked && (inviteEmail != null || invitePhone != null);

  factory FamilyProfile.fromJson(Map<String, dynamic> json) {
    return FamilyProfile(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      age: json['age'] as int?,
      preferredLang: json['preferred_lang'] as String? ?? 'en',
      dietaryPrefs:
          (json['dietary_prefs'] as List<dynamic>?)?.cast<String>() ?? [],
      allergies:
          (json['allergies'] as List<dynamic>?)?.cast<String>() ?? [],
      mealTimes: (json['meal_times'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
      avatarUrl: json['avatar_url'] as String?,
      linkedUserId: json['linked_user_id'] as String?,
      linkedMemberId: json['linked_member_id'] as String?,
      inviteEmail: json['invite_email'] as String?,
      invitePhone: json['invite_phone'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      linkedUserEmail: json['linked_user_email'] as String?,
      linkedUserDisplayName: json['linked_user_display_name'] as String?,
      linkedUserAvatarUrl: json['linked_user_avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role,
      if (age != null) 'age': age,
      'preferred_lang': preferredLang,
      'dietary_prefs': dietaryPrefs,
      'allergies': allergies,
      'meal_times': mealTimes,
      if (inviteEmail != null) 'invite_email': inviteEmail,
      if (invitePhone != null) 'invite_phone': invitePhone,
    };
  }

  FamilyProfile copyWith({
    String? id,
    String? householdId,
    String? name,
    String? role,
    int? age,
    String? preferredLang,
    List<String>? dietaryPrefs,
    List<String>? allergies,
    Map<String, String>? mealTimes,
    String? avatarUrl,
    String? linkedUserId,
    String? linkedMemberId,
    String? inviteEmail,
    String? invitePhone,
    bool? isAdmin,
    String? linkedUserEmail,
    String? linkedUserDisplayName,
    String? linkedUserAvatarUrl,
    DateTime? createdAt,
  }) {
    return FamilyProfile(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      role: role ?? this.role,
      age: age ?? this.age,
      preferredLang: preferredLang ?? this.preferredLang,
      dietaryPrefs: dietaryPrefs ?? this.dietaryPrefs,
      allergies: allergies ?? this.allergies,
      mealTimes: mealTimes ?? this.mealTimes,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      linkedUserId: linkedUserId ?? this.linkedUserId,
      linkedMemberId: linkedMemberId ?? this.linkedMemberId,
      inviteEmail: inviteEmail ?? this.inviteEmail,
      invitePhone: invitePhone ?? this.invitePhone,
      isAdmin: isAdmin ?? this.isAdmin,
      linkedUserEmail: linkedUserEmail ?? this.linkedUserEmail,
      linkedUserDisplayName: linkedUserDisplayName ?? this.linkedUserDisplayName,
      linkedUserAvatarUrl: linkedUserAvatarUrl ?? this.linkedUserAvatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

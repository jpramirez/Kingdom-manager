class Household {
  final String id;
  final String name;
  final String inviteCode;
  final String timezone;
  final String createdBy;
  final DateTime createdAt;

  Household({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.timezone = 'Asia/Singapore',
    required this.createdBy,
    required this.createdAt,
  });

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      timezone: json['timezone'] as String? ?? 'Asia/Singapore',
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Household copyWith({String? name, String? timezone}) {
    return Household(
      id: id,
      name: name ?? this.name,
      inviteCode: inviteCode,
      timezone: timezone ?? this.timezone,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}

class HouseholdMember {
  final String id;
  final String householdId;
  final String userId;
  final String role;
  final String? nickname;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final DateTime joinedAt;

  HouseholdMember({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.role,
    this.nickname,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    required this.joinedAt,
  });

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    return HouseholdMember(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      nickname: json['nickname'] as String?,
      displayName: json['display_name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}

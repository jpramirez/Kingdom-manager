class Recipe {
  final String id;
  final String householdId;
  final String name;
  final String? description;
  final String? instructions;
  final String? imageUrl;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final int? servings;
  final List<String>? tags;
  final String createdBy;
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.householdId,
    required this.name,
    this.description,
    this.instructions,
    this.imageUrl,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.servings,
    this.tags,
    required this.createdBy,
    required this.createdAt,
  });

  int? get totalTimeMinutes {
    if (prepTimeMinutes == null && cookTimeMinutes == null) return null;
    return (prepTimeMinutes ?? 0) + (cookTimeMinutes ?? 0);
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      instructions: json['instructions'] as String?,
      imageUrl: json['image_url'] as String?,
      prepTimeMinutes: json['prep_time_minutes'] as int?,
      cookTimeMinutes: json['cook_time_minutes'] as int?,
      servings: json['servings'] as int?,
      tags: (json['tags'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (instructions != null) 'instructions': instructions,
      if (imageUrl != null) 'image_url': imageUrl,
      if (prepTimeMinutes != null) 'prep_time_minutes': prepTimeMinutes,
      if (cookTimeMinutes != null) 'cook_time_minutes': cookTimeMinutes,
      if (servings != null) 'servings': servings,
      if (tags != null) 'tags': tags,
    };
  }

  Recipe copyWith({
    String? name,
    String? description,
    String? instructions,
    String? imageUrl,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    int? servings,
    List<String>? tags,
  }) {
    return Recipe(
      id: id,
      householdId: householdId,
      name: name ?? this.name,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      imageUrl: imageUrl ?? this.imageUrl,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      servings: servings ?? this.servings,
      tags: tags ?? this.tags,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}

class MealPlan {
  final String id;
  final String householdId;
  final DateTime date;
  final String mealType;
  final String? recipeId;
  final String? customMealName;
  final String? notes;
  final String? profileId;
  final String? profileName;
  final int? servings;
  final String createdBy;
  final String? recipeName;

  MealPlan({
    required this.id,
    required this.householdId,
    required this.date,
    required this.mealType,
    this.recipeId,
    this.customMealName,
    this.notes,
    this.profileId,
    this.profileName,
    this.servings,
    required this.createdBy,
    this.recipeName,
  });

  String get displayName {
    final name = recipeName ?? customMealName ?? '';
    if (profileName != null && profileName!.isNotEmpty) {
      return '$name ($profileName)';
    }
    return name;
  }

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      date: DateTime.parse(json['date'] as String),
      mealType: json['meal_type'] as String,
      recipeId: json['recipe_id'] as String?,
      customMealName: json['custom_meal_name'] as String?,
      notes: json['notes'] as String?,
      profileId: json['profile_id'] as String?,
      profileName: json['profile_name'] as String?,
      servings: json['servings'] as int?,
      createdBy: json['created_by'] as String,
      recipeName: json['recipe_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T').first,
      'meal_type': mealType,
      if (recipeId != null) 'recipe_id': recipeId,
      if (customMealName != null) 'custom_meal_name': customMealName,
      if (notes != null) 'notes': notes,
      if (profileId != null) 'profile_id': profileId,
      if (servings != null) 'servings': servings,
    };
  }

  MealPlan copyWith({
    DateTime? date,
    String? mealType,
    String? recipeId,
    String? customMealName,
    String? notes,
    String? profileId,
    String? profileName,
    int? servings,
    String? recipeName,
  }) {
    return MealPlan(
      id: id,
      householdId: householdId,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      recipeId: recipeId ?? this.recipeId,
      customMealName: customMealName ?? this.customMealName,
      notes: notes ?? this.notes,
      profileId: profileId ?? this.profileId,
      profileName: profileName ?? this.profileName,
      servings: servings ?? this.servings,
      createdBy: createdBy,
      recipeName: recipeName ?? this.recipeName,
    );
  }
}

class MealRequest {
  final String id;
  final String householdId;
  final String requestedBy;
  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime? preferredDate;
  final String status;
  final DateTime createdAt;
  final String? requesterName;

  MealRequest({
    required this.id,
    required this.householdId,
    required this.requestedBy,
    required this.title,
    this.description,
    this.imageUrl,
    this.preferredDate,
    required this.status,
    required this.createdAt,
    this.requesterName,
  });

  factory MealRequest.fromJson(Map<String, dynamic> json) {
    return MealRequest(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      requestedBy: json['requested_by'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      preferredDate: json['preferred_date'] != null
          ? DateTime.parse(json['preferred_date'] as String)
          : null,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      requesterName: json['requester_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      if (preferredDate != null)
        'preferred_date': preferredDate!.toIso8601String().split('T').first,
    };
  }

  MealRequest copyWith({
    String? title,
    String? description,
    String? imageUrl,
    DateTime? preferredDate,
    String? status,
    String? requesterName,
  }) {
    return MealRequest(
      id: id,
      householdId: householdId,
      requestedBy: requestedBy,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      preferredDate: preferredDate ?? this.preferredDate,
      status: status ?? this.status,
      createdAt: createdAt,
      requesterName: requesterName ?? this.requesterName,
    );
  }
}

class MealIngredient {
  final String name;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatsGrams;

  const MealIngredient({
    required this.name,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatsGrams,
  });

  factory MealIngredient.fromJson(Map<String, dynamic> json) {
    return MealIngredient(
      name: (json['name'] ?? '').toString(),
      calories: Meal._toInt(json['calories']),
      proteinGrams: Meal._toInt(json['protein_grams'] ?? json['protein']),
      carbsGrams: Meal._toInt(json['carbs_grams'] ?? json['carbs']),
      fatsGrams: Meal._toInt(json['fats_grams'] ?? json['fat']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'calories': calories,
      'protein_grams': proteinGrams,
      'carbs_grams': carbsGrams,
      'fats_grams': fatsGrams,
    };
  }
}

class Meal {
  final String foodName;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatsGrams;
  final List<MealIngredient> ingredients;
  final DateTime loggedAt;

  const Meal({
    required this.foodName,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatsGrams,
    required this.ingredients,
    required this.loggedAt,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      foodName: (json['food_name'] ?? '').toString(),
      calories: _toInt(json['calories']),
      proteinGrams: _toInt(json['protein_grams'] ?? json['protein']),
      carbsGrams: _toInt(json['carbs_grams'] ?? json['carbs']),
      fatsGrams: _toInt(json['fats_grams'] ?? json['fat']),
      ingredients: (json['ingredients'] is List)
          ? (json['ingredients'] as List)
              .whereType<Map>()
              .map((item) => MealIngredient.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
      loggedAt: json['logged_at'] != null
          ? DateTime.tryParse(json['logged_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'food_name': foodName,
      'calories': calories,
      'protein_grams': proteinGrams,
      'carbs_grams': carbsGrams,
      'fats_grams': fatsGrams,
      'ingredients': ingredients.map((item) => item.toJson()).toList(),
      'logged_at': loggedAt.toIso8601String(),
    };
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

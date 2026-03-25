class Meal {
  final String foodName;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatsGrams;
  final DateTime loggedAt;

  const Meal({
    required this.foodName,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatsGrams,
    required this.loggedAt,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      foodName: (json['food_name'] ?? '').toString(),
      calories: _toInt(json['calories']),
      proteinGrams: _toInt(json['protein_grams']),
      carbsGrams: _toInt(json['carbs_grams']),
      fatsGrams: _toInt(json['fats_grams']),
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
      'logged_at': loggedAt.toIso8601String(),
    };
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

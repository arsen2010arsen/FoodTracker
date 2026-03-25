enum Gender { male, female }

enum UserGoal { loseWeight, maintain, gainMuscle }

class DailyTargets {
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatsGrams;

  const DailyTargets({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatsGrams,
  });

  factory DailyTargets.fromJson(Map<String, dynamic> json) {
    return DailyTargets(
      calories: _toInt(json['calories']),
      proteinGrams: _toInt(json['protein_grams']),
      carbsGrams: _toInt(json['carbs_grams']),
      fatsGrams: _toInt(json['fats_grams']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein_grams': proteinGrams,
      'carbs_grams': carbsGrams,
      'fats_grams': fatsGrams,
    };
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class UserProfile {
  final Gender gender;
  final int ageYears;
  final int heightCm;
  final int weightKg;
  final UserGoal goal;
  final DailyTargets dailyTargets;

  const UserProfile({
    required this.gender,
    required this.ageYears,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    required this.dailyTargets,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      gender: _genderFromValue(json['gender']?.toString()),
      ageYears: DailyTargets._toInt(json['age_years']),
      heightCm: DailyTargets._toInt(json['height_cm']),
      weightKg: DailyTargets._toInt(json['weight_kg']),
      goal: _goalFromValue(json['goal']?.toString()),
      dailyTargets: DailyTargets.fromJson(
        Map<String, dynamic>.from(json['daily_targets'] ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gender': gender.name,
      'age_years': ageYears,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'goal': goal.name,
      'daily_targets': dailyTargets.toJson(),
    };
  }

  static Gender _genderFromValue(String? value) {
    return value == Gender.female.name ? Gender.female : Gender.male;
  }

  static UserGoal _goalFromValue(String? value) {
    switch (value) {
      case 'loseWeight':
        return UserGoal.loseWeight;
      case 'gainMuscle':
        return UserGoal.gainMuscle;
      default:
        return UserGoal.maintain;
    }
  }
}

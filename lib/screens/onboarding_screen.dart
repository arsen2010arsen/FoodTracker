import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.storageService});

  final StorageService storageService;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  Gender _gender = Gender.male;
  UserGoal _goal = UserGoal.maintain;
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final age = int.parse(_ageController.text.trim());
    final height = int.parse(_heightController.text.trim());
    final weight = int.parse(_weightController.text.trim());

    final targets = _calculateTargets(
      gender: _gender,
      ageYears: age,
      heightCm: height,
      weightKg: weight,
      goal: _goal,
    );

    final profile = UserProfile(
      gender: _gender,
      ageYears: age,
      heightCm: height,
      weightKg: weight,
      goal: _goal,
      dailyTargets: targets,
    );

    await widget.storageService.saveUserProfile(profile.toJson());
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  DailyTargets _calculateTargets({
    required Gender gender,
    required int ageYears,
    required int heightCm,
    required int weightKg,
    required UserGoal goal,
  }) {
    final bmrBase = (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears);
    final bmr = gender == Gender.male ? bmrBase + 5 : bmrBase - 161;

    final activityMultiplier = switch (goal) {
      UserGoal.loseWeight => 1.35,
      UserGoal.maintain => 1.50,
      UserGoal.gainMuscle => 1.65,
    };
    final calorieAdjustment = switch (goal) {
      UserGoal.loseWeight => -300.0,
      UserGoal.maintain => 0.0,
      UserGoal.gainMuscle => 250.0,
    };
    final calories = ((bmr * activityMultiplier) + calorieAdjustment).round();

    final proteinGrams = switch (goal) {
      UserGoal.loseWeight => (weightKg * 2.0).round(),
      UserGoal.maintain => (weightKg * 1.6).round(),
      UserGoal.gainMuscle => (weightKg * 2.2).round(),
    };
    final fatsGrams = (calories * 0.27 / 9).round();
    final carbsCalories = calories - (proteinGrams * 4) - (fatsGrams * 9);
    final carbsGrams = (carbsCalories / 4).round().clamp(50, 700);

    return DailyTargets(
      calories: calories.clamp(1200, 5000),
      proteinGrams: proteinGrams.clamp(60, 300),
      carbsGrams: carbsGrams,
      fatsGrams: fatsGrams.clamp(35, 180),
    );
  }

  String? _validatePositiveNumber(String? value, {required int min, required int max}) {
    final v = int.tryParse(value?.trim() ?? '');
    if (v == null) return 'Введіть коректне число';
    if (v < min || v > max) return 'Діапазон: $min-$max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Початкове налаштування')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  'Розрахуємо ваші персональні цілі',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Gender>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Стать'),
                  items: const [
                    DropdownMenuItem(value: Gender.male, child: Text('Чоловік')),
                    DropdownMenuItem(value: Gender.female, child: Text('Жінка')),
                  ],
                  onChanged: (v) => setState(() => _gender = v ?? Gender.male),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Вік (років)',
                    hintText: 'Наприклад, 29',
                  ),
                  validator: (v) => _validatePositiveNumber(v, min: 12, max: 100),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Зріст (см)',
                    hintText: 'Наприклад, 175',
                  ),
                  validator: (v) => _validatePositiveNumber(v, min: 120, max: 230),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Вага (кг)',
                    hintText: 'Наприклад, 72',
                  ),
                  validator: (v) => _validatePositiveNumber(v, min: 35, max: 250),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserGoal>(
                  value: _goal,
                  decoration: const InputDecoration(labelText: 'Ціль'),
                  items: const [
                    DropdownMenuItem(
                      value: UserGoal.loseWeight,
                      child: Text('Схуднення'),
                    ),
                    DropdownMenuItem(
                      value: UserGoal.maintain,
                      child: Text('Підтримка ваги'),
                    ),
                    DropdownMenuItem(
                      value: UserGoal.gainMuscle,
                      child: Text('Набір мʼязової маси'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _goal = v ?? UserGoal.maintain),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saveProfile,
                  child: const Text('Зберегти та продовжити'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/meal.dart';
import '../models/user_profile.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import 'meal_analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.storageService,
    required this.geminiService,
    required this.profile,
  });

  final StorageService storageService;
  final GeminiService geminiService;
  final UserProfile profile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = _startOfDay(DateTime.now());
  List<Meal> _selectedDayMeals = [];
  UserProfile? _latestProfile;

  static DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  void initState() {
    super.initState();
    _latestProfile = widget.profile;
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadProfile(),
      _loadMeals(),
    ]);
  }

  Future<void> _loadProfile() async {
    final profile = await widget.storageService.getUserProfile();
    if (!mounted || profile == null) return;
    setState(() => _latestProfile = profile);
  }

  Future<void> _loadMeals() async {
    final meals = await widget.storageService.getMealsForDate(_selectedDate);
    if (!mounted) return;
    setState(() => _selectedDayMeals = meals);
  }

  int get _dayCalories =>
      _selectedDayMeals.fold(0, (sum, meal) => sum + meal.calories);
  int get _dayProtein =>
      _selectedDayMeals.fold(0, (sum, meal) => sum + meal.proteinGrams);
  int get _dayCarbs =>
      _selectedDayMeals.fold(0, (sum, meal) => sum + meal.carbsGrams);
  int get _dayFats =>
      _selectedDayMeals.fold(0, (sum, meal) => sum + meal.fatsGrams);

  void _shiftDate(int days) {
    final candidate = _startOfDay(_selectedDate.add(Duration(days: days)));
    final today = _startOfDay(DateTime.now());
    if (candidate.isAfter(today)) return;
    setState(() {
      _selectedDate = candidate;
    });
    _loadMeals();
  }

  bool get _isSelectedToday {
    final t = _startOfDay(DateTime.now());
    return _selectedDate == t;
  }

  String get _dateTitle {
    if (_isSelectedToday) return 'Сьогодні';
    return DateFormat('d MMMM', 'uk').format(_selectedDate);
  }

  Future<void> _goToCapture() async {
    final shouldRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MealAnalysisScreen(
          geminiService: widget.geminiService,
          storageService: widget.storageService,
        ),
      ),
    );
    if (shouldRefresh == true) {
      await _loadAllData();
    }
  }

  Future<void> _openSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171A21),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Змінити особисті дані'),
                  subtitle: const Text('Скинути профіль і пройти онбординг знову'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await widget.storageService.clearUserProfile();
                    if (!mounted) return;
                    Navigator.of(this.context).pushReplacementNamed('/');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: const Text('Очистити історію їжі'),
                  subtitle: const Text('Видалити всі збережені прийоми їжі'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await widget.storageService.clearAllMeals();
                    if (!mounted) return;
                    await _loadAllData();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Історію їжі очищено')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Вийти'),
                  subtitle: const Text('Повернутися на екран входу'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    Navigator.of(this.context).pushReplacementNamed('/');
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final meals = _selectedDayMeals;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodTracker'),
        actions: [
          IconButton(
            onPressed: _openSettingsSheet,
            icon: const Icon(Icons.settings),
            tooltip: 'Налаштування',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToCapture,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Додати прийом їжі'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _shiftDate(-1),
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Попередній день',
                      ),
                      Text(
                        _dateTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        onPressed: _isSelectedToday ? null : () => _shiftDate(1),
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Наступний день',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _DailyProgressCard(
                calories: _dayCalories,
                protein: _dayProtein,
                carbs: _dayCarbs,
                fats: _dayFats,
                targets: (_latestProfile ?? widget.profile).dailyTargets,
                isToday: _isSelectedToday,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Прийоми їжі',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    DateFormat('EEE, d MMM', 'uk').format(_selectedDate),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: meals.isEmpty
                    ? _EmptyMealsState(isToday: _isSelectedToday)
                    : ListView.separated(
                        itemCount: meals.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final meal = meals[index];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              title: Text(
                                meal.foodName.isEmpty ? 'Невідома страва' : meal.foodName,
                              ),
                              subtitle: Text(
                                '${meal.calories} ккал • Б ${meal.proteinGrams}г • '
                                'В ${meal.carbsGrams}г • Ж ${meal.fatsGrams}г',
                              ),
                              trailing: Text(
                                DateFormat('HH:mm', 'uk').format(meal.loggedAt),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyProgressCard extends StatelessWidget {
  const _DailyProgressCard({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.targets,
    required this.isToday,
  });

  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final DailyTargets targets;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final calorieGoal = targets.calories.toDouble();
    final progress = (calories / calorieGoal).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$calories',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        '$calories / ${targets.calories} ккал',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        isToday ? 'сьогодні' : 'вибрана дата',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroColumn(label: 'Білки', grams: protein, target: targets.proteinGrams),
                _MacroColumn(label: 'Вуглеводи', grams: carbs, target: targets.carbsGrams),
                _MacroColumn(label: 'Жири', grams: fats, target: targets.fatsGrams),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroColumn extends StatelessWidget {
  const _MacroColumn({
    required this.label,
    required this.grams,
    required this.target,
  });

  final String label;
  final int grams;
  final int target;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$grams/$target г', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyMealsState extends StatelessWidget {
  const _EmptyMealsState({required this.isToday});

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_meals_outlined, size: 48, color: Colors.white54),
          const SizedBox(height: 10),
          Text(
            isToday ? 'Сьогодні ще немає записів' : 'Немає записів за цю дату',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text('Натисніть "Додати прийом їжі", щоб проаналізувати фото.'),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../main.dart';
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

  Future<void> _showImageSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Додати прийом їжі',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                _SettingsTile(
                  icon: Icons.camera_alt_rounded,
                  iconColor: AppColors.accent,
                  title: 'Зробити фото',
                  subtitle: 'Відкрити камеру та сфотографувати страву',
                  onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                ),
                _SettingsTile(
                  icon: Icons.photo_library_rounded,
                  iconColor: AppColors.primaryStart,
                  title: 'Вибрати з галереї',
                  subtitle: 'Обрати готове фото зі сховища',
                  onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;
    await _goToCaptureWithSource(source);
  }

  Future<void> _goToCaptureWithSource(ImageSource source) async {
    final shouldRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MealAnalysisScreen(
          geminiService: widget.geminiService,
          storageService: widget.storageService,
          imageSource: source,
        ),
      ),
    );
    if (shouldRefresh == true) {
      await _loadAllData();
    }
  }

  Future<void> _deleteMeal(Meal meal) async {
    final docId = meal.docId;
    if (docId == null) return;

    // Optimistic UI update
    setState(() {
      _selectedDayMeals = _selectedDayMeals
          .where((m) => m.docId != docId)
          .toList();
    });

    try {
      await widget.storageService.deleteMeal(docId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Прийом їжі видалено')),
      );
    } catch (e) {
      // Revert on failure
      if (!mounted) return;
      await _loadMeals();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося видалити. Спробуйте ще раз.')),
      );
    }
  }

  Future<void> _openSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  iconColor: AppColors.accent,
                  title: 'Змінити особисті дані',
                  subtitle: 'Скинути профіль і пройти онбординг знову',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await widget.storageService.clearUserProfile();
                    if (!mounted) return;
                    Navigator.of(this.context).pushReplacementNamed('/');
                  },
                ),
                _SettingsTile(
                  icon: Icons.delete_sweep_outlined,
                  iconColor: AppColors.fats,
                  title: 'Очистити історію їжі',
                  subtitle: 'Видалити всі збережені прийоми їжі',
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
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  iconColor: Colors.white54,
                  title: 'Вийти',
                  subtitle: 'Повернутися на екран входу',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    Navigator.of(this.context).pushReplacementNamed('/');
                  },
                ),
                const SizedBox(height: 8),
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
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Налаштування',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Date selector ────────────────────────
                    _DateSelector(
                      dateTitle: _dateTitle,
                      isToday: _isSelectedToday,
                      onPrevious: () => _shiftDate(-1),
                      onNext: _isSelectedToday ? null : () => _shiftDate(1),
                    ),
                    const SizedBox(height: 16),

                    // ── Daily progress card ──────────────────
                    _DailyProgressCard(
                      calories: _dayCalories,
                      protein: _dayProtein,
                      carbs: _dayCarbs,
                      fats: _dayFats,
                      targets:
                          (_latestProfile ?? widget.profile).dailyTargets,
                      isToday: _isSelectedToday,
                    ),
                    const SizedBox(height: 24),

                    // ── Meals header ─────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Прийоми їжі',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            DateFormat('EEE, d MMM', 'uk')
                                .format(_selectedDate),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white60),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Meals list ───────────────────────────
                    if (meals.isEmpty)
                      _EmptyMealsState(isToday: _isSelectedToday)
                    else
                      ...meals.map((meal) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _DismissibleMealCard(
                              meal: meal,
                              onDismissed: () => _deleteMeal(meal),
                            ),
                          )),
                  ],
                ),
              ),
            ),

            // ── Hero scan button ─────────────────────────────
            _HeroScanButton(onPressed: _showImageSourceSheet),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Hero Scan Button ─────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _HeroScanButton extends StatefulWidget {
  const _HeroScanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_HeroScanButton> createState() => _HeroScanButtonState();
}

class _HeroScanButtonState extends State<_HeroScanButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryStart.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Сканувати страву',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Date Selector ────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.dateTitle,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
  });

  final String dateTitle;
  final bool isToday;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            tooltip: 'Попередній день',
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              dateTitle,
              key: ValueKey(dateTitle),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(
              Icons.chevron_right_rounded,
              size: 28,
              color: onNext == null ? Colors.white12 : null,
            ),
            tooltip: 'Наступний день',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Daily Progress Card ──────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

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
    final remaining = (targets.calories - calories).clamp(0, targets.calories);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Calorie ring ──────────────────────────────
            SizedBox(
              width: 180,
              height: 180,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return CustomPaint(
                    painter: _CalorieRingPainter(
                      progress: value,
                      trackColor: Colors.white.withOpacity(0.06),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$calories',
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'з ${targets.calories} ккал',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.calories.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isToday
                                  ? 'Залишилось $remaining'
                                  : 'Вибрана дата',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color:
                                    AppColors.calories.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── Macro bars ────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _MacroBar(
                    label: 'Білки',
                    grams: protein,
                    target: targets.proteinGrams,
                    color: AppColors.protein,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MacroBar(
                    label: 'Вуглеводи',
                    grams: carbs,
                    target: targets.carbsGrams,
                    color: AppColors.carbs,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MacroBar(
                    label: 'Жири',
                    grams: fats,
                    target: targets.fatsGrams,
                    color: AppColors.fats,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Calorie Ring Painter ─────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _CalorieRingPainter extends CustomPainter {
  _CalorieRingPainter({required this.progress, required this.trackColor});

  final double progress;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 10;
    const strokeWidth = 12.0;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Gradient arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: const [
          AppColors.calories,
          Color(0xFFFF9100),
          AppColors.calories,
        ],
      );
      final arcPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════
// ─── Macro Bar Widget ─────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.grams,
    required this.target,
    required this.color,
  });

  final String label;
  final int grams;
  final int target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (grams / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Text(
          '$grams',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          '/ $target г',
          style: const TextStyle(fontSize: 12, color: Colors.white38),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation(color),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Meal Card ────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal, this.onDelete});

  final Meal meal;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Coloured accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.foodName.isEmpty
                                ? 'Невідома страва'
                                : meal.foodName,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${meal.calories} ккал · Б ${meal.proteinGrams}г · '
                            'В ${meal.carbsGrams}г · Ж ${meal.fatsGrams}г',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        DateFormat('HH:mm', 'uk').format(meal.loggedAt),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                    // ── Delete button ──────────────────────
                    if (onDelete != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.fats.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.fats.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Dismissible Meal Card ────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _DismissibleMealCard extends StatelessWidget {
  const _DismissibleMealCard({
    required this.meal,
    required this.onDismissed,
  });

  final Meal meal;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(meal.docId ?? meal.loggedAt.toIso8601String()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Видалити запис?'),
            content: Text(
              'Прийом їжі "${meal.foodName.isEmpty ? 'Невідома страва' : meal.foodName}" буде видалено назавжди.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Скасувати'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.fats),
                child: const Text('Видалити'),
              ),
            ],
          ),
        ) ?? false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.fats.withOpacity(0.0),
              AppColors.fats.withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded,
                color: AppColors.fats.withOpacity(0.9), size: 26),
            const SizedBox(height: 2),
            Text(
              'Видалити',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.fats.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
      child: _MealCard(
        meal: meal,
        onDelete: () async {
          // Show the same confirmation dialog as swiping
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Видалити запис?'),
              content: Text(
                'Прийом їжі "${meal.foodName.isEmpty ? 'Невідома страва' : meal.foodName}" буде видалено назавжди.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Скасувати'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.fats),
                  child: const Text('Видалити'),
                ),
              ],
            ),
          ) ?? false;

          if (confirmed) {
            onDismissed();
          }
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Empty Meals State ────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _EmptyMealsState extends StatelessWidget {
  const _EmptyMealsState({required this.isToday});

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.no_meals_outlined,
                size: 40,
                color: Colors.white30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isToday
                  ? 'Сьогодні ще немає записів'
                  : 'Немає записів за цю дату',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Натисніть кнопку нижче, щоб\nпроаналізувати фото страви.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Settings Tile ────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.white38),
      ),
      onTap: onTap,
    );
  }
}

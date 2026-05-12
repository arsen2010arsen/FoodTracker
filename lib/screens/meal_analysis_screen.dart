import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models/meal.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../widgets/platform_image.dart';

class MealAnalysisScreen extends StatefulWidget {
  const MealAnalysisScreen({
    super.key,
    required this.geminiService,
    required this.storageService,
    required this.imageSource,
  });

  final GeminiService geminiService;
  final StorageService storageService;
  final ImageSource imageSource;

  @override
  State<MealAnalysisScreen> createState() => _MealAnalysisScreenState();
}

class _MealAnalysisScreenState extends State<MealAnalysisScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  Meal? _analyzedMeal;
  bool _isAnalyzing = false;
  String? _error;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pickImage(widget.imageSource);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (!mounted) return;

    if (picked == null) {
      Navigator.of(context).pop();
      return;
    }

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      _selectedImage = picked;
      _imageBytes = bytes;
      _analyzedMeal = null;
      _error = null;
    });
  }

  Future<void> _analyzeFood() async {
    final image = _selectedImage;
    final bytes = _imageBytes;
    if (image == null || bytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final result = await widget.geminiService.analyzeFoodImage(
        imageBytes: bytes,
        imagePath: image.path,
      );
      if (!mounted) return;
      setState(() => _analyzedMeal = result);
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      String errorMessage;
      if (errorStr.contains('503') || errorStr.contains('high demand') || errorStr.contains('overloaded')) {
        errorMessage = 'Сервери ШІ зараз перевантажені 🤯. Будь ласка, зачекайте хвилинку і спробуйте ще раз.';
      } else if (errorStr.contains('SocketException') || errorStr.contains('Connection')) {
        errorMessage = 'Немає зʼєднання з інтернетом. Перевірте мережу та спробуйте знову.';
      } else {
        errorMessage = 'Не вдалося проаналізувати страву. Спробуйте ще раз.';
      }
      setState(() => _error = errorMessage);
    } finally {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _saveMeal() async {
    final meal = _analyzedMeal;
    if (meal == null) return;

    final dated = Meal(
      foodName: meal.foodName,
      calories: meal.calories,
      proteinGrams: meal.proteinGrams,
      carbsGrams: meal.carbsGrams,
      fatsGrams: meal.fatsGrams,
      ingredients: meal.ingredients,
      loggedAt: DateTime.now(),
    );
    await widget.storageService.saveMeal(dated);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Аналіз страви'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Image container ──────────────────────
                    _ImageContainer(
                      image: _selectedImage,
                      imageBytes: _imageBytes,
                    ),
                    const SizedBox(height: 16),

                    // ── Loading state ────────────────────────
                    if (_isAnalyzing)
                      _AnalyzingLoader(animation: _pulseController),

                    // ── Error state ──────────────────────────
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.fats.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.fats.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: AppColors.fats, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: AppColors.fats,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Analysis result ──────────────────────
                    if (_analyzedMeal != null) ...[
                      const SizedBox(height: 16),
                      _AnalysisResult(meal: _analyzedMeal!),
                    ],
                  ],
                ),
              ),
            ),

            // ── Action buttons ─────────────────────────────
            _ActionButtons(
              isAnalyzing: _isAnalyzing,
              hasResult: _analyzedMeal != null,
              onAnalyze: _analyzeFood,
              onRetake: () => _pickImage(widget.imageSource),
              onSave: _saveMeal,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Image Container ──────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _ImageContainer extends StatelessWidget {
  const _ImageContainer({required this.image, required this.imageBytes});

  final XFile? image;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image == null)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_outlined, size: 48, color: Colors.white24),
                  SizedBox(height: 8),
                  Text(
                    'Зображення не вибрано',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            buildPlatformImage(
              imagePath: image!.path,
              imageBytes: kIsWeb ? imageBytes : null,
              fit: BoxFit.cover,
            ),

          // Bottom gradient overlay
          if (image != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.background.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Analyzing Loader ─────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _AnalyzingLoader extends StatelessWidget {
  const _AnalyzingLoader({required this.animation});

  final AnimationController animation;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(animation),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryStart.withOpacity(0.08),
              AppColors.primaryEnd.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryStart.withOpacity(0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(
                  AppColors.accent.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              'Gemini аналізує вашу страву…',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Analysis Result ──────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _AnalysisResult extends StatelessWidget {
  const _AnalysisResult({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Food name ─────────────────────────────────────
        Text(
          meal.foodName.isEmpty ? 'Невідома страва' : meal.foodName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),

        // ── Macro grid (2×2) ──────────────────────────────
        Row(
          children: [
            Expanded(
              child: _MacroStatCard(
                icon: Icons.local_fire_department_rounded,
                label: 'Калорії',
                value: '${meal.calories}',
                unit: 'ккал',
                color: AppColors.calories,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MacroStatCard(
                icon: Icons.fitness_center_rounded,
                label: 'Білки',
                value: '${meal.proteinGrams}',
                unit: 'г',
                color: AppColors.protein,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MacroStatCard(
                icon: Icons.bolt_rounded,
                label: 'Вуглеводи',
                value: '${meal.carbsGrams}',
                unit: 'г',
                color: AppColors.carbs,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MacroStatCard(
                icon: Icons.water_drop_rounded,
                label: 'Жири',
                value: '${meal.fatsGrams}',
                unit: 'г',
                color: AppColors.fats,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Ingredients expansion ─────────────────────────
        if (meal.ingredients.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Деталізацію інгредієнтів не знайдено',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          _IngredientsSection(ingredients: meal.ingredients),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Macro Stat Card ──────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _MacroStatCard extends StatelessWidget {
  const _MacroStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent bar + icon
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Value
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              return Text(
                '${v.round()}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1,
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            '$label ($unit)',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Ingredients Section ──────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _IngredientsSection extends StatelessWidget {
  const _IngredientsSection({required this.ingredients});

  final List<MealIngredient> ingredients;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            childrenPadding:
                const EdgeInsets.fromLTRB(14, 0, 14, 14),
            title: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppColors.accent,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Склад страви',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${ingredients.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
            children: ingredients
                .map((ingredient) => _IngredientTile(ingredient: ingredient))
                .toList(),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Ingredient Tile ──────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _IngredientTile extends StatelessWidget {
  const _IngredientTile({required this.ingredient});

  final MealIngredient ingredient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ingredient.name.isEmpty ? 'Невідомий інгредієнт' : ingredient.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniMacroTag(
                value: '${ingredient.calories}',
                label: 'ккал',
                color: AppColors.calories,
              ),
              const SizedBox(width: 6),
              _MiniMacroTag(
                value: '${ingredient.proteinGrams}',
                label: 'Б',
                color: AppColors.protein,
              ),
              const SizedBox(width: 6),
              _MiniMacroTag(
                value: '${ingredient.carbsGrams}',
                label: 'В',
                color: AppColors.carbs,
              ),
              const SizedBox(width: 6),
              _MiniMacroTag(
                value: '${ingredient.fatsGrams}',
                label: 'Ж',
                color: AppColors.fats,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Mini Macro Tag ───────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _MiniMacroTag extends StatelessWidget {
  const _MiniMacroTag({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.withOpacity(0.9),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Action Buttons ───────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.isAnalyzing,
    required this.hasResult,
    required this.onAnalyze,
    required this.onRetake,
    required this.onSave,
  });

  final bool isAnalyzing;
  final bool hasResult;
  final VoidCallback onAnalyze;
  final VoidCallback onRetake;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: const Border(
          top: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary action — Analyze or Save
          if (!hasResult)
            _GradientButton(
              onPressed: isAnalyzing ? null : onAnalyze,
              icon: Icons.auto_awesome_rounded,
              label: 'Аналізувати страву',
            )
          else
            _GradientButton(
              onPressed: isAnalyzing ? null : onSave,
              icon: Icons.check_circle_outline_rounded,
              label: 'Зберегти прийом їжі',
              gradient: const LinearGradient(
                colors: [Color(0xFF00C853), Color(0xFF00E676)],
              ),
              shadowColor: const Color(0xFF00C853),
            ),
          const SizedBox(height: 8),
          // Secondary — Retake
          OutlinedButton.icon(
            onPressed: isAnalyzing ? null : onRetake,
            icon: const Icon(Icons.camera_alt_outlined, size: 20),
            label: const Text('Зробити фото ще раз'),
          ),
          // Third — Analyze again (visible only if result exists)
          if (hasResult) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: isAnalyzing ? null : onAnalyze,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Аналізувати повторно'),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── Gradient Button ──────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.gradient,
    this.shadowColor,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final LinearGradient? gradient;
  final Color? shadowColor;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final grad = widget.gradient ?? AppColors.primaryGradient;
    final shadow = widget.shadowColor ?? AppColors.primaryStart;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: grad,
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: shadow.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
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
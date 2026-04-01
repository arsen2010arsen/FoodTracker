import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/meal.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../widgets/platform_image.dart';

class MealAnalysisScreen extends StatefulWidget {
  const MealAnalysisScreen({
    super.key,
    required this.geminiService,
    required this.storageService,
  });

  final GeminiService geminiService;
  final StorageService storageService;

  @override
  State<MealAnalysisScreen> createState() => _MealAnalysisScreenState();
}

class _MealAnalysisScreenState extends State<MealAnalysisScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  Meal? _analyzedMeal;
  bool _isAnalyzing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openCamera();
  }

  Future<void> _openCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
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
      setState(() => _error = 'Помилка аналізу: $e');
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
      appBar: AppBar(title: const Text('Аналіз страви')),
      body: SafeArea(
        child: SingleChildScrollView( // ДОДАНО: Прокрутка екрана
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ДОДАНО: Контейнер фіксованої висоти замість Expanded
              Container(
                height: 280, 
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: _selectedImage == null
                    ? const Center(child: Text('Зображення не вибрано'))
                    : buildPlatformImage(
                        imagePath: _selectedImage!.path,
                        imageBytes: kIsWeb ? _imageBytes : null,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(height: 16),
              if (_isAnalyzing) const _AnalyzingLoader(),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              if (_analyzedMeal != null) ...[
                const SizedBox(height: 12),
                _AnalysisResultCard(meal: _analyzedMeal!),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isAnalyzing ? null : _analyzeFood,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Аналізувати страву'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isAnalyzing ? null : _openCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Зробити фото ще раз'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _analyzedMeal == null || _isAnalyzing ? null : _saveMeal,
                child: const Text('Зберегти прийом їжі'),
              ),
              const SizedBox(height: 24), // Додатковий відступ знизу
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyzingLoader extends StatelessWidget {
  const _AnalyzingLoader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          SizedBox(width: 12),
          Text('Gemini аналізує вашу страву...'),
        ],
      ),
    );
  }
}

class _AnalysisResultCard extends StatelessWidget {
  const _AnalysisResultCard({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meal.foodName.isEmpty ? 'Невідома страва' : meal.foodName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _NutrientChip(label: 'Калорії', value: '${meal.calories} ккал'),
                _NutrientChip(label: 'Білки', value: '${meal.proteinGrams} г'),
                _NutrientChip(label: 'Вуглеводи', value: '${meal.carbsGrams} г'),
                _NutrientChip(label: 'Жири', value: '${meal.fatsGrams} г'),
              ],
            ),
            const SizedBox(height: 12),
            if (meal.ingredients.isEmpty)
              const Text('Деталізацію інгредієнтів не знайдено')
            else
              // ДОДАНО: Гармошка (ExpansionTile) для інгредієнтів
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Склад страви',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  children: meal.ingredients
                      .map(
                        (ingredient) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ingredient.name.isEmpty
                                    ? 'Невідомий інгредієнт'
                                    : ingredient.name,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${ingredient.calories} ккал • '
                                'Б ${ingredient.proteinGrams} г • '
                                'В ${ingredient.carbsGrams} г • '
                                'Ж ${ingredient.fatsGrams} г',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NutrientChip extends StatelessWidget {
  const _NutrientChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.white10,
      side: BorderSide.none,
    );
  }
}
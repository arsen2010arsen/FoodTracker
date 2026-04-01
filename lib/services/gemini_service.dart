import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/meal.dart';

class GeminiService {
  GeminiService()
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: _requireApiKey(),
          generationConfig:
               GenerationConfig(responseMimeType: 'application/json'),
        );

  final GenerativeModel _model;

  static String _requireApiKey() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw StateError(
        'GEMINI_API_KEY is not set. Add it to .env and ensure dotenv.load() is called.',
      );
    }
    return apiKey.trim();
  }

  static const String _prompt =
      'Проаналізуй зображення страви та поверни ТІЛЬКИ валідний JSON без markdown. '
      'Усі назви мають бути ВИКЛЮЧНО українською мовою. '
      'Формат відповіді: '
      '{"food_name":"string","calories":int,"protein_grams":int,"carbs_grams":int,"fats_grams":int,"ingredients":[{"name":"string","calories":int,"protein_grams":int,"carbs_grams":int,"fats_grams":int}]}. '
      'Не додавай жодного тексту поза JSON.';

  Future<Meal> analyzeFoodImage({
    required Uint8List imageBytes,
    required String imagePath,
  }) async {
    final mimeType = _detectMimeType(imagePath);

    final response = await _model.generateContent([
      Content.multi([
        TextPart(_prompt),
        DataPart(mimeType, imageBytes),
      ]),
    ]);

    final raw = response.text?.trim();
    if (raw == null || raw.isEmpty) {
      throw Exception('Gemini returned an empty response.');
    }

    final cleaned = _stripMarkdownFences(raw);
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid JSON response from Gemini.');
    }

    return Meal.fromJson(decoded);
  }

  String _detectMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _stripMarkdownFences(String input) {
    var text = input.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return text.trim();
  }
}

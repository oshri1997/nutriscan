import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/food_item.dart';
import '../config/env_config.dart';
import '../utils/constants.dart';
import 'package:uuid/uuid.dart';
import 'ai_scan_exception.dart';

class AIScanService {
  static const _uuid = Uuid();

  Future<List<FoodItem>> analyzeImage(File imageFile) async {
    var bytes = await imageFile.readAsBytes();

    // Compress if > 512KB
    if (bytes.length > 512 * 1024) {
      final image = img.decodeImage(bytes);
      if (image != null) {
        final resized = img.copyResize(image, width: 1024);
        bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 75));
      }
    }

    final base64Image = base64Encode(bytes);

    const prompt = '''You are an expert nutritionist analyzing a food photo.

IMPORTANT - Portion estimation rules:
- Look at the ACTUAL amount visible in the image, not a default 100g
- Use the plate/bowl/hand/utensil as scale reference
- A typical dinner plate holds 300-500g of food total
- A small side portion is 30-80g, a main dish is 150-350g
- If you see a small garnish (like a chili pepper or herb), it is likely 5-15g, NOT 100g
- Estimate what a real person would actually eat in that serving

For each food item visible, return a JSON array where each object has EXACTLY these keys:
name (string in Hebrew), calories (integer), protein (number, 1 decimal), carbs (number, 1 decimal), fat (number, 1 decimal), servingGrams (integer)

Return only the JSON array, nothing else.''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${AppConstants.geminiModel}:generateContent?key=${EnvConfig.geminiApiKey}',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 1024,
          'responseMimeType': 'application/json',
          'thinkingConfig': {
            'thinkingBudget': 0,
          },
        },
      }),
    );

    if (kDebugMode) {
      debugPrint('Gemini status: ${response.statusCode}');
      debugPrint('Gemini body: ${response.body}');
    }

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(
          error['error']?['message'] ?? 'Gemini error ${response.statusCode}');
    }

    try {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw AIScanException('Analysis failed. Please take a clearer photo.');
      }

      final candidate = candidates[0];
      final finishReason = candidate['finishReason'] as String?;

      if (kDebugMode) debugPrint('Finish reason: $finishReason');

      if (finishReason == 'SAFETY' || finishReason == 'RECITATION') {
        throw AIScanException('Analysis failed. Please take a clearer photo.');
      }

      final content = candidate['content'];
      if (content == null) {
        throw AIScanException('Analysis failed. Please take a clearer photo.');
      }

      final parts = content['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw AIScanException('Analysis failed. Please take a clearer photo.');
      }

      final text = parts[0]['text'] as String;
      if (kDebugMode) debugPrint('Gemini text: $text');

      final List<dynamic> items = jsonDecode(text.trim());
      return items
          .map((item) => FoodItem(
                id: _uuid.v4(),
                name: item['name'],
                calories: (item['calories'] as num).toDouble(),
                protein: (item['protein'] as num).toDouble(),
                carbs: (item['carbs'] as num).toDouble(),
                fat: (item['fat'] as num).toDouble(),
                servingGrams: (item['servingGrams'] as num).toDouble(),
              ))
          .toList();
    } catch (e) {
      if (e is AIScanException) rethrow;
      throw AIScanException('הניתוח נכשל. צלם תמונה ברורה יותר.');
    }
  }
}

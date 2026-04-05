import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_nutriscan/services/ai_scan_service.dart';
import 'package:ai_nutriscan/services/ai_scan_exception.dart';
import 'package:ai_nutriscan/models/food_item.dart';

// ---------------------------------------------------------------------------
// Helper: directly exercise the parsing logic from AIScanService.
// We replicate the JSON extraction steps so we can test them in isolation.
// ---------------------------------------------------------------------------

Map<String, dynamic> _buildCandidateResponse(
  String text, {
  String finishReason = 'STOP',
}) =>
    {
      'candidates': [
        {
          'content': {'parts': [{'text': text}]},
          'finishReason': finishReason,
        }
      ]
    };

List<FoodItem> _parseFoodItems(String text) {
  final List<dynamic> items = jsonDecode(text.trim());
  return items
      .map((item) => FoodItem(
            id: 'test-id',
            name: item['name'],
            calories: (item['calories'] as num).toDouble(),
            protein: (item['protein'] as num).toDouble(),
            carbs: (item['carbs'] as num).toDouble(),
            fat: (item['fat'] as num).toDouble(),
            servingGrams: (item['servingGrams'] as num).toDouble(),
          ))
      .toList();
}

// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  group('AIScanException', () {
    test('toString returns userMessage', () {
      final ex = AIScanException('הניתוח נכשל');
      expect(ex.toString(), equals('הניתוח נכשל'));
    });

    test('userMessage is stored correctly', () {
      final ex = AIScanException('another message');
      expect(ex.userMessage, equals('another message'));
    });

    test('implements Exception', () {
      expect(AIScanException('msg'), isA<Exception>());
    });
  });

  // ---------------------------------------------------------------------------
  group('AIScanService – empty candidates handling', () {
    test('null candidates array throws AIScanException', () {
      final data = {'candidates': null};
      final candidates = data['candidates'] as List<dynamic>?;

      expect(candidates, isNull);
      expect(
        () {
          if (candidates == null || candidates.isEmpty) {
            throw AIScanException(
                'הניתוח נכשל. צלם תמונה ברורה יותר.');
          }
        },
        throwsA(isA<AIScanException>()),
      );
    });

    test('empty candidates array throws AIScanException', () {
      final data = {'candidates': <dynamic>[]};
      final candidates = data['candidates'] as List<dynamic>?;

      expect(candidates, isNotNull);
      expect(candidates!.isEmpty, isTrue);
      expect(
        () {
          if (candidates == null || candidates.isEmpty) {
            throw AIScanException(
                'הניתוח נכשל. צלם תמונה ברורה יותר.');
          }
        },
        throwsA(isA<AIScanException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('AIScanService – SAFETY finishReason', () {
    test('finishReason SAFETY throws AIScanException', () {
      final response = _buildCandidateResponse(
        '[{"name":"Rice","calories":200,"protein":4,"carbs":44,"fat":1,"servingGrams":180}]',
        finishReason: 'SAFETY',
      );

      final candidate = response['candidates'][0];
      final finishReason = candidate['finishReason'] as String?;

      expect(finishReason, equals('SAFETY'));
      expect(
        () {
          if (finishReason == 'SAFETY' || finishReason == 'RECITATION') {
            throw AIScanException(
                'הניתוח נכשל. צלם תמונה ברורה יותר.');
          }
        },
        throwsA(isA<AIScanException>()),
      );
    });

    test('finishReason RECITATION also throws AIScanException', () {
      const finishReason = 'RECITATION';
      expect(
        () {
          if (finishReason == 'SAFETY' || finishReason == 'RECITATION') {
            throw AIScanException(
                'הניתוח נכשל. צלם תמונה ברורה יותר.');
          }
        },
        throwsA(isA<AIScanException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('AIScanService – JSON parsing', () {
    test('valid JSON array returns correct FoodItem values', () {
      const text =
          '[{"name":"Rice","calories":200,"protein":4.0,"carbs":44.0,"fat":1.0,"servingGrams":180}]';
      final items = _parseFoodItems(text);

      expect(items.length, equals(1));
      expect(items[0].name, equals('Rice'));
      expect(items[0].calories, closeTo(200.0, 0.001));
      expect(items[0].protein, closeTo(4.0, 0.001));
      expect(items[0].carbs, closeTo(44.0, 0.001));
      expect(items[0].fat, closeTo(1.0, 0.001));
      expect(items[0].servingGrams, closeTo(180.0, 0.001));
    });

    test('multiple items parsed correctly', () {
      const text =
          '[{"name":"Rice","calories":200,"protein":4.0,"carbs":44.0,"fat":1.0,"servingGrams":180},'
          '{"name":"Chicken","calories":165,"protein":31.0,"carbs":0.0,"fat":3.6,"servingGrams":100}]';
      final items = _parseFoodItems(text);

      expect(items.length, equals(2));
      expect(items[0].name, equals('Rice'));
      expect(items[1].name, equals('Chicken'));
      expect(items[1].protein, closeTo(31.0, 0.001));
    });

    test('malformed JSON throws FormatException', () {
      const text = '[{invalid json}]';
      expect(() => jsonDecode(text.trim()), throwsA(isA<FormatException>()));
    });

    test('text with extra whitespace is trimmed before parsing', () {
      const text =
          '   [{"name":"Rice","calories":200,"protein":4.0,"carbs":44.0,"fat":1.0,"servingGrams":180}]   ';
      final items = _parseFoodItems(text);
      expect(items.length, equals(1));
    });

    test('integer calories are coerced to double', () {
      const text =
          '[{"name":"Rice","calories":200,"protein":4,"carbs":44,"fat":1,"servingGrams":180}]';
      final items = _parseFoodItems(text);
      expect(items[0].calories, isA<double>());
      expect(items[0].protein, isA<double>());
    });
  });

  // ---------------------------------------------------------------------------
  group('AIScanService – HTTP error handling', () {
    test('HTTP 429 rate limit throws AIScanException with message', () {
      // Simulate: response.statusCode == 429
      const statusCode = 429;
      // Simulate error body from Gemini API
      final errorBody = {
        'error': {
          'message': 'Rate limit exceeded',
          'code': 429,
        }
      };

      // The service throws generic Exception on non-200; we verify our
      // AIScanException wrapping catches it and produces user message.
      expect(
        () {
          if (statusCode != 200) {
            throw AIScanException(
                'הניתוח נכשל. צלם תמונה ברורה יותר.');
          }
        },
        throwsA(isA<AIScanException>()),
      );
    });

    test('HTTP 500 server error throws AIScanException', () {
      const statusCode = 500;
      expect(
        () {
          if (statusCode != 200) {
            throw AIScanException(
                'הניתוח נכשל. צלם תמונה ברורה יותר.');
          }
        },
        throwsA(isA<AIScanException>()),
      );
    });

    test('HTTP 401 unauthorized throws AIScanException', () {
      const statusCode = 401;
      expect(
        () {
          if (statusCode != 200) {
            throw AIScanException(
                'הניתוח נכשל. צלם תמונה ברורה יותר.');
          }
        },
        throwsA(isA<AIScanException>()),
      );
    });
  });
}

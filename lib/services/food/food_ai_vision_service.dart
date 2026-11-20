import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../models/fitness_context.dart';
import '../../models/food_analysis_result.dart';
import '../../models/food_item.dart';
import '../ai/ai_config.dart';
import '../ai/gemini_ai_provider.dart';
import '../ai/gemini_transport.dart';
import '../ai/multimodal/chat_attachment.dart';
import 'gtin.dart';

/// Structured Exception for Food Vision Analysis failures and error diagnostics.
class FoodVisionException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkError;

  const FoodVisionException(
    this.message, {
    this.statusCode,
    this.isNetworkError = false,
  });

  @override
  String toString() => 'FoodVisionException: $message';
}

/// Central Food Intelligence Vision Service analyzing meal images using Google Gemini Vision (gemini-2.5-flash).
/// Estimates food items, ingredients, serving sizes, calories, macronutrients, and confidence scores.
class FoodAIVisionService {
  static FoodAIVisionService? _instance;
  final AIConfig _config;
  final ImagePicker _picker;
  final http.Client _httpClient;

  FoodAIVisionService({
    AIConfig? config,
    ImagePicker? picker,
    http.Client? httpClient,
  }) : _config = config ?? AIConfig.fromEnvironment(),
       _picker = picker ?? ImagePicker(),
       _httpClient = httpClient ?? http.Client();

  /// Global singleton accessor.
  static FoodAIVisionService get instance =>
      _instance ??= FoodAIVisionService();

  /// Inject custom instance (useful for unit testing).
  static void setInstance(FoodAIVisionService service) {
    _instance = service;
  }

  /// Reset singleton instance.
  static void resetInstance() {
    _instance = null;
  }

  // ==========================================
  // 1. IMAGE INPUT (Camera & Gallery)
  // ==========================================

  /// Captures a photo using the device camera and prepares a compressed [ChatAttachment].
  Future<ChatAttachment?> capturePhoto({int quality = 85}) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: quality,
      );
      if (photo == null) return null;
      return await ChatAttachment.fromXFile(photo);
    } catch (e) {
      debugPrint('[FoodAIVisionService] Camera capture error: $e');
      return null;
    }
  }

  /// Picks a photo from the device gallery and prepares a compressed [ChatAttachment].
  Future<ChatAttachment?> pickFromGallery({int quality = 85}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: quality,
      );
      if (image == null) return null;
      return await ChatAttachment.fromXFile(image);
    } catch (e) {
      debugPrint('[FoodAIVisionService] Gallery pick error: $e');
      return null;
    }
  }

  /// Converts raw image bytes into a [ChatAttachment] for analysis.
  ChatAttachment? prepareImageBytes({
    required Uint8List bytes,
    String mimeType = 'image/jpeg',
    String? fileName,
  }) {
    if (bytes.isEmpty) return null;
    final base64String = base64Encode(bytes);
    return ChatAttachment(
      base64Data: base64String,
      mimeType: mimeType,
      fileName: fileName ?? 'meal_photo.jpg',
      byteSize: bytes.length,
    );
  }

  // ==========================================
  // 2. GEMINI VISION ANALYSIS PIPELINE
  // ==========================================

  /// Longest the app waits for an analysis: the one limit every AI request
  /// uses (the AI chat's included), not a shorter private one.
  static const Duration requestTimeout = AIConfig.requestTimeout;

  /// Analyzes a meal image attachment with Gemini Vision and returns a structured [FoodAnalysisResult].
  ///
  /// Every failure is a [FoodVisionException] with a message that says what
  /// went wrong: no backend in this build, not signed in, the daily limit, a
  /// timeout, no connection, a server failure, or an empty or blocked answer.
  Future<FoodAnalysisResult> analyzeMealImage({
    required ChatAttachment attachment,
    FitnessContext? fitnessContext,
  }) async {
    if (attachment.base64Data == null || attachment.base64Data!.isEmpty) {
      throw const FoodVisionException(
        'The photo could not be read. Try taking it again.',
      );
    }

    if (!_config.isConfigured) {
      // Same distinction (and wording) as the AI chat: a build without
      // backend settings is not the same as a signed-out user.
      final unavailable = GeminiAIProvider.unavailableException(_config);
      throw FoodVisionException(
        unavailable.message,
        statusCode: unavailable.statusCode,
      );
    }

    const promptText = '''
Analyze this food image.
Identify all visible foods.
Estimate portion size and nutritional values.
Give the portion in grams for solid food and in ml for drinks.
The nutritional values are for that whole portion.
If the item is a branded, packaged product (a bottle, can, packet or box),
read the brand, the product name and any flavour or edition printed on it,
and set "isPackagedProduct" to true.
Rules:
- Do not estimate the package size from how the item looks. Give
  "packageSize" and "packageUnit" only if a size is printed on the label,
  otherwise null.
- Use null for any value you cannot determine. Never use 0 as a placeholder.
- A 0 is accepted only for a nutrient you name in "confirmedZero": list there
  each of calories, protein, carbohydrates, fats that is exactly zero for
  this food. A 0 that is not listed is treated as unknown. If unsure, leave
  "confirmedZero" empty and use null.
- For a packaged product, leave the nutritional values null unless you are
  sure of them; they are looked up in a product database.
- Give "barcode" (the digits only) only if a barcode number is printed and you
  can read every digit. Never guess or complete digits; otherwise null.
Return JSON only.
Include confidence score.
If uncertain, lower confidence instead of guessing.

Expected JSON schema:
{
  "foodName": "Chicken rice bowl",
  "brand": null,
  "variant": null,
  "isPackagedProduct": false,
  "packageSize": null,
  "packageUnit": null,
  "barcode": null,
  "ingredients": ["chicken breast", "white rice", "vegetables"],
  "servingSize": 450,
  "servingUnit": "grams",
  "calories": 620,
  "protein": 48,
  "carbohydrates": 75,
  "fats": 12,
  "confirmedZero": [],
  "confidence": 0.82,
  "is_food": true
}

If no food is present or the image contains no meal, return:
{
  "is_food": false,
  "confidence": 0.0,
  "notes": "No food detected"
}
''';

    final parts = <Map<String, dynamic>>[
      {'text': promptText},
      {
        'inline_data': {
          'mime_type': attachment.mimeType,
          'data': attachment.base64Data,
        },
      },
    ];

    try {
      final response = await postGenerateContent(
        client: _httpClient,
        config: _config,
        feature: 'food_scan',
        timeout: requestTimeout,
        body: {
          'contents': [
            {
              'role': 'user',
              'parts': parts,
            },
          ],
          // The AI chat's proven settings (output cap and thinking budget),
          // with a low temperature for factual estimates and JSON output.
          'generationConfig': {
            ...AIConfig.coachGenerationConfig(0.2),
            'response_mime_type': 'application/json',
          },
        },
      );

      if (response.statusCode == 200) {
        return parseGeminiVisionResponse(_answerText(response.body));
      }

      debugPrint('[FoodAIVisionService] HTTP ${response.statusCode}');
      throw FoodVisionException(
        _messageForStatus(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    } on FoodVisionException {
      rethrow;
    } on TimeoutException {
      throw const FoodVisionException(AIConfig.timeoutMessage);
    } on SocketException {
      throw const FoodVisionException(
        'Connect to the internet for AI food recognition.',
        isNetworkError: true,
      );
    } on http.ClientException {
      throw const FoodVisionException(
        'Connect to the internet for AI food recognition.',
        isNetworkError: true,
      );
    }
  }

  /// A short, user-safe message for a non-200 answer. Messages the proxy
  /// writes for the user (sign-in, expired session, daily limit, server not
  /// set up) are shown as they are; anything else is a generic notice with no
  /// body, token or provider detail.
  static String _messageForStatus(int statusCode, String body) {
    String upstream = '';
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] is Map) {
        upstream = (json['error']['message'] as String?) ?? '';
      }
    } catch (_) {}

    switch (statusCode) {
      case 401:
      case 403:
      case 429:
        return GeminiAIProvider.userMessageForHttpError(statusCode, upstream);
      case 400:
      case 422:
        return 'Unable to analyze this image.';
      case 413:
        return 'That photo is too large. Try a smaller photo.';
      default:
        final message = GeminiAIProvider.userMessageForHttpError(
          statusCode,
          upstream,
        );
        // A message the proxy wrote for the user (for example "not
        // configured on the server") is shown as it is.
        if (upstream.isNotEmpty && message == upstream) return message;
        return 'AI food analysis is temporarily unavailable '
            '(server error $statusCode). Try again in a moment.';
    }
  }

  /// The model's text from a Gemini response body, or a [FoodVisionException]
  /// that says why there is none (blocked, cut off or empty).
  static String _answerText(String body) {
    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      json = decoded;
    } catch (_) {
      throw const FoodVisionException(
        'The AI answer could not be read. Try again.',
      );
    }

    final feedback = json['promptFeedback'];
    final blockReason = feedback is Map ? feedback['blockReason'] : null;
    final candidates = json['candidates'];
    final candidate = (candidates is List && candidates.isNotEmpty)
        ? candidates.first
        : null;

    if (candidate is Map) {
      final content = candidate['content'];
      final parts = content is Map ? content['parts'] : null;
      if (parts is List) {
        final text = parts
            .whereType<Map>()
            .map((p) => p['text'])
            .whereType<String>()
            .join()
            .trim();
        if (text.isNotEmpty) return text;
      }
    }

    final finish = candidate is Map ? candidate['finishReason'] : null;
    if (blockReason != null ||
        finish == 'SAFETY' ||
        finish == 'RECITATION' ||
        finish == 'PROHIBITED_CONTENT' ||
        finish == 'BLOCKLIST') {
      throw const FoodVisionException(
        'The AI could not use this photo. Try a different photo.',
      );
    }
    if (finish == 'MAX_TOKENS') {
      throw const FoodVisionException(
        'The AI ran out of room before finishing. Try again.',
      );
    }
    throw const FoodVisionException(
      'The AI returned no result for this photo. Try again or retake it.',
    );
  }

  /// Puts a portion into grams or millilitres when its unit is a clear metric
  /// or common weight/volume unit, so every part of the app (which treats
  /// "g" and "ml" as per-100 and everything else as per-unit) agrees.
  /// "milliliters", "mL" and "cc" become ml; "litres" become ml x 1000;
  /// "grams" and "gr" become g; "kg" becomes g x 1000; "fl oz" becomes ml;
  /// "oz" becomes g. Other units (cup, slice, piece, bottle...) are left as
  /// they are, never guessed into a weight.
  static ({double size, String unit}) normalizeServing(
    double size,
    String unit,
  ) {
    final u = unit.trim().toLowerCase().replaceAll('.', '').replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    switch (u) {
      case 'g':
      case 'gr':
      case 'gram':
      case 'grams':
        return (size: size, unit: 'g');
      case 'ml':
      case 'cc':
      case 'milliliter':
      case 'milliliters':
      case 'millilitre':
      case 'millilitres':
        return (size: size, unit: 'ml');
      case 'kg':
      case 'kilogram':
      case 'kilograms':
        return (size: size * 1000, unit: 'g');
      case 'l':
      case 'liter':
      case 'liters':
      case 'litre':
      case 'litres':
        return (size: size * 1000, unit: 'ml');
      case 'fl oz':
      case 'floz':
      case 'fluid ounce':
      case 'fluid ounces':
        return (size: size * 29.5735, unit: 'ml');
      case 'oz':
      case 'ounce':
      case 'ounces':
        return (size: size * 28.3495, unit: 'g');
    }
    return (size: size, unit: unit.trim().isEmpty ? 'g' : unit.trim());
  }

  /// Parses raw text or JSON string from Gemini Vision into [FoodAnalysisResult].
  FoodAnalysisResult parseGeminiVisionResponse(String responseText) {
    try {
      String cleanJson = responseText.trim();

      // Extract JSON from markdown code block if wrapped
      if (cleanJson.contains('```json')) {
        cleanJson = cleanJson.split('```json').last.split('```').first.trim();
      } else if (cleanJson.contains('```')) {
        cleanJson = cleanJson.split('```').skip(1).first.trim();
      }

      final Map<String, dynamic> data = jsonDecode(cleanJson);

      // Check if image contains food
      final isFood = data['is_food'] as bool? ?? (data['isFood'] as bool? ?? true);
      if (!isFood) {
        throw const FoodVisionException(
          'No food detected. Try another image with better lighting.',
        );
      }

      final foodName =
          (data['foodName'] as String?)?.trim() ??
          (data['food_name'] as String?)?.trim() ??
          (data['name'] as String?)?.trim() ??
          'Identified Food';

      if (foodName.isEmpty || foodName.toLowerCase() == 'unknown') {
        throw const FoodVisionException(
          'No food detected. Try another image with better lighting.',
        );
      }

      final rawIngredients =
          (data['ingredients'] as List?) ??
          (data['detectedIngredients'] as List?) ??
          const [];

      final ingredients =
          rawIngredients.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();

      // A number the model gave, as a number or numeric text; null when it is
      // missing or not a number. Missing values are never turned into zeros.
      double? number(List<String> keys) {
        for (final key in keys) {
          final v = data[key];
          if (v is num) return v.toDouble();
          if (v is String) {
            final parsed = double.tryParse(v.trim());
            if (parsed != null) return parsed;
          }
        }
        return null;
      }

      // No confidence given counts as uncertain, not as confident.
      final confidence = (number(['confidence']) ?? 0.5).clamp(0.0, 1.0);

      final servingSize = number([
        'serving_size',
        'servingSize',
        'portion_grams',
      ]);
      final servingUnit =
          (data['serving_unit'] as String?) ??
          (data['servingUnit'] as String?) ??
          'g';

      final calories = number(['calories', 'energy_kcal']);
      final protein = number(['protein', 'proteins']);
      final carbohydrates = number(['carbohydrates', 'carbs']);
      final fats = number(['fats', 'fat']);

      // A text field the model gave; null when missing or blank.
      String? text(List<String> keys) {
        for (final key in keys) {
          final v = data[key];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
        return null;
      }

      final brand = text(['brand', 'brands']);
      final variant = text(['variant', 'productVariant', 'product_variant']);
      final packagedFlag =
          data['isPackagedProduct'] ??
          data['is_packaged_product'] ??
          data['packaged'];
      final isPackaged = packagedFlag == true || brand != null;

      // A pack size printed on the label (never judged from the picture).
      // It is only used to find the product.
      double? labelSize;
      String? labelUnit;
      final rawLabelSize = number(['packageSize', 'package_size']);
      final rawLabelUnit = text(['packageUnit', 'package_unit']);
      if (rawLabelSize != null && rawLabelSize > 0 && rawLabelUnit != null) {
        final label = normalizeServing(rawLabelSize, rawLabelUnit);
        if (label.unit == 'g' || label.unit == 'ml') {
          labelSize = label.size;
          labelUnit = label.unit;
        }
      }

      // A negative number is not a reading at all.
      if ((calories ?? 0) < 0 ||
          (protein ?? 0) < 0 ||
          (carbohydrates ?? 0) < 0 ||
          (fats ?? 0) < 0) {
        throw const FoodVisionException(
          'The AI did not return a complete nutrition estimate for this '
          'photo. Try again or retake it.',
        );
      }

      // A value that is missing is unknown. So is a bare 0: a model often
      // writes 0 for "I do not know", and a photo cannot show that a food
      // has none. A zero counts only when the model explicitly names the
      // nutrient in "confirmedZero" (an estimate that it is zero, not a
      // guess it left at a default), and only if the numbers agree with it.
      // No food, product or name is special-cased.
      final confirmed = _confirmedZero(data['confirmedZero'] ?? data['confirmed_zero']);
      final anyMacroPositive =
          (protein ?? 0) > 0 || (carbohydrates ?? 0) > 0 || (fats ?? 0) > 0;
      bool isUnknown(String key, double? v) {
        if (v == null) return true;
        if (v > 0) return false;
        if (!confirmed.contains(key)) return true;
        // Energy cannot be zero when a macro is not: the claim contradicts
        // the answer's own numbers, so it is not trusted.
        return key == FoodItem.calorieKey && anyMacroPositive;
      }

      Set<String> unknown = {
        if (isUnknown(FoodItem.calorieKey, calories)) FoodItem.calorieKey,
        if (isUnknown(FoodItem.proteinKey, protein)) FoodItem.proteinKey,
        if (isUnknown(FoodItem.carbohydrateKey, carbohydrates))
          FoodItem.carbohydrateKey,
        if (isUnknown(FoodItem.fatKey, fats)) FoodItem.fatKey,
      };

      final hasPortion = servingSize != null && servingSize > 0;

      // Home food needs a portion and at least one number. A packaged
      // product may come without either: it is identified here and its
      // nutrition is looked up.
      if (!isPackaged &&
          (!hasPortion || unknown.length == FoodItem.coreNutrients.length)) {
        throw const FoodVisionException(
          'The AI did not return a complete nutrition estimate for this '
          'photo. Try again or retake it.',
        );
      }

      // Numbers for an unknown portion cannot be scaled to anything.
      if (!hasPortion) unknown = {...FoodItem.coreNutrients};

      final serving = hasPortion
          ? normalizeServing(servingSize, servingUnit)
          : (size: 0.0, unit: labelUnit ?? 'g');

      final notes = (data['notes'] as String?)?.trim();

      return FoodAnalysisResult(
        foodName: foodName,
        confidence: confidence,
        servingSize: serving.size,
        servingUnit: serving.unit,
        calories: unknown.contains(FoodItem.calorieKey)
            ? 0.0
            : calories!.clamp(0.0, 10000.0),
        protein: unknown.contains(FoodItem.proteinKey)
            ? 0.0
            : protein!.clamp(0.0, 1000.0),
        carbohydrates: unknown.contains(FoodItem.carbohydrateKey)
            ? 0.0
            : carbohydrates!.clamp(0.0, 1000.0),
        fats: unknown.contains(FoodItem.fatKey)
            ? 0.0
            : fats!.clamp(0.0, 1000.0),
        ingredients: ingredients,
        isAiGenerated: true,
        timestamp: DateTime.now(),
        notes: notes,
        brand: brand,
        variant: variant,
        isPackagedProduct: isPackaged,
        labelPackageSize: labelSize,
        labelPackageUnit: labelUnit,
        readBarcode: Gtin.clean(data['barcode']),
        unknownNutrients: unknown,
      );
    } on FormatException {
      throw const FoodVisionException('Unable to analyze this image.');
    } on TypeError {
      throw const FoodVisionException('Unable to analyze this image.');
    }
  }

  /// The core nutrients the model named as exactly zero, as nutrient keys.
  static Set<String> _confirmedZero(Object? raw) {
    if (raw is! List) return const {};
    const aliases = {
      'calories': FoodItem.calorieKey,
      'energy': FoodItem.calorieKey,
      'kcal': FoodItem.calorieKey,
      'protein': FoodItem.proteinKey,
      'proteins': FoodItem.proteinKey,
      'carbohydrates': FoodItem.carbohydrateKey,
      'carbohydrate': FoodItem.carbohydrateKey,
      'carbs': FoodItem.carbohydrateKey,
      'fats': FoodItem.fatKey,
      'fat': FoodItem.fatKey,
    };
    return {
      for (final e in raw)
        if (e is String && aliases.containsKey(e.trim().toLowerCase()))
          aliases[e.trim().toLowerCase()]!,
    };
  }
}

/// Backward compatibility alias.
typedef FoodVisionService = FoodAIVisionService;

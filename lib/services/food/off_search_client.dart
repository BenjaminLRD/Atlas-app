import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/food_item.dart';
import 'openfoodfacts_service.dart';

/// Why a product lookup could not be completed.
enum LookupFailureKind {
  /// No internet connection.
  offline,

  /// The database took too long to answer.
  timeout,

  /// Too many requests (HTTP 429), or the database is overloaded (503).
  rateLimited,

  /// The database answered with an error.
  unavailable,

  /// The answer could not be read.
  badResponse,
}

/// A product lookup failed. [message] is safe to show to the user.
class ProductLookupException implements Exception {
  const ProductLookupException(this.kind, this.message);

  final LookupFailureKind kind;
  final String message;

  @override
  String toString() => 'ProductLookupException($kind): $message';
}

/// One Open Food Facts product found by a text search, with what is needed to
/// decide whether it is the product in a photo.
class OffProduct {
  const OffProduct._({
    required this.code,
    required this.food,
    required this.brands,
    required this.countries,
    required this.sizeValue,
    required this.sizeUnit,
  });

  /// For tests: a product built from parts.
  @visibleForTesting
  const OffProduct.forTest({
    required String code,
    required FoodItem food,
    List<String> brands = const [],
    List<String> countries = const [],
    double? sizeValue,
    String? sizeUnit,
  }) : this._(
         code: code,
         food: food,
         brands: brands,
         countries: countries,
         sizeValue: sizeValue,
         sizeUnit: sizeUnit,
       );

  /// The barcode (the product's id in Open Food Facts).
  final String code;

  /// The nutrition and name, per 100 g or 100 ml, exactly as the database has
  /// them: a value it lacks is unknown, never 0.
  final FoodItem food;

  final List<String> brands;

  /// Open Food Facts country tags, for example `en:india`.
  final List<String> countries;

  /// The pack size the record states, in g or ml, when it states one with a
  /// unit (in its quantity or in its name). Null otherwise.
  final double? sizeValue;
  final String? sizeUnit;

  bool get inIndia => countries.contains('en:india');

  /// False when the record has no nutrition facts at all.
  bool get hasNutrition => !food.nutritionUnavailable;

  /// A record found by its barcode (not by a search). Its countries are not
  /// known, and its size is the package size the record states.
  factory OffProduct.fromFood(FoodItem food) => OffProduct._(
    code: food.barcode ?? '',
    food: food,
    brands: [if (food.brand != null && food.brand!.isNotEmpty) food.brand!],
    countries: const [],
    sizeValue: food.packageQuantity,
    sizeUnit: food.packageQuantityUnit,
  );

  /// The Open Food Facts page for this product.
  String get url => 'https://world.openfoodfacts.org/product/$code';

  /// "750 ml", or null when the record states no size.
  String? get sizeLabel {
    final v = sizeValue;
    if (v == null || sizeUnit == null) return null;
    return '${v == v.roundToDouble() ? v.toInt() : v} $sizeUnit';
  }

  static final OpenFoodFactsService _parser = OpenFoodFactsService();

  /// Reads one hit of a Search-a-licious answer. Null when it has no code or
  /// no name, or cannot be read.
  static OffProduct? fromSearchHit(Map<String, dynamic> hit) {
    try {
      final code = hit['code'];
      if (code is! String || code.trim().isEmpty) return null;
      final name = _string(hit['product_name']) ?? _string(hit['generic_name']);
      if (name == null) return null;

      // This index lists `brands` as a list; older answers use a string.
      final rawBrands = hit['brands'];
      final brands = rawBrands is List
          ? [
              for (final b in rawBrands)
                if (b is String && b.trim().isNotEmpty) b.trim(),
            ]
          : (rawBrands is String
                ? [
                    for (final b in rawBrands.split(','))
                      if (b.trim().isNotEmpty) b.trim(),
                  ]
                : <String>[]);

      final rawCountries = hit['countries_tags'];
      final countries = rawCountries is List
          ? [for (final c in rawCountries) c.toString()]
          : <String>[];

      // The size: the quantity if it has a unit, else the product quantity,
      // else a size written in the name ("Mountain Dew 750 ml"). The quantity
      // is often junk in this database ("3"), so a bare number is ignored.
      final quantity = _string(hit['quantity']);
      var size = quantity == null ? null : parseSize(quantity);
      var sizeText = size == null ? null : quantity;
      if (size == null) {
        final pq = hit['product_quantity'];
        final unit = _string(hit['product_quantity_unit']);
        if (pq != null && unit != null) {
          final text = '$pq $unit';
          size = parseSize(text);
          if (size != null) sizeText = text;
        }
      }
      if (size == null) {
        size = parseSize(name);
        if (size != null) {
          sizeText = '${size.value} ${size.unit}';
        }
      }

      final nutriments = hit['nutriments'];
      final product = <String, dynamic>{
        'product_name': name,
        'brands': brands.join(', '),
        'quantity': ?sizeText,
        'serving_size': ?_string(hit['serving_size']),
        'nutrition_data_per': ?_string(hit['nutrition_data_per']),
        'nutriments': nutriments is Map
            ? Map<String, dynamic>.from(nutriments)
            : <String, dynamic>{},
        'categories_tags': hit['categories_tags'] is List
            ? hit['categories_tags']
            : const [],
        'image_front_url': ?_string(hit['image_front_url']),
        'ingredients_text': ?_string(hit['ingredients_text']),
      };

      final parsed = _parser.parseOpenFoodFactsProduct({
        'status': 1,
        'product': product,
      }, code.trim());
      if (parsed == null) return null;

      final url = 'https://world.openfoodfacts.org/product/${code.trim()}';
      return OffProduct._(
        code: code.trim(),
        food: parsed.copyWith(
          nutritionSource: NutritionSource.openFoodFacts,
          sourceUrl: url,
        ),
        brands: brands,
        countries: countries,
        sizeValue: size?.value,
        sizeUnit: size?.unit,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _string(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;

  /// The first weight or volume in [text], in g or ml (see
  /// [OpenFoodFactsService.parseSize]).
  static ({double value, String unit})? parseSize(String text) =>
      OpenFoodFactsService.parseSize(text);

  /// [text] without any size written in it.
  static String withoutSize(String text) =>
      OpenFoodFactsService.withoutSize(text);
}

/// Searches Open Food Facts by text through its Search-a-licious API, which
/// needs no key. Searching is only done for an explicit user action (a photo
/// was taken), never as the user types, and at most one request per
/// [minInterval]: Open Food Facts allows 10 searches a minute per IP address.
class OffSearchClient {
  OffSearchClient({
    http.Client? httpClient,
    Duration? timeout,
    Duration? minInterval,
    Future<void> Function(Duration)? wait,
    DateTime Function()? now,
  }) : _http = httpClient ?? http.Client(),
       _timeout = timeout ?? defaultTimeout,
       _minInterval = minInterval ?? defaultMinInterval,
       _wait = wait ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  static const String baseUrl = 'https://search.openfoodfacts.org/search';

  /// Longest a search waits for the database.
  static const Duration defaultTimeout = Duration(seconds: 10);

  /// Shortest time between two searches (OFF allows 10 a minute).
  static const Duration defaultMinInterval = Duration(seconds: 6);

  /// How many results are asked for.
  static const int pageSize = 20;

  /// The fields the parser reads.
  static const String fields =
      'code,product_name,generic_name,brands,quantity,product_quantity,'
      'product_quantity_unit,serving_size,nutrition_data_per,nutriments,'
      'countries_tags,categories_tags,image_front_url,ingredients_text';

  final http.Client _http;
  final Duration _timeout;
  final Duration _minInterval;
  final Future<void> Function(Duration) _wait;
  final DateTime Function() _now;
  DateTime? _lastRequestAt;

  /// Search text with the characters of the search syntax removed, so a
  /// product name cannot change what is asked.
  static String sanitize(String query) => query
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s.&\x27]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Products matching [query]. With [indiaOnly], only products listed for
  /// India. Throws [ProductLookupException] when the search cannot be done.
  Future<List<OffProduct>> search(
    String query, {
    bool indiaOnly = false,
  }) async {
    final text = sanitize(query);
    if (text.isEmpty) return const [];

    final last = _lastRequestAt;
    if (last != null) {
      final remaining = _minInterval - _now().difference(last);
      if (remaining > Duration.zero) await _wait(remaining);
    }
    _lastRequestAt = _now();

    final url = Uri.parse(baseUrl).replace(
      queryParameters: {
        'q': indiaOnly ? 'countries_tags:"en:india" $text' : text,
        'page_size': '$pageSize',
        'langs': 'en',
        'fields': fields,
      },
    );

    final http.Response response;
    try {
      response = await _http
          .get(
            url,
            headers: {
              'User-Agent': OpenFoodFactsService.userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const ProductLookupException(
        LookupFailureKind.timeout,
        'The product database took too long to answer.',
      );
    } on SocketException {
      throw const ProductLookupException(
        LookupFailureKind.offline,
        'No internet connection to check the product database.',
      );
    } on http.ClientException {
      throw const ProductLookupException(
        LookupFailureKind.offline,
        'No internet connection to check the product database.',
      );
    }

    if (response.statusCode == 429 || response.statusCode == 503) {
      throw const ProductLookupException(
        LookupFailureKind.rateLimited,
        'The product database is busy. Try again in a minute.',
      );
    }
    if (response.statusCode != 200) {
      throw ProductLookupException(
        LookupFailureKind.unavailable,
        'The product database is unavailable (error ${response.statusCode}).',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const ProductLookupException(
        LookupFailureKind.badResponse,
        'The product database sent an answer that could not be read.',
      );
    }
    final hits = decoded is Map ? decoded['hits'] : null;
    if (hits is! List) {
      throw const ProductLookupException(
        LookupFailureKind.badResponse,
        'The product database sent an answer that could not be read.',
      );
    }
    return [
      for (final hit in hits)
        if (hit is Map)
          ?OffProduct.fromSearchHit(Map<String, dynamic>.from(hit)),
    ];
  }
}

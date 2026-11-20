import '../../models/food_item.dart';
import 'gtin.dart';
import 'off_search_client.dart';
import 'openfoodfacts_service.dart';
import 'product_matcher.dart';

/// How a product lookup ended.
enum LookupStatus {
  /// One record is the same product (see [ProductMatcher]).
  exact,

  /// Several records may be it: the user chooses.
  choose,

  /// Nothing reliable was found.
  none,

  /// The lookup could not be done (offline, timeout, busy...).
  failed,
}

/// The outcome of looking a photographed product up in Open Food Facts.
class ProductLookupResult {
  /// One record is the product. [candidates] are other records of the same
  /// product (other sizes) the user may prefer, for example when the exact
  /// record has no nutrition facts.
  const ProductLookupResult.exact(
    OffProduct product, {
    this.candidates = const [],
    this.viaBarcode = false,
  }) : status = LookupStatus.exact,
       exact = product,
       failure = null,
       message = null,
       widened = false;

  /// Several plausible records. [widened] is true when they come from a search
  /// beyond India, which can never give an exact match.
  const ProductLookupResult.choose(this.candidates, {this.widened = false})
    : status = LookupStatus.choose,
      exact = null,
      failure = null,
      message = null,
      viaBarcode = false;

  const ProductLookupResult.none({this.widened = false})
    : status = LookupStatus.none,
      exact = null,
      candidates = const [],
      failure = null,
      message = null,
      viaBarcode = false;

  const ProductLookupResult.failed(LookupFailureKind kind, this.message)
    : status = LookupStatus.failed,
      exact = null,
      candidates = const [],
      failure = kind,
      widened = false,
      viaBarcode = false;

  final LookupStatus status;
  final OffProduct? exact;
  final List<OffProduct> candidates;
  final LookupFailureKind? failure;

  /// Why the lookup failed, safe to show to the user.
  final String? message;

  /// True when the search went beyond India.
  final bool widened;

  /// True when the product was found by a barcode number read from the photo
  /// rather than by a text search.
  final bool viaBarcode;
}

/// Finds the database record for a packaged product seen in a photo.
///
/// Order: records listed for India first; if none fit, all regions, but those
/// can only be offered for choosing, never accepted as exact (a recipe can
/// differ between countries). Nothing is cached as verified here.
class ProductLookupService {
  ProductLookupService({
    OffSearchClient? client,
    Future<FoodItem?> Function(String barcode)? barcodeLookup,
    DateTime Function()? now,
  }) : _client = client ?? OffSearchClient(),
       _barcodeLookup =
           barcodeLookup ??
           ((code) => OpenFoodFactsService.instance.getProductByBarcode(code)),
       _now = now ?? DateTime.now;

  final OffSearchClient _client;
  final Future<FoodItem?> Function(String barcode) _barcodeLookup;
  final DateTime Function() _now;

  /// How long an answer is reused for the same product. A match is kept for
  /// hours, a list to choose from for minutes, and "nothing found" for a
  /// short while, so a retake does not search again but a corrected record is
  /// soon seen. A failed lookup is never kept.
  static const Duration exactTtl = Duration(hours: 6);
  static const Duration chooseTtl = Duration(minutes: 10);
  static const Duration noneTtl = Duration(minutes: 5);

  final Map<String, ({DateTime at, ProductLookupResult result})> _cache = {};

  static String _key(ProductCandidate c) => [
    c.barcode,
    c.brand,
    c.name,
    c.variant,
    c.sizeValue == null ? null : '${c.sizeValue}${c.sizeUnit}',
  ].map((v) => (v ?? '').toString().trim().toLowerCase()).join('|');

  Duration? _ttl(ProductLookupResult r) => switch (r.status) {
    LookupStatus.exact => exactTtl,
    LookupStatus.choose => chooseTtl,
    LookupStatus.none => noneTtl,
    LookupStatus.failed => null,
  };

  static ProductLookupService? _instance;

  static ProductLookupService get instance =>
      _instance ??= ProductLookupService();

  /// Replaces the shared instance (tests).
  static void setInstance(ProductLookupService service) {
    _instance = service;
  }

  static void resetInstance() {
    _instance = null;
  }

  Future<ProductLookupResult> lookup(ProductCandidate candidate) async {
    final key = _key(candidate);
    final hit = _cache[key];
    if (hit != null) {
      final ttl = _ttl(hit.result);
      if (ttl != null && _now().difference(hit.at) < ttl) return hit.result;
      _cache.remove(key);
    }
    final result = await _lookupUncached(candidate);
    if (_ttl(result) != null) _cache[key] = (at: _now(), result: result);
    return result;
  }

  Future<ProductLookupResult> _lookupUncached(
    ProductCandidate candidate,
  ) async {
    final query = [candidate.brand, candidate.name, candidate.variant]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' ');
    if (candidate.name.trim().isEmpty || query.isEmpty) {
      return const ProductLookupResult.none();
    }

    // A barcode number that passed its check digit is the surest way in.
    final code = candidate.barcode;
    if (code != null && Gtin.isValid(code)) {
      try {
        final food = await _barcodeLookup(code);
        if (food != null) {
          final product = OffProduct.fromFood(food);
          // The number can be misread yet still pass the check: it is only
          // accepted as the product when the record looks like the photo.
          return ProductMatcher.looksLike(candidate, product)
              ? ProductLookupResult.exact(product, viaBarcode: true)
              : ProductLookupResult.choose([product]);
        }
      } catch (_) {
        // Offline, slow or not in the database: use the text search below.
      }
    }

    try {
      final inIndia = ProductMatcher.match(
        candidate,
        await _client.search(query, indiaOnly: true),
      );
      final exact = inIndia.exact;
      if (exact != null) {
        return ProductLookupResult.exact(exact, candidates: inIndia.possible);
      }
      if (inIndia.possible.isNotEmpty) {
        return ProductLookupResult.choose(inIndia.possible);
      }

      final everywhere = ProductMatcher.match(
        candidate,
        await _client.search(query),
      );
      final candidates = [?everywhere.exact, ...everywhere.possible];
      return candidates.isEmpty
          ? const ProductLookupResult.none(widened: true)
          : ProductLookupResult.choose(candidates, widened: true);
    } on ProductLookupException catch (e) {
      return ProductLookupResult.failed(e.kind, e.message);
    }
  }
}

import 'off_search_client.dart';

/// What a photo says about a packaged product, to look up in a database.
///
/// [sizeValue] is a pack size the model read as text on the label (in g or
/// ml). It is used only to tell sizes of the same product apart, never as a
/// verified fact.
class ProductCandidate {
  const ProductCandidate({
    required this.name,
    this.brand,
    this.variant,
    this.sizeValue,
    this.sizeUnit,
    this.barcode,
  });

  /// A barcode number read from the photo (only one that passed the check
  /// digit), to be looked up first.
  final String? barcode;

  final String name;
  final String? brand;
  final String? variant;
  final double? sizeValue;
  final String? sizeUnit;
}

/// The result of comparing a [ProductCandidate] with search results.
class MatchOutcome {
  const MatchOutcome({this.exact, this.possible = const []});

  /// The one record that is the same product: same brand, same name and
  /// flavour, a pack size that agrees, and listed for India. Whether it has
  /// nutrition facts does not matter for being the same product.
  final OffProduct? exact;

  /// Records that may be the product, best first, for the user to choose
  /// from. Never includes [exact].
  final List<OffProduct> possible;
}

/// Decides how well Open Food Facts records fit a photographed product.
///
/// It is deliberately strict about "exact": a similar product (another
/// brand, another flavour, another size, or one listed only for another
/// country, where the recipe may differ) is only ever "possible", and the
/// user chooses.
class ProductMatcher {
  ProductMatcher._();

  /// The most records offered for choosing.
  static const int maxPossible = 8;

  static Set<String> _tokens(String text) =>
      _normalize(text).split(' ').where((t) => t.isNotEmpty).toSet();

  static String _normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  /// Whether a record is plausibly the product in the photo: they share at
  /// least one word of the name or brand. Used for a record found by a barcode
  /// number the AI read, which can be wrong while still passing the check.
  static bool looksLike(ProductCandidate candidate, OffProduct product) {
    final wanted = _tokens(
      '${candidate.brand ?? ''} ${OffProduct.withoutSize(candidate.name)} '
      '${candidate.variant ?? ''}',
    );
    final have = _tokens(
      '${product.brands.join(' ')} ${OffProduct.withoutSize(product.food.name)}',
    );
    return wanted.intersection(have).isNotEmpty;
  }

  static MatchOutcome match(
    ProductCandidate candidate,
    List<OffProduct> products,
  ) {
    final brand = _normalize(candidate.brand ?? '');
    final brandTokens = _tokens(brand);

    Set<String> core(String name) =>
        _tokens(OffProduct.withoutSize(name)).difference(brandTokens);

    final wanted = core('${candidate.name} ${candidate.variant ?? ''}');
    if (wanted.isEmpty) return const MatchOutcome();

    bool brandEqual(OffProduct p) =>
        brand.isNotEmpty && p.brands.any((b) => _normalize(b) == brand);

    bool sizeAgrees(OffProduct p) {
      final size = candidate.sizeValue;
      if (size == null) return true;
      final have = p.sizeValue;
      if (have == null || p.sizeUnit != candidate.sizeUnit) return false;
      return (have - size).abs() <= size * 0.01;
    }

    double overlap(Set<String> a, Set<String> b) {
      if (a.isEmpty || b.isEmpty) return 0;
      return a.intersection(b).length / a.union(b).length;
    }

    bool nameEqual(OffProduct p) {
      final c = core(p.food.name);
      return c.length == wanted.length && c.containsAll(wanted);
    }

    final exactSet = [
      for (final p in products)
        if (brandEqual(p) && nameEqual(p) && p.inIndia && sizeAgrees(p)) p,
    ];
    final exact = exactSet.length == 1 ? exactSet.single : null;

    final possible = [
      for (final p in products)
        if (!identical(p, exact) &&
            (nameEqual(p) ||
                (brandEqual(p) && overlap(wanted, core(p.food.name)) >= 0.5)))
          p,
    ];

    int rank(OffProduct p) =>
        (p.inIndia ? 8 : 0) +
        (brandEqual(p) ? 4 : 0) +
        (p.hasNutrition ? 2 : 0) +
        (sizeAgrees(p) ? 1 : 0);
    possible.sort((a, b) {
      final byRank = rank(b).compareTo(rank(a));
      return byRank != 0 ? byRank : a.code.compareTo(b.code);
    });

    return MatchOutcome(
      exact: exact,
      possible: possible.take(maxPossible).toList(),
    );
  }
}

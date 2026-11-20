/// Barcode numbers (GTIN: EAN-13, EAN-8, UPC-A) and their check digit.
///
/// A number read from a photo by an AI is easy to get wrong by a digit. The
/// last digit of a real barcode is a check on the others, so a misread number
/// almost always fails it and is thrown away instead of looked up.
class Gtin {
  Gtin._();

  /// True for an 8, 12 or 13 digit number whose check digit is right.
  static bool isValid(String code) {
    if (!RegExp(r'^\d+$').hasMatch(code)) return false;
    if (code.length != 8 && code.length != 12 && code.length != 13) {
      return false;
    }
    final digits = [for (final c in code.split('')) int.parse(c)];
    // From the right, the digit before the check digit counts 3, then 1, 3...
    var sum = 0;
    var weight = 3;
    for (var i = digits.length - 2; i >= 0; i--) {
      sum += digits[i] * weight;
      weight = weight == 3 ? 1 : 3;
    }
    return (10 - sum % 10) % 10 == digits.last;
  }

  /// [raw] with spaces and hyphens removed, if it is a valid barcode number;
  /// otherwise null (including anything that is not text).
  static String? clean(Object? raw) {
    if (raw is! String) return null;
    final digits = raw.replaceAll(RegExp(r'[\s-]'), '');
    return isValid(digits) ? digits : null;
  }
}

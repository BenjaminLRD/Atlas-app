/// What is known about one nutrient value of a food.
///
/// A number alone cannot say whether it was measured: a 0 can be a real zero
/// or "nobody knows". This status is what every screen and total uses.
enum NutrientStatus {
  /// No reliable value: the source left it out, or it could not be read.
  /// The stored number (if any) is only a placeholder and must not be shown.
  unknown,

  /// A source states that the amount is zero.
  knownZero,

  /// A source (the database, a label, the user) gives a usable number.
  known,

  /// An AI estimate that has not been checked against a source.
  estimate,
}

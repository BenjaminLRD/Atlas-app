/// What a machine scan concluded about a photo.
enum MachineScanStatus {
  /// Gym equipment, identified with reasonable confidence. Still has to be
  /// confirmed by the user before anything is shown as guidance.
  identified,

  /// Gym equipment, but the AI is not sure. Shown with a clear warning.
  uncertain,

  /// The photo does not show gym equipment.
  notEquipment,

  /// The photo may show equipment, but it could not be identified.
  unidentified,
}

/// Structured result of identifying a gym machine from a photo (or from a
/// machine name the user chose). Nothing here is a fact: it is the AI's best
/// guess, and the screen asks the user to confirm it.
class MachineScanResult {
  /// Below this the result is [MachineScanStatus.uncertain] and flagged.
  static const double lowConfidenceThreshold = 0.6;

  /// Below this the machine is treated as not identified at all.
  static const double unidentifiedThreshold = 0.35;

  final MachineScanStatus status;

  /// The likely machine name as the AI named it (null when not identified).
  final String? machineName;

  /// Id of the matching item in Atlas's equipment catalog. Only set when the
  /// id (or the exact name) really exists in the catalog; never invented.
  final String? catalogId;

  /// Name of the catalog item for [catalogId].
  final String? catalogName;

  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> setupSteps;
  final List<String> usageSteps;
  final List<String> safetyCues;
  final List<String> commonMistakes;

  /// The AI's own confidence, 0 to 1.
  final double confidence;

  /// What the AI is unsure about, in its words.
  final String? uncertaintyNote;

  /// A short reason for [MachineScanStatus.notEquipment] or
  /// [MachineScanStatus.unidentified], to show to the user.
  final String? message;

  const MachineScanResult({
    required this.status,
    this.machineName,
    this.catalogId,
    this.catalogName,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.setupSteps = const [],
    this.usageSteps = const [],
    this.safetyCues = const [],
    this.commonMistakes = const [],
    this.confidence = 0.0,
    this.uncertaintyNote,
    this.message,
  });

  /// True for results that carry a machine and guidance to show.
  bool get hasDetails =>
      status == MachineScanStatus.identified ||
      status == MachineScanStatus.uncertain;

  bool get isLowConfidence => confidence < lowConfidenceThreshold;

  bool get hasCatalogMatch => catalogId != null;

  int get confidencePercent => (confidence * 100).round().clamp(0, 100);
}

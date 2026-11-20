import '../knowledge/knowledge_document.dart';
import 'research_agent_service.dart';

/// Result of scientific knowledge evaluation.
class ValidationResult {
  final bool isValid;
  final double confidenceScore; // 0.0 to 1.0
  final String evidenceGrade; // 'Grade A', 'Grade B', etc.
  final bool safetyPassed;
  final List<String> rejectionReasons;
  final KnowledgeDocument? validatedDocument;

  const ValidationResult({
    required this.isValid,
    required this.confidenceScore,
    required this.evidenceGrade,
    required this.safetyPassed,
    this.rejectionReasons = const [],
    this.validatedDocument,
  });

  Map<String, dynamic> toJson() => {
    'is_valid': isValid,
    'confidence_score': confidenceScore,
    'evidence_grade': evidenceGrade,
    'safety_passed': safetyPassed,
    'rejection_reasons': rejectionReasons,
    if (validatedDocument != null) 'validated_document_id': validatedDocument!.id,
  };
}

/// Gatekeeper service validating sports science evidence, methodology rigor,
/// and safety compliance before allowing research into the Atlas knowledge base.
class KnowledgeValidationService {
  static KnowledgeValidationService? _instance;
  static KnowledgeValidationService get instance =>
      _instance ??= KnowledgeValidationService();

  static void resetInstance() {
    _instance = null;
  }

  /// Minimum confidence threshold for automatic knowledge base ingestion.
  static const double minimumConfidenceThreshold = 0.75;

  /// Validates a candidate ResearchItem against scientific and clinical safety criteria.
  ValidationResult validateResearch(ResearchItem item) {
    final reasons = <String>[];
    double confidence = 0.5;
    String grade = 'Grade C';

    // 1. Evidence Level Rigor Scoring
    switch (item.evidenceLevel) {
      case ResearchEvidenceLevel.metaAnalysis:
        confidence = 0.95;
        grade = 'Grade A+';
        break;
      case ResearchEvidenceLevel.randomizedControlledTrial:
        confidence = 0.88;
        grade = 'Grade A';
        break;
      case ResearchEvidenceLevel.cohortStudy:
        confidence = 0.78;
        grade = 'Grade B';
        break;
      case ResearchEvidenceLevel.caseSeries:
        confidence = 0.65;
        grade = 'Grade C';
        break;
      case ResearchEvidenceLevel.expertConsensus:
        confidence = 0.70;
        grade = 'Grade B-';
        break;
    }

    // 2. Sample Size Impact
    if (item.sampleSize >= 100) {
      confidence = (confidence + 0.05).clamp(0.0, 1.0);
    } else if (item.sampleSize > 0 && item.sampleSize < 20) {
      confidence = (confidence - 0.10).clamp(0.0, 1.0);
      reasons.add('Small sample size (N=${item.sampleSize.toInt()}) limits generalizability.');
    }

    // 3. Recency Evaluation (Prefer literature within last 15 years)
    final currentYear = DateTime.now().year;
    if (item.publicationYear < currentYear - 15) {
      confidence = (confidence - 0.05).clamp(0.0, 1.0);
    }

    // 4. Safety Guardrail & Clinical Integrity Filter
    bool safetyPassed = true;
    final textToCheck = '${item.title} ${item.abstractSummary} ${item.practicalTakeaway}'.toLowerCase();

    // Harmful advice patterns
    final unsafePhrases = [
      'ignore pain',
      'push through sharp pain',
      'starve',
      'under 800 calories',
      'anabolic steroid',
      'sarms',
      'cure cancer',
      'replace medication',
      'diagnose pathology',
      'extreme dehydration',
    ];

    for (final phrase in unsafePhrases) {
      if (textToCheck.contains(phrase)) {
        safetyPassed = false;
        reasons.add('Violates safety policy: Contains unverified or harmful claim ("$phrase").');
      }
    }

    final isValid = safetyPassed && confidence >= minimumConfidenceThreshold;

    KnowledgeDocument? doc;
    if (isValid) {
      doc = KnowledgeDocument(
        id: 'kb_${item.id}',
        title: item.title,
        category: item.category.toKnowledgeCategory(),
        content: '${item.practicalTakeaway} Evidence: ${item.abstractSummary}',
        source: '${item.authors} (${item.publicationYear}). ${item.journal}.',
        tags: item.tags,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {
          'research_id': item.id,
          'evidence_grade': grade,
          'confidence_score': confidence,
          'sample_size': item.sampleSize,
          'effect_size': item.effectSize,
        },
      );
    }

    return ValidationResult(
      isValid: isValid,
      confidenceScore: confidence,
      evidenceGrade: grade,
      safetyPassed: safetyPassed,
      rejectionReasons: reasons,
      validatedDocument: doc,
    );
  }
}

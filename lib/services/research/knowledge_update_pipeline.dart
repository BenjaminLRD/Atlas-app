import '../knowledge/knowledge_base_service.dart';
import 'knowledge_validation_service.dart';
import 'research_agent_service.dart';

/// Summary report of an autonomous research ingestion cycle.
class PipelineRunReport {
  final int totalProcessed;
  final int validatedAndAdded;
  final int rejected;
  final List<String> rejectionSummaries;
  final DateTime executedAt;

  const PipelineRunReport({
    required this.totalProcessed,
    required this.validatedAndAdded,
    required this.rejected,
    required this.rejectionSummaries,
    required this.executedAt,
  });

  Map<String, dynamic> toJson() => {
    'total_processed': totalProcessed,
    'validated_and_added': validatedAndAdded,
    'rejected': rejected,
    'rejection_summaries': rejectionSummaries,
    'executed_at': executedAt.toIso8601String(),
  };
}

/// Automated Continuous Knowledge Update Pipeline.
/// Executes the complete flow: Research Discovery -> Scientific Validation ->
/// Embedding Generation -> Knowledge Base Enhancement.
class KnowledgeUpdatePipeline {
  static KnowledgeUpdatePipeline? _instance;
  static KnowledgeUpdatePipeline get instance =>
      _instance ??= KnowledgeUpdatePipeline();

  static void resetInstance() {
    _instance = null;
  }

  final ResearchAgentService _researchAgent;
  final KnowledgeValidationService _validationService;
  final KnowledgeBaseService _knowledgeBase;

  KnowledgeUpdatePipeline({
    ResearchAgentService? researchAgent,
    KnowledgeValidationService? validationService,
    KnowledgeBaseService? knowledgeBase,
  })  : _researchAgent = researchAgent ?? ResearchAgentService.instance,
        _validationService = validationService ?? KnowledgeValidationService.instance,
        _knowledgeBase = knowledgeBase ?? KnowledgeBaseService.instance;

  /// Processes a single research item through the pipeline.
  ValidationResult processResearchItem(ResearchItem item) {
    final result = _validationService.validateResearch(item);
    if (result.isValid && result.validatedDocument != null) {
      _knowledgeBase.storeDocument(result.validatedDocument!);
    }
    return result;
  }

  /// Runs continuous batch processing across all pending research items.
  PipelineRunReport runIngestionCycle({List<ResearchItem>? itemsOverride}) {
    final items = itemsOverride ?? _researchAgent.collectedResearch;
    int validatedCount = 0;
    int rejectedCount = 0;
    final rejectionDetails = <String>[];

    for (final item in items) {
      final validation = _validationService.validateResearch(item);
      if (validation.isValid && validation.validatedDocument != null) {
        _knowledgeBase.storeDocument(validation.validatedDocument!);
        validatedCount++;
      } else {
        rejectedCount++;
        rejectionDetails.add('${item.title}: ${validation.rejectionReasons.join(", ")}');
      }
    }

    return PipelineRunReport(
      totalProcessed: items.length,
      validatedAndAdded: validatedCount,
      rejected: rejectedCount,
      rejectionSummaries: rejectionDetails,
      executedAt: DateTime.now(),
    );
  }
}

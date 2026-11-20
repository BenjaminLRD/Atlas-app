import '../../models/fitness_context.dart';
import '../ai/memory/fitness_memory.dart';
import '../ai/memory/memory_item.dart';
import '../athlete/athlete_state_aggregator.dart';
import 'knowledge_base_service.dart';
import 'knowledge_document.dart';
import 'vector_search_service.dart';

/// Synthesized Retrieval-Augmented Generation context container.
class RAGContext {
  final String query;
  final List<KnowledgeDocument> retrievedDocuments;
  final List<VectorSearchResult> searchResults;
  final List<MemoryItem> retrievedMemories;
  final AthleteStateSnapshot? stateSnapshot;
  final FitnessContext? fitnessContext;

  const RAGContext({
    required this.query,
    required this.retrievedDocuments,
    required this.searchResults,
    required this.retrievedMemories,
    this.stateSnapshot,
    this.fitnessContext,
  });

  bool get hasScientificEvidence => retrievedDocuments.isNotEmpty;
  bool get hasAthleteMemory => retrievedMemories.isNotEmpty;

  /// Formats retrieved scientific documents into an evidence citation block.
  String formatKnowledgeBlock() {
    if (retrievedDocuments.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('[EVIDENCE-BASED FITNESS KNOWLEDGE]');
    for (final result in searchResults) {
      final doc = result.document;
      final matchPct = (result.similarity * 100).round();
      buffer.writeln('• [${doc.category.name.toUpperCase()} | Match: $matchPct% | Source: ${doc.source}]');
      buffer.writeln('  Title: ${doc.title}');
      buffer.writeln('  Evidence: ${doc.content}');
    }
    return buffer.toString();
  }

  /// Formats athlete memories and real-time state into context block.
  String formatAthleteContextBlock() {
    final buffer = StringBuffer();

    if (stateSnapshot != null) {
      buffer.writeln(stateSnapshot!.toPromptContext());
    }

    if (retrievedMemories.isNotEmpty) {
      buffer.writeln('\n[ATHLETE PERSONAL MEMORY]');
      for (final mem in retrievedMemories) {
        buffer.writeln('• [${mem.category.name} | Conf: ${(mem.confidenceScore * 100).round()}%] ${mem.title}: ${mem.content}');
      }
    }

    return buffer.toString();
  }

  /// Formats the complete RAG prompt augmentation block.
  String toPromptAugmentation() {
    final buffer = StringBuffer();
    final kb = formatKnowledgeBlock();
    final athlete = formatAthleteContextBlock();

    if (kb.isNotEmpty) {
      buffer.writeln(kb);
    }
    if (athlete.isNotEmpty) {
      if (kb.isNotEmpty) buffer.writeln();
      buffer.writeln(athlete);
    }

    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'query': query,
    'retrieved_documents': retrievedDocuments.map((d) => d.id).toList(),
    'search_results': searchResults.map((r) => r.toJson()).toList(),
    'retrieved_memories': retrievedMemories.map((m) => m.id).toList(),
    'has_scientific_evidence': hasScientificEvidence,
  };
}

/// Retrieval-Augmented Generation (RAG) Orchestrator for Atlas AI.
/// Connects private vector knowledge search, long-term athlete memory,
/// and live physiological telemetry into prompt augmentations.
class RAGService {
  static RAGService? _instance;
  static RAGService get instance => _instance ??= RAGService();

  static void resetInstance() {
    _instance = null;
  }

  final KnowledgeBaseService _knowledgeBase;
  final FitnessMemory _memory;

  RAGService({
    KnowledgeBaseService? knowledgeBase,
    FitnessMemory? memory,
  })  : _knowledgeBase = knowledgeBase ?? KnowledgeBaseService.instance,
        _memory = memory ?? FitnessMemory.instance;

  /// Executes end-to-end RAG pipeline for a given user query.
  RAGContext retrieveContext({
    required String query,
    FitnessContext? context,
    AthleteStateSnapshot? stateSnapshot,
    KnowledgeCategory? categoryFilter,
    int topK = 3,
    double minSimilarity = 0.15,
  }) {
    // 1. Vector similarity search across private knowledge base
    final searchResults = _knowledgeBase.searchKnowledge(
      query: query,
      category: categoryFilter,
      limit: topK,
      minSimilarity: minSimilarity,
    );

    final retrievedDocs = searchResults.map((r) => r.document).toList();

    // 2. Multi-factor memory retrieval from long-term memory
    final retrievedMemories = _memory.rankMemoriesForContext(
      query,
      limit: 3,
    );

    return RAGContext(
      query: query,
      retrievedDocuments: retrievedDocs,
      searchResults: searchResults,
      retrievedMemories: retrievedMemories,
      stateSnapshot: stateSnapshot,
      fitnessContext: context,
    );
  }

  /// Synthesizes an evidence-grounded system prompt incorporating RAG context.
  String buildRAGEnrichedPrompt({
    required String basePrompt,
    required RAGContext ragContext,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(basePrompt);
    buffer.writeln('\n--- RETRIEVAL-AUGMENTED CONTEXT (RAG) ---');

    final augmentation = ragContext.toPromptAugmentation();
    if (augmentation.isNotEmpty) {
      buffer.writeln(augmentation);
    } else {
      buffer.writeln('No specific domain literature match found. Rely on foundational exercise physiology.');
    }

    buffer.writeln('\n[COACHING INSTRUCTION]');
    buffer.writeln('1. Synthesize the scientific evidence above with the athlete\'s personal data.');
    buffer.writeln('2. Do NOT recite generic fitness tips; cite specific mechanisms, numbers (sets, reps, grams, minutes), and personal historical responses.');
    buffer.writeln('3. Maintain a warm, encouraging, yet scientifically authoritative coaching persona.');

    return buffer.toString();
  }
}

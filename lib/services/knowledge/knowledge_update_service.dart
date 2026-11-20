import 'knowledge_base_service.dart';
import 'knowledge_document.dart';
import 'vector_search_service.dart';

/// Audit record for knowledge base update events.
class KnowledgeUpdateLog {
  final String id;
  final String documentId;
  final String action; // 'create', 'update', 'deprecate', 'reindex'
  final String summary;
  final String author;
  final DateTime timestamp;

  const KnowledgeUpdateLog({
    required this.id,
    required this.documentId,
    required this.action,
    required this.summary,
    this.author = 'system',
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'document_id': documentId,
    'action': action,
    'summary': summary,
    'author': author,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Pipeline service managing ingestion, updates, deprecation, and re-indexing
/// of the Atlas private fitness knowledge corpus.
class KnowledgeUpdateService {
  static KnowledgeUpdateService? _instance;
  static KnowledgeUpdateService get instance =>
      _instance ??= KnowledgeUpdateService();

  static void resetInstance() {
    _instance = null;
  }

  final KnowledgeBaseService _knowledgeBase;
  final VectorSearchService _vectorSearch;
  final List<KnowledgeUpdateLog> _updateHistory = [];

  KnowledgeUpdateService({
    KnowledgeBaseService? knowledgeBase,
    VectorSearchService? vectorSearch,
  })  : _knowledgeBase = knowledgeBase ?? KnowledgeBaseService.instance,
        _vectorSearch = vectorSearch ?? VectorSearchService.instance;

  List<KnowledgeUpdateLog> get updateHistory => List.unmodifiable(_updateHistory);

  /// Ingests a new document into the knowledge base with embedding generation and audit log.
  KnowledgeDocument ingestDocument({
    required String title,
    required KnowledgeCategory category,
    required String content,
    required String source,
    List<String> tags = const [],
    Map<String, dynamic> metadata = const {},
    String author = 'system',
  }) {
    final now = DateTime.now();
    final docId = 'kb_${title.toLowerCase().replaceAll(RegExp(r'[^\w]'), '_')}_${now.millisecondsSinceEpoch}';

    final embedding = _vectorSearch.generateEmbedding(
      '$title $content ${tags.join(' ')}',
    );

    final doc = KnowledgeDocument(
      id: docId,
      title: title,
      category: category,
      content: content,
      source: source,
      embedding: embedding,
      tags: tags,
      createdAt: now,
      updatedAt: now,
      metadata: {
        ...metadata,
        'version': 1,
        'author': author,
      },
    );

    final stored = _knowledgeBase.storeDocument(doc);

    _logAction(
      documentId: stored.id,
      action: 'create',
      summary: 'Ingested "$title" into ${category.name}',
      author: author,
    );

    return stored;
  }

  /// Ingests a batch of documents into the knowledge base.
  List<KnowledgeDocument> ingestBatch(
    List<KnowledgeDocument> documents, {
    String author = 'batch_pipeline',
  }) {
    final ingested = <KnowledgeDocument>[];
    for (final doc in documents) {
      final stored = _knowledgeBase.storeDocument(doc);
      ingested.add(stored);
      _logAction(
        documentId: stored.id,
        action: 'create',
        summary: 'Batch ingested "${doc.title}"',
        author: author,
      );
    }
    return ingested;
  }

  /// Updates an existing document, bumps its version, regenerates embeddings, and logs the change.
  KnowledgeDocument? updateKnowledge({
    required String id,
    String? title,
    String? content,
    String? source,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    String changeReason = 'Routine knowledge update',
    String author = 'curator',
  }) {
    final existing = _knowledgeBase.getDocument(id);
    if (existing == null) return null;

    final newTitle = title ?? existing.title;
    final newContent = content ?? existing.content;
    final newTags = tags ?? existing.tags;
    final currentVersion = (existing.metadata['version'] as num?)?.toInt() ?? 1;

    final newEmbedding = _vectorSearch.generateEmbedding(
      '$newTitle $newContent ${newTags.join(' ')}',
    );

    final updatedDoc = existing.copyWith(
      title: newTitle,
      content: newContent,
      source: source ?? existing.source,
      tags: newTags,
      embedding: newEmbedding,
      updatedAt: DateTime.now(),
      metadata: {
        ...existing.metadata,
        ...?metadata,
        'version': currentVersion + 1,
        'last_change_reason': changeReason,
      },
    );

    final result = _knowledgeBase.updateDocument(updatedDoc);

    _logAction(
      documentId: id,
      action: 'update',
      summary: 'v${currentVersion + 1}: $changeReason',
      author: author,
    );

    return result;
  }

  /// Deprecates and removes outdated knowledge from the active corpus.
  bool deprecateDocument({
    required String id,
    required String reason,
    String author = 'curator',
  }) {
    final existing = _knowledgeBase.getDocument(id);
    if (existing == null) return false;

    final removed = _knowledgeBase.removeDocument(id);
    if (removed) {
      _logAction(
        documentId: id,
        action: 'deprecate',
        summary: 'Removed "${existing.title}". Reason: $reason',
        author: author,
      );
    }
    return removed;
  }

  /// Re-indexes embeddings for all active documents in the knowledge base.
  int reindexAllEmbeddings() {
    final docs = _knowledgeBase.getAllDocuments();
    int count = 0;
    for (final doc in docs) {
      final embedding = _vectorSearch.generateEmbedding(
        '${doc.title} ${doc.content} ${doc.tags.join(' ')}',
      );
      _knowledgeBase.updateDocument(doc.copyWith(embedding: embedding));
      count++;
    }

    _logAction(
      documentId: 'corpus_global',
      action: 'reindex',
      summary: 'Re-indexed $count embeddings across knowledge corpus',
      author: 'system',
    );

    return count;
  }

  void _logAction({
    required String documentId,
    required String action,
    required String summary,
    required String author,
  }) {
    _updateHistory.add(KnowledgeUpdateLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}_${_updateHistory.length}',
      documentId: documentId,
      action: action,
      summary: summary,
      author: author,
      timestamp: DateTime.now(),
    ));
  }
}

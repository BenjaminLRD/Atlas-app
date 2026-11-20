import 'dart:math' as math;
import 'knowledge_document.dart';

/// Result wrapper representing a ranked vector similarity match.
class VectorSearchResult {
  final KnowledgeDocument document;
  final double similarity;
  final int rank;

  const VectorSearchResult({
    required this.document,
    required this.similarity,
    required this.rank,
  });

  Map<String, dynamic> toJson() => {
    'document_id': document.id,
    'title': document.title,
    'category': document.category.code,
    'similarity': similarity,
    'rank': rank,
  };
}

/// On-device high-performance vector mathematics & semantic search engine.
/// Computes cosine similarities over dense float embeddings, prepared for
/// transparent sync with PostgreSQL pgvector / Supabase Vector.
class VectorSearchService {
  static VectorSearchService? _instance;
  static VectorSearchService get instance => _instance ??= VectorSearchService();

  static void resetInstance() {
    _instance = null;
  }

  /// Default embedding dimensionality for Atlas on-device semantic vectors.
  static const int vectorDimensions = 128;

  /// Generates a normalized 64-dimensional dense semantic embedding vector for a given text.
  List<double> generateEmbedding(String text) {
    final cleanText = text.toLowerCase().trim();
    if (cleanText.isEmpty) {
      return List.filled(vectorDimensions, 0.0);
    }

    final rawVector = List<double>.filled(vectorDimensions, 0.0);

    // 1. Domain keyword priority boosting
    final domainKeywordWeights = {
      'hypertrophy': 3.5,
      'overload': 3.2,
      'progressive': 3.0,
      'protein': 3.2,
      'amino': 2.8,
      'leucine': 3.0,
      'recovery': 3.0,
      'sleep': 3.0,
      'fatigue': 2.8,
      'deload': 3.0,
      'rpe': 3.0,
      'rir': 3.0,
      'volume': 2.8,
      'frequency': 2.5,
      'intensity': 2.5,
      'calorie': 2.8,
      'deficit': 2.6,
      'surplus': 2.6,
      'carbohydrate': 2.6,
      'glycogen': 2.8,
      'fat': 2.4,
      'cardio': 2.5,
      'zone2': 3.0,
      'vo2': 3.2,
      'hrv': 3.2,
      'rmssd': 3.5,
      'biomechanics': 3.0,
      'squat': 2.5,
      'bench': 2.5,
      'deadlift': 2.5,
      'injury': 3.5,
      'pain': 3.5,
      'disclaimer': 3.0,
      'hydration': 2.6,
      'creatine': 3.0,
      'electrolyte': 2.8,
      'eccentric': 2.8,
      'concentric': 2.8,
      'isometric': 2.8,
      'periodization': 3.0,
      'tendonitis': 3.2,
      'scapular': 3.0,
    };

    final tokens = cleanText
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1)
        .toList();

    for (final token in tokens) {
      final weight = domainKeywordWeights[token] ?? 1.0;

      // Map token to vector indices via deterministic rolling hash
      int hash1 = 5381;
      int hash2 = 0;
      for (int c = 0; c < token.length; c++) {
        final code = token.codeUnitAt(c);
        hash1 = ((hash1 << 5) + hash1 + code) & 0x7FFFFFFF;
        hash2 = ((hash2 << 7) ^ code) & 0x7FFFFFFF;
      }

      final idx1 = hash1 % vectorDimensions;
      final idx2 = hash2 % vectorDimensions;
      final sign1 = (hash1 & 1 == 0) ? 1.0 : -1.0;
      final sign2 = (hash2 & 1 == 0) ? 1.0 : -1.0;

      rawVector[idx1] += weight * 2.5 * sign1;
      rawVector[idx2] += weight * 1.8 * sign2;

      // Character trigram projection for subword semantic overlap
      if (token.length >= 3) {
        for (int c = 0; c <= token.length - 3; c++) {
          final trigram = token.substring(c, c + 3);
          int triHash = 2166136261;
          for (int tc = 0; tc < trigram.length; tc++) {
            triHash = ((triHash ^ trigram.codeUnitAt(tc)) * 16777619) & 0x7FFFFFFF;
          }
          final triIdx = triHash % vectorDimensions;
          final triSign = (triHash & 1 == 0) ? 1.0 : -1.0;
          rawVector[triIdx] += 0.15 * weight * triSign;
        }
      }
    }

    // 2. Unit Normalization (L2 norm) so dot product equals cosine similarity
    double normSq = 0.0;
    for (final val in rawVector) {
      normSq += val * val;
    }

    if (normSq <= 0.000001) {
      return List.filled(vectorDimensions, 0.0);
    }

    final norm = math.sqrt(normSq);
    return rawVector.map((v) => v / norm).toList();
  }

  /// Calculates the cosine similarity between two float vectors.
  /// Returns a value between -1.0 and 1.0 (clamped to 0.0 .. 1.0 for semantic matching).
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA <= 0.000001 || normB <= 0.000001) return 0.0;

    final similarity = dotProduct / (math.sqrt(normA) * math.sqrt(normB));
    return similarity.clamp(0.0, 1.0);
  }

  /// Executes similarity search over a collection of knowledge documents.
  List<VectorSearchResult> search({
    required String query,
    required List<KnowledgeDocument> documents,
    KnowledgeCategory? category,
    int topK = 3,
    double minSimilarity = 0.15,
  }) {
    if (query.trim().isEmpty || documents.isEmpty) return [];

    final queryEmbedding = generateEmbedding(query);

    final scored = <VectorSearchResult>[];

    for (final doc in documents) {
      if (category != null && doc.category != category) continue;

      final docEmbedding = doc.embedding ??
          generateEmbedding('${doc.title} ${doc.content} ${doc.tags.join(' ')}');

      final sim = cosineSimilarity(queryEmbedding, docEmbedding);

      if (sim >= minSimilarity) {
        scored.add(VectorSearchResult(
          document: doc,
          similarity: sim,
          rank: 0,
        ));
      }
    }

    scored.sort((a, b) => b.similarity.compareTo(a.similarity));

    final results = <VectorSearchResult>[];
    for (int i = 0; i < math.min(topK, scored.length); i++) {
      final item = scored[i];
      results.add(VectorSearchResult(
        document: item.document,
        similarity: item.similarity,
        rank: i + 1,
      ));
    }

    return results;
  }
}

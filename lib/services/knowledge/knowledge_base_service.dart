import 'knowledge_document.dart';
import 'vector_search_service.dart';

/// Centralized private fitness science knowledge base.
/// Holds curated scientific literature, biomechanical rules, and nutritional guidelines.
/// Supports CRUD operations, categorization, and semantic vector retrieval.
class KnowledgeBaseService {
  static KnowledgeBaseService? _instance;
  static KnowledgeBaseService get instance => _instance ??= KnowledgeBaseService();

  static void resetInstance() {
    _instance = null;
  }

  final VectorSearchService _vectorSearch;
  final Map<String, KnowledgeDocument> _documents = {};

  KnowledgeBaseService({VectorSearchService? vectorSearch})
      : _vectorSearch = vectorSearch ?? VectorSearchService.instance {
    _seedDefaultCorpus();
  }

  /// Seeds foundational peer-reviewed exercise physiology and clinical guidelines.
  void _seedDefaultCorpus() {
    final now = DateTime.now();

    final defaultDocs = [
      KnowledgeDocument(
        id: 'kb_hypertrophy_overload',
        title: 'Mechanisms of Hypertrophy & Progressive Overload',
        category: KnowledgeCategory.exerciseScience,
        content:
            'Muscle hypertrophy is primarily driven by mechanical tension. '
            'Progressive overload requires systematically increasing load, volume (hard sets within 0-3 RIR), '
            'or range of motion across mesocycles. The optimal weekly direct volume per muscle group '
            'ranges between 10 to 20 hard sets for intermediate to advanced lifters.',
        source: 'Schoenfeld BJ. The Mechanisms of Muscle Hypertrophy. Sports Med (2010).',
        tags: ['hypertrophy', 'overload', 'volume', 'rir', 'tension'],
        createdAt: now,
        updatedAt: now,
      ),
      KnowledgeDocument(
        id: 'kb_protein_synthesis',
        title: 'Protein Distribution & Muscle Protein Synthesis (MPS)',
        category: KnowledgeCategory.nutrition,
        content:
            'To optimize muscle protein synthesis (MPS), daily protein intake should be 1.6 to 2.2 g/kg total bodyweight '
            '(or 2.0 to 2.4 g/kg in a caloric deficit). Intake should ideally be distributed across 3 to 5 meals '
            'containing at least 2.5 to 3.0g of leucine per meal to trigger the leucine threshold.',
        source: 'ISSN Position Stand: Protein and Exercise. J Int Soc Sports Nutr (2017).',
        tags: ['protein', 'mps', 'leucine', 'nutrition', 'macronutrient'],
        createdAt: now,
        updatedAt: now,
      ),
      KnowledgeDocument(
        id: 'kb_recovery_hrv_sleep',
        title: 'Autonomic Nervous System Recovery, HRV & Sleep Architecture',
        category: KnowledgeCategory.recovery,
        content:
            'Heart Rate Variability (rMSSD) reflects parasympathetic vs sympathetic autonomic tone. '
            'A sustained drop in baseline HRV (>1.5 SD below weekly baseline) indicates systemic under-recovery or excessive '
            'allostatic load. High-quality deep (slow-wave) sleep facilitates growth hormone secretion and tissue remodeling. '
            'Athletes with recovery scores < 50% should reduce training intensity or incorporate active recovery.',
        source: 'Plews DJ, et al. Training Adaptation and Heart Rate Variability in Athletes. Sports Med (2013).',
        tags: ['recovery', 'hrv', 'rmssd', 'sleep', 'fatigue', 'parasympathetic'],
        createdAt: now,
        updatedAt: now,
      ),
      KnowledgeDocument(
        id: 'kb_biomechanics_joint_safety',
        title: 'Spinal Mechanics, Joint Centration & Kinetic Safety',
        category: KnowledgeCategory.safety,
        content:
            'Multi-joint compound movements (squats, deadlifts, overhead presses) require maintaining a neutral spine '
            'with intra-abdominal pressure (Valsalva maneuver). Avoid excessive spinal flexion under compressive load. '
            'Shoulder pressing and bench pressing require active scapular retraction/depression and subacromial joint space preservation.',
        source: 'McGill SM. Ultimate Back Fitness and Performance (2009).',
        tags: ['safety', 'biomechanics', 'spine', 'shoulder', 'scapular', 'injury'],
        createdAt: now,
        updatedAt: now,
      ),
      KnowledgeDocument(
        id: 'kb_periodization_deload',
        title: 'Periodization Models & Deload Fatigue Dissipation',
        category: KnowledgeCategory.training,
        content:
            'Accumulated fatigue masks fitness expression. Every 4 to 8 weeks, a planned deload week (reducing volume by 30-50% '
            'or intensity by 10-20% while maintaining movement patterns) dissipates peripheral and central nervous system fatigue, '
            'resensitizes skeletal muscle to volume, and mitigates overuse injury risk.',
        source: 'Bompa TO, Haff GG. Periodization: Theory and Methodology of Training (2009).',
        tags: ['training', 'periodization', 'deload', 'fatigue', 'mesocycle'],
        createdAt: now,
        updatedAt: now,
      ),
      KnowledgeDocument(
        id: 'kb_energy_balance_macros',
        title: 'Energy Balance, Caloric Deficits & Macro Partitioning',
        category: KnowledgeCategory.nutrition,
        content:
            'Fat loss requires an energy deficit, ideally 300 to 500 kcal/day to preserve lean tissue. '
            'Muscle gain is optimized with a mild surplus of 200 to 400 kcal/day for lean hypertrophy. '
            'Fat intake should remain above 0.6g/kg to support steroidogenesis and endocrine function, '
            'with remaining non-protein calories allocated to carbohydrates for glycogen replenishment.',
        source: 'Hall KD, et al. Energy balance and its components. Am J Clin Nutr (2012).',
        tags: ['nutrition', 'calories', 'deficit', 'surplus', 'carbohydrates', 'fat'],
        createdAt: now,
        updatedAt: now,
      ),
      KnowledgeDocument(
        id: 'kb_clinical_red_flags',
        title: 'Clinical Red Flags, Pain vs Discomfort & Medical Referral',
        category: KnowledgeCategory.safety,
        content:
            'Sharp, localized, radiating pain, sudden joint locking, neural tingling/numbness, or acute swelling are clinical red flags. '
            'AI coaches must never diagnose musculoskeletal pathologies or prescribe medical treatment. '
            'Athletes experiencing sharp joint pain must be advised to discontinue the aggravating movement and consult a licensed physical therapist or physician.',
        source: 'ACSM Guidelines for Exercise Testing and Prescription (11th Ed).',
        tags: ['safety', 'red flags', 'pain', 'medical', 'clinical', 'disclaimer'],
        createdAt: now,
        updatedAt: now,
      ),
      KnowledgeDocument(
        id: 'kb_hydration_electrolytes',
        title: 'Hydration Kinetics, Electrolytes & Muscle Cramp Etiology',
        category: KnowledgeCategory.recovery,
        content:
            'A 2% body mass loss via dehydration significantly impairs power output and cognitive focus during resistance training. '
            'Daily baseline hydration should be 30-40 mL/kg body mass plus 500-1000 mL per hour of intense perspiration. '
            'Sodium (500-1000mg/L sweat), potassium, and magnesium co-transport maintain membrane potential and prevent neuro-muscular cramping.',
        source: 'Sawka MN, et al. American College of Sports Medicine position stand: Exercise and fluid replacement (2007).',
        tags: ['recovery', 'hydration', 'electrolytes', 'cramps', 'water'],
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final doc in defaultDocs) {
      final embedding = _vectorSearch.generateEmbedding(
        '${doc.title} ${doc.content} ${doc.tags.join(' ')}',
      );
      _documents[doc.id] = doc.copyWith(embedding: embedding);
    }
  }

  /// Stores a new knowledge document and generates its dense vector embedding.
  KnowledgeDocument storeDocument(KnowledgeDocument doc) {
    final embedding = doc.embedding ??
        _vectorSearch.generateEmbedding(
          '${doc.title} ${doc.content} ${doc.tags.join(' ')}',
        );

    final stored = doc.copyWith(
      embedding: embedding,
      updatedAt: DateTime.now(),
    );
    _documents[stored.id] = stored;
    return stored;
  }

  /// Updates an existing document in the knowledge base.
  KnowledgeDocument? updateDocument(KnowledgeDocument doc) {
    if (!_documents.containsKey(doc.id)) return null;

    final embedding = doc.embedding ??
        _vectorSearch.generateEmbedding(
          '${doc.title} ${doc.content} ${doc.tags.join(' ')}',
        );

    final updated = doc.copyWith(
      embedding: embedding,
      updatedAt: DateTime.now(),
    );
    _documents[updated.id] = updated;
    return updated;
  }

  /// Removes a document by ID. Returns true if removed.
  bool removeDocument(String id) {
    return _documents.remove(id) != null;
  }

  /// Retrieves a document by ID.
  KnowledgeDocument? getDocument(String id) {
    return _documents[id];
  }

  /// Returns all stored knowledge documents.
  List<KnowledgeDocument> getAllDocuments() {
    return _documents.values.toList();
  }

  /// Returns documents filtered by category.
  List<KnowledgeDocument> getDocumentsByCategory(KnowledgeCategory category) {
    return _documents.values.where((d) => d.category == category).toList();
  }

  /// Semantic vector similarity search over the private knowledge base.
  List<VectorSearchResult> searchKnowledge({
    required String query,
    KnowledgeCategory? category,
    int limit = 3,
    double minSimilarity = 0.15,
  }) {
    return _vectorSearch.search(
      query: query,
      documents: _documents.values.toList(),
      category: category,
      topK: limit,
      minSimilarity: minSimilarity,
    );
  }

  /// Resets the knowledge base back to pre-seeded peer-reviewed standards.
  void resetToDefaults() {
    _documents.clear();
    _seedDefaultCorpus();
  }
}

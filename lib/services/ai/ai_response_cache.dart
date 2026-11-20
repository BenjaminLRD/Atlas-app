import 'dart:collection';

/// Cached entry representing a previously generated AI response.
class CachedAIResponse {
  final String key;
  final String response;
  final DateTime cachedAt;
  final Duration ttl;
  final List<String> tags;
  final bool isImmutableKnowledge;

  CachedAIResponse({
    required this.key,
    required this.response,
    required this.cachedAt,
    this.ttl = const Duration(hours: 12),
    this.tags = const [],
    this.isImmutableKnowledge = false,
  });

  bool get isExpired =>
      !isImmutableKnowledge && DateTime.now().difference(cachedAt) > ttl;
}

/// Smart in-memory and semantic response cache for AI Coach requests.
/// Drastically reduces Gemini API consumption, eliminates unnecessary latency,
/// and serves instant, verified fitness knowledge for recurring athlete questions.
class AIResponseCache {
  static final AIResponseCache _instance = AIResponseCache._internal();
  factory AIResponseCache() => _instance;
  AIResponseCache._internal() {
    _preloadDomainKnowledge();
  }

  static AIResponseCache get instance => _instance;

  final int maxEntries = 50;
  final LinkedHashMap<String, CachedAIResponse> _cache = LinkedHashMap();

  int _hitCount = 0;
  int _missCount = 0;

  int get hitCount => _hitCount;
  int get missCount => _missCount;
  int get size => _cache.length;

  /// Words that indicate private medical or transient personal state that must never be cached across sessions.
  static final Set<String> _uncacheableKeywords = {
    'pain',
    'injury',
    'hurt',
    'doctor',
    'diagnose',
    'medical',
    'prescription',
    'blood pressure',
    'heart rate',
    'my last workout',
    'what did i eat',
    'my weight today',
  };

  /// Generates a normalized cache lookup key.
  static String generateKey(String message, [String? contextSignature]) {
    final normalized = _normalizeText(message);
    if (contextSignature != null && contextSignature.isNotEmpty) {
      return '$normalized::${contextSignature.trim().toLowerCase()}';
    }
    return normalized;
  }

  static String _normalizeText(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Words that make a question about the asker (their age, name, body
  /// measurements, or anything "mine"). The answer depends on who is asking,
  /// so it is never cached or served from the cache.
  static final RegExp _personalPattern = RegExp(
    r"\b(my|mine|myself|age|old|name|bmi|height|tall|weight|weigh|born|birthday|dob|am i|i am|i'm|im)\b",
  );

  /// True when [text] is about the person asking.
  static bool isPersonalQuery(String text) =>
      _personalPattern.hasMatch(text.toLowerCase());

  /// The question part of a key: [generateKey] appends `::context` to it.
  static String _messageOf(String key) => key.split('::').first;

  /// Checks if a query is eligible for general response caching.
  bool isCacheable(String message) {
    final normalized = _messageOf(message).trim().toLowerCase();
    if (isPersonalQuery(normalized)) return false;
    for (final kw in _uncacheableKeywords) {
      if (normalized.contains(kw)) return false;
    }
    return true;
  }

  /// Retrieves cached response text, or null. See [lookup].
  String? get(String key, {double similarityThreshold = 0.75}) =>
      lookup(key, similarityThreshold: similarityThreshold)?.response;

  /// Finds a cached entry for [key], or null.
  ///
  /// - Personal questions (see [isPersonalQuery]) never match anything.
  /// - An exact key match is returned for any entry; callers can tell a
  ///   preloaded answer from a generated one with
  ///   [CachedAIResponse.isImmutableKnowledge].
  /// - Otherwise only the preloaded, immutable knowledge entries can match
  ///   loosely, and only when the question is nearly the same (Jaccard
  ///   overlap of its words at least [similarityThreshold]). Generated
  ///   answers are never returned for a merely similar question.
  CachedAIResponse? lookup(String key, {double similarityThreshold = 0.75}) {
    if (isPersonalQuery(_messageOf(key))) {
      _missCount++;
      return null;
    }

    // 1. Exact key lookup
    final exact = _cache[key];
    if (exact != null) {
      if (!exact.isExpired) {
        // Refresh LRU position
        _cache.remove(key);
        _cache[key] = exact;
        _hitCount++;
        return exact;
      }
      _cache.remove(key);
    }

    // 2. Near-identical wording against verified knowledge only
    final queryTokens = _tokenize(_messageOf(key));
    if (queryTokens.length >= 2) {
      for (final entry in _cache.values) {
        if (!entry.isImmutableKnowledge || entry.isExpired) continue;
        final sim = _similarityScore(queryTokens, _tokenize(entry.key));
        if (sim >= similarityThreshold) {
          _hitCount++;
          return entry;
        }
      }
    }

    _missCount++;
    return null;
  }

  /// Stores response in cache if eligible.
  void put(
    String key,
    String response, {
    Duration ttl = const Duration(hours: 12),
    List<String> tags = const [],
    bool isImmutable = false,
  }) {
    if (key.trim().isEmpty || response.trim().isEmpty) return;
    if (!isImmutable && !isCacheable(key)) return;

    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxEntries) {
      // Evict oldest non-immutable entry or oldest entry
      final evictKey = _cache.keys.firstWhere(
        (k) => !_cache[k]!.isImmutableKnowledge,
        orElse: () => _cache.keys.first,
      );
      _cache.remove(evictKey);
    }

    _cache[key] = CachedAIResponse(
      key: key,
      response: response,
      cachedAt: DateTime.now(),
      ttl: ttl,
      tags: tags,
      isImmutableKnowledge: isImmutable,
    );
  }

  /// Jaccard overlap of two word sets. Containment is deliberately not used:
  /// a long, specific question that merely contains a short entry's words
  /// ("how much protein should I eat if I weigh 90 kg") is a different
  /// question.
  double _similarityScore(Set<String> queryTokens, Set<String> entryTokens) {
    if (queryTokens.isEmpty || entryTokens.isEmpty) return 0.0;
    final intersection = queryTokens.intersection(entryTokens).length;
    if (intersection == 0) return 0.0;
    return intersection / queryTokens.union(entryTokens).length;
  }

  Set<String> _tokenize(String text) {
    final stopWords = {
      'a',
      'an',
      'the',
      'is',
      'are',
      'was',
      'were',
      'to',
      'for',
      'of',
      'in',
      'on',
      'at',
      'by',
      'with',
      'about',
      'how',
      'what',
      'why',
      'can',
      'should',
      'do',
      'i',
      'my',
      'me',
      'you',
      'your',
      'much',
      'many',
      'long',
    };
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !stopWords.contains(t))
        .toSet();
  }

  /// Preloads verified, evergreen fitness & nutrition domain knowledge into immutable cache.
  void _preloadDomainKnowledge() {
    put(
      'benefits of creatine',
      'Creatine Monohydrate is one of the most thoroughly researched supplements in sports science. Key benefits include:\n• **Increased Strength & Power Output**: Increases intramuscular phosphocreatine stores for ATP resynthesis during high-intensity lifts.\n• **Enhanced Muscle Hypertrophy**: Supports cellular hydration and training volume.\n• **Cognitive & Recovery Support**: Aids cellular energy availability during fatigue.\n*Recommended Dosage*: 3–5g daily, taken consistently with water.',
      isImmutable: true,
      tags: const ['supplements', 'creatine'],
    );

    put(
      'how long should i rest between sets',
      'Optimal rest intervals depend on your primary training goal:\n• **Strength & Power (1–5 reps)**: 2.5 to 5 minutes to allow complete ATP and central nervous system replenishment.\n• **Hypertrophy / Muscle Building (6–12 reps)**: 1.5 to 3 minutes for maximum mechanical tension and adequate metabolic recovery.\n• **Muscular Endurance / Circuits (15+ reps)**: 30 to 60 seconds.',
      isImmutable: true,
      tags: const ['training', 'rest_periods'],
    );

    put(
      'how much protein should i eat',
      'Evidence-based daily protein targets for active individuals and lifters:\n• **Muscle Gain / Hypertrophy**: 1.6 to 2.2g per kg of bodyweight (0.7–1.0g per lb).\n• **Fat Loss / Cutting (preserving lean mass)**: 2.0 to 2.4g per kg of bodyweight.\n• **General Health & Maintenance**: 1.2 to 1.6g per kg of bodyweight.\nDistribute intake across 3 to 5 meals with 25–40g high-quality protein per meal.',
      isImmutable: true,
      tags: const ['nutrition', 'protein'],
    );

    put(
      'why is warming up important',
      'A thorough dynamic warm-up accomplishes three critical performance and safety goals:\n1. **Elevates Core & Muscle Temperature**: Improves tissue elasticity and reduces strain risk.\n2. **Enhances Synovial Fluid Circulation**: Lubricates joints (shoulders, knees, hips) for smooth biomechanics under load.\n3. **Potentiates Central Nervous System (CNS)**: Primes motor unit recruitment for heavier lifts.',
      isImmutable: true,
      tags: const ['training', 'warmup'],
    );

    put(
      'how much water should i drink daily',
      'Hydration guidelines for athletes and gym trainees:\n• **Baseline Intake**: Approximately 30–35 ml per kg of bodyweight daily (typically 2.5 to 3.5 Liters for active adults).\n• **Workout Addition**: Drink an additional 500–750 ml per hour of intense resistance or cardio training.\n• **Electrolytes**: Ensure adequate sodium, potassium, and magnesium during heavy sweating.',
      isImmutable: true,
      tags: const ['nutrition', 'hydration'],
    );
  }

  /// Manually triggers preloading verified domain knowledge.
  void preloadDomainKnowledge() {
    _preloadDomainKnowledge();
  }

  /// Clears cache and resets metrics.
  void clear({bool keepImmutable = false}) {
    if (keepImmutable) {
      _cache.removeWhere((_, v) => !v.isImmutableKnowledge);
    } else {
      _cache.clear();
    }
    _hitCount = 0;
    _missCount = 0;
  }
}

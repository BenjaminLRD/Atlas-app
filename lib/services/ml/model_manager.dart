/// Metadata entry for a machine learning model binary (e.g. .tflite).
class MLModelMetadata {
  final String modelId;
  final String modelName;
  final String version;
  final int fileSizeBytes;
  final bool isCached;
  final DateTime lastUpdated;

  const MLModelMetadata({
    required this.modelId,
    required this.modelName,
    required this.version,
    required this.fileSizeBytes,
    required this.isCached,
    required this.lastUpdated,
  });

  factory MLModelMetadata.fromJson(Map<String, dynamic> json) {
    return MLModelMetadata(
      modelId: json['model_id'] as String? ?? '',
      modelName: json['model_name'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      isCached: json['is_cached'] as bool? ?? false,
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model_id': modelId,
      'model_name': modelName,
      'version': version,
      'file_size_bytes': fileSizeBytes,
      'is_cached': isCached,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}

/// Central model management coordinator responsible for downloading, caching,
/// versioning, and updating on-device TensorFlow Lite model binaries.
class ModelManager {
  static ModelManager? _instance;
  static ModelManager get instance => _instance ??= ModelManager();

  final Map<String, MLModelMetadata> _modelRegistry = {
    'workout_recommendation': MLModelMetadata(
      modelId: 'workout_recommendation',
      modelName: 'Workout Recommendation Model',
      version: '1.2.0',
      fileSizeBytes: 2457600, // 2.4 MB
      isCached: true,
      lastUpdated: DateTime.now(),
    ),
    'exercise_classification': MLModelMetadata(
      modelId: 'exercise_classification',
      modelName: 'Pose Exercise Classification Model',
      version: '2.1.0',
      fileSizeBytes: 4194304, // 4.2 MB
      isCached: true,
      lastUpdated: DateTime.now(),
    ),
    'movement_quality': MLModelMetadata(
      modelId: 'movement_quality',
      modelName: 'Biomechanics & Movement Quality Model',
      version: '1.4.0',
      fileSizeBytes: 3145728, // 3.1 MB
      isCached: true,
      lastUpdated: DateTime.now(),
    ),
    'nutrition_prediction': MLModelMetadata(
      modelId: 'nutrition_prediction',
      modelName: 'Nutrition Adherence Predictor',
      version: '1.0.0',
      fileSizeBytes: 1048576, // 1.0 MB
      isCached: true,
      lastUpdated: DateTime.now(),
    ),
  };

  final Map<String, List<int>> _inMemoryBinaryCache = {};

  /// Retrieve metadata for a registered model
  MLModelMetadata? getModelMetadata(String modelId) {
    return _modelRegistry[modelId];
  }

  /// Get active version string of a model
  String getModelVersion(String modelId) {
    return _modelRegistry[modelId]?.version ?? '1.0.0';
  }

  /// Whether the requested model binary is downloaded and cached
  bool isModelCached(String modelId) {
    return _modelRegistry[modelId]?.isCached ?? false;
  }

  /// Simulates / executes downloading model binary from remote endpoint
  Future<bool> downloadModel(String modelId, String remoteUrl) async {
    final existing = _modelRegistry[modelId];
    _modelRegistry[modelId] = MLModelMetadata(
      modelId: modelId,
      modelName: existing?.modelName ?? modelId,
      version: existing?.version ?? '1.0.0',
      fileSizeBytes: existing?.fileSizeBytes ?? 2048000,
      isCached: true,
      lastUpdated: DateTime.now(),
    );
    return true;
  }

  /// Cache binary bytes in memory or local secure storage
  void cacheModel(String modelId, List<int> modelBytes) {
    _inMemoryBinaryCache[modelId] = modelBytes;
    final existing = _modelRegistry[modelId];
    if (existing != null) {
      _modelRegistry[modelId] = MLModelMetadata(
        modelId: modelId,
        modelName: existing.modelName,
        version: existing.version,
        fileSizeBytes: modelBytes.length,
        isCached: true,
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Updates or upgrades a model version and hyperparameter configuration
  void updateModel({
    required String modelId,
    required String newVersion,
    int? newFileSizeBytes,
  }) {
    final existing = _modelRegistry[modelId];
    _modelRegistry[modelId] = MLModelMetadata(
      modelId: modelId,
      modelName: existing?.modelName ?? modelId,
      version: newVersion,
      fileSizeBytes: newFileSizeBytes ?? existing?.fileSizeBytes ?? 2048000,
      isCached: true,
      lastUpdated: DateTime.now(),
    );
  }

  /// Lists all registered models in the system
  List<MLModelMetadata> listModels() {
    return _modelRegistry.values.toList();
  }
}

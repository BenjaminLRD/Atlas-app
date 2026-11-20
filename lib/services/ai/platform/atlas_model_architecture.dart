/// Supported custom and fine-tuned AI model targets for Atlas.
enum AIModelFamily {
  geminiPro('gemini-1.5-pro', 'General High-Reasoning Cloud LLM'),
  geminiFlash('gemini-1.5-flash', 'High-Speed Low-Latency Cloud LLM'),
  atlasSportsScience(
    'atlas-sports-science-v1',
    'Custom Fine-Tuned Exercise Physiology Model',
  ),
  atlasBiomechanicsOnDevice(
    'atlas-biomechanics-edge-v1',
    'On-Device Quantized Form Kinematics Model',
  );

  final String modelId;
  final String description;
  const AIModelFamily(this.modelId, this.description);
}

/// Metadata and benchmark performance of an registered AI model.
class ModelDescriptor {
  final String modelId;
  final AIModelFamily family;
  final String version;
  final int parameterCountMillions;
  final double averageLatencyMs;
  final double physiologyAccuracyScore; // 0-100
  final bool isEdgeDeployable;

  const ModelDescriptor({
    required this.modelId,
    required this.family,
    required this.version,
    required this.parameterCountMillions,
    required this.averageLatencyMs,
    required this.physiologyAccuracyScore,
    required this.isEdgeDeployable,
  });

  Map<String, dynamic> toJson() => {
    'model_id': modelId,
    'family': family.name,
    'version': version,
    'params_m': parameterCountMillions,
    'avg_latency_ms': averageLatencyMs,
    'accuracy_score': physiologyAccuracyScore,
    'is_edge': isEdgeDeployable,
  };
}

/// Atlas AI Model Architecture & Registry Service.
/// Manages model routing, parameter benchmarking, and fine-tuned sports science model versioning.
class AtlasModelArchitecture {
  static AtlasModelArchitecture? _instance;
  static AtlasModelArchitecture get instance =>
      _instance ??= AtlasModelArchitecture();

  static void resetInstance() {
    _instance = null;
  }

  final List<ModelDescriptor> _registeredModels = [];

  AtlasModelArchitecture() {
    _seedModelRegistry();
  }

  List<ModelDescriptor> get registeredModels =>
      List.unmodifiable(_registeredModels);

  void _seedModelRegistry() {
    _registeredModels.addAll([
      const ModelDescriptor(
        modelId: 'atlas-sports-science-v1',
        family: AIModelFamily.atlasSportsScience,
        version: '1.4.0',
        parameterCountMillions: 8000,
        averageLatencyMs: 140.0,
        physiologyAccuracyScore: 96.5,
        isEdgeDeployable: false,
      ),
      const ModelDescriptor(
        modelId: 'atlas-biomechanics-edge-v1',
        family: AIModelFamily.atlasBiomechanicsOnDevice,
        version: '1.1.2',
        parameterCountMillions: 350,
        averageLatencyMs: 18.0,
        physiologyAccuracyScore: 94.2,
        isEdgeDeployable: true,
      ),
      const ModelDescriptor(
        modelId: 'gemini-1.5-flash',
        family: AIModelFamily.geminiFlash,
        version: 'latest',
        parameterCountMillions: 12000,
        averageLatencyMs: 220.0,
        physiologyAccuracyScore: 91.0,
        isEdgeDeployable: false,
      ),
    ]);
  }

  /// Selects the optimal model descriptor based on latency requirement and hardware capability.
  ModelDescriptor selectModel({
    required bool prefersOnDevice,
    required bool requiresDeepReasoning,
  }) {
    if (prefersOnDevice) {
      return _registeredModels.firstWhere(
        (m) => m.isEdgeDeployable,
        orElse: () => _registeredModels.first,
      );
    }
    if (requiresDeepReasoning) {
      return _registeredModels.firstWhere(
        (m) => m.family == AIModelFamily.atlasSportsScience,
        orElse: () => _registeredModels.first,
      );
    }
    return _registeredModels.firstWhere(
      (m) => m.family == AIModelFamily.geminiFlash,
      orElse: () => _registeredModels.first,
    );
  }
}

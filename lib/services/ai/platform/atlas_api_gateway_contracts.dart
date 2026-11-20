/// Standardized OpenAPI schema contracts for Atlas Platform APIs.
class AtlasApiGatewayContracts {
  static const String apiVersion = 'v1.0';

  /// Generates schema descriptor for Workout Intelligence endpoint.
  static Map<String, dynamic> getWorkoutIntelligenceEndpointContract() {
    return {
      'endpoint': '/api/$apiVersion/intelligence/workout',
      'method': 'POST',
      'headers': {
        'Authorization': 'Bearer <token>',
        'Content-Type': 'application/json',
      },
      'request_body': {
        'user_id': 'string',
        'target_muscle_groups': ['string'],
        'available_minutes': 'integer',
        'recovery_score': 'integer (0-100)',
      },
      'response_schema': {
        'session_title': 'string',
        'estimated_duration_min': 'integer',
        'exercises': [
          {
            'name': 'string',
            'sets': 'integer',
            'rep_range': 'string',
            'target_rir': 'integer',
          },
        ],
      },
    };
  }

  /// Generates schema descriptor for Biomechanics Intelligence endpoint.
  static Map<String, dynamic> getBiomechanicsEndpointContract() {
    return {
      'endpoint': '/api/$apiVersion/intelligence/biomechanics',
      'method': 'POST',
      'headers': {
        'Authorization': 'Bearer <token>',
        'Content-Type': 'application/json',
      },
      'request_body': {
        'exercise_type': 'string',
        'pose_landmarks': 'array<object>',
        'timestamp_ms': 'number',
      },
      'response_schema': {
        'rep_count': 'integer',
        'efficiency_score': 'number (0-100)',
        'detected_faults': ['string'],
        'real_time_cue': 'string',
      },
    };
  }
}

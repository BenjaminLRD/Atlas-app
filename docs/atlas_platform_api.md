# Atlas Platform Public & Developer API Specifications

## 1. Overview

The Atlas Platform API enables developers, third-party wearable manufacturers, and enterprise gyms to integrate Atlas's proprietary workout intelligence, nutrition arithmetic, and biomechanics form analytics.

```
Base URL: https://api.atlasfit.ai/v1
Authentication: Bearer <API_KEY>
Content-Type: application/json
```

---

## 2. API Endpoints

### 2.1 Workout Intelligence API
- **Endpoint**: `POST /v1/intelligence/workout`
- **Description**: Synthesizes an individualized, fatigue-aware training session.
- **Request**:
```json
{
  "athlete_id": "ath_98234",
  "target_split": "upper_body_hypertrophy",
  "available_time_minutes": 60,
  "recovery_score": 82,
  "equipment_available": ["barbell", "dumbbells", "cable_machine"]
}
```
- **Response**:
```json
{
  "session_title": "Upper Body Hypertrophy (Accumulation)",
  "estimated_duration_min": 55,
  "total_working_sets": 14,
  "exercises": [
    {
      "name": "Barbell Incline Bench Press",
      "sets": 4,
      "rep_range": "8-10",
      "target_rir": 2,
      "rest_seconds": 120
    }
  ]
}
```

---

### 2.2 Biomechanics Analysis API
- **Endpoint**: `POST /v1/intelligence/biomechanics`
- **Description**: Evaluates 3D landmark kinematics and identifies movement flaws.
- **Request**:
```json
{
  "exercise_pattern": "squat_pattern",
  "joint_angles": {
    "knee_flexion_depth_deg": 74.5,
    "hip_flexion_depth_deg": 64.0,
    "torso_incline_deg": 46.2
  },
  "bar_path_drift_cm": 2.4
}
```
- **Response**:
```json
{
  "rep_valid": true,
  "mechanical_efficiency_score": 94.5,
  "dominant_torque_joint": "Knee Dominant (Anterior Lever)",
  "identified_flaws": [],
  "real_time_cue": "Perfect depth and vertical bar path. Keep driving through midfoot."
}
```

---

### 2.3 Athlete Analytics API
- **Endpoint**: `GET /v1/athletes/{id}/analytics`
- **Description**: Returns 7-day trailing volume, muscle protein synthesis status, and 1RM progression forecasts.

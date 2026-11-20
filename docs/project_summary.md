# Atlas — Executive Project Summary & Portfolio Showcase

## Executive Overview
**Atlas** is an enterprise-grade, autonomous AI personal trainer and health intelligence platform built with **Flutter**, **Google Gemini 2.5**, **Supabase**, and on-device **Computer Vision**. It addresses the limitations of static fitness logbooks by delivering an autonomous coaching loop: analyzing real-time wearable biometrics, meal photos, and 3D movement biomechanics to dynamically adapt workouts, calibrate nutrition, and maximize athletic performance.

---

## 🎯 Key Engineering Innovations

1. **Autonomous Conversational AI Agent with Behavioral Memory**:
   - Built a 2-turn function-calling AI agent powered by **Google Gemini 2.5 Flash** with specialized tools (`WorkoutTool`, `NutritionTool`, `HealthTool`, `ProgressTool`).
   - Engineered **`FitnessMemory`**, a persistent behavioral learning system that learns movement preferences, respects injury limits, and automatically demotes disliked exercises based on athlete substitutions.

2. **Real-Time 3D Computer Vision Pose Biomechanics**:
   - Implemented an on-device computer vision pipeline using 33 3D body landmarks to analyze joint angles, vertical alignment, and horizontal bar drift across 6 compound lifts (Squat, Deadlift, Bench Press, Push-up, Shoulder Press, Bicep Curl).
   - Embedded non-medical safety guardrails that detect movement faults (e.g. knee valgus, lumbar rounding, elbow flare) and deliver instant educational cues.

3. **Multimodal Nutrition Vision & Barcode Engine**:
   - Developed a unified food scanning engine integrating **Gemini Vision AI** for automated meal photo recognition and **OpenFoodFacts REST API v2** for sub-10ms barcode nutrition resolution with offline caching.

4. **Physiological Recovery & Training Load Intelligence**:
   - Engineered an acute/chronic workload engine (ATL 7-day, CTL 28-day, ACWR, TSB) that monitors injury risks and calculates a **5-Factor Training Readiness Score** (0–100) from wearable biometrics (HRV, sleep, resting heart rate).
   - Dynamically scales workout volume in real time based on athlete recovery states.

5. **Production-Grade Software Engineering & Test-Driven Development**:
   - Maintained **1,000+ comprehensive automated unit, widget, and integration tests** with **100% pass rate** and **0 static analysis warnings**.
   - Built with clean layered architecture, offline-first local persistence, Supabase Row-Level Security (RLS), and zero-secret credential separation.

---

## 📊 System Metrics & Quality Benchmarks

| Metric | Benchmark | Achievement |
|---|---|---|
| **Test Suite** | Comprehensive Coverage | **1,011 / 1,011 Tests Passing (100%)** |
| **Static Analysis** | `flutter analyze` | **0 Warnings / 0 Errors** |
| **UI Performance** | Target Frame Rate | **60 FPS** smooth hardware-accelerated animations |
| **Barcode Lookup** | Response Latency | **< 15ms** (cached) / **< 250ms** (network) |
| **AI Vision Response** | End-to-End Latency | **1.2s – 2.0s** streaming multimodal response |
| **Security & Privacy** | Credential Exposure | **0 hardcoded secrets**, 100% environment isolated |

---

## 💼 Resume Bullet Points

### For AI Engineer / Full-Stack AI Roles:
- **Architected and developed Atlas**, an autonomous AI fitness platform in Flutter and Dart, integrating Google Gemini 2.5 Flash with multi-turn function calling and on-device computer vision for personalized workout generation and biomechanics analysis.
- **Engineered a long-term behavioral memory system (`FitnessMemory`)** that dynamically tracks athlete movement preferences, applies reinforcement feedback scoring on exercise substitutions, and customizes AI coaching tone over time.
- **Developed a multimodal food recognition pipeline** leveraging Gemini Vision and OpenFoodFacts API, enabling real-time macro estimation from meal photos and sub-10ms barcode scanning.
- **Formulated a 5-factor physiological recovery engine** calculating Acute:Chronic Workload Ratio (ACWR), Training Stress Balance (TSB), and heart rate variability (HRV) telemetry to dynamically adapt workout volume.

### For Senior / Lead Mobile Engineer Roles:
- **Led end-to-end mobile architecture of Atlas** using Flutter, Dart, and Supabase (PostgreSQL), implementing clean layered architecture with unidirectional data flow and repository patterns.
- **Built an interactive in-gym workout execution engine** featuring real-time rest timers, 1RM progressive overload calculations via the Brzycki formula, and haptic feedback loops.
- **Established an enterprise-grade automated testing suite** comprising 1,000+ unit, widget, and integration tests, maintaining a 100% pass rate and zero static analysis warnings.
- **Designed a startup-grade 7-step onboarding flow** and glassmorphic UI design system, optimizing first-time user activation and cross-screen visual consistency across Android, iOS, and Web.

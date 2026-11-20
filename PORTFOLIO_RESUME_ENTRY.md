# Portfolio & Resume Project Entry — Atlas

---

## 📄 Bullet Points for Resume (Software Engineer / Mobile Engineer)

### Option 1: Detailed & Impact-Focused (Recommended)

**Atlas — AI-Powered Mobile Fitness Ecosystem (Flutter, Dart, Supabase)**
- Engineered a production-grade, offline-first mobile fitness platform supporting 680+ test-verified features including adaptive workout planning, macro nutrition tracking, biometric telemetry, and ranked gamification.
- Designed a **Clean Layered Architecture** with the **Repository Pattern** and 3-tier caching (RAM `<1ms`, Hardware Keystore, Supabase PostgreSQL), enabling seamless offline operation and background sync queues.
- Integrated **Google Gemini AI** with an in-memory LRU prompt response cache (`AIResponseCache`), slashing repeated query latency from 10s to `<1ms` while reducing cloud API consumption.
- Implemented enterprise-grade mobile security utilizing **Android Keystore** / **Apple Keychain** hardware encryption for biometric health telemetry and PostgreSQL **Row Level Security (RLS)** for multi-tenant cloud isolation.
- Optimized rendering performance with dynamic list virtualization and isolated `ValueNotifier` bindings, maintaining a 60fps budget and achieving sub-100ms startup times on a 61.1 MB release binary.
- Built a comprehensive test suite of **685 unit and widget tests** with 100% pass rate and zero static analyzer warnings.

---

### Option 2: Concise & Standard

**Atlas — AI Fitness Platform | Flutter, Dart, Supabase, PostgreSQL**
- Developed a full-stack mobile fitness ecosystem combining AI workout generation, nutrition planning, health telemetry, and social community feeds.
- Built an equipment-aware training engine with real-time set logging, automated rest timers, and personal record (PR) detection.
- Architected an offline-first data pipeline utilizing Supabase PostgreSQL RLS and hardware-encrypted local storage (Android Keystore / Apple Keychain).
- Created an in-memory LRU cache for AI chat requests, eliminating redundant network calls and optimizing battery consumption.
- Delivered 685 automated unit/widget tests, achieving 100% test pass rate and zero analyzer issues across multiple responsive viewports (320px–412px+).

---

## 💼 Key Skills Demonstrated

- **Mobile Development**: Flutter, Dart, Responsive UI Design, Glassmorphism, Material 3, Custom Animations
- **Architecture & Patterns**: Clean Layered Architecture, Repository Pattern, Dependency Injection, Offline-First, Optimistic UI
- **Cloud & Databases**: Supabase, PostgreSQL 15+, Row Level Security (RLS), Realtime Channels, REST APIs
- **Mobile Security**: Android Keystore (`EncryptedSharedPreferences`), Apple Keychain, Hardware Secure Enclave, PII Redaction
- **Performance Engineering**: Memory profiling, LRU Caching, ListView dynamic virtualization, ProGuard R8 tree-shaking
- **Testing & CI/CD**: Unit testing, Widget testing, Mocking, Automated APK build pipelines

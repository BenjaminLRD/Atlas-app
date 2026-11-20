# Atlas Foundation Model Roadmap

## 1. Vision & Architectural Evolution

Atlas is transitioning from general-purpose cloud Large Language Models (Gemini 1.5 Pro / Flash) to a domain-specialized, hybrid AI foundation model stack tailored for exercise physiology, biomechanics, metabolism, and athletic recovery.

```
+-------------------------------------------------------------------------+
|                              Atlas Hybrid AI Architecture               |
+-------------------------------------------------------------------------+
                                      │
                 ┌────────────────────┴────────────────────┐
                 ▼                                         ▼
      [ Cloud Frontier LLM ]                   [ Atlas-FM Edge Model ]
      - Gemini 1.5 Pro / Flash                 - 7B Quantized Parameter Model
      - Deep Scientific Synthesis              - On-Device Sub-20ms Inference
      - Complex Multi-Year Periodization       - Real-Time Live Coaching Cues
                 │                                         │
                 └────────────────────┬────────────────────┘
                                      │
                                      ▼
                   [ Atlas Sports Science RAG Knowledge Base ]
                   - 10,000+ Peer-Reviewed Sports Science Studies
                   - Vector Embeddings (128-dim Cosine Similarity)
                   - Evidence-Graded Hierarchy (Meta-Analyses > RCTs)
```

---

## 2. Core Training Domains & Pre-Training Corpus

The future `Atlas-FM` foundation model is pre-trained and fine-tuned across 5 specialized domains:

1. **Exercise Science & Hypertrophy Kinetics**:
   - Stimulus-to-fatigue ratios (SFR), volume step-loading models, muscle fiber recruitment, and progressive overload dynamics.
2. **Clinical Nutrition & Metabolic Bioenergetics**:
   - Protein pacing, leucine thresholds ($3\text{g}$ per bolus), caloric titration kinetics, glycogen restoration, and micronutrient bio-availability.
3. **Computer Vision & Biomechanical Kinematics**:
   - 3D spatial pose estimation, joint moment arms, torque distribution across knee/hip levers, and bar path deviation analysis.
4. **Physiological Recovery & Autonomic Telemetry**:
   - Heart rate variability (rMSSD), circadian rhythm alignment, sleep architecture optimization, and central nervous system (CNS) fatigue decay.
5. **Behavioral Psychology & Habit Adherence**:
   - Motivation scaffolding, streak reinforcement, cognitive reframing, and overcoming workout resistance.

---

## 3. Phased Implementation Milestones

| Milestone | Architecture Focus | Model Family | Target Latency |
| :--- | :--- | :--- | :--- |
| **Phase 1 (Current)** | Cloud RAG + Multi-Tier Model Router | Gemini 1.5 Flash / Pro | $150 - 350\text{ ms}$ |
| **Phase 2 (Hybrid)** | Cloud LLM + Local Kinematic Form Validator | Gemini Flash + TFLite Edge | $20 - 50\text{ ms}$ (Local) |
| **Phase 3 (Custom Foundation)** | Fine-Tuned Domain Model (`Atlas-FM-7B`) | Quantized Llama / Mistral Fine-Tune | $<100\text{ ms}$ |
| **Phase 4 (Autonomous Multimodal)** | End-to-End On-Device Multimodal Coach | Atlas Multimodal Engine | $<15\text{ ms}$ (Zero Network) |

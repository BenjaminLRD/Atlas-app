# Atlas AI Ethics, Safety & Governance Framework

## 1. Ethical Principles & Clinical Boundaries

Atlas is an AI fitness coaching platform designed to enhance athletic performance and lifestyle health. It is **not** a licensed medical provider or medical diagnostic tool.

### 1.1 Non-Medical Disclaimer & Red Lines
- **Zero Medical Diagnoses**: Atlas will never diagnose medical conditions, prescribe pharmaceutical drugs, or provide treatment protocols for acute pathologies.
- **Mandatory Clinical Disclaimers**: Any query touching upon injury symptoms, sharp joint pain, or cardiovascular concerns triggers a non-negotiable referral to licensed medical professionals.
- **Immediate Injury Redirection**: Atlas strictly rejects queries advising athletes to "push through sharp joint pain."

---

## 2. Privacy & Data Sovereignty

1. **User Data Ownership**: Athletes maintain 100% ownership of their workout logs, biometric telemetry, and habit data.
2. **On-Device Vision & Voice**: Camera form detection frames and microphone voice inputs are processed locally on-device in volatile memory and are never transmitted to external cloud servers.
3. **Differential Privacy ($\epsilon < 1.0$)**: All population-level insights use mathematical noise perturbation to ensure individual athletes cannot be re-identified from aggregate trends.
4. **Data Deletion Rights**: Athletes can export or permanently delete all stored memory and profile data at any time with a single tap.

---

## 3. Algorithmic Transparency
- Every AI coaching recommendation provides an expandable "Why did Atlas recommend this?" reasoning drawer detailing the scientific rationale, evidence confidence level, and participating agent consensus.

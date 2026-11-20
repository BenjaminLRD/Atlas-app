# Atlas Biomechanics & Computer Vision Research Architecture

## 1. Vision-to-Biofeedback Pipeline

The Atlas real-time biomechanics pipeline processes 60 FPS video input entirely on-device, extracting skeletal landmarks, computing 3D inverse kinematics, and generating actionable audio cues with $<30\text{ms}$ latency.

```
       [ Camera Feed (60 FPS) ]
                  │
                  ▼
     [ Real-Time Pose Estimation ] (33 Keypoint Skeletal Tracking)
                  │
                  ▼
     [ 3D Kinematic Angle Engine ] (Knee, Hip, Back, Elbow, Shoulder)
                  │
                  ▼
     [ Moment Arm & Torque Analysis ] (Joint Load Distribution)
                  │
                  ▼
     [ Biomechanical Flaw Classifier ]
     - Knee Valgus / Varus
     - Lumbar Spinal Rounding
     - Sub-Parallel Depth
     - Bar Path Horizontal Drift (>5cm)
                  │
                  ▼
     [ Real-Time Audio & Visual Cues ] ("Spread the floor", "Chest up")
```

---

## 2. Key Kinematic Algorithms

### 2.1 Joint Range of Motion (ROM) Calculation
$$\theta = \arccos\left(\frac{\vec{u} \cdot \vec{v}}{\|\vec{u}\| \|\vec{v}\|}\right)$$
- Tracks continuous joint angular velocity during concentric and eccentric phases.

### 2.2 Horizontal Bar Path Deviation
$$\Delta X_{\text{drift}} = \max(X_{\text{bar}}) - \min(X_{\text{bar}})$$
- Elite bar paths remain within a vertical cylinder ($<4\text{cm}$ drift), minimizing wasted mechanical work.

---

## 3. Privacy & On-Device Guarantees
- Zero raw camera frames or videos are uploaded to cloud servers.
- Landmark extraction and tensor inference occur purely in local volatile memory.

# Atlas — Complete Feature Inventory & Functional Specifications

---

## 1. 🏋️‍♂️ Fitness & Training System

### Equipment-Aware Workout Generation
- **Dynamic Equipment Profiling**: Automatically generates customized workout routines based on selected equipment:
  - Commercial Gym (Barbells, Cable Stations, Leg Press, Smith Machine)
  - Home Dumbbells & Benches
  - Resistance Bands & Suspension Trainers
  - Pure Bodyweight & Calisthenics
- **Target Muscle Focus**: Generates split routines (Push, Pull, Legs, Upper, Lower, Full Body, Core, Cardio).

### Active Workout Session Runner
- **Live Set Logging**: Real-time logging of weight lifted (kg/lbs), completed reps, and Rating of Perceived Exertion (RPE 1–10).
- **Automated Rest Interval Timers**: Configurable rest countdowns (30s, 60s, 90s, 120s) with audio chimes and background preservation.
- **Personal Record (PR) Auto-Detection**: Automatically detects all-time personal bests (1RM, max weight, max reps) during workout sessions.
- **Exercise Swaps & Alternatives**: Allows instant exercise substitutions targeting identical muscle groups without breaking workout flow.

### Exercise Library & Multimedia Form Guides
- **Comprehensive Database**: High-definition exercise guides covering mechanics, execution cues, primary/secondary muscles, and safety notes.
- **Muscle Activation Maps**: Visual anatomical balance charts highlighting targeted muscle groups.

---

## 2. 🤖 AI Fitness Intelligence

### Context-Aware AI Fitness Coach
- **Gemini AI Integration**: Powers conversational chat with real-time access to the athlete's training history, current recovery score, dietary macros, and equipment.
- **Context Synthesis**: Ingests comprehensive `FitnessContext` snapshots for hyper-personalized coaching without manual data re-entry.

### Sub-Second LRU Response Caching
- **`AIResponseCache`**: In-memory LRU cache with 12-hour TTL for prompt deduplication.
- **Instantaneous Responses**: Delivers cached answers for repeated inquiries (e.g. *"Suggest high protein post-workout meal"*) in `<1ms`, eliminating network latency and conserving API quotas.

### Daily Strategic Briefs & Trainer AI
- **Morning Daily Brief**: Synthesizes today's workout plan, nutrition targets, and recovery status into a concise daily brief.
- **Trainer AI Assistant**: Generates structured client progress summaries for gym trainers.

---

## 3. 🥗 Nutrition & Macro Intelligence

### 1,000+ Item Food Database
- **Regional & Global Diversity**: Whole foods, Indian cuisine, local Mizo specialties, high-protein supplements, and fast-food nutritional entries.
- **Category Filtering & Search**: Instant real-time search with chips for Protein, Fruits, Vegetables, Grains, Fast Food, and Favorites.

### Barcode Food Scanner
- **Camera-Based Scanning**: Fast barcode scanning with automatic fallback to OpenFoodFacts REST lookup for packaged items.
- **Portion Multiplier**: Dynamic scaling of food entries by serving size (grams, ml, scoops, pieces).

### Calorie & Macro Target Planner
- **Metabolic Equations**: Automated Harris-Benedict BMR, TDEE, and goal-specific calorie surpluses/deficits (Muscle Gain, Fat Loss, Maintenance).
- **Macro Distribution Wheels**: Visual breakdown of daily protein, carbohydrates, fats, and water consumption against personalized targets.

---

## 4. 📊 Health, Biometrics & Recovery

### Daily Telemetry Dashboard
- **Step & Distance Tracking**: Real-time pedometer logging with daily step goals (e.g. 10,000 steps).
- **Active Calorie Burn**: Continuous calculation of active energy expenditure.
- **Heart Rate & Sleep Monitoring**: Resting heart rate (bpm) and sleep duration logs.

### Recovery Score & Readiness Engine
- **Readiness Score (0–100)**: Composite metric derived from sleep quality, HRV/resting heart rate, and training strain.
- **Deload & Adaptation Alerts**: Flags cumulative central nervous system (CNS) fatigue and automatically suggests active recovery routines on low-readiness days.

---

## 5. 🌐 Social Community & Fitness Hub

### Activity Feed & Post Sharing
- **Workout Showcase**: Share completed workout summaries with lifted volume, workout time, and custom photos.
- **Meal Prep Logs**: Share healthy recipes and macro breakdowns with fellow athletes.
- **PR Celebrations**: Auto-generated milestone achievement cards posted to the public gym feed.

### Peer Interactions & Challenges
- **Reactions & Comments**: Realtime liking, cheering, and commenting on member posts.
- **Weekly Quests**: Gym-wide fitness quests (e.g. *"Log 4 workouts this week"* or *"Hit 150g protein 5 days in a row"*).

---

## 6. 🏆 Gamification & Competitive Ranked Arena

### Ranked Mode
- **Divisions**: Bronze → Silver → Gold → Platinum → Diamond → Champion, each with divisions III, II, I (18 in total).
- **Four stats**: Strength, Endurance, Cardio and Consistency, each with 5 milestone levels. Every level reached moves you up one division (Champion I at 18 of 20 points).
- **Fair milestones**: strength targets are bodyweight multiples of an estimated one-rep max, with separate men's and women's standards. Endurance is push-ups in one set, Cardio is the fastest 5 km, Consistency is workouts in the last 28 days.
- **Verified on the server**: the `ranked-sync` Edge Function judges milestones from synced workouts and cardio sessions; rank is computed in the database from approved milestones only. Strength and push-up levels 4–5 need a proof video, approved by a reviewer.
- **XP and levels**: XP still rewards workouts, nutrition, streaks and quests with levels, but does not change rank.

### Leaderboards & Achievements
- **Ranked leaderboard**: verified ranks of signed-in athletes.
- **Achievement Showcase**: Unlockable badges with tiered visual rarity (Common, Rare, Epic, Legendary).

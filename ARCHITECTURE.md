\# Architecture



\## Folder Structure



lib/



├── models/

│   ├── UserProfile

│   ├── WorkoutPlan

│   ├── Exercise

│   ├── DietPlan

│   └── AIMessage

│

├── providers/

│   ├── ProfileProvider

│   ├── WorkoutProvider

│   ├── NutritionProvider

│   └── AIChatProvider

│

├── services/

│   ├── LocalStorage

│   ├── WorkoutService

│   ├── NutritionService

│   ├── AIService

│   └── NotificationService

│

├── screens/

│   ├── Splash

│   ├── Login

│   ├── Onboarding

│   ├── Dashboard

│   ├── Workout

│   ├── ExerciseSession

│   ├── Diet

│   ├── Progress

│   ├── Profile

│   ├── EditProfile

│   ├── Payment

│   ├── Notifications

│   └── AIChat

│

├── widgets/

│   ├── TopAppBar

│   ├── BottomNavigation

│   ├── WorkoutCard

│   ├── ProgressCard

│   ├── NutritionCard

│   ├── AIChatBubble

│   └── ProfileCard



\---



\## State Management



ProfileProvider



WorkoutProvider



NutritionProvider



AIChatProvider



SharedPreferences



\---



\## Navigation Flow



Splash

↓



Login

↓



Onboarding (first-time users only)

↓



Dashboard



Dashboard can navigate to:



\- Workout

\- Diet

\- Progress

\- Notifications

\- Profile

\- AI Chat



Workout



↓



Exercise Session



↓



Workout Summary



Profile



↓



Edit Profile



Payment



↓



Return to Profile



AI Chat



Accessible from every page via the floating AI chat bubble.



The AI chat always opens the existing AI chat screen.



Never create duplicate AI chat pages.



\---



\## Architecture Rules



There is only ONE UserProfile.



There is only ONE AI chat screen.



There is only ONE Workout flow.



Never duplicate pages.



Always reuse existing widgets.



Never hardcode user data.



Persist all user information locally.



Profile updates must immediately refresh every screen.


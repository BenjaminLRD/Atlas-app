\# PROJECT.md



\# Aizawl Gym



\## Overview



Aizawl Gym is an AI-powered Flutter fitness application that creates personalized workout plans, diet plans, and progress tracking for users.



The application should look and behave like a polished production fitness app rather than a prototype.



\---



\# Technology



Framework:

Flutter



Language:

Dart



Design:

Material 3



Storage:

SharedPreferences (currently)



Future Backend:

Firebase / Supabase (optional)



AI:

AI Chat Coach



Design Tools:

Google Stitch MCP



Development Tools:

Dart MCP



\---



\# Main Features



\## Authentication



\- Login

\- Sign Up

\- Forgot Password

\- Google Sign In

\- Apple Sign In



No backend currently.

Authentication is simulated.



\---



\## Onboarding



Collect:



\- Name

\- Birthdate

\- Gender

\- Height

\- Weight

\- Fitness Goal

\- Workout Experience

\- Workout Days

\- Diet Preference



Generate a personalized profile.



\---



\## Dashboard



Contains:



\- Greeting

\- Today's Workout

\- Start Workout

\- View Plan

\- Today's Protein Intake

\- Progress Cards

\- AI Insights



\---



\## Workout



Contains:



\- Weekly Schedule

\- Workout Details

\- Exercise List

\- Start Workout

\- Progress Tracking



Reuse existing workout pages whenever possible.



Never create duplicate workout pages.



\---



\## Profile



Contains:



\- Profile Picture

\- Personal Information

\- Height

\- Weight

\- Age

\- Subscription

\- Edit Profile



All profile information should come from a single UserProfile model.



\---



\## Edit Profile



Editable fields:



\- Name

\- Birthdate

\- Gender

\- Height

\- Weight

\- Goal

\- Workout Experience

\- Workout Days

\- Diet

\- Profile Picture



Changes should immediately update the entire application.



\---



\## AI Coach



Floating glassmorphism chat button.



Provides:



\- Workout advice

\- Diet advice

\- Progress analysis



\---



\## Subscription



Plans:



Free



Pro



Premium



Rules:



Free



\- Immediate activation



Pro



\- Current Plan badge

\- Cannot purchase twice



Premium



\- Opens payment page



\---



\## Payment



Demo only.



Supports:



\- Credit Card

\- Debit Card

\- UPI

\- Net Banking



No real payment gateway.



\---



\# Navigation Flow



Splash



↓



Login



↓



Onboarding (first-time users)



↓



Dashboard



↓



Workout



↓



Exercise Session



↓



Progress



Profile can be opened from every page.



Notifications can be opened from every page.



AI Chat can be opened from every page.



\---



\# Folder Structure



lib/



models/



services/



screens/



widgets/



utils/



theme/



\---



\# Data Rules



There is ONE UserProfile.



Every page must read from the same profile.



Never hardcode:



\- Name

\- Weight

\- Age

\- Height

\- Goal

\- Subscription



All values must persist locally.



\---



\# UI Rules



Theme:



Modern



Minimal



Premium



Fitness-oriented



Green primary color



Glassmorphism where appropriate



Rounded corners



Material 3



Consistent spacing



Smooth animations



\---



\# Existing Pages



Current pages include:



\- Splash

\- Login

\- Dashboard

\- Workout

\- Edit Profile

\- Payment

\- Notifications

\- AI Chat



Always reuse these pages.



Do not create duplicate versions.



\---



\# Development Rules



When implementing a feature:



1\. Reuse existing pages.



2\. Reuse existing widgets.



3\. Reuse existing navigation.



4\. Avoid duplicate code.



5\. Maintain app consistency.



6\. Keep architecture modular.



7\. Run flutter analyze after completing changes.



8\. Fix all warnings and errors.



9\. Ensure every button performs its intended action.



10\. Verify all edited data persists after restarting the app.



\---



\# Goal



The finished app should feel comparable to premium fitness applications like:



\- Fitbod

\- Strong

\- Nike Training Club

\- Hevy



while maintaining the existing Aizawl Gym branding and green design language.


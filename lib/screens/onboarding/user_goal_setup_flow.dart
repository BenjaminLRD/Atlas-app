import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/user_goal.dart';
import '../../widgets/common/app_button.dart';
import 'goal_selection_screen.dart';
import 'fitness_level_screen.dart';
import 'body_metrics_screen.dart';
import 'activity_level_screen.dart';
import 'goal_summary_screen.dart';

class UserGoalSetupFlow extends StatefulWidget {
  const UserGoalSetupFlow({super.key});

  @override
  State<UserGoalSetupFlow> createState() => _UserGoalSetupFlowState();
}

class _UserGoalSetupFlowState extends State<UserGoalSetupFlow> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 5;

  // Temporary setup state
  FitnessGoalType _goalType = FitnessGoalType.muscleGain;
  FitnessLevel _fitnessLevel = FitnessLevel.intermediate;
  int _age = 25;
  double _height = 175.0;
  double _currentWeight = 70.0;
  double _targetWeight = 75.0;
  ActivityLevel _activityLevel = ActivityLevel.moderate;

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Step Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _currentStep > 0 ? _previousStep : null,
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: _currentStep > 0
                              ? context.appTextPrimary
                              : Colors.transparent,
                        ),
                      ),
                      Text(
                        'Step ${_currentStep + 1} of $_totalSteps',
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 16,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 48), // Balancing spacer
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      minHeight: 5,
                      backgroundColor: context.appSurfaceElevated,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page View with 5 Steps
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentStep = idx),
                children: [
                  GoalSelectionScreen(
                    selectedGoal: _goalType,
                    onGoalSelected: (type) {
                      setState(() => _goalType = type);
                    },
                  ),
                  FitnessLevelScreen(
                    selectedLevel: _fitnessLevel,
                    onLevelSelected: (level) {
                      setState(() => _fitnessLevel = level);
                    },
                  ),
                  BodyMetricsScreen(
                    age: _age,
                    height: _height,
                    currentWeight: _currentWeight,
                    targetWeight: _targetWeight,
                    onChanged: ({
                      required int age,
                      required double height,
                      required double currentWeight,
                      required double targetWeight,
                    }) {
                      setState(() {
                        _age = age;
                        _height = height;
                        _currentWeight = currentWeight;
                        _targetWeight = targetWeight;
                      });
                    },
                  ),
                  ActivityLevelScreen(
                    selectedActivity: _activityLevel,
                    onActivitySelected: (activity) {
                      setState(() => _activityLevel = activity);
                    },
                  ),
                  GoalSummaryScreen(
                    goalType: _goalType,
                    fitnessLevel: _fitnessLevel,
                    activityLevel: _activityLevel,
                    age: _age,
                    height: _height,
                    currentWeight: _currentWeight,
                    targetWeight: _targetWeight,
                  ),
                ],
              ),
            ),

            // Bottom Navigation Action Bar (for steps 1 - 4)
            if (_currentStep < _totalSteps - 1)
              Padding(
                padding: const EdgeInsets.all(20),
                child: AppButton.primary(
                  label: 'Continue',
                  onPressed: _nextStep,
                  isPill: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

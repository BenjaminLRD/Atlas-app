import '../widgets/onboarding/onboarding_kit.dart';
import 'onboarding/permissions_step.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/local_storage.dart';
import '../main.dart';
import '../models/user_equipment_profile.dart';
import '../providers/fitness_provider.dart';
import '../services/ai/memory/fitness_memory.dart';
import '../services/onboarding_state_service.dart';
import '../providers/showcase_mode_provider.dart';
import '../widgets/common/app_animation.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/atlas_logo.dart';
import 'login_screen.dart';

/// Startup-Grade 7-Step Onboarding Experience
/// Guides the athlete through value discovery, goal setting, experience calibration,
/// equipment profiling, workout scheduling, nutrition targets, and AI Coach introduction.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.permissionGateway});

  /// Replaces the platform permission calls (for tests).
  final OnboardingPermissionGateway? permissionGateway;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 8;

  // Step 1: Goal
  String _selectedGoal = 'Build Muscle';

  // Step 2: Experience Level
  String _selectedLevel = 'Intermediate';

  // Step 3: Equipment Access
  String _selectedEquipmentPreset = 'full_commercial';

  // Step 4: Workout Schedule & Duration
  int _selectedFrequencyDays = 4;
  int _selectedDurationMins = 45;

  // Step 5: Nutrition & Diet
  String _selectedDiet = 'High Protein';
  int _calorieTarget = 2400;
  final int _mealsPerDay = 4;

  final List<Map<String, dynamic>> _goalOptions = const [
    {
      'title': 'Build Muscle',
      'subtitle': 'Hypertrophy, muscle density & size',
      'icon': Icons.fitness_center_rounded,
      'badge': 'HYPERTROPHY',
    },
    {
      'title': 'Lose Fat',
      'subtitle': 'Caloric deficit, metabolic burn & lean tone',
      'icon': Icons.local_fire_department_rounded,
      'badge': 'FAT LOSS',
    },
    {
      'title': 'Gain Strength',
      'subtitle': 'Heavy compound power & 1RM progression',
      'icon': Icons.bolt_rounded,
      'badge': 'POWERLIFTING',
    },
    {
      'title': 'Peak Endurance',
      'subtitle': 'Cardiorespiratory stamina & VO2 max',
      'icon': Icons.directions_run_rounded,
      'badge': 'CONDITIONING',
    },
    {
      'title': 'General Longevity',
      'subtitle': 'Joint health, mobility & daily vitality',
      'icon': Icons.favorite_rounded,
      'badge': 'HEALTH',
    },
  ];

  final List<Map<String, dynamic>> _levelOptions = const [
    {
      'title': 'Beginner',
      'subtitle': 'New to structured lifting (< 6 months)',
      'icon': Icons.sentiment_satisfied_alt_rounded,
      'badge': 'FOUNDATION',
    },
    {
      'title': 'Intermediate',
      'subtitle': 'Consistent training background (1 - 3 years)',
      'icon': Icons.trending_up_rounded,
      'badge': 'PROGRESSION',
    },
    {
      'title': 'Advanced',
      'subtitle': 'Dedicated lifter with strong base (3+ years)',
      'icon': Icons.workspace_premium_rounded,
      'badge': 'MASTERY',
    },
    {
      'title': 'Elite Athlete',
      'subtitle': 'Competitive powerlifter, bodybuilder, or coach',
      'icon': Icons.emoji_events_rounded,
      'badge': 'PEAK PERFORMANCE',
    },
  ];

  final List<Map<String, dynamic>> _equipmentOptions = const [
    {
      'id': 'full_commercial',
      'title': 'Full Commercial Gym',
      'subtitle': 'Barbells, dumbbells, cable machines, leg press & racks',
      'icon': Icons.domain_rounded,
      'badge': 'COMPLETE ACCESS',
    },
    {
      'id': 'home_dumbbells',
      'title': 'Home Dumbbells & Bench',
      'subtitle': 'Adjustable dumbbells, flat/incline bench, pull-up bar',
      'icon': Icons.home_rounded,
      'badge': 'HOME GYM',
    },
    {
      'id': 'barbell_rack',
      'title': 'Barbell & Squat Rack',
      'subtitle': 'Power cage, Olympic barbell, plates & bench',
      'icon': Icons.fitness_center_rounded,
      'badge': 'GARAGE GYM',
    },
    {
      'id': 'bodyweight',
      'title': 'Bodyweight & Calisthenics',
      'subtitle': 'Pull-up bar, dip bars, resistance bands & floor',
      'icon': Icons.accessibility_new_rounded,
      'badge': 'NO WEIGHTS',
    },
  ];

  final List<Map<String, dynamic>> _dietOptions = const [
    {
      'title': 'High Protein',
      'subtitle': 'Optimized for lean hypertrophy & accelerated recovery',
      'icon': Icons.egg_alt_outlined,
      'badge': 'MUSCLE GROWTH',
    },
    {
      'title': 'Balanced Clean',
      'subtitle': 'Even macronutrient distribution across whole foods',
      'icon': Icons.restaurant_rounded,
      'badge': 'BALANCED',
    },
    {
      'title': 'Low Carb / Keto',
      'subtitle': 'High healthy fats, moderate protein & minimal sugars',
      'icon': Icons.grain_rounded,
      'badge': 'METABOLIC',
    },
    {
      'title': 'Vegetarian',
      'subtitle': 'Plant-forward nutrition with dairy and eggs',
      'icon': Icons.eco_rounded,
      'badge': 'VEGETARIAN',
    },
    {
      'title': '100% Vegan',
      'subtitle': 'Purely plant-based whole foods & grain proteins',
      'icon': Icons.spa_rounded,
      'badge': 'PLANT BASED',
    },
  ];

  void _nextPage() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    final provider = AppDependencies.instance.profileProvider;
    final profile = provider.userProfile;

    profile.fitnessGoal = _selectedGoal;
    profile.workoutExperience = _selectedLevel;
    profile.dietPreference = _selectedDiet;
    profile['targetCalories'] = _calorieTarget;
    profile['mealsPerDay'] = _mealsPerDay;
    profile['frequencyDays'] = _selectedFrequencyDays;
    profile['durationMinutes'] = _selectedDurationMins;

    await provider.update(profile);

    // Save Equipment Profile
    final UserEquipmentProfile eqProfile;
    if (_selectedEquipmentPreset == 'home_dumbbells') {
      eqProfile = UserEquipmentProfile.homeDumbbellsAndBench();
    } else if (_selectedEquipmentPreset == 'barbell_rack') {
      eqProfile = UserEquipmentProfile(
        userId: 'local_user',
        availableEquipmentIds: const [
          'barbell',
          'bench',
          'pull_up_bar',
          'exercise_mat',
        ],
        updatedAt: DateTime.now(),
      );
    } else if (_selectedEquipmentPreset == 'bodyweight') {
      eqProfile = UserEquipmentProfile.bodyweightCalisthenics();
    } else {
      eqProfile = UserEquipmentProfile.fullCommercialGym();
    }
    await LocalStorage.saveUserEquipmentProfile(eqProfile);

    // Save Memory Preferences
    final currentPref = FitnessMemory.instance.getPreferenceProfile();
    await FitnessMemory.instance.saveProfile(
      currentPref.copyWith(
        preferredWorkoutDurationMinutes: _selectedDurationMins,
        trainingStyle: _selectedGoal.toLowerCase().contains('strength')
            ? 'strength'
            : (_selectedGoal.toLowerCase().contains('endurance')
                  ? 'endurance'
                  : 'hypertrophy'),
        coachPersonalityPreference: 'encouraging',
      ),
    );

    await OnboardingStateService.instance.setCompletedOnboarding(true);
    await LocalStorage.setCompletedOnboarding(true);
    await LocalStorage.setGoalOnboardingCompleted(true);

    if (mounted) {
      final isAuthenticated =
          LocalStorage.isLoggedIn() || FitnessProvider.instance.isAuthenticated;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              isAuthenticated ? const MainShell() : const LoginScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: OnboardingBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with back button and segmented progress (not on Welcome)
              if (_currentStep > 0)
                OnboardingTopBar(
                  step: _currentStep,
                  total: _totalSteps - 1,
                  onBack: _prevPage,
                ),

              // Main Page Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (step) => setState(() => _currentStep = step),
                  children: [
                    _buildStep0Welcome(context),
                    _buildStep1FitnessGoal(context),
                    _buildStep2ExperienceLevel(context),
                    _buildStep3EquipmentProfile(context),
                    _buildStep4WorkoutSchedule(context),
                    _buildStep5NutritionGoal(context),
                    OnboardingPermissionsStep(
                      gateway:
                          widget.permissionGateway ??
                          const PlatformOnboardingPermissions(),
                    ),
                    _buildStep6AICoachIntro(context),
                  ],
                ),
              ),

              // Bottom Continue Action Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton.primary(
                      label: _currentStep == 0
                          ? "LET'S GET STARTED"
                          : (_currentStep == _totalSteps - 1
                                ? 'ENTER DASHBOARD'
                                : 'CONTINUE'),
                      icon: _currentStep == _totalSteps - 1
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: _nextPage,
                    ),
                    if (_currentStep == 6)
                      TextButton(
                        key: const Key('permissions_skip'),
                        onPressed: _nextPage,
                        child: Text(
                          'Skip for now',
                          style: TextStyle(color: context.appTextSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP 0: WELCOME & VALUE PROPOSITION SCREEN
  // ===========================================================================
  Widget _buildStep0Welcome(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          // Atlas AI logo (shared with the splash screen and AI coach)
          const AtlasLogoMark(size: 88, glow: true),
          const SizedBox(height: 24),

          const AtlasWordmark(fontSize: 28, letterSpacing: 1.5),
          const SizedBox(height: 8),

          Text(
            'Your Autonomous Personal Trainer & Nutrition Intelligence',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(
              fontSize: 14,
              color: context.appTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // 3 Feature Showcase Cards
          _buildFeatureCard(
            context: context,
            icon: Icons.fitness_center_rounded,
            title: 'Adaptive Workout Engine',
            description:
                'AI-generated splits calibrated to your equipment, goal, and daily readiness score.',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context: context,
            icon: Icons.camera_alt_rounded,
            title: 'Vision Nutrition Scanner',
            description:
                'Snap a photo or scan barcodes for instant AI calorie, macro, and ingredient tracking.',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context: context,
            icon: Icons.psychology_rounded,
            title: '24/7 AI Strength Coach',
            description:
                'Direct conversational coaching, form corrections, and progressive overload intelligence.',
          ),
          const SizedBox(height: 24),
          AppButton.secondary(
            label: '⚡ TRY SHOWCASE MODE (NO SIGNUP)',
            icon: Icons.play_arrow_rounded,
            onPressed: () async {
              await ShowcaseModeProvider.instance.enableShowcaseMode();
              await OnboardingStateService.instance.setCompletedOnboarding(
                true,
              );
              await LocalStorage.setCompletedOnboarding(true);
              await LocalStorage.setLoggedIn(true);
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MainShell()),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: Text(
              'Already have an account? Log In',
              style: AppTheme.bodyMd.copyWith(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryContainer, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 12,
                    color: context.appTextSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 1: FITNESS GOAL SELECTION
  // ===========================================================================
  Widget _buildStep1FitnessGoal(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingHeader(
            eyebrow: 'GOAL',
            title: "What's your primary goal?",
            subtitle:
                'We optimize your workout split, volume curves, and macro targets accordingly.',
          ),
          const SizedBox(height: 20),

          Column(
            children: _goalOptions.map((opt) {
              final selected = _selectedGoal == opt['title'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSelectionCard(
                  context: context,
                  title: opt['title'] as String,
                  subtitle: opt['subtitle'] as String,
                  badge: opt['badge'] as String,
                  icon: opt['icon'] as IconData,
                  isSelected: selected,
                  onTap: () =>
                      setState(() => _selectedGoal = opt['title'] as String),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 2: EXPERIENCE LEVEL
  // ===========================================================================
  Widget _buildStep2ExperienceLevel(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingHeader(
            eyebrow: 'EXPERIENCE',
            title: 'Lifting Experience',
            subtitle:
                'Helps calibrate progressive overload rate and starting weights.',
          ),
          const SizedBox(height: 20),

          Column(
            children: _levelOptions.map((opt) {
              final selected = _selectedLevel == opt['title'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSelectionCard(
                  context: context,
                  title: opt['title'] as String,
                  subtitle: opt['subtitle'] as String,
                  badge: opt['badge'] as String,
                  icon: opt['icon'] as IconData,
                  isSelected: selected,
                  onTap: () =>
                      setState(() => _selectedLevel = opt['title'] as String),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 3: EQUIPMENT PROFILE SELECTION
  // ===========================================================================
  Widget _buildStep3EquipmentProfile(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingHeader(
            eyebrow: 'EQUIPMENT',
            title: 'Available Equipment',
            subtitle:
                'Your AI Coach will only prescribe exercises matching your gear.',
          ),
          const SizedBox(height: 20),

          Column(
            children: _equipmentOptions.map((opt) {
              final selected = _selectedEquipmentPreset == opt['id'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSelectionCard(
                  context: context,
                  title: opt['title'] as String,
                  subtitle: opt['subtitle'] as String,
                  badge: opt['badge'] as String,
                  icon: opt['icon'] as IconData,
                  isSelected: selected,
                  onTap: () => setState(
                    () => _selectedEquipmentPreset = opt['id'] as String,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 4: WORKOUT SCHEDULE & PREFERENCE
  // ===========================================================================
  Widget _buildStep4WorkoutSchedule(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingHeader(
            eyebrow: 'SCHEDULE',
            title: 'Workout Preference',
            subtitle: 'Customize training frequency and session length.',
          ),
          const SizedBox(height: 24),

          Text(
            'WEEKLY TRAINING FREQUENCY',
            style: AppTheme.labelCaps.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryContainer,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [3, 4, 5, 6].map((days) {
              final isSel = _selectedFrequencyDays == days;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => setState(() => _selectedFrequencyDays = days),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.primaryContainer
                            : context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSel
                              ? AppColors.primaryContainer
                              : context.appOutlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$days',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isSel
                                  ? Colors.black
                                  : context.appTextPrimary,
                            ),
                          ),
                          Text(
                            'Days/wk',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSel
                                  ? Colors.black87
                                  : context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          Text(
            'PREFERRED SESSION DURATION',
            style: AppTheme.labelCaps.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryContainer,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [30, 45, 60, 75].map((mins) {
              final isSel = _selectedDurationMins == mins;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDurationMins = mins),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.primaryContainer
                            : context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSel
                              ? AppColors.primaryContainer
                              : context.appOutlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$mins',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isSel
                                  ? Colors.black
                                  : context.appTextPrimary,
                            ),
                          ),
                          Text(
                            'Minutes',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSel
                                  ? Colors.black87
                                  : context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 5: NUTRITION GOAL & MACROS
  // ===========================================================================
  Widget _buildStep5NutritionGoal(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingHeader(
            eyebrow: 'NUTRITION',
            title: 'Nutrition Strategy',
            subtitle: 'Set your diet style and target daily calorie intake.',
          ),
          const SizedBox(height: 20),

          Column(
            children: _dietOptions.map((opt) {
              final selected = _selectedDiet == opt['title'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSelectionCard(
                  context: context,
                  title: opt['title'] as String,
                  subtitle: opt['subtitle'] as String,
                  badge: opt['badge'] as String,
                  icon: opt['icon'] as IconData,
                  isSelected: selected,
                  onTap: () =>
                      setState(() => _selectedDiet = opt['title'] as String),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Calorie Target Slider Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Daily Calorie Target',
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 14,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_calorieTarget kcal',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _calorieTarget.toDouble(),
                  min: 1500,
                  max: 4000,
                  divisions: 25,
                  activeColor: AppColors.primaryContainer,
                  onChanged: (val) =>
                      setState(() => _calorieTarget = val.toInt()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 6: MEET YOUR AI COACH (FINAL REVIEW)
  // ===========================================================================
  Widget _buildStep6AICoachIntro(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Glowing AI Persona Badge
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: AppColors.primaryContainer,
              size: 54,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Meet Your AI Coach',
            style: AppTheme.headlineLg.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            '"I am ready to adapt your training, monitor your recovery, and keep your nutrition on track."',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Athlete Configuration Summary Checklist
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _buildSummaryRow(context, 'Primary Goal', _selectedGoal),
                const Divider(height: 16),
                _buildSummaryRow(context, 'Experience', _selectedLevel),
                const Divider(height: 16),
                _buildSummaryRow(
                  context,
                  'Schedule',
                  '$_selectedFrequencyDays days/wk • $_selectedDurationMins mins',
                ),
                const Divider(height: 16),
                _buildSummaryRow(
                  context,
                  'Nutrition Plan',
                  '$_selectedDiet • $_calorieTarget kcal',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTheme.headlineMd.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SHARED SELECTION CARD WIDGET
  // ===========================================================================
  Widget _buildSelectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AppAnimation.scaleBounce(
      active: isSelected,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        borderColor: isSelected
            ? AppColors.primaryContainer
            : context.appOutlineVariant.withValues(alpha: 0.3),
        backgroundColor: isSelected
            ? AppColors.secondaryContainer.withValues(alpha: 0.25)
            : null,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryContainer
                    : context.appSurfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.black : context.appTextSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: AppColors.primaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryContainer,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

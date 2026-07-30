import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/local_storage.dart';
import '../main.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  final TextEditingController _nameController = TextEditingController(
    text: 'Alex Rivera',
  );
  String _selectedGender = 'Male';
  DateTime? _selectedBirthdate = DateTime(1998, 5, 14);

  final TextEditingController _heightController = TextEditingController(
    text: '178',
  );
  final TextEditingController _weightController = TextEditingController(
    text: '72.5',
  );
  final TextEditingController _targetWeightController = TextEditingController(
    text: '68.0',
  );
  final double _weeklyGoal = 0.5;

  String _selectedGoal = 'Muscle Gain';
  String _selectedLevel = 'Intermediate';
  String _selectedDiet = 'High Protein';

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  final List<Map<String, dynamic>> _goalOptions = [
    {
      'title': 'Build Muscle',
      'subtitle': 'Hypertrophy & progressive overload',
      'icon': Icons.fitness_center,
    },
    {
      'title': 'Lose Weight',
      'subtitle': 'Caloric deficit & fat loss',
      'icon': Icons.local_fire_department,
    },
    {
      'title': 'Improve Strength',
      'subtitle': 'Heavy compound lifts & power',
      'icon': Icons.bolt,
    },
    {
      'title': 'Increase Endurance',
      'subtitle': 'Stamina & cardiovascular health',
      'icon': Icons.directions_run,
    },
    {
      'title': 'General Fitness',
      'subtitle': 'Overall health & mobility',
      'icon': Icons.favorite,
    },
  ];

  final List<Map<String, dynamic>> _levelOptions = [
    {
      'title': 'Beginner',
      'subtitle': 'New to structured lifting (< 6 months)',
      'icon': Icons.sentiment_satisfied_alt,
    },
    {
      'title': 'Intermediate',
      'subtitle': 'Consistent training (1 - 3 years)',
      'icon': Icons.trending_up,
    },
    {
      'title': 'Advanced',
      'subtitle': 'Experienced lifter (3+ years)',
      'icon': Icons.workspace_premium,
    },
    {
      'title': 'Expert',
      'subtitle': 'Competitive athlete or coach',
      'icon': Icons.emoji_events,
    },
  ];

  final List<Map<String, dynamic>> _dietOptions = [
    {
      'title': 'High Protein',
      'subtitle': 'Optimized for muscle growth & recovery',
      'icon': Icons.egg_alt_outlined,
    },
    {
      'title': 'No Preference',
      'subtitle': 'Balanced macros across food groups',
      'icon': Icons.restaurant,
    },
    {
      'title': 'Low Carb',
      'subtitle': 'Ketogenic / reduced carbohydrate',
      'icon': Icons.grain,
    },
    {
      'title': 'Vegetarian',
      'subtitle': 'Plant-based with dairy and eggs',
      'icon': Icons.eco,
    },
    {
      'title': 'Vegan',
      'subtitle': '100% plant-based nutrition',
      'icon': Icons.spa,
    },
  ];

  void _nextPage() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    final provider = AppDependencies.instance.profileProvider;
    final profile = provider.userProfile;

    profile.name = _nameController.text.trim();
    profile.gender = _selectedGender;
    if (_selectedBirthdate != null) {
      profile.dob = _selectedBirthdate!.toIso8601String().split('T')[0];
    } else {
      profile.dob = '1998-01-01';
    }
    profile.weight = _weightController.text.trim();
    profile.height = _heightController.text.trim();
    profile.fitnessGoal = _selectedGoal;
    profile.workoutExperience = _selectedLevel;
    profile.dietPreference = _selectedDiet;

    profile['targetWeight'] =
        double.tryParse(_targetWeightController.text) ?? 68.0;
    profile['weeklyGoal'] = _weeklyGoal;

    await provider.update(profile);
    await LocalStorage.setLoggedIn(true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainShell()),
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
            // Top Navigation & Step Indicator Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _currentStep > 0 ? _prevPage : null,
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
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      minHeight: 4,
                      backgroundColor: context.appSurfaceElevated,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page View Form Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentStep = idx),
                children: [
                  _buildStep1PersonalInfo(context),
                  _buildStep2BodyMetrics(context),
                  _buildStep3FitnessGoal(context),
                  _buildStep4Experience(context),
                  _buildStep5DietPreference(context),
                ],
              ),
            ),

            // Bottom Action Bar
            Padding(
              padding: const EdgeInsets.all(20),
              child: AppButton.primary(
                label: _currentStep == _totalSteps - 1
                    ? 'Complete Setup'
                    : 'Continue',
                onPressed: _nextPage,
                isPill: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 1: Personal Info
  Widget _buildStep1PersonalInfo(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Aizawl Gym',
            style: AppTheme.headlineLg.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Let us customize your training and nutrition protocol.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 28),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    filled: true,
                    fillColor: context.appSurfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Gender',
                  style: AppTheme.labelCaps.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: _genderOptions.map((g) {
                    final selected = _selectedGender == g;
                    return ChoiceChip(
                      label: Text(g),
                      selected: selected,
                      selectedColor: AppColors.secondaryContainer,
                      onSelected: (val) => setState(() => _selectedGender = g),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                Text(
                  'Date of Birth',
                  style: AppTheme.labelCaps.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedBirthdate ?? DateTime(1998, 1, 1),
                      firstDate: DateTime(1940),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _selectedBirthdate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: context.appSurfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedBirthdate != null
                              ? DateFormat(
                                  'MMMM dd, yyyy',
                                ).format(_selectedBirthdate!)
                              : 'Select Date of Birth',
                          style: AppTheme.bodyMd.copyWith(
                            color: context.appTextPrimary,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 2: Body Metrics
  Widget _buildStep2BodyMetrics(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Body Measurements',
            style: AppTheme.headlineLg.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Accurate metrics help calculate your basal metabolic rate.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 28),

          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Height (cm)',
                          filled: true,
                          fillColor: context.appSurfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Current Weight (kg)',
                          filled: true,
                          fillColor: context.appSurfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _targetWeightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Target Weight (kg)',
                    filled: true,
                    fillColor: context.appSurfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 3: Fitness Goal
  Widget _buildStep3FitnessGoal(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What is your primary goal?',
            style: AppTheme.headlineLg.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'We will align your daily caloric target & training split.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 24),

          Column(
            children: _goalOptions.map((opt) {
              final selected = _selectedGoal == opt['title'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSelectionCard(
                  context: context,
                  title: opt['title'],
                  subtitle: opt['subtitle'],
                  icon: opt['icon'],
                  isSelected: selected,
                  onTap: () => setState(() => _selectedGoal = opt['title']),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Step 4: Experience Level
  Widget _buildStep4Experience(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workout Experience',
            style: AppTheme.headlineLg.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Helps calibrate workout volume and progressive overload rate.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 24),

          Column(
            children: _levelOptions.map((opt) {
              final selected = _selectedLevel == opt['title'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSelectionCard(
                  context: context,
                  title: opt['title'],
                  subtitle: opt['subtitle'],
                  icon: opt['icon'],
                  isSelected: selected,
                  onTap: () => setState(() => _selectedLevel = opt['title']),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Step 5: Diet Preference
  Widget _buildStep5DietPreference(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dietary Preference',
            style: AppTheme.headlineLg.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Customizes macro splits and meal recommendations.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 24),

          Column(
            children: _dietOptions.map((opt) {
              final selected = _selectedDiet == opt['title'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSelectionCard(
                  context: context,
                  title: opt['title'],
                  subtitle: opt['subtitle'],
                  icon: opt['icon'],
                  isSelected: selected,
                  onTap: () => setState(() => _selectedDiet = opt['title']),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AppCard(
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
                  ? context.appPrimary
                  : context.appSurfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? AppColors.onPrimary
                  : context.appTextSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 16,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 22,
            ),
        ],
      ),
    );
  }
}

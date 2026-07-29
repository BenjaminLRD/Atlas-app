import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../data/local_storage.dart';
import '../data/profile_provider.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Step 1: Personal
  final _nameController = TextEditingController(text: 'New User');
  DateTime? _selectedBirthdate;
  String _selectedGender = 'Male';

  // Step 2: Physical
  final _weightController = TextEditingController(text: '70');
  final _heightController = TextEditingController(text: '170');
  final _targetWeightController = TextEditingController(text: '68');

  // Step 3: Goal
  String _selectedGoal = 'Build Muscle';

  // Step 4: Fitness & Experience
  String _selectedLevel = 'Intermediate';
  double _weeklyGoal = 4.0;

  // Step 5: Nutrition & Diet
  String _selectedDiet = 'No Preference';

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

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
    final provider = ProfileProvider();
    final profile = provider.userProfile;

    profile.name = _nameController.text.trim();
    profile.gender = _selectedGender;
    if (_selectedBirthdate != null) {
      profile.dob = _selectedBirthdate!.toIso8601String().split('T')[0];
    } else {
      profile.dob = '1998-01-01'; // fallback default
    }
    profile.weight = _weightController.text.trim();
    profile.height = _heightController.text.trim();
    profile.fitnessGoal = _selectedGoal;
    profile.workoutExperience = _selectedLevel;
    profile.dietPreference = _selectedDiet;
    profile.profilePic = '';

    // Save extra fields for onboarding tracking
    profile['targetWeight'] = double.tryParse(_targetWeightController.text) ?? 68.0;
    profile['weeklyGoal'] = _weeklyGoal.toInt();

    await provider.update(profile);
    await LocalStorage.setLoggedIn(true);

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
                      onPressed: _prevPage,
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Step ${_currentStep + 1} of $_totalSteps',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _totalSteps,
                  backgroundColor: AppColors.primaryFixed.withValues(alpha: 0.3),
                  color: AppColors.primary,
                  minHeight: 6,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Form Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentStep = page;
                  });
                },
                children: [
                  _buildStepPersonal(),
                  _buildStepPhysical(),
                  _buildStepGoal(),
                  _buildStepFitness(),
                  _buildStepNutrition(),
                ],
              ),
            ),

            // Bottom Navigation Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _currentStep == _totalSteps - 1
                              ? 'Get Started'
                              : 'Continue',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 1: Personal ---
  Widget _buildStepPersonal() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us about yourself',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We use this to customize recommendations for workouts and calorie tracking.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),

          // Name field
          Text(
            'Full Name',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: _inputDecoration(
              hint: 'Enter your full name',
              icon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 24),

          // Birthdate field
          Text(
            'Birthdate',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
                firstDate: DateTime(1940),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).brightness == Brightness.dark
                          ? const ColorScheme.dark(
                              primary: AppColors.primary,
                              onPrimary: AppColors.onPrimary,
                              onSurface: AppColors.onSurface,
                            )
                          : const ColorScheme.light(
                              primary: AppColors.primary,
                              onPrimary: AppColors.onPrimary,
                              onSurface: AppColors.onSurface,
                            ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                setState(() {
                  _selectedBirthdate = date;
                });
              }
            },
            child: Builder(
              builder: (context) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined, color: AppColors.onSurfaceVariant, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _selectedBirthdate == null
                        ? 'Select your birthday'
                        : DateFormat('MMM dd, yyyy').format(_selectedBirthdate!),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _selectedBirthdate == null
                          ? AppColors.outline
                          : AppColors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down, color: AppColors.onSurfaceVariant),
                ],
              ),
            ),
          ),
          ),
          const SizedBox(height: 24),

          // Gender field
          Text(
            'Gender Identity',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return ToggleButtons(
                borderWidth: 1.5,
                borderColor: AppColors.outlineVariant,
                selectedBorderColor: AppColors.primary,
                fillColor: AppColors.primaryFixed.withValues(alpha: 0.4),
                selectedColor: AppColors.primary,
                color: AppColors.onSurfaceVariant,
                borderRadius: BorderRadius.circular(10),
                constraints: BoxConstraints.expand(
                  width: (constraints.maxWidth - 6) / 3,
                  height: 48,
                ),
                isSelected: [
                  _selectedGender == 'Male',
                  _selectedGender == 'Female',
                  _selectedGender == 'Other',
                ],
                onPressed: (index) {
                  setState(() {
                    if (index == 0) _selectedGender = 'Male';
                    if (index == 1) _selectedGender = 'Female';
                    if (index == 2) _selectedGender = 'Other';
                  });
                },
                children: const [
                  Text('Male', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('Female', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('Other', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Step 2: Physical ---
  Widget _buildStepPhysical() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your body metrics',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please input your physical measurement metrics below.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),

          // Height with Stepper
          Text(
            'Height (cm)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    hint: 'Height',
                    icon: Icons.height,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: () {
                  final val = int.tryParse(_heightController.text) ?? 170;
                  _heightController.text = (val - 1).toString();
                },
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryFixed,
                  foregroundColor: AppColors.primary,
                ),
              ),
              IconButton.filledTonal(
                onPressed: () {
                  final val = int.tryParse(_heightController.text) ?? 170;
                  _heightController.text = (val + 1).toString();
                },
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryFixed,
                  foregroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Weight
          Text(
            'Current Weight (kg)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(
              hint: 'Current Weight',
              icon: Icons.scale_outlined,
            ),
          ),
          const SizedBox(height: 24),

          // Target Weight
          Text(
            'Target Weight (kg)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _targetWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(
              hint: 'Target weight goal',
              icon: Icons.track_changes_outlined,
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 3: Goal ---
  Widget _buildStepGoal() {
    final goals = [
      {'title': 'Lose Weight', 'desc': 'Burn fat and get leaner', 'icon': Icons.trending_down},
      {'title': 'Build Muscle', 'desc': 'Gain strength and mass', 'icon': Icons.bolt},
      {'title': 'Maintain Weight', 'desc': 'Stay active and keep fit', 'icon': Icons.favorite_border},
      {'title': 'Improve Fitness', 'desc': 'Enhance stamina and health', 'icon': Icons.speed},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What is your primary goal?',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your path will be optimized based on your choice.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          ...goals.map((goal) {
            final isSelected = _selectedGoal == goal['title'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedGoal = goal['title'] as String;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryFixed.withValues(alpha: 0.4)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          goal['icon'] as IconData,
                          color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal['title'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              goal['desc'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- Step 4: Fitness & Experience ---
  Widget _buildStepFitness() {
    final levels = [
      {'title': 'Beginner', 'desc': 'Just starting out / low fitness level'},
      {'title': 'Intermediate', 'desc': 'Active workout background / some weight training'},
      {'title': 'Advanced', 'desc': 'Heavy lifter / athletic performance focused'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your workout experience',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We will select appropriate baseline exercises for you.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Current Experience Level',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          ...levels.map((level) {
            final isSelected = _selectedLevel == level['title'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () {
                  setState(() {
                    _selectedLevel = level['title']!;
                  });
                },
                tileColor: isSelected
                    ? AppColors.primaryFixed.withValues(alpha: 0.4)
                    : Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                leading: Radio<String>(
                  value: level['title']!,
                  groupValue: _selectedLevel,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      _selectedLevel = val!;
                    });
                  },
                ),
                title: Text(
                  level['title']!,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  level['desc']!,
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ),
            );
          }),

          const SizedBox(height: 28),

          // Slider for days
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Workout Target',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              Chip(
                label: Text(
                  '${_weeklyGoal.toInt()} Days',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                backgroundColor: AppColors.primaryFixed,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.outlineVariant,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _weeklyGoal,
              min: 1.0,
              max: 7.0,
              divisions: 6,
              label: '${_weeklyGoal.toInt()} days',
              onChanged: (val) {
                setState(() {
                  _weeklyGoal = val;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 5: Nutrition & Diet ---
  Widget _buildStepNutrition() {
    final diets = [
      {'title': 'Vegetarian', 'desc': 'Plant-based foods, dairy, eggs, no meat', 'icon': Icons.eco_outlined},
      {'title': 'Vegan', 'desc': 'Pure plant-based diet, no animal products', 'icon': Icons.grass_outlined},
      {'title': 'Non-Veg', 'desc': 'Meat, fish, poultry included', 'icon': Icons.restaurant_outlined},
      {'title': 'No Preference', 'desc': 'Standard regular meal variety', 'icon': Icons.lunch_dining_outlined},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nutrition preference',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your preference to personalize your macros and recipe options.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),

          ...diets.map((diet) {
            final isSelected = _selectedDiet == diet['title'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedDiet = diet['title'] as String;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryFixed.withValues(alpha: 0.4)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          diet['icon'] as IconData,
                          color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              diet['title'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              diet['desc'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

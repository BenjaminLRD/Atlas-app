import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/subscription_plan.dart';
import '../providers/fitness_provider.dart';
import '../services/billing/demo_plan_store.dart';
import '../services/profile_photo_store.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/profile_provider.dart';
import 'subscription_screen.dart';
import '../widgets/common/app_header.dart';
import '../widgets/profile_picture.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final ProfileProvider _profileProvider;
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _profile;
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _targetWeightController;
  bool _isLoading = false;

  // Units and options
  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];
  final List<String> _fitnessGoalOptions = [
    'Build Muscle',
    'Lose Weight',
    'Improve Strength',
    'Increase Endurance',
    'General Fitness',
    'Get Stronger',
  ];
  final List<String> _workoutExperienceOptions = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert',
  ];
  final List<String> _workoutDaysOptions = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final List<String> _dietPreferenceOptions = [
    'No Preference',
    'High Protein',
    'Low Carb',
    'Vegetarian',
    'Vegan',
    'Keto',
  ];

  @override
  void initState() {
    super.initState();
    _profileProvider = AppDependencies.instance.profileProvider;
    _loadProfile();
  }

  void _loadProfile() {
    final profile = Map<String, dynamic>.from(_profileProvider.profile);
    setState(() {
      _profile = profile;
      _nameController = TextEditingController(text: profile['name'] ?? '');
      _bioController = TextEditingController(text: profile['bio'] ?? '');
      _emailController = TextEditingController(text: profile['email'] ?? '');
      _phoneController = TextEditingController(text: profile['phone'] ?? '');
      _heightController = TextEditingController(
        text: profile['height']?.toString() ?? '',
      );
      _weightController = TextEditingController(
        text: profile['weight']?.toString() ?? '',
      );
      _targetWeightController = TextEditingController(
        text: profile['targetWeight']?.toString() ?? '',
      );
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        final savedPath = await ProfilePhotoStore.persist(image.path);
        if (!mounted) return;
        setState(() {
          _profile['profilePic'] = savedPath;
        });
        await _profileProvider.updateField('profilePic', savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  int _calculateAgeFromDob(String? dobString) {
    if (dobString == null || dobString.isEmpty) return 0;
    try {
      final dob = DateTime.parse(dobString);
      final today = DateTime.now();
      int age = today.year - dob.year;
      if (today.month < dob.month ||
          (today.month == dob.month && today.day < dob.day)) {
        age--;
      }
      return age > 0 ? age : 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final calculatedAge = _calculateAgeFromDob(_profile['dob'] as String?);

    return Scaffold(
      appBar: AppHeader.back(
        title: 'Edit Profile',
        onBackTap: () => Navigator.maybePop(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Picture Avatar Card
                    Center(
                      child: Stack(
                        children: [
                          ProfileImage(
                            path: _profile['profilePic'],
                            size: 110,
                            iconSize: 54,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SECTION 1: IDENTITY & PROFILE
                    _buildSectionHeader(
                      icon: Icons.badge_outlined,
                      title: 'Identity & Profile',
                    ),
                    const SizedBox(height: 12),
                    _buildCardContainer(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Display Name / Full Name',
                          hint: 'Enter your name',
                          icon: Icons.person_rounded,
                          required: true,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _bioController,
                          label: 'Bio / Fitness Motto (Optional)',
                          hint: 'e.g. Dedicated powerlifter & hybrid athlete',
                          icon: Icons.short_text_rounded,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'Enter your email address',
                          icon: Icons.email_rounded,
                          required: true,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Phone Number (Optional)',
                          hint: 'Enter your phone number',
                          icon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION 2: PERSONAL INFORMATION
                    _buildSectionHeader(
                      icon: Icons.person_outline_rounded,
                      title: 'Personal Information',
                    ),
                    const SizedBox(height: 12),
                    _buildCardContainer(
                      children: [
                        _buildDatePicker(),
                        if (calculatedAge > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.cake_outlined,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Calculated Age: $calculatedAge years old',
                                style: AppTheme.bodySm.copyWith(
                                  color: context.appTextSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        _buildDropdownField(
                          label: 'Gender',
                          value: _profile['gender'] as String?,
                          hintText: 'Select gender',
                          options: _genderOptions,
                          icon: Icons.wc_rounded,
                          onChanged: (value) {
                            setState(() {
                              _profile['gender'] = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION 3: BODY METRICS
                    _buildSectionHeader(
                      icon: Icons.straighten_rounded,
                      title: 'Body Metrics & Units',
                    ),
                    const SizedBox(height: 12),
                    _buildCardContainer(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _heightController,
                                label: 'Height',
                                hint: '175',
                                icon: Icons.height_rounded,
                                keyboardType: TextInputType.number,
                                unit: Text(
                                  _profile['lengthUnit'] ?? 'cm',
                                  style: AppTheme.bodyMd.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _weightController,
                                label: 'Weight',
                                hint: '75.0',
                                icon: Icons.monitor_weight_rounded,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                unit: Text(
                                  _profile['massUnit'] ?? 'kg',
                                  style: AppTheme.bodyMd.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _targetWeightController,
                          label: 'Target Weight (Optional Goal)',
                          hint: '78.0',
                          icon: Icons.flag_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          unit: Text(
                            _profile['massUnit'] ?? 'kg',
                            style: AppTheme.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildUnitSelector(),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION 4: FITNESS PREFERENCES
                    _buildSectionHeader(
                      icon: Icons.fitness_center_rounded,
                      title: 'Fitness Preferences',
                    ),
                    const SizedBox(height: 12),
                    _buildCardContainer(
                      children: [
                        _buildDropdownField(
                          label: 'Fitness Goal',
                          value: _profile['fitnessGoal'] as String?,
                          hintText: 'Select primary goal',
                          options: _fitnessGoalOptions,
                          icon: Icons.track_changes_rounded,
                          onChanged: (value) {
                            setState(() {
                              _profile['fitnessGoal'] = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildDropdownField(
                          label: 'Workout Experience',
                          value: _profile['workoutExperience'] as String?,
                          hintText: 'Select experience level',
                          options: _workoutExperienceOptions,
                          icon: Icons.timeline_rounded,
                          onChanged: (value) {
                            setState(() {
                              _profile['workoutExperience'] = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildMultiSelectField(
                          label: 'Preferred Workout Days',
                          value:
                              _profile['preferredDays'] as List<dynamic>? ?? [],
                          options: _workoutDaysOptions,
                          icon: Icons.calendar_month_rounded,
                          onChanged: (value) {
                            setState(() {
                              _profile['preferredDays'] = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION 5: NUTRITION & PREFERENCES
                    _buildSectionHeader(
                      icon: Icons.restaurant_menu_rounded,
                      title: 'Nutrition & Preferences',
                    ),
                    const SizedBox(height: 12),
                    _buildCardContainer(
                      children: [
                        _buildDropdownField(
                          label: 'Diet Preference',
                          value: _profile['dietPreference'] as String?,
                          hintText: 'Select diet preference',
                          options: _dietPreferenceOptions,
                          icon: Icons.restaurant_rounded,
                          onChanged: (value) {
                            setState(() {
                              _profile['dietPreference'] = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSwitchField(
                          label: 'Workout & Habit Notifications',
                          value:
                              _profile['notificationsEnabled'] as bool? ?? true,
                          icon: Icons.notifications_active_rounded,
                          onChanged: (value) {
                            setState(() {
                              _profile['notificationsEnabled'] = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION 6: SUBSCRIPTION & MEMBERSHIP
                    _buildSectionHeader(
                      icon: Icons.card_membership_rounded,
                      title: 'Subscription & Membership',
                    ),
                    const SizedBox(height: 12),
                    _buildCardContainer(
                      children: [_buildSubscriptionSection()],
                    ),
                    const SizedBox(height: 28),

                    // SAVE / CANCEL ACTION ROW
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveProfile,
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.appTextPrimary,
                            side: BorderSide(color: context.appOutlineVariant),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTheme.headlineMd.copyWith(
              color: context.appTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    bool enabled = true,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Widget? unit,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : context.appOutlineVariant,
        ),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: AppTheme.bodyMd.copyWith(
          color: context.appTextPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTheme.bodySm.copyWith(
            color: context.appTextSecondary,
            fontWeight: FontWeight.w500,
          ),
          hintText: hint,
          hintStyle: AppTheme.bodySm.copyWith(
            color: context.appTextSecondary.withValues(alpha: 0.6),
          ),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          suffix: unit != null
              ? Padding(padding: const EdgeInsets.only(right: 12), child: unit)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String hintText,
    required List<String> options,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : context.appOutlineVariant,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: DropdownButtonFormField<String>(
        initialValue: (value != null && options.contains(value)) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTheme.bodySm.copyWith(
            color: context.appTextSecondary,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        hint: Text(
          hintText,
          style: AppTheme.bodySm.copyWith(
            color: context.appTextSecondary.withValues(alpha: 0.6),
          ),
        ),
        isExpanded: true,
        dropdownColor: context.appSurface,
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(
              option,
              style: AppTheme.bodyMd.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : context.appOutlineVariant,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: InkWell(
        onTap: () async {
          DateTime initialDate = DateTime.now();
          if (_profile['dob'] != null && _profile['dob'].isNotEmpty) {
            try {
              initialDate = DateTime.parse(_profile['dob']);
            } catch (_) {}
          }
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            setState(() {
              _profile['dob'] = picked.toIso8601String().split('T')[0];
            });
          }
        },
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date of Birth',
                    style: AppTheme.bodySm.copyWith(
                      color: context.appTextSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _profile['dob'] != null && _profile['dob'].isNotEmpty
                        ? _formatDate(_profile['dob'])
                        : 'Select date of birth',
                    style: AppTheme.bodyMd.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.appTextSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectField({
    required String label,
    required List<dynamic> value,
    required List<String> options,
    required IconData icon,
    required Function(List<String>) onChanged,
  }) {
    final List<String> selectedList = value.map((e) => e.toString()).toList();

    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : context.appOutlineVariant,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.bodySm.copyWith(
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((option) {
              final isSelected = selectedList.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : context.appTextPrimary,
                ),
                backgroundColor: context.appSurface,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : context.appOutlineVariant,
                ),
                onSelected: (selected) {
                  final updated = List<String>.from(selectedList);
                  if (selected) {
                    updated.add(option);
                  } else {
                    updated.remove(option);
                  }
                  onChanged(updated);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelector() {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : context.appOutlineVariant,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Units System',
                  style: AppTheme.bodyMd.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Metric (kg/cm)'),
                selected: _profile['massUnit'] == 'kg',
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _profile['massUnit'] == 'kg'
                      ? Colors.white
                      : context.appTextSecondary,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _profile['massUnit'] = 'kg';
                      _profile['lengthUnit'] = 'cm';
                    });
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Imperial (lbs/in)'),
                selected: _profile['massUnit'] == 'lbs',
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _profile['massUnit'] == 'lbs'
                      ? Colors.white
                      : context.appTextSecondary,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _profile['massUnit'] = 'lbs';
                      _profile['lengthUnit'] = 'in';
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchField({
    required String label,
    required bool value,
    required IconData icon,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : context.appOutlineVariant,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: AppTheme.bodyMd.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    // The plan actually in use: a store subscription is Pro; otherwise the
    // demo plan chosen on the Plans page (labelled), else Free.
    final real = FitnessProvider.instance.isPremium;
    final demo = DemoPlanStore.instance.demoTier;
    final currentSubscription = real
        ? 'Atlas Pro'
        : (demo == PlanTier.free
              ? 'Free'
              : '${PlanCatalog.of(demo).name} (demo)');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Current Tier: $currentSubscription',
                style: AppTheme.bodyMd.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Manage Plan', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      return "${_getMonthAbbreviation(date.month)} ${date.day}, ${date.year}";
    } catch (_) {
      return dateString;
    }
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month >= 1 && month <= 12) return months[month];
    return '';
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        _profile['name'] = _nameController.text.trim();
        _profile['bio'] = _bioController.text.trim();
        _profile['email'] = _emailController.text.trim();
        _profile['phone'] = _phoneController.text.trim();
        _profile['height'] = _heightController.text.trim();
        _profile['weight'] = _weightController.text.trim();
        _profile['targetWeight'] = _targetWeightController.text.trim();

        await _profileProvider.update(_profile);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile saved successfully! 🎉'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving profile: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}

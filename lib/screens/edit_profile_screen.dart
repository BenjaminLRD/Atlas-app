import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/profile_provider.dart';
import 'payment_screen.dart';
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
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  bool _isLoading = false;

  // Units and options
  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];
  final List<String> _fitnessGoalOptions = [
    'Build Muscle',
    'Lose Weight',
    'Improve Strength',
    'Increase Endurance',
    'General Fitness',
    'Get Stronger'
  ];
  final List<String> _workoutExperienceOptions = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert'
  ];
  final List<String> _workoutDaysOptions = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  final List<String> _dietPreferenceOptions = [
    'No Preference',
    'High Protein',
    'Low Carb',
    'Vegetarian',
    'Vegan',
    'Keto'
  ];

  @override
  void initState() {
    super.initState();
    _profileProvider = AppDependencies.instance.profileProvider;
    _loadProfile();
  }

  void _loadProfile() {
    // Always read from the provider — single source of truth
    final profile = Map<String, dynamic>.from(_profileProvider.profile);
    setState(() {
      _profile = profile;
      _nameController = TextEditingController(text: profile['name'] ?? '');
      _emailController = TextEditingController(text: profile['email'] ?? '');
      _phoneController = TextEditingController(text: profile['phone'] ?? '');
      _heightController = TextEditingController(text: profile['height']?.toString() ?? '');
      _weightController = TextEditingController(text: profile['weight']?.toString() ?? '');
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
        setState(() {
          _profile['profilePic'] = image.path;
        });
        // Update provider → persists to LocalStorage + notifies all listeners
        await _profileProvider.updateField('profilePic', image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Picture Section
                    Center(
                      child: Stack(
                        children: [
                          ProfileImage(
                            path: _profile['profilePic'],
                            size: 120,
                            iconSize: 60,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.onPrimary,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: AppColors.onPrimary,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Basic Information Section
                    _buildSectionTitle('Basic Information'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      icon: Icons.person,
                      required: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'Enter your email address',
                      icon: Icons.email,
                      required: true,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number (Optional)',
                      hint: 'Enter your phone number',
                      icon: Icons.phone,
                    ),
                    const SizedBox(height: 24),

                    // Physical Information Section
                    _buildSectionTitle('Physical Information'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _heightController,
                            label: 'Height',
                            hint: '175',
                            icon: Icons.height,
                            keyboardType: TextInputType.number,
                            unit: Text('cm', style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _weightController,
                            label: 'Weight',
                            hint: '68.2',
                            icon: Icons.monitor_weight,
                            keyboardType: TextInputType.number,
                            unit: Text('kg', style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'Gender',
                      value: _profile['gender'] as String? ?? 'Male',
                      options: _genderOptions,
                      icon: Icons.person_outline,
                      onChanged: (value) {
                        setState(() {
                          _profile['gender'] = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDatePicker(),
                    const SizedBox(height: 24),

                    // Fitness Information Section
                    _buildSectionTitle('Fitness Information'),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'Fitness Goal',
                      value: _profile['fitnessGoal'] as String? ?? 'Build Muscle',
                      options: _fitnessGoalOptions,
                      icon: Icons.fitness_center,
                      onChanged: (value) {
                        setState(() {
                          _profile['fitnessGoal'] = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'Workout Experience',
                      value: _profile['workoutExperience'] as String? ?? 'Intermediate',
                      options: _workoutExperienceOptions,
                      icon: Icons.timeline,
                      onChanged: (value) {
                        setState(() {
                          _profile['workoutExperience'] = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMultiSelectField(
                      label: 'Preferred Workout Days',
                      value: _profile['preferredDays'] as List<dynamic>? ?? [],
                      options: _workoutDaysOptions,
                      icon: Icons.calendar_today,
                      onChanged: (value) {
                        setState(() {
                          _profile['preferredDays'] = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'Diet Preference',
                      value: _profile['dietPreference'] as String? ?? 'High Protein',
                      options: _dietPreferenceOptions,
                      icon: Icons.restaurant,
                      onChanged: (value) {
                        setState(() {
                          _profile['dietPreference'] = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildUnitSelector(),
                    const SizedBox(height: 24),

                    // Subscription & Privacy Section
                    _buildSectionTitle('Subscription & Privacy'),
                    const SizedBox(height: 16),
                    _buildSubscriptionSection(),
                    const SizedBox(height: 16),
                    _buildSwitchField(
                      label: 'Enable Notifications',
                      value: _profile['notificationsEnabled'] as bool? ?? true,
                      icon: Icons.notifications,
                      onChanged: (value) {
                        setState(() {
                          _profile['notificationsEnabled'] = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveProfile,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Changes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainer,
                            foregroundColor: AppColors.onSurface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTheme.headlineMd.copyWith(
        color: AppColors.onSurface,
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
    TextInputType keyboardType = TextInputType.text,
    Widget? unit,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.1),
        ),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary),
          suffix: unit != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: unit,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
        validator: required
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
            : null,
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildDatePicker() {
    final dobStr = (_profile['dob'] as String?) ?? '';
    DateTime? parsedDob;
    try {
      if (dobStr.isNotEmpty) parsedDob = DateTime.parse(dobStr);
    } catch (_) {}
    final initialDate = parsedDob ?? DateTime(1995, 1, 1);

    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            _profile['dob'] = picked.toIso8601String().split('T')[0];
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.outline.withValues(alpha: 0.1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  'Date of Birth',
                  style: AppTheme.bodyMd,
                ),
              ],
            ),
            Text(
              parsedDob != null ? _formatDate(dobStr) : 'Not set',
              style: AppTheme.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> options,
    required IconData icon,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
          isExpanded: true,
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
          items: options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(option, style: AppTheme.bodyMd),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMultiSelectField({
    required String label,
    required List<dynamic> value,
    required List<String> options,
    required IconData icon,
    required Function(List<dynamic>) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(label, style: AppTheme.bodyMd),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = value.contains(option);
              return GestureDetector(
                onTap: () {
                  final newValue = List<dynamic>.from(value);
                  if (isSelected) {
                    newValue.remove(option);
                  } else {
                    newValue.add(option);
                  }
                  onChanged(newValue);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option,
                        style: AppTheme.bodySm.copyWith(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                ),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten, color: AppColors.primary),
              const SizedBox(width: 12),
              Text('Units', style: AppTheme.bodyMd),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildUnitOption(
                  label: 'Weight',
                  current: _profile['massUnit'] as String? ?? 'kg',
                  option1: 'kg',
                  option2: 'lbs',
                  onChanged: (val) {
                    setState(() {
                      _profile['massUnit'] = val;
                      _weightController.text = _weightController.text;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildUnitOption(
                  label: 'Height',
                  current: _profile['lengthUnit'] as String? ?? 'cm',
                  option1: 'cm',
                  option2: 'ft',
                  onChanged: (val) {
                    setState(() {
                      _profile['lengthUnit'] = val;
                      _heightController.text = _heightController.text;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitOption({
    required String label,
    required String current,
    required String option1,
    required String option2,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.labelCaps.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: current == option1
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: current == option1
                          ? AppColors.primary
                          : AppColors.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                       Text(
                        option1,
                        style: AppTheme.bodySm.copyWith(
                          fontWeight: current == option1
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: current == option1
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (current == option1) ...[
                        const SizedBox(height: 4),
                        Icon(Icons.check, size: 14, color: AppColors.primary),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option2),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: current == option2
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: current == option2
                          ? AppColors.primary
                          : AppColors.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        option2,
                        style: AppTheme.bodySm.copyWith(
                          fontWeight: current == option2
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: current == option2
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (current == option2) ...[
                        const SizedBox(height: 4),
                        Icon(Icons.check, size: 14, color: AppColors.primary),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubscriptionSection() {
    final currentPlan = (_profile['subscription'] as String?) ?? 'Pro';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_membership, color: AppColors.primary),
              const SizedBox(width: 12),
              Text('Subscription Plan', style: AppTheme.bodyMd),
            ],
          ),
          const SizedBox(height: 16),
          _buildSubscriptionOption(
            title: 'Free',
            price: '₹0/month',
            features: [
              'Limited workout plans',
              'Basic progress tracking',
              '7-day chat history access',
            ],
            isSelected: _profile['subscription'] == 'Free',
            isActivePlan: currentPlan == 'Free',
          ),
          const SizedBox(height: 12),
          _buildSubscriptionOption(
            title: 'Pro',
            price: '₹499/month',
            features: [
              'Unlimited workouts & plans',
              'Advanced analytics & insights',
              'Unlimited chat history',
              'Custom nutrition plans',
            ],
            isSelected: _profile['subscription'] == 'Pro',
            isActivePlan: currentPlan == 'Pro',
            isPopular: true,
          ),
          const SizedBox(height: 12),
          _buildSubscriptionOption(
            title: 'Premium',
            price: '₹999/month',
            features: [
              'Everything in Pro',
              'Personalized AI coaching',
              '1-on-1 trainer support',
              'Advanced performance metrics',
              'Priority support',
            ],
            isSelected: _profile['subscription'] == 'Premium',
            isActivePlan: currentPlan == 'Premium',
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOption({
    required String title,
    required String price,
    required List<String> features,
    required bool isSelected,
    required bool isActivePlan,
    bool isPopular = false,
  }) {
    Color cardBg = isSelected
        ? AppColors.primaryFixed.withValues(alpha: 0.08)
        : AppColors.surfaceContainer;
    Color borderColor = isSelected
        ? AppColors.primary
        : (isPopular ? AppColors.tertiary.withValues(alpha: 0.4) : AppColors.outline.withValues(alpha: 0.2));
    double borderWidth = (isSelected || isPopular) ? 2 : 1;

    return GestureDetector(
      onTap: () {
        if (isActivePlan) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You are already subscribed to the $title plan.'),
              backgroundColor: AppColors.primary,
            ),
          );
          return;
        }

        if (title == 'Free') {
          setState(() {
            _profile['subscription'] = 'Free';
          });
          // Update provider → persists to LocalStorage + notifies all listeners
          _profileProvider.update(_profile);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Plan Activated'),
              content: const Text('Free plan has been successfully activated!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              planName: title,
              price: price,
            ),
          ),
        ).then((success) {
          if (success == true) {
            setState(() {
              _profile['subscription'] = title;
            });
            _saveProfile();
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: isPopular
              ? [
                  BoxShadow(
                    color: AppColors.tertiary.withValues(alpha: 0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTheme.headlineMd.copyWith(
                        color: isSelected ? AppColors.primary : AppColors.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isActivePlan)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'CURRENT PLAN',
                          style: AppTheme.labelCaps.copyWith(
                            color: AppColors.onPrimary,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.tertiary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'POPULAR',
                          style: AppTheme.labelCaps.copyWith(
                            color: AppColors.onTertiary,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    price,
                    style: AppTheme.bodySm.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...features.map((feature) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 14,
                          color: isSelected ? AppColors.primary : AppColors.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: AppTheme.bodySm.copyWith(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(label, style: AppTheme.bodyMd),
            ],
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

  String _formatDate(String dateString) {
    final DateTime date = DateTime.parse(dateString);
    return "${_getMonthAbbreviation(date.month)} ${date.day}, ${date.year}";
  }

  String _getMonthAbbreviation(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Flush text-field values into the profile map
        _profile['name'] = _nameController.text.trim();
        _profile['email'] = _emailController.text.trim();
        _profile['phone'] = _phoneController.text.trim();
        _profile['height'] = _heightController.text.trim();
        _profile['weight'] = _weightController.text.trim();

        // Single call: persists to LocalStorage + notifies all listeners
        await _profileProvider.update(_profile);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile saved successfully!'),
              backgroundColor: AppColors.primary,
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
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../widgets/common/app_card.dart';

class BodyMetricsScreen extends StatefulWidget {
  final int age;
  final double height;
  final double currentWeight;
  final double targetWeight;
  final Function({
    required int age,
    required double height,
    required double currentWeight,
    required double targetWeight,
  }) onChanged;

  const BodyMetricsScreen({
    super.key,
    required this.age,
    required this.height,
    required this.currentWeight,
    required this.targetWeight,
    required this.onChanged,
  });

  @override
  State<BodyMetricsScreen> createState() => _BodyMetricsScreenState();
}

class _BodyMetricsScreenState extends State<BodyMetricsScreen> {
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _currentWeightController;
  late TextEditingController _targetWeightController;

  String? _ageError;
  String? _heightError;
  String? _currentWeightError;
  String? _targetWeightError;

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(text: widget.age > 0 ? widget.age.toString() : '');
    _heightController = TextEditingController(text: widget.height > 0 ? widget.height.toStringAsFixed(1) : '');
    _currentWeightController = TextEditingController(text: widget.currentWeight > 0 ? widget.currentWeight.toStringAsFixed(1) : '');
    _targetWeightController = TextEditingController(text: widget.targetWeight > 0 ? widget.targetWeight.toStringAsFixed(1) : '');
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _currentWeightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  void _notifyChanges() {
    final age = int.tryParse(_ageController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final currentWeight = double.tryParse(_currentWeightController.text.trim());
    final targetWeight = double.tryParse(_targetWeightController.text.trim());

    setState(() {
      _ageError = _validateAge(age);
      _heightError = _validateHeight(height);
      _currentWeightError = _validateWeight(currentWeight, 'Current weight');
      _targetWeightError = _validateWeight(targetWeight, 'Target weight');
    });

    if (_ageError == null &&
        _heightError == null &&
        _currentWeightError == null &&
        _targetWeightError == null &&
        age != null &&
        height != null &&
        currentWeight != null &&
        targetWeight != null) {
      widget.onChanged(
        age: age,
        height: height,
        currentWeight: currentWeight,
        targetWeight: targetWeight,
      );
    }
  }

  static String? _validateAge(int? age) {
    if (age == null) return 'Age is required';
    if (age < 10 || age > 100) return 'Age must be between 10 and 100';
    return null;
  }

  static String? _validateHeight(double? height) {
    if (height == null) return 'Height is required';
    if (height < 100 || height > 250) return 'Height must be between 100 and 250 cm';
    return null;
  }

  static String? _validateWeight(double? weight, String label) {
    if (weight == null) return '$label is required';
    if (weight < 30 || weight > 300) return '$label must be between 30 and 300 kg';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Body Measurements',
            style: AppTheme.headlineLg.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'We use these parameters to compute your Basal Metabolic Rate (BMR) and daily expenditure.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputField(
                  context: context,
                  label: 'Age',
                  hint: 'e.g. 25',
                  suffix: 'years',
                  controller: _ageController,
                  errorText: _ageError,
                  icon: Icons.cake_rounded,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  context: context,
                  label: 'Height',
                  hint: 'e.g. 175',
                  suffix: 'cm',
                  controller: _heightController,
                  errorText: _heightError,
                  icon: Icons.height_rounded,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  context: context,
                  label: 'Current Weight',
                  hint: 'e.g. 70.0',
                  suffix: 'kg',
                  controller: _currentWeightController,
                  errorText: _currentWeightError,
                  icon: Icons.monitor_weight_rounded,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  context: context,
                  label: 'Target Weight',
                  hint: 'e.g. 75.0',
                  suffix: 'kg',
                  controller: _targetWeightController,
                  errorText: _targetWeightError,
                  icon: Icons.track_changes_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required BuildContext context,
    required String label,
    required String hint,
    required String suffix,
    required TextEditingController controller,
    required String? errorText,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTheme.headlineMd.copyWith(
                fontSize: 14,
                color: context.appTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _notifyChanges(),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            errorText: errorText,
            filled: true,
            fillColor: context.appSurfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

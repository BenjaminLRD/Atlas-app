import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/food_item.dart';
import '../../providers/fitness_provider.dart';
import '../../services/food_validation_service.dart';

/// Modal bottom sheet for creating or editing custom food entries.
class CustomFoodModal extends StatefulWidget {
  final FoodItem? initialFood;

  const CustomFoodModal({super.key, this.initialFood});

  static Future<void> show(BuildContext context, {FoodItem? initialFood}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomFoodModal(initialFood: initialFood),
    );
  }

  @override
  State<CustomFoodModal> createState() => _CustomFoodModalState();
}

class _CustomFoodModalState extends State<CustomFoodModal> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _servingSizeController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _saturatedFatController;
  late final TextEditingController _saltController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatsController;
  late final TextEditingController _fiberController;
  late final TextEditingController _sugarController;
  late final TextEditingController _sodiumController;

  String _selectedCategory = 'Protein';
  String _selectedUnit = 'grams';

  final List<String> _categories = [
    'Protein',
    'Fruits',
    'Vegetables',
    'Grains',
    'Indian',
    'Mizo',
    'Fast Food',
    'Snacks',
    'Drinks',
    'Desserts',
    'General',
  ];

  final List<String> _units = [
    'grams',
    'g',
    'kg',
    'ml',
    'L',
    'piece',
    'serving',
    'cup',
    'slice',
    'bowl',
    'packet',
    'bottle',
    'can',
  ];

  @override
  void initState() {
    super.initState();
    final f = widget.initialFood;
    _nameController = TextEditingController(text: f?.name ?? '');
    _brandController = TextEditingController(text: f?.brand ?? '');
    _servingSizeController = TextEditingController(
      text: f?.servingSize ?? '100',
    );
    // Values the product database did not have start empty (the fields are
    // required), so an unknown value is never saved as a typed-in 0.
    _caloriesController = TextEditingController(
      text: f != null && f.isNutrientKnown(FoodItem.calorieKey)
          ? f.calories.toStringAsFixed(0)
          : '',
    );
    _proteinController = TextEditingController(
      text: f != null && f.isNutrientKnown(FoodItem.proteinKey)
          ? f.protein.toStringAsFixed(1)
          : '',
    );
    _carbsController = TextEditingController(
      text: f != null && f.isNutrientKnown(FoodItem.carbohydrateKey)
          ? f.carbohydrates.toStringAsFixed(1)
          : '',
    );
    _fatsController = TextEditingController(
      text: f != null && f.isNutrientKnown(FoodItem.fatKey)
          ? f.fats.toStringAsFixed(1)
          : '',
    );
    _fiberController = TextEditingController(
      text: f?.fiber != null ? f!.fiber!.toStringAsFixed(1) : '',
    );
    _sugarController = TextEditingController(
      text: f?.sugar != null ? f!.sugar!.toStringAsFixed(1) : '',
    );
    _sodiumController = TextEditingController(
      text: f?.sodium != null ? f!.sodium!.toStringAsFixed(1) : '',
    );
    _saturatedFatController = TextEditingController(
      text: f?.saturatedFat != null ? f!.saturatedFat!.toStringAsFixed(1) : '',
    );
    _saltController = TextEditingController(
      text: f?.salt != null ? f!.salt!.toStringAsFixed(2) : '',
    );

    if (f != null) {
      if (_categories.contains(f.category)) {
        _selectedCategory = f.category;
      }
      if (_units.contains(f.servingUnit)) {
        _selectedUnit = f.servingUnit;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _servingSizeController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _saturatedFatController.dispose();
    _saltController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _sodiumController.dispose();
    super.dispose();
  }

  /// A core nutrient is typed in as a number. Text that is not a number is
  /// rejected, never read as 0 (0 is a value the user must type).
  String? _requiredNumber(String? val) {
    final text = val?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    return double.tryParse(text) == null ? 'Enter a number' : null;
  }

  Future<void> _saveFood() async {
    if (!_formKey.currentState!.validate()) return;

    final String name = _nameController.text.trim();
    final String? brand = _brandController.text.trim().isNotEmpty
        ? _brandController.text.trim()
        : null;
    final String servingSizeRaw = _servingSizeController.text.trim();
    final double calories = double.tryParse(_caloriesController.text) ?? 0.0;
    final double protein = double.tryParse(_proteinController.text) ?? 0.0;
    final double carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final double fats = double.tryParse(_fatsController.text) ?? 0.0;
    final double? fiber = _fiberController.text.isNotEmpty
        ? double.tryParse(_fiberController.text)
        : null;
    final double? sugar = _sugarController.text.isNotEmpty
        ? double.tryParse(_sugarController.text)
        : null;
    final double? sodium = _sodiumController.text.isNotEmpty
        ? double.tryParse(_sodiumController.text)
        : null;
    // Left empty means not known, never 0.
    final double? saturatedFat = _saturatedFatController.text.trim().isNotEmpty
        ? double.tryParse(_saturatedFatController.text)
        : null;
    final double? salt = _saltController.text.trim().isNotEmpty
        ? double.tryParse(_saltController.text)
        : null;

    final id =
        widget.initialFood?.id ??
        'custom_${DateTime.now().millisecondsSinceEpoch}';
    final servingSize = '$servingSizeRaw $_selectedUnit';

    final food = FoodItem(
      id: id,
      name: name,
      brand: brand,
      category: _selectedCategory,
      servingSize: servingSize,
      servingUnit: _selectedUnit,
      calories: calories,
      protein: protein,
      carbohydrates: carbs,
      fats: fats,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
      saturatedFat: saturatedFat,
      salt: salt,
      // What the user typed in is theirs, not a verified record.
      nutritionSource: NutritionSource.userEntry,
      isCustom: true,
      isPackaged: brand != null && brand.trim().isNotEmpty,
      altNames: [name.toLowerCase(), if (brand != null) brand.toLowerCase()],
      // Keeps a scanned product's barcode, so scanning it again finds this
      // entry with the values the user typed in.
      barcode: widget.initialFood?.barcode,
    );

    final validation = FoodValidationService.validateCustomFood(food);
    if (!validation.isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validation.errors.join('\n')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // Only a food that is already a custom food can be updated; a scanned
    // product being completed by hand is saved as a new custom food.
    if (widget.initialFood != null && widget.initialFood!.isCustom) {
      await FitnessProvider.instance.updateCustomFood(food);
    } else {
      await FitnessProvider.instance.addCustomFood(food);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialFood != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: context.appCardBorder, width: 1),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.appOutlineVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing
                                  ? 'EDIT CUSTOM FOOD'
                                  : 'CREATE CUSTOM FOOD',
                              style: AppTheme.labelCaps.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEditing
                                  ? 'Update details of your saved food'
                                  : 'Add your custom dish or recipe to catalogue',
                              style: AppTheme.bodySm.copyWith(
                                color: context.appTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Food Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Food Name *',
                      hintText: 'e.g. Homemade Chicken Wrap',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter food name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Brand (Optional)
                  TextFormField(
                    controller: _brandController,
                    decoration: InputDecoration(
                      labelText: 'Brand (Optional)',
                      hintText: 'e.g. Pintola, Homemade, Amul',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category & Serving Unit Dropdowns
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: _categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCategory = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedUnit,
                          decoration: InputDecoration(
                            labelText: 'Serving Unit',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: _units.map((u) {
                            return DropdownMenuItem(value: u, child: Text(u));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedUnit = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All nutrition values below are for ONE serving of the size '
                    'you enter (for example 150 grams), not per 100 g. Leave '
                    'the optional ones empty if you do not know them: empty '
                    'means unknown, not zero. This food is saved as your own '
                    'entry and is not verified.',
                    key: const Key('custom_food_basis_note'),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Serving Size & Calories
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _servingSizeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Serving Size *',
                            hintText: 'e.g. 100 or 1',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _caloriesController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Calories (kcal) *',
                            hintText: 'e.g. 450',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          validator: _requiredNumber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Macros Row: Protein, Carbs, Fats
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _proteinController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Protein (g) *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          ),
                          validator: _requiredNumber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _carbsController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Carbs (g) *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          ),
                          validator: _requiredNumber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _fatsController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Fat (g) *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          ),
                          validator: _requiredNumber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Micronutrients Optional Row: Fiber, Sugar, Sodium
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _fiberController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Fiber (g)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _sugarController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Sugar (g)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _sodiumController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Sodium (mg)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Optional: saturated fat and salt. Empty means not known.
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _saturatedFatController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Saturated fat (g)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _saltController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Salt (g)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Actions: Cancel & Save
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveFood,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isEditing ? 'UPDATE FOOD' : 'SAVE FOOD',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

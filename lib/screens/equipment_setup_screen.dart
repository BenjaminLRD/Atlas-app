import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/equipment.dart';
import '../models/user_equipment_profile.dart';
import '../repositories/equipment_repository.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_chip.dart';

/// Interactive setup screen enabling users to configure and save their available physical gym gear.
class EquipmentSetupScreen extends StatefulWidget {
  final EquipmentRepository? repository;

  const EquipmentSetupScreen({super.key, this.repository});

  @override
  State<EquipmentSetupScreen> createState() => _EquipmentSetupScreenState();
}

class _EquipmentSetupScreenState extends State<EquipmentSetupScreen> {
  late final EquipmentRepository _repository;
  bool _isLoading = true;
  bool _isSaving = false;
  Set<String> _selectedEquipmentIds = <String>{};
  EquipmentCategory? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const LocalEquipmentRepository();
    _loadProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await _repository.getProfile();
    setState(() {
      _selectedEquipmentIds = profile.availableEquipmentIds.toSet();
      _isLoading = false;
    });
  }

  void _toggleEquipment(String id) {
    setState(() {
      if (_selectedEquipmentIds.contains(id)) {
        _selectedEquipmentIds.remove(id);
      } else {
        _selectedEquipmentIds.add(id);
      }
    });
  }

  void _applyPreset(UserEquipmentProfile preset) {
    setState(() {
      _selectedEquipmentIds = preset.availableEquipmentIds.toSet();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preset applied. Tap "Save Setup" to confirm.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _selectAll() {
    setState(() {
      _selectedEquipmentIds = Equipment.masterCatalog()
          .map((e) => e.id)
          .toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedEquipmentIds.clear();
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final updatedProfile = UserEquipmentProfile(
      userId: 'local_user',
      availableEquipmentIds: _selectedEquipmentIds.toList(),
      updatedAt: DateTime.now(),
    );

    await _repository.saveProfile(updatedProfile);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${_selectedEquipmentIds.length} available equipment items! Workouts & AI Coach adapted.',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Equipment> get _filteredEquipment {
    final catalog = Equipment.masterCatalog();
    return catalog.where((e) {
      final matchesCategory =
          _selectedCategory == null || e.category == _selectedCategory;
      final query = _searchQuery.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          e.name.toLowerCase().contains(query) ||
          e.description.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalCount = Equipment.masterCatalog().length;
    final selectedCount = _selectedEquipmentIds.length;
    final coveragePercent = totalCount > 0 ? (selectedCount / totalCount) : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Equipment Setup',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'select_all') _selectAll();
              if (val == 'deselect_all') _deselectAll();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'select_all',
                child: Text('Select All Equipment'),
              ),
              PopupMenuItem(value: 'deselect_all', child: Text('Deselect All')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Fixed Summary & Filter Panel
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Coverage Summary Card
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.tune_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Available Gear',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedCount > 0
                                          ? AppColors.secondary
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$selectedCount / $totalCount Active',
                                      style: TextStyle(
                                        color: selectedCount > 0
                                            ? AppColors.primary
                                            : Colors.grey.shade700,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: coveragePercent,
                                backgroundColor: theme.dividerColor.withValues(
                                  alpha: 0.1,
                                ),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Workouts and AI Coach only recommend exercises you can actually perform.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Quick Presets Carousel
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text(
                              'Presets: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AppChip(
                              label: 'Full Commercial Gym',
                              icon: Icons.business_rounded,
                              onTap: () => _applyPreset(
                                UserEquipmentProfile.fullCommercialGym(),
                              ),
                            ),
                            const SizedBox(width: 6),
                            AppChip(
                              label: 'Home Dumbbell & Bench',
                              icon: Icons.home_rounded,
                              onTap: () => _applyPreset(
                                UserEquipmentProfile.homeDumbbellsAndBench(),
                              ),
                            ),
                            const SizedBox(width: 6),
                            AppChip(
                              label: 'Calisthenics',
                              icon: Icons.accessibility_new_rounded,
                              onTap: () => _applyPreset(
                                UserEquipmentProfile.bodyweightCalisthenics(),
                              ),
                            ),
                            const SizedBox(width: 6),
                            AppChip(
                              label: 'Minimalist',
                              icon: Icons.flight_takeoff_rounded,
                              onTap: () => _applyPreset(
                                UserEquipmentProfile.minimalist(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Search bar
                      TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText:
                              'Search equipment (e.g. barbell, cables)...',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedText,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: theme.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      // Category Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCategoryChip(null, 'All'),
                            ...EquipmentCategory.values.map(
                              (c) => _buildCategoryChip(c, c.label),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Equipment List
                Expanded(
                  child: _filteredEquipment.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: AppColors.mutedText,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'No matching equipment found',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.xs,
                            AppSpacing.lg,
                            AppSpacing.xl * 2,
                          ),
                          itemCount: _filteredEquipment.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final item = _filteredEquipment[index];
                            final isSelected = _selectedEquipmentIds.contains(
                              item.id,
                            );

                            return InkWell(
                              onTap: () => _toggleEquipment(item.id),
                              borderRadius: BorderRadius.circular(16),
                              child: AppCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm + 2,
                                ),
                                borderColor: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.5)
                                    : null,
                                backgroundColor: isSelected
                                    ? AppColors.secondary.withValues(
                                        alpha: 0.25,
                                      )
                                    : null,
                                child: Row(
                                  children: [
                                    // Equipment Icon Container
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.secondary
                                            : theme.dividerColor.withValues(
                                                alpha: 0.08,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),

                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : null,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.description,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),

                                    // Toggle Checkbox / Indicator
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : theme.dividerColor.withValues(
                                                  alpha: 0.3,
                                                ),
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 18,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Sticky Bottom Save Bar
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: AppButton.primary(
                      label: 'Save Equipment Setup ($selectedCount Selected)',
                      isLoading: _isSaving,
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: _isSaving ? null : _saveProfile,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryChip(EquipmentCategory? category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = category),
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.secondary,
        checkmarkColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/exercise.dart';
import '../widgets/common/app_card.dart';
import '../widgets/exercise/exercise_thumbnail.dart';
import 'exercise_detail_screen.dart';
import 'machine_scanner_screen.dart';

/// Exercise Library Screen with multi-filter capability (Muscle Group, Equipment, Difficulty)
/// and search bar with instant navigation into ExerciseDetailScreen.
class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedMuscle = 'All';
  String _selectedEquipment = 'All';
  String _selectedDifficulty = 'All';
  String _searchQuery = '';

  static const List<String> _muscleOptions = [
    'All',
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Arms',
    'Core',
  ];

  static const List<String> _equipmentOptions = [
    'All',
    'Barbell',
    'Dumbbell',
    'Machine',
    'Bodyweight',
    'Cable',
  ];

  static const List<String> _difficultyOptions = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  late final List<Exercise> _allExercises;

  @override
  void initState() {
    super.initState();
    _allExercises = Exercise.defaultRegistry();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Exercise> get _filteredExercises {
    return _allExercises.where((ex) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = ex.name.toLowerCase().contains(q);
        final matchMuscle = ex.muscleGroup.toLowerCase().contains(q);
        final matchEq = ex.equipment.toLowerCase().contains(q);
        if (!matchName && !matchMuscle && !matchEq) return false;
      }

      // 2. Muscle Group
      if (_selectedMuscle != 'All') {
        final muscleLower = _selectedMuscle.toLowerCase();
        final exMuscleLower = ex.muscleGroup.toLowerCase();
        if (!exMuscleLower.contains(muscleLower)) {
          // Special handling for Legs (Quadriceps, Hamstrings, Glutes)
          if (_selectedMuscle == 'Legs') {
            if (!exMuscleLower.contains('quad') &&
                !exMuscleLower.contains('hamstring') &&
                !exMuscleLower.contains('glute') &&
                !exMuscleLower.contains('calf')) {
              return false;
            }
          } else if (_selectedMuscle == 'Arms') {
            if (!exMuscleLower.contains('bicep') &&
                !exMuscleLower.contains('tricep') &&
                !exMuscleLower.contains('forearm')) {
              return false;
            }
          } else {
            return false;
          }
        }
      }

      // 3. Equipment
      if (_selectedEquipment != 'All') {
        final eqLower = _selectedEquipment.toLowerCase();
        final exEqLower = ex.equipment.toLowerCase();
        if (!exEqLower.contains(eqLower)) return false;
      }

      // 4. Difficulty
      if (_selectedDifficulty != 'All') {
        if (ex.difficulty.toLowerCase() != _selectedDifficulty.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredExercises;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.appTextPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Exercise Library',
          style: AppTheme.headlineMd.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Scan a machine',
            icon: Icon(
              Icons.photo_camera_outlined,
              color: context.appTextPrimary,
              size: 22,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MachineScannerScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: context.appSurfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.appOutlineVariant),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  style: AppTheme.bodySm.copyWith(
                    color: context.appTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search movement or muscle...',
                    hintStyle: AppTheme.bodySm.copyWith(
                      color: context.appTextSecondary,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

            // 2. Filter Chips Scrollable Rows
            _buildFilterRow(
              title: 'Muscle Group',
              options: _muscleOptions,
              selected: _selectedMuscle,
              onSelected: (val) => setState(() => _selectedMuscle = val),
            ),
            _buildFilterRow(
              title: 'Equipment',
              options: _equipmentOptions,
              selected: _selectedEquipment,
              onSelected: (val) => setState(() => _selectedEquipment = val),
            ),
            _buildFilterRow(
              title: 'Difficulty',
              options: _difficultyOptions,
              selected: _selectedDifficulty,
              onSelected: (val) => setState(() => _selectedDifficulty = val),
            ),

            const SizedBox(height: 6),

            // 3. Exercise Count & Results Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${filtered.length} MOVEMENTS FOUND',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.appTextSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (_selectedMuscle != 'All' ||
                      _selectedEquipment != 'All' ||
                      _selectedDifficulty != 'All' ||
                      _searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMuscle = 'All';
                          _selectedEquipment = 'All';
                          _selectedDifficulty = 'All';
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      child: Text(
                        'Reset Filters',
                        style: AppTheme.bodySm.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 4. Exercise Card List
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final exercise = filtered[index];
                        return _buildExerciseCard(context, exercise);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        itemBuilder: (context, idx) {
          final opt = options[idx];
          final isSelected = opt == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(opt),
              selected: isSelected,
              onSelected: (_) => onSelected(opt),
              labelStyle: AppTheme.labelCaps.copyWith(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (context.isDarkMode ? Colors.black : Colors.white)
                    : context.appTextSecondary,
              ),
              selectedColor: context.isDarkMode
                  ? AppColors.primaryContainer
                  : AppColors.primary,
              backgroundColor: context.appSurfaceElevated,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? Colors.transparent
                      : context.appOutlineVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, Exercise exercise) {
    final isDark = context.isDarkMode;
    final hasVideo =
        exercise.videoUrl != null && exercise.videoUrl!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExerciseDetailScreen(exercise: exercise),
            ),
          );
        },
        child: Row(
          children: [
            // The exercise's own illustration (never a photo of someone else).
            ExerciseThumbnail(
              exerciseId: exercise.id,
              exerciseName: exercise.name,
              size: 64,
              borderRadius: 12,
              fallbackIcon: exercise.categoryIcon,
            ),
            const SizedBox(width: 14),

            // Exercise Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          exercise.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.headlineMd.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ),
                      if (hasVideo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.primaryContainer.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.videocam_rounded,
                                size: 11,
                                color: isDark
                                    ? AppColors.primaryContainer
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '4K GUIDE',
                                style: AppTheme.labelCaps.copyWith(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppColors.primaryContainer
                                      : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exercise.muscleGroup,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.appSurfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          exercise.equipment,
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 9,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.appSurfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          exercise.difficulty,
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 9,
                            color: exercise.difficulty == 'Advanced'
                                ? Colors.redAccent
                                : (exercise.difficulty == 'Intermediate'
                                      ? Colors.orangeAccent
                                      : Colors.green),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: context.appTextSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: context.appTextSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No exercises found',
              style: AppTheme.headlineMd.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing your search terms or filter selections.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySm.copyWith(
                fontSize: 13,
                color: context.appTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

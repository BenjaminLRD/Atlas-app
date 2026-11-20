import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_theme.dart';
import '../../data/local_storage.dart';
import '../../data/profile_provider.dart';
import '../../models/activity_post.dart';
import '../../providers/fitness_provider.dart';
import '../../services/community/community_cloud_repository.dart';
import '../common/app_button.dart';
import '../common/app_image.dart';
import 'community_avatar_helper.dart';

/// Modal bottom sheet allowing users to compose and publish rich community posts
/// with media attachments (photos, videos), workout stats, PRs, and recipes.
class CreatePostModal extends StatefulWidget {
  final ValueChanged<ActivityPost> onPostCreated;

  const CreatePostModal({super.key, required this.onPostCreated});

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<ActivityPost> onPostCreated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => CreatePostModal(onPostCreated: onPostCreated),
    );
  }

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  ActivityPostType _selectedType = ActivityPostType.workout;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Media Attachment State
  String? _attachedMediaUrl;
  bool _isAttachedVideo = false;
  bool _isPublishing = false;

  // Workout fields
  final _durationController = TextEditingController();
  final _volumeController = TextEditingController();
  final _exercisesCountController = TextEditingController();

  // PR fields
  final _prExerciseController = TextEditingController();
  final _prPrevWeightController = TextEditingController();
  final _prNewWeightController = TextEditingController();

  // Meal fields
  final _mealCaloriesController = TextEditingController();
  final _mealProteinController = TextEditingController();
  final _mealCarbsController = TextEditingController();
  final _mealFatController = TextEditingController();
  final _mealIngredientsController = TextEditingController(
    text: 'Chicken, Rice, Broccoli, Olive Oil',
  );

  // Routine fields
  final _splitNameController = TextEditingController(
    text: 'Upper / Lower Power Split',
  );
  final _splitDaysController = TextEditingController(
    text: 'Upper: Bench Press, Rows • Lower: Squats, RDL',
  );

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _volumeController.dispose();
    _exercisesCountController.dispose();
    _prExerciseController.dispose();
    _prPrevWeightController.dispose();
    _prNewWeightController.dispose();
    _mealCaloriesController.dispose();
    _mealProteinController.dispose();
    _mealCarbsController.dispose();
    _mealFatController.dispose();
    _mealIngredientsController.dispose();
    _splitNameController.dispose();
    _splitDaysController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _attachedMediaUrl = picked.path;
        _isAttachedVideo = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open your photos.')),
      );
    }
  }

  Future<void> _pickVideo() async {
    if (CommunityCloudRepository.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video posts are not available yet.')),
      );
      return;
    }
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );
      if (picked == null || !mounted) return;
      setState(() {
        _attachedMediaUrl = picked.path;
        _isAttachedVideo = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open your videos.')),
      );
    }
  }

  void _removeMedia() {
    setState(() {
      _attachedMediaUrl = null;
      _isAttachedVideo = false;
    });
  }

  Future<void> _submitPost() async {
    if (_isPublishing) return;
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : '${_selectedType.displayName} ${_selectedType.emoji}';
    final desc = _descriptionController.text.trim();

    // Only what the athlete entered: never invented numbers.
    final metadata = <String, dynamic>{};
    void putNum(String key, String text) {
      final value = num.tryParse(text.trim());
      if (value != null) metadata[key] = value;
    }

    if (_isAttachedVideo) metadata['isVideo'] = true;

    switch (_selectedType) {
      case ActivityPostType.workout:
        putNum('durationMinutes', _durationController.text);
        putNum('totalVolumeKg', _volumeController.text);
        putNum('exercisesCount', _exercisesCountController.text);
      case ActivityPostType.achievement:
        if (_prExerciseController.text.trim().isNotEmpty) {
          metadata['exerciseName'] = _prExerciseController.text.trim();
        }
        putNum('previousWeightKg', _prPrevWeightController.text);
        putNum('newWeightKg', _prNewWeightController.text);
        final prev = metadata['previousWeightKg'] as num?;
        final curr = metadata['newWeightKg'] as num?;
        if (prev != null && curr != null) {
          metadata['improvementKg'] = curr - prev;
        }
      case ActivityPostType.meal:
        putNum('calories', _mealCaloriesController.text);
        putNum('proteinGrams', _mealProteinController.text);
        putNum('carbsGrams', _mealCarbsController.text);
        putNum('fatGrams', _mealFatController.text);
        final ingredients = _mealIngredientsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (ingredients.isNotEmpty) metadata['ingredients'] = ingredients;
      case ActivityPostType.routine:
        if (_splitNameController.text.trim().isNotEmpty) {
          metadata['splitName'] = _splitNameController.text.trim();
        }
      case ActivityPostType.transformation:
      case ActivityPostType.progress:
      case ActivityPostType.cardio:
        break;
    }

    final profile = LocalStorage.getUserProfile();
    final provider = FitnessProvider.instance;
    final draft = ActivityPost(
      id: 'post_${DateTime.now().millisecondsSinceEpoch}',
      userId: provider.currentUser?.id ?? 'usr_local',
      userName: LocalStorage.isShowcaseModeEnabled()
          ? ProfileProvider.showcaseSelfLabel
          : (profile.name.isNotEmpty ? profile.name : 'You'),
      userAvatar:
          profile.profilePic.isNotEmpty && !LocalStorage.isShowcaseModeEnabled()
          ? profile.profilePic
          : null,
      userRank: provider.fullRank,
      type: _selectedType,
      title: title,
      description: desc,
      images: _attachedMediaUrl != null ? [_attachedMediaUrl!] : const [],
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    ActivityPost post = draft;
    if (CommunityCloudRepository.isActive) {
      setState(() => _isPublishing = true);
      try {
        post = await CommunityCloudRepository.instance.createPost(
          draft,
          photo: _attachedMediaUrl != null && !_isAttachedVideo
              ? File(_attachedMediaUrl!)
              : null,
        );
      } catch (_) {
        if (!mounted) return;
        setState(() => _isPublishing = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Your post could not be published. Try again.'),
          ),
        );
        return;
      }
    } else {
      LocalStorage.addCommunityPost(post);
    }

    widget.onPostCreated(post);
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Post published to Community! 🔥'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required BuildContext context,
    required String labelText,
    String? hintText,
    double borderRadius = 12,
  }) {
    final isDark = context.isDarkMode;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      isDense: true,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white70 : AppColors.textSecondary,
      ),
      hintStyle: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white38 : AppColors.mutedText,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : context.appOutlineVariant,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.black.withValues(alpha: 0.02),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final textStyle = TextStyle(
      fontSize: 14,
      color: isDark ? Colors.white : AppColors.textPrimary,
    );

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 18,
        right: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : context.appOutlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Row: Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create Post',
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : AppColors.textPrimary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Author Info Header
            Row(
              children: [
                CommunityAvatarHelper.buildAvatar(
                  userId: 'usr_local',
                  userName: 'Alex Lalremruata',
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CommunityAvatarHelper.displayNameFor(
                        'usr_local',
                        'Alex Lalremruata',
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Diamond I',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Post Type Selector
            Text(
              'POST TYPE',
              style: AppTheme.labelCaps.copyWith(
                fontSize: 10,
                color: isDark ? Colors.white70 : context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ActivityPostType.values
                    // Run & ride posts are made from a finished activity,
                    // not typed in here.
                    .where((t) => t != ActivityPostType.cardio)
                    .map((t) {
                      final isSelected = t == _selectedType;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${t.emoji} ${t.displayName}'),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                      ? Colors.white70
                                      : context.appTextSecondary),
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedType = t);
                          },
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Caption / Description Field
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: textStyle,
              decoration: _buildInputDecoration(
                context: context,
                labelText: "What's on your mind?",
                hintText: 'Share your workout, meal prep, or fitness win...',
              ),
            ),
            const SizedBox(height: 12),

            // Media Attachment Action Row
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                  label: const Text(
                    '+ Add Photo',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam_rounded, size: 18),
                  label: const Text(
                    '🎥 Add Video',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3B82F6),
                    side: BorderSide(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),

            // Attached Media Preview
            if (_attachedMediaUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppImage(
                          imageUrl: _attachedMediaUrl,
                          fit: BoxFit.cover,
                          borderRadius: 12,
                        ),
                        // Media Badge Top Left
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isAttachedVideo
                                      ? Icons.videocam_rounded
                                      : Icons.photo_rounded,
                                  color: _isAttachedVideo
                                      ? const Color(0xFF3B82F6)
                                      : AppColors.primary,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isAttachedVideo ? 'VIDEO (0:45)' : 'PHOTO',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Remove Button Top Right
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: _removeMedia,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        if (_isAttachedVideo)
                          const Center(
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Post Title
            TextField(
              controller: _titleController,
              style: textStyle,
              decoration: _buildInputDecoration(
                context: context,
                labelText: 'Post Title (Optional)',
                hintText: 'e.g. Chest Day PR or High-Protein Meal Prep',
              ),
            ),
            const SizedBox(height: 12),

            // Type-Specific Inputs
            _buildTypeSpecificInputs(context, textStyle),
            const SizedBox(height: 18),

            // Submit Button
            AppButton.primary(
              label: 'PUBLISH POST',
              icon: Icons.send_rounded,
              onPressed: _submitPost,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSpecificInputs(BuildContext context, TextStyle textStyle) {
    switch (_selectedType) {
      case ActivityPostType.workout:
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                style: textStyle,
                decoration: _buildInputDecoration(
                  context: context,
                  labelText: 'Duration (min)',
                  borderRadius: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _volumeController,
                keyboardType: TextInputType.number,
                style: textStyle,
                decoration: _buildInputDecoration(
                  context: context,
                  labelText: 'Volume (kg)',
                  borderRadius: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _exercisesCountController,
                keyboardType: TextInputType.number,
                style: textStyle,
                decoration: _buildInputDecoration(
                  context: context,
                  labelText: 'Exercises',
                  borderRadius: 10,
                ),
              ),
            ),
          ],
        );
      case ActivityPostType.achievement:
        return Column(
          children: [
            TextField(
              controller: _prExerciseController,
              style: textStyle,
              decoration: _buildInputDecoration(
                context: context,
                labelText: 'Exercise Name',
                borderRadius: 10,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _prPrevWeightController,
                    keyboardType: TextInputType.number,
                    style: textStyle,
                    decoration: _buildInputDecoration(
                      context: context,
                      labelText: 'Previous (kg)',
                      borderRadius: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _prNewWeightController,
                    keyboardType: TextInputType.number,
                    style: textStyle,
                    decoration: _buildInputDecoration(
                      context: context,
                      labelText: 'New PR (kg)',
                      borderRadius: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      case ActivityPostType.meal:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mealCaloriesController,
                    keyboardType: TextInputType.number,
                    style: textStyle,
                    decoration: _buildInputDecoration(
                      context: context,
                      labelText: 'Calories',
                      borderRadius: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _mealProteinController,
                    keyboardType: TextInputType.number,
                    style: textStyle,
                    decoration: _buildInputDecoration(
                      context: context,
                      labelText: 'Protein (g)',
                      borderRadius: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _mealCarbsController,
                    keyboardType: TextInputType.number,
                    style: textStyle,
                    decoration: _buildInputDecoration(
                      context: context,
                      labelText: 'Carbs (g)',
                      borderRadius: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _mealFatController,
                    keyboardType: TextInputType.number,
                    style: textStyle,
                    decoration: _buildInputDecoration(
                      context: context,
                      labelText: 'Fat (g)',
                      borderRadius: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mealIngredientsController,
              style: textStyle,
              decoration: _buildInputDecoration(
                context: context,
                labelText: 'Ingredients (comma separated)',
                borderRadius: 10,
              ),
            ),
          ],
        );
      case ActivityPostType.routine:
        return Column(
          children: [
            TextField(
              controller: _splitNameController,
              style: textStyle,
              decoration: _buildInputDecoration(
                context: context,
                labelText: 'Split Name',
                borderRadius: 10,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _splitDaysController,
              style: textStyle,
              decoration: _buildInputDecoration(
                context: context,
                labelText: 'Key Days & Movements',
                borderRadius: 10,
              ),
            ),
          ],
        );
      case ActivityPostType.transformation:
      case ActivityPostType.progress:
      case ActivityPostType.cardio:
        return const SizedBox.shrink();
    }
  }
}

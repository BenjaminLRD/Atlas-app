import 'package:flutter/material.dart';
import '../../services/feedback/beta_feedback_service.dart';
import '../../theme/app_theme.dart';
import '../common/app_button.dart';

/// Modal dialog allowing beta testers and athletes to submit bug reports,
/// UI issues, feature requests, and AI coaching feedback.
class FeedbackSubmissionModal extends StatefulWidget {
  final String userId;

  const FeedbackSubmissionModal({super.key, this.userId = 'usr_local'});

  static Future<void> show(
    BuildContext context, {
    String userId = 'usr_local',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FeedbackSubmissionModal(userId: userId),
    );
  }

  @override
  State<FeedbackSubmissionModal> createState() =>
      _FeedbackSubmissionModalState();
}

class _FeedbackSubmissionModalState extends State<FeedbackSubmissionModal> {
  final TextEditingController _feedbackController = TextEditingController();
  String _selectedCategory = 'bug';
  String _selectedPriority = 'medium';
  bool _isSubmitting = false;
  bool _isSuccess = false;

  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'bug',
      'label': 'Bug',
      'icon': Icons.bug_report_rounded,
      'color': AppColors.error,
    },
    {
      'id': 'feature_request',
      'label': 'Feature',
      'icon': Icons.lightbulb_rounded,
      'color': AppColors.tertiary,
    },
    {
      'id': 'ui_issue',
      'label': 'UI Issue',
      'icon': Icons.design_services_rounded,
      'color': AppColors.primary,
    },
    {
      'id': 'ai_issue',
      'label': 'AI Issue',
      'icon': Icons.auto_awesome_rounded,
      'color': Colors.purpleAccent,
    },
  ];

  final List<String> _priorities = ['low', 'medium', 'high', 'critical'];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    final success = await BetaFeedbackService.instance.submitFeedback(
      userId: widget.userId,
      feedback: text,
      category: _selectedCategory,
      priority: _selectedPriority,
    );

    setState(() {
      _isSubmitting = false;
      _isSuccess = success;
    });

    if (success && mounted) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: bottomInset + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.feedback_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Beta Feedback & Bug Report',
                  style: AppTypography.cardTitleLg.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Help us perfect Atlas for launch. Tell us what you noticed or what we should build next.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Category Selector
            Text(
              'Category',
              style: AppTypography.labelCaps.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['id'];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 16,
                        color: isSelected
                            ? Colors.black
                            : cat['color'] as Color,
                      ),
                      const SizedBox(width: 6),
                      Text(cat['label'] as String),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat['id'] as String);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Priority Selector
            Text(
              'Priority',
              style: AppTypography.labelCaps.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _priorities.map((p) {
                final isSelected = _selectedPriority == p;
                return ChoiceChip(
                  label: Text(p.toUpperCase()),
                  selected: isSelected,
                  selectedColor: p == 'critical'
                      ? AppColors.error
                      : AppColors.tertiary,
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 11,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedPriority = p);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Text Input
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:
                    'Describe what happened or what feature you would love...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_isSuccess)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Thank you! Your feedback was received.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              AppButton.primary(
                label: _isSubmitting ? 'Submitting...' : 'Submit Feedback',
                icon: Icons.send_rounded,
                onPressed: _isSubmitting ? null : _submit,
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/coach_message.dart';
import '../providers/fitness_provider.dart';
import '../widgets/coach/recommendation_card.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_page.dart';

/// Full screen AI Coach user experience displaying active personalized recommendations
/// and live AI Coach conversation system.
class AICoachScreen extends StatefulWidget {
  const AICoachScreen({super.key});

  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _starterQuestions = const [
    'How do I hit my protein goal?',
    'Should I take a rest day?',
    'How can I improve my progress?',
  ];

  @override
  void initState() {
    super.initState();
    FitnessProvider.instance.addListener(_onFitnessChanged);
  }

  @override
  void dispose() {
    FitnessProvider.instance.removeListener(_onFitnessChanged);
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFitnessChanged() {
    if (mounted) setState(() {});
  }

  void _handleSend(String text) {
    if (text.trim().isEmpty) return;
    _chatController.clear();
    FitnessProvider.instance.sendCoachMessage(text);

    // Scroll to bottom after message sent
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppDurations.fast,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recommendations = FitnessProvider.instance.recommendations;
    final messages = FitnessProvider.instance.coachMessages;
    final isReplying = FitnessProvider.instance.isCoachReplying;

    return AppPage.back(
      title: 'AI Coach',
      subtitle: 'Personalized fitness protocol & guidance',
      headerTrailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
        tooltip: 'Clear Chat History',
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dialogCtx) => AlertDialog(
              title: const Text('Clear Chat History?'),
              content: const Text(
                'This will remove all stored messages from your AI Coach chat.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('CLEAR', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );

          if (confirm == true) {
            FitnessProvider.instance.clearCoachConversation();
          }
        },
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: AppSpacing.xxl + 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Coach Header Card
            _buildCoachHeaderCard(context, recommendations.length),
            const SizedBox(height: AppSpacing.xl),

            // 2. Today's Recommendations Section
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Today\'s Recommendations',
                  style: AppTheme.bodyLg.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (recommendations.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.2),
                      borderRadius: AppRadii.borderFull,
                    ),
                    child: Text(
                      '${recommendations.length} Active',
                      style: AppTheme.labelCaps.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Recommendations List or Empty State
            if (recommendations.isNotEmpty) ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recommendations.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  return RecommendationCard(
                    recommendation: recommendations[index],
                  );
                },
              ),
            ] else ...[
              _buildEmptyStateCard(context),
            ],

            const SizedBox(height: AppSpacing.xxl),

            // 3. Ask Coach Section
            Row(
              children: [
                const Icon(
                  Icons.forum_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Ask AI Coach',
                  style: AppTheme.bodyLg.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ask questions about your workouts, nutrition targets, or recovery protocol.',
              style: AppTheme.bodySm.copyWith(
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Starter Questions Chips
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: _starterQuestions.map((question) {
                return ActionChip(
                  avatar: const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    question,
                    style: AppTheme.labelCaps.copyWith(
                      color: context.appTextPrimary,
                    ),
                  ),
                  backgroundColor: context.appCardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.borderFull,
                    side: BorderSide(color: context.appCardBorder),
                  ),
                  onPressed: () => _handleSend(question),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Chat Messages Stream Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  if (messages.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Start a conversation with your AI Coach! Tap a starter question above or type your question below.',
                        textAlign: TextAlign.center,
                        style: AppTheme.bodySm.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                    ),
                  ] else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: messages.length,
                      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isUser = msg.role == CoachRole.user;
                        final isSystem = msg.role == CoachRole.system;

                        if (isSystem) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                msg.content,
                                style: AppTheme.labelCaps.copyWith(
                                  color: context.appTextSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          );
                        }

                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm + 2,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? AppColors.primary
                                  : context.isDarkMode
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isUser ? 16 : 4),
                                bottomRight: Radius.circular(isUser ? 4 : 16),
                              ),
                            ),
                            child: Text(
                              msg.content,
                              style: AppTheme.bodyMd.copyWith(
                                color: isUser
                                    ? Colors.white
                                    : context.appTextPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  // Loading / Typing Indicator
                  if (isReplying) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: context.isDarkMode
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Coach is analyzing...',
                              style: AppTheme.labelCaps.copyWith(
                                color: AppColors.primary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.sm),

                  // Chat Input Field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          enabled: !isReplying,
                          style: AppTheme.bodyMd.copyWith(
                            color: context.appTextPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: isReplying
                                ? 'Coach is typing...'
                                : 'Ask AI Coach...',
                            hintStyle: AppTheme.bodySm.copyWith(
                              color: context.appTextSecondary,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                          ),
                          onSubmitted: _handleSend,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.send_rounded,
                          color: isReplying
                              ? context.appTextSecondary
                              : AppColors.primary,
                        ),
                        onPressed: isReplying
                            ? null
                            : () => _handleSend(_chatController.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachHeaderCard(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
            AppColors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.borderXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'AI COACH',
                      style: AppTheme.bodyLg.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs + 2,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: AppRadii.borderFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF70FF76),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ONLINE',
                            style: AppTheme.labelCaps.copyWith(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  count > 0
                      ? '$count personalized insights ready for review'
                      : 'All training & nutrition goals are synchronized',
                  style: AppTheme.bodySm.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'You\'re all caught up!',
              style: AppTheme.bodyLg.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Keep building healthy habits. Your AI Coach will generate new recommendations as you log workouts and nutrition.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd.copyWith(
                color: context.appTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

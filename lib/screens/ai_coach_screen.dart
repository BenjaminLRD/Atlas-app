import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../data/local_storage.dart';
import '../models/coach_message.dart';
import '../models/recommendation.dart';
import '../providers/fitness_provider.dart';
import '../services/ai/ai_request_router.dart';
import '../services/ai/ai_config.dart';
import '../services/ai/memory/fitness_memory.dart';
import '../services/ai/multimodal/chat_attachment.dart';
import '../services/ai/vision/ai_vision_service.dart';
import '../widgets/coach/ai_chat_status_banner.dart';
import '../widgets/coach/coach_action_handler.dart';
import '../widgets/common/app_glass.dart';
import '../widgets/common/atlas_logo.dart';
import 'ai/ai_onboarding_screen.dart';

/// Redesigned AI Gym Coach full-screen chat application providing
/// a premium AI personal trainer user experience with keyboard safety,
/// real-time data context indicators, typing animation, message grouping,
/// interactive recommendation cards, and action toolbars.
class AICoachScreen extends StatefulWidget {
  final String? initialPrompt;
  const AICoachScreen({super.key, this.initialPrompt});

  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _showScrollToBottom = false;
  bool _isRefreshingContext = false;
  String? _errorMessage;
  String _lastSentMessage = '';
  final Map<String, bool> _feedbackByMessageId = {};
  String _loadingStatus = AIRequestRouter.defaultLoadingStatus;
  ChatAttachment? _selectedAttachment;
  bool _isPickingImage = false;

  bool _hasCompletedOnboarding = AIOnboardingScreen.hasCompleted();

  final List<Map<String, dynamic>> _quickActions = const [
    {
      'label': "Plan my day",
      'icon': Icons.auto_awesome_rounded,
      'prompt':
          "Plan my day with a complete schedule for training, nutrition targets, and habits.",
    },
    {
      'label': "Analyze my nutrition",
      'icon': Icons.restaurant_rounded,
      'prompt':
          "Analyze my nutrition, meals, calories, macros, and micronutrient balance for today.",
    },
    {
      'label': "Check my recovery",
      'icon': Icons.favorite_rounded,
      'prompt':
          "Check my recovery status, readiness score, HRV, sleep, stress & recovery insights.",
    },
  ];

  final List<Map<String, dynamic>> _welcomePrompts = const [
    {
      'title': "Plan my day",
      'subtitle': "Get a complete plan for training, nutrition, and habits",
      'icon': Icons.auto_awesome_rounded,
      'prompt':
          "Plan my day with a complete schedule for training, nutrition targets, and habits.",
    },
    {
      'title': "Analyze my nutrition",
      'subtitle': "Review meals, calories, macros, and micronutrients",
      'icon': Icons.restaurant_rounded,
      'prompt':
          "Analyze my nutrition, meals, calories, macros, and micronutrient balance for today.",
    },
    {
      'title': "Check my recovery",
      'subtitle': "Readiness, HRV, sleep, stress & recovery insights",
      'icon': Icons.favorite_rounded,
      'prompt':
          "Check my recovery status, readiness score, HRV, sleep, stress & recovery insights.",
    },
    {
      'title': "Track my progress",
      'subtitle': "Performance analytics, trends & predictive insights",
      'icon': Icons.insights_rounded,
      'prompt':
          "Track my fitness progress, performance analytics, trends & predictive insights.",
    },
    {
      'title': "Answer anything",
      'subtitle': "Your 24/7 intelligence partner for all fitness queries",
      'icon': Icons.chat_bubble_outline_rounded,
      'prompt':
          "How can Atlas AI assist me as my 24/7 fitness intelligence partner today?",
    },
  ];

  @override
  void initState() {
    super.initState();
    FitnessProvider.instance.addListener(_onFitnessChanged);
    _scrollController.addListener(_onScrollChanged);

    // Initial context reload & recommendations check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FitnessProvider.instance.refreshRecommendations();
      if (widget.initialPrompt != null &&
          widget.initialPrompt!.trim().isNotEmpty) {
        _handleSend(widget.initialPrompt!.trim());
      }
      _scrollToBottomIfNeeded();
    });
  }

  @override
  void dispose() {
    FitnessProvider.instance.removeListener(_onFitnessChanged);
    _scrollController.removeListener(_onScrollChanged);
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final isScrolledUp = (maxScroll - currentScroll) > 120;

    if (isScrolledUp != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = isScrolledUp;
      });
    }
  }

  void _onFitnessChanged() {
    if (mounted) {
      setState(() {});
      _scrollToBottomIfNeeded();
    }
  }

  void _scrollToBottomIfNeeded() {
    if (!_showScrollToBottom && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  void _scrollToBottomForce() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _handleSend(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && _selectedAttachment == null) return;

    final attachment = _selectedAttachment;
    _chatController.clear();
    setState(() {
      _selectedAttachment = null;
      _errorMessage = null;
      _lastSentMessage = trimmed;
      _loadingStatus = AIRequestRouter.loadingStatusFor(
        AIRequestRouter.instance.classifyIntent(trimmed),
        hasAttachment: attachment != null,
      );
    });

    try {
      await FitnessProvider.instance.sendCoachMessage(
        trimmed,
        attachment: attachment,
      );
      _scrollToBottomForce();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to connect to AI Coach. Tap retry to try again.';
        });
      }
    }
  }

  final AIVisionService _visionService = AIVisionService();

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isPickingImage = true);
      final attachment = await _visionService.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (attachment != null) {
        setState(() {
          _selectedAttachment = attachment;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _refreshContext() async {
    setState(() => _isRefreshingContext = true);
    await Future.delayed(const Duration(milliseconds: 400));
    FitnessProvider.instance.refreshRecommendations();
    if (mounted) {
      setState(() => _isRefreshingContext = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.black, size: 18),
              SizedBox(width: 8),
              Text('Training & nutrition context reloaded!'),
            ],
          ),
          backgroundColor: AppColors.primaryContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF191B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ATTACH IMAGE FOR AI ANALYSIS',
                style: TextStyle(
                  color: AppColors.primaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.primaryContainer,
                ),
                title: const Text(
                  'Take Photo (Camera)',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Scan gym equipment, meals, or form',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.primaryContainer,
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Select a food photo or nutrition label',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.blueAccent,
                ),
                title: const Text(
                  'Workout History Data',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Attach recent sets and volume data',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleSend(
                    'Please analyze my recent workout history and volume trends.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.restaurant_rounded,
                  color: Colors.orangeAccent,
                ),
                title: const Text(
                  'Nutrition & Food Logs',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Attach today\'s meals and macro totals',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleSend(
                    'Here is my nutrition log for today. How am I doing on macros?',
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.show_chart_rounded,
                  color: Colors.purpleAccent,
                ),
                title: const Text(
                  'Progress & Metric Summary',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Attach streak, XP, and rank stats',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleSend(
                    'Give me a full review of my workout streak and XP progress.',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCompletedOnboarding) {
      return AIOnboardingScreen(
        onGetStarted: () {
          setState(() {
            _hasCompletedOnboarding = true;
          });
        },
      );
    }

    final provider = FitnessProvider.instance;
    final messages = provider.coachMessages;
    final recommendations = provider.recommendations;
    final isReplying = provider.isCoachReplying;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF0F1015),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Fixed Header Bar
            _buildFixedHeader(context),

            // 2. Coaching Context Indicator Banner
            _buildContextBanner(provider),

            // 3. Quick Action Chips Row
            _buildQuickActionChips(),
            const Divider(height: 1, color: Color(0xFF1F222B)),

            // 4. Main Chat Body (Welcome Screen or Message List)
            Expanded(
              child: Stack(
                children: [
                  messages.isEmpty
                      ? _buildWelcomeState()
                      : _buildMessageList(
                          messages,
                          recommendations,
                          isReplying,
                        ),

                  // Floating "↓ New Message" Button when scrolled up
                  if (_showScrollToBottom && messages.isNotEmpty)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton.extended(
                        onPressed: _scrollToBottomForce,
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: Colors.black,
                        icon: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'New Message',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        elevation: 4,
                      ),
                    ),
                ],
              ),
            ),

            // Inline Error Banner (if any)
            if (_errorMessage != null) _buildInlineErrorBanner(),

            // 5. Floating Keyboard-Safe Input Composer
            _buildInputComposer(isReplying),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF14151B),
        border: Border(bottom: BorderSide(color: Color(0xFF1F222B))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),

          // Atlas AI logo
          const AtlasLogoMark(size: 38),
          const SizedBox(width: 10),

          // Title & Subtitle + Online Indicator
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        'Atlas AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),

                    Flexible(
                      child: // Small Animated/Visual Online Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primaryContainer.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: FittedBox(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.circle,
                                size: 6,
                                color: AppColors.primaryContainer,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Online',
                                style: TextStyle(
                                  color: AppColors.primaryContainer,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Your fitness intelligence partner',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Refresh Button
          IconButton(
            icon: _isRefreshingContext
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryContainer,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
            tooltip: 'Refresh Context',
            onPressed: _isRefreshingContext ? null : _refreshContext,
          ),

          // Options Menu (Clear Chat)
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white70,
              size: 20,
            ),
            color: const Color(0xFF191B22),
            onSelected: (value) async {
              if (value == 'clear') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF191B22),
                    title: const Text(
                      'Clear Chat History?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'This will remove all stored messages from your AI Coach chat thread.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'CLEAR',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FitnessProvider.instance.clearCoachConversation();
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Clear History',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextBanner(FitnessProvider provider) {
    return AiChatStatusBanner(
      isSignedIn: provider.isCoachAvailable,
      isShowcase: LocalStorage.isShowcaseModeEnabled(),
      backendMissing:
          provider.coachUnavailableReason ==
          AIUnavailableReason.backendNotConfigured,
    );
  }

  Widget _buildQuickActionChips() {
    return Container(
      color: const Color(0xFF0F1015),
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _quickActions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final action = _quickActions[index];
          return ActionChip(
            avatar: Icon(
              action['icon'] as IconData,
              size: 14,
              color: AppColors.primaryContainer,
            ),
            label: Text(
              action['label'] as String,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xFF1A1C24),
            side: BorderSide(
              color: AppColors.primaryContainer.withValues(alpha: 0.25),
              width: 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            onPressed: () => _handleSend(action['prompt'] as String),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Hero Avatar Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1A1C24),
                  AppColors.primaryContainer.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                const AtlasLogoMark(size: 72, glow: true),
                const SizedBox(height: 16),
                const Text(
                  'Atlas AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '"Your complete fitness intelligence."',
                  style: TextStyle(
                    color: AppColors.primaryContainer,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ask me anything about training, nutrition, recovery, habits, performance, or your overall health.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Suggested Prompts Title
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ATLAS AI CAN HELP WITH:',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4 Suggested Prompt Cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _welcomePrompts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final prompt = _welcomePrompts[index];
              return InkWell(
                onTap: () => _handleSend(prompt['prompt'] as String),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C24),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          prompt['icon'] as IconData,
                          color: AppColors.primaryContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prompt['title'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              prompt['subtitle'] as String,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.grey,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(
    List<CoachMessage> messages,
    List<Recommendation> recommendations,
    bool isReplying,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(left: 14, right: 14, top: 14, bottom: 24),
      itemCount:
          messages.length +
          (recommendations.isNotEmpty ? 1 : 0) +
          (isReplying ? 1 : 0),
      itemBuilder: (context, index) {
        // Render Top Integrated Recommendation Card if available
        if (recommendations.isNotEmpty && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildIntegratedRecommendationCard(
              context,
              recommendations.first,
            ),
          );
        }

        final messageIndex = recommendations.isNotEmpty ? index - 1 : index;

        // Render Typing Indicator at the end
        if (isReplying && messageIndex == messages.length) {
          return _buildTypingIndicator();
        }

        if (messageIndex >= messages.length) return const SizedBox.shrink();

        final msg = messages[messageIndex];
        final isUser = msg.role == CoachRole.user;
        final isSystem = msg.role == CoachRole.system;

        if (isSystem) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  msg.content,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        // Check if previous message is from same sender for grouping
        final bool isSameSenderAsPrevious =
            messageIndex > 0 && messages[messageIndex - 1].role == msg.role;

        final double topMargin = isSameSenderAsPrevious ? 6.0 : 18.0;

        return Padding(
          padding: EdgeInsets.only(top: topMargin),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: isUser
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Avatar (Shown ONLY on first message of consecutive AI group)
                  if (!isUser) ...[
                    if (!isSameSenderAsPrevious)
                      Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryContainer,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryContainer.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'A',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 40),
                  ],

                  // Message Content Bubble
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width *
                            (isUser ? 0.75 : 0.85),
                      ),
                      child: AppGlassContainer.chatBubble(
                        context: context,
                        isUser: isUser,
                        customBorderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(
                            isUser ? 20 : (isSameSenderAsPrevious ? 20 : 4),
                          ),
                          bottomRight: Radius.circular(
                            isUser ? (isSameSenderAsPrevious ? 20 : 4) : 20,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Attached Image Preview inside User Bubble
                            if (msg.hasImage) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 220,
                                    maxWidth: 260,
                                  ),
                                  child: msg.imageBase64 != null
                                      ? Image.memory(
                                          base64Decode(msg.imageBase64!),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const SizedBox.shrink(),
                                        )
                                      : msg.imagePath != null
                                      ? Image.file(
                                          File(msg.imagePath!),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const SizedBox.shrink(),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            _buildFormattedText(
                              msg.content,
                              isUser ? Colors.black : Colors.white,
                            ),

                            // Safety Disclaimer for Soreness / Injury Responses
                            if (!isUser &&
                                _containsSafetyKeyword(msg.content)) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Text(
                                  '💡 Safety Note: Consider your energy levels. If this causes sharp pain, stop immediately and consult a medical professional.',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 10,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!isUser &&
                                    (msg.category == CoachReplySource.error ||
                                        msg.category ==
                                            CoachReplySource.local)) ...[
                                  Text(
                                    msg.category == CoachReplySource.error
                                        ? 'Not an AI answer'
                                        : 'Local reply (no AI)',
                                    key: Key('reply_source_${msg.id}'),
                                    style: TextStyle(
                                      color:
                                          msg.category == CoachReplySource.error
                                          ? Colors.redAccent
                                          : Colors.white54,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  DateFormat('h:mm a').format(msg.timestamp),
                                  style: TextStyle(
                                    color: isUser
                                        ? Colors.black54
                                        : Colors.white38,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // AI Message Micro-Action Toolbar (Feedback & Copy)
              if (!isUser) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Was this helpful?',
                        style: TextStyle(
                          color: Colors.grey.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Helpful Button
                      InkWell(
                        onTap: () async {
                          final isCurrentlyHelpful =
                              _feedbackByMessageId[msg.id] == true;
                          final newHelpful = !isCurrentlyHelpful;
                          setState(() {
                            if (isCurrentlyHelpful) {
                              _feedbackByMessageId.remove(msg.id);
                            } else {
                              _feedbackByMessageId[msg.id] = true;
                            }
                          });

                          if (newHelpful) {
                            await FitnessMemory.instance
                                .recordRecommendationFeedback(
                                  recommendationId: msg.id,
                                  isHelpful: true,
                                  recommendationTitle: msg.content.length > 50
                                      ? msg.content.substring(0, 50)
                                      : msg.content,
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Thanks for the feedback! AI Coach is learning.',
                                  ),
                                  backgroundColor: AppColors.primaryContainer,
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _feedbackByMessageId[msg.id] == true
                                ? AppColors.primaryContainer.withValues(
                                    alpha: 0.25,
                                  )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.thumb_up_rounded,
                                size: 12,
                                color: _feedbackByMessageId[msg.id] == true
                                    ? AppColors.primaryContainer
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Helpful',
                                style: TextStyle(
                                  color: _feedbackByMessageId[msg.id] == true
                                      ? AppColors.primaryContainer
                                      : Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Not Useful Button
                      InkWell(
                        onTap: () async {
                          final isCurrentlyUnhelpful =
                              _feedbackByMessageId[msg.id] == false;
                          final newUnhelpful = !isCurrentlyUnhelpful;
                          setState(() {
                            if (isCurrentlyUnhelpful) {
                              _feedbackByMessageId.remove(msg.id);
                            } else {
                              _feedbackByMessageId[msg.id] = false;
                            }
                          });

                          if (newUnhelpful) {
                            await FitnessMemory.instance
                                .recordRecommendationFeedback(
                                  recommendationId: msg.id,
                                  isHelpful: false,
                                  recommendationTitle: msg.content.length > 50
                                      ? msg.content.substring(0, 50)
                                      : msg.content,
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Feedback saved. We\'ll refine future suggestions.',
                                  ),
                                  backgroundColor: Color(0xFF331B1B),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _feedbackByMessageId[msg.id] == false
                                ? Colors.redAccent.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.thumb_down_rounded,
                                size: 12,
                                color: _feedbackByMessageId[msg.id] == false
                                    ? Colors.redAccent
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Not useful',
                                style: TextStyle(
                                  color: _feedbackByMessageId[msg.id] == false
                                      ? Colors.redAccent
                                      : Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: msg.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Message copied to clipboard!',
                              ),
                              backgroundColor: AppColors.primaryContainer,
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              size: 12,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildIntegratedRecommendationCard(
    BuildContext context,
    Recommendation rec,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primaryContainer,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'SUGGESTED ROUTINE',
                style: TextStyle(
                  color: AppColors.primaryContainer,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rec.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rec.description,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                CoachActionHandler.handleAction(
                  context,
                  rec.actionRoute ?? 'open_workout',
                );
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: Text(
                rec.actionTitle.isNotEmpty ? rec.actionTitle : 'Start Routine',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final statusText = _loadingStatus;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer,
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1C24),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? 'Something went wrong.',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              if (_lastSentMessage.isNotEmpty) {
                _handleSend(_lastSentMessage);
              }
            },
            child: const Text(
              'RETRY',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _imageSuggestedPrompts = [
    'What machine is this?',
    'How do I use it?',
    'What muscles does it target?',
    'Give me alternatives',
    'Estimate calories',
    'Estimate protein',
    'Is this good for my goal?',
    'How can I improve this meal?',
    'Explain this exercise',
    'What are common mistakes?',
  ];

  Widget _buildImageSuggestedPrompts() {
    if (_selectedAttachment == null) return const SizedBox.shrink();

    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _imageSuggestedPrompts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = _imageSuggestedPrompts[index];
          return ActionChip(
            label: Text(
              prompt,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFF1E212B),
            side: BorderStyle.none == BorderStyle.solid
                ? BorderSide.none
                : BorderSide(
                    color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            onPressed: () {
              _chatController.text = prompt;
              _handleSend(prompt);
            },
          );
        },
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    if (_selectedAttachment == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _openAttachmentSheet, // Tap thumbnail to replace image
            child: Tooltip(
              message: 'Tap to replace image',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: _selectedAttachment!.base64Data != null
                      ? Image.memory(
                          base64Decode(_selectedAttachment!.base64Data!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.image,
                                color: AppColors.primaryContainer,
                                size: 20,
                              ),
                        )
                      : const Icon(
                          Icons.image,
                          color: AppColors.primaryContainer,
                          size: 20,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onTap: _openAttachmentSheet, // Tap text info to replace image
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedAttachment!.fileName ?? 'Attached Image',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${(_selectedAttachment!.byteSize / 1024).toStringAsFixed(1)} KB • Tap to replace',
                    style: const TextStyle(
                      color: AppColors.primaryContainer,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _selectedAttachment = null),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white12,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputComposer(bool isReplying) {
    final hasText = _chatController.text.trim().isNotEmpty;
    final canSend = (hasText || _selectedAttachment != null) && !isReplying;

    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageSuggestedPrompts(),
          _buildAttachmentPreview(),
          AppGlassContainer(
            borderRadius: BorderRadius.circular(28),
            color: const Color(0xFF1A1C24).withValues(alpha: 0.85),
            blur: 16.0,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // 1. Attachment Button [+]
                IconButton(
                  icon: Icon(
                    _selectedAttachment != null
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    color: _selectedAttachment != null
                        ? AppColors.primaryContainer
                        : Colors.grey,
                    size: 22,
                  ),
                  onPressed: _isPickingImage ? null : _openAttachmentSheet,
                  tooltip: 'Attach image for analysis',
                ),

                // 2. Multiline Text Field
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    enabled: !isReplying,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: _handleSend,
                    decoration: InputDecoration(
                      hintText: isReplying
                          ? 'Atlas is thinking...'
                          : _selectedAttachment != null
                          ? 'Ask about this image...'
                          : 'Ask Atlas anything...',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),

                // 3. Camera Button [ 📷 ]
                IconButton(
                  icon: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.grey,
                    size: 22,
                  ),
                  onPressed: _isPickingImage
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  tooltip: 'Take photo of machine, meal, or form',
                ),

                // 4. Voice Assistant Button [ 🎙️ ]
                IconButton(
                  icon: const Icon(
                    Icons.mic_rounded,
                    color: AppColors.primaryContainer,
                    size: 22,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              Icons.mic_rounded,
                              color: AppColors.primaryContainer,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Atlas Voice Assistant active. Speak your command or question.',
                            ),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Atlas Voice Assistant',
                ),

                // 5. Send Button
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canSend
                        ? AppColors.primaryContainer
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_upward_rounded,
                      color: canSend ? Colors.black : Colors.grey,
                      size: 20,
                    ),
                    onPressed: canSend
                        ? () => _handleSend(_chatController.text)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedText(String content, Color textColor) {
    // Simple helper converting markdown bold and linebreaks into clean Text spans
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.trim().isEmpty) return const SizedBox(height: 6);
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            line,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              height: 1.45,
              fontWeight: line.startsWith('**')
                  ? FontWeight.w800
                  : FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _containsSafetyKeyword(String text) {
    final lower = text.toLowerCase();
    return lower.contains('sore') ||
        lower.contains('pain') ||
        lower.contains('injury') ||
        lower.contains('hurt') ||
        lower.contains('ache');
  }
}

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_chip.dart';
import '../data/ai_chat_service.dart';
import '../models/chat_message.dart';

class AiCoachChatScreen extends StatefulWidget {
  const AiCoachChatScreen({super.key});

  @override
  State<AiCoachChatScreen> createState() => _AiCoachChatScreenState();
}

class _AiCoachChatScreenState extends State<AiCoachChatScreen> {
  late final AIChatService _chatService;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];

  final List<String> _suggestedPrompts = [
    "Generate today's workout",
    "Analyze my progress",
    "Improve my diet",
    "Replace an exercise",
    "Explain proper form",
  ];

  @override
  void initState() {
    super.initState();
    _chatService = AppDependencies.instance.aiChatService;
    _loadMessages();
  }

  void _loadMessages() {
    setState(() {
      _messages = _chatService.getChatHistory();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(sender: 'user', text: text);

    setState(() {
      _messages.add(userMsg);
    });
    _chatService.saveChatHistory(_messages);
    _controller.clear();
    _scrollToBottom();

    _chatService.generateResponse(text).then((botResponse) {
      if (mounted) {
        setState(() {
          _messages.add(botResponse);
        });
        _chatService.saveChatHistory(_messages);
        _scrollToBottom();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppHeader.back(
        title: 'AI Gym Coach',
        subtitle: 'Always online AI trainer',
        onBackTap: () => Navigator.maybePop(context),
        trailing: IconButton(
          icon: Icon(Icons.refresh, color: context.appTextPrimary, size: 20),
          onPressed: () async {
            await _chatService.clearChatHistory();
            _loadMessages();
          },
        ),
      ),
      body: Column(
        children: [
          // Suggested prompts list
          _buildSuggestedPromptsList(),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isBot = msg['sender'] == 'bot';
                if (isBot) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildBotMessage(
                      msg['text'] ?? '',
                      tags: (msg['tags'] as List?)
                          ?.map((e) => e.toString())
                          .toList(),
                      routineCard: msg['routineCard'] == true,
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildUserMessage(msg['text'] ?? ''),
                  );
                }
              },
            ),
          ),

          // Input bar
          _buildInputBar(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSuggestedPromptsList() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestedPrompts.length,
        itemBuilder: (context, index) {
          final prompt = _suggestedPrompts[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppChip(label: prompt, onTap: () => _sendMessage(prompt)),
          );
        },
      ),
    );
  }

  Widget _buildBotMessage(
    String text, {
    List<String>? tags,
    bool routineCard = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 4),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryContainer,
          ),
          child: const Icon(
            Icons.smart_toy,
            size: 14,
            color: AppColors.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(0),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(color: AppColors.surfaceVariant),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppTheme.bodyMd.copyWith(color: AppColors.onSurface),
                ),
                if (tags != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tertiaryFixed,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          tag,
                          style: AppTheme.labelCaps.copyWith(
                            color: AppColors.onTertiaryFixed,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (routineCard) ...[
                  const SizedBox(height: 12),
                  _buildRoutineCard(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserMessage(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(0),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Text(
              text,
              style: AppTheme.bodyMd.copyWith(color: AppColors.onPrimary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 4),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.secondaryContainer,
          ),
          child: const Icon(
            Icons.person,
            size: 14,
            color: AppColors.onSecondaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildRoutineCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.fitness_center,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SUGGESTED ROUTINE',
                  style: AppTheme.labelCaps.copyWith(
                    color: AppColors.primary,
                    fontSize: 8,
                  ),
                ),
                Text(
                  'Mobility Correction A',
                  style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.play_circle,
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.surfaceVariant),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'Ask Aizawl Gym AI...',
                  hintStyle: AppTheme.bodyMd.copyWith(color: AppColors.outline),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            IconButton(
              onPressed: () => _sendMessage(_controller.text),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(
                  Icons.send,
                  color: AppColors.onPrimary,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

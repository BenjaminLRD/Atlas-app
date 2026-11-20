import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/coach_message.dart';
import '../../models/fitness_context.dart';
import 'agent/agent_action.dart';
import 'ai_guardrail_service.dart';
import 'agent/agent_result.dart';
import 'ai_config.dart';
import 'coach_safety_rules.dart';
import 'ai_model_provider.dart';
import 'analytics/ai_usage_tracker.dart';
import 'coach_memory.dart';
import 'coach_prompt_builder.dart';
import 'gemini_transport.dart';
import 'tools/ai_tool.dart';
import 'multimodal/chat_attachment.dart';

/// Structured Exception for Gemini API communication, validation, and HTTP errors.
class GeminiApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkError;
  final dynamic details;

  const GeminiApiException({
    required this.message,
    this.statusCode,
    this.isNetworkError = false,
    this.details,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'GeminiApiException (HTTP $statusCode): $message';
    }
    return 'GeminiApiException: $message';
  }
}

/// Production AI Provider for Google Gemini (gemini-2.5-flash).
/// Requests go through the Supabase `ai-proxy` Edge Function in production, or
/// directly to Google with a developer key in debug builds (see [AIConfig]).
/// Handles multimodal attachments, function calling and structured errors.
class GeminiAIProvider implements AIModelProvider {
  final AIConfig config;
  final CoachMemory memory;
  final CoachPromptBuilder promptBuilder;
  final http.Client? httpClient;

  bool _lastCallSucceeded = false;
  String _lastStatus = 'Ready';

  GeminiAIProvider({
    AIConfig? config,
    this.memory = const CoachMemory(),
    this.promptBuilder = const CoachPromptBuilder(),
    this.httpClient,
  }) : config = config ?? AIConfig.fromEnvironment();

  @override
  String get providerName => 'Google Gemini (${config.model})';

  @override
  String get modelIdentifier => config.model;

  @override
  int get maxContextTokens => 1000000;

  @override
  bool get supportsVision => true;

  @override
  bool get supportsToolCalling => true;

  @override
  int estimateTokens(String text) => AIUsageTracker.estimateTokens(text);

  @override
  bool get isOnline => config.isConfigured;

  /// Internal indicator: true if a live Gemini request can be made now.
  bool get isGeminiActive => config.isConfigured;

  /// Human-readable runtime diagnostic status indicator.
  String get runtimeStatus {
    if (!config.isConfigured) {
      return config.proxyUrl.isNotEmpty
          ? 'Gemini Inactive (Sign in required)'
          : 'Gemini Inactive (AI backend not configured)';
    }
    if (_lastCallSucceeded) {
      return 'Gemini Active (${config.model})';
    }
    return _lastStatus;
  }

  @override
  Future<String> analyzeImage({
    required ChatAttachment attachment,
    required String prompt,
    required FitnessContext context,
  }) async {
    return generateResponse(
      message: prompt,
      context: context,
      history: const [],
      attachment: attachment,
    );
  }

  /// Most recent chat messages sent as context for follow-up questions.
  static const int maxHistoryMessages = 8;

  /// Longest text kept per history message.
  static const int maxHistoryChars = 600;

  /// The real user messages and AI answers of [history] in order, without
  /// local redirects, error notices or the message being sent now.
  static List<CoachMessage> _chatTurns(
    List<CoachMessage> history,
    String currentMessage,
  ) {
    final turns = history.where((m) {
      if (m.role != CoachRole.user && m.role != CoachRole.assistant) {
        return false;
      }
      if (m.content.trim().isEmpty) return false;
      if (m.role == CoachRole.assistant) {
        if (m.category == CoachReplySource.local ||
            m.category == CoachReplySource.error) {
          return false;
        }
        // Messages saved before sources were recorded.
        if (m.id.startsWith('msg_error_') ||
            m.content == AIGuardrailService.offTopicResponse) {
          return false;
        }
      }
      return true;
    }).toList();

    // The chat service stores the new user message before asking the model.
    if (turns.isNotEmpty &&
        turns.last.role == CoachRole.user &&
        (turns.last.content.trim() == currentMessage.trim() ||
            turns.last.hasImage)) {
      turns.removeLast();
    }
    return turns;
  }

  /// The system instruction for a chat request: the fixed Atlas AI rules plus,
  /// for a long conversation, a short note of what the dropped older turns
  /// covered.
  static Map<String, dynamic> systemInstructionFor(
    List<CoachMessage> history, {
    required String currentMessage,
  }) {
    final turns = _chatTurns(history, currentMessage);
    final dropped = turns.length > maxHistoryMessages
        ? turns.sublist(0, turns.length - maxHistoryMessages)
        : const <CoachMessage>[];
    final summary = CoachSafetyRules.summarizeEarlier(dropped);
    return {
      'parts': [
        {
          'text': summary == null
              ? CoachSafetyRules.systemInstruction
              : '${CoachSafetyRules.systemInstruction}\n$summary',
        },
      ],
    };
  }

  /// Recent conversation as Gemini `contents` turns (`user` / `model`), oldest
  /// first. Only real user messages and real AI answers are included: local
  /// redirects and error notices are left out, the message being sent now is
  /// not repeated, and the list is capped in count and length.
  static List<Map<String, dynamic>> buildHistoryContents(
    List<CoachMessage> history, {
    required String currentMessage,
  }) {
    final turns = _chatTurns(history, currentMessage);

    final recent = turns.length > maxHistoryMessages
        ? turns.sublist(turns.length - maxHistoryMessages)
        : turns;

    final contents = <Map<String, dynamic>>[];
    for (final m in recent) {
      final role = m.role == CoachRole.user ? 'user' : 'model';
      if (contents.isEmpty && role != 'user') continue; // must start with user
      var text = m.content.trim();
      if (text.length > maxHistoryChars) {
        text = '${text.substring(0, maxHistoryChars)}…';
      }
      if (contents.isNotEmpty && contents.last['role'] == role) {
        final parts = contents.last['parts'] as List<Map<String, dynamic>>;
        parts.first['text'] = '${parts.first['text']}\n$text';
      } else {
        contents.add({
          'role': role,
          'parts': <Map<String, dynamic>>[
            {'text': text},
          ],
        });
      }
    }
    return contents;
  }

  @override
  Future<String> generateResponse({
    required String message,
    required FitnessContext context,
    required List<CoachMessage> history,
    ChatAttachment? attachment,
  }) async {
    // 1. Verify API Key
    if (!config.isConfigured) {
      _lastCallSucceeded = false;
      final unavailable = unavailableException(config);
      _lastStatus = unavailable.message;
      throw unavailable;
    }

    try {
      final promptText = promptBuilder.buildPrompt(
        message: message,
        context: context,
        memory: memory,
      );

      final parts = <Map<String, dynamic>>[
        {'text': promptText},
      ];

      // Add multimodal image attachment if provided
      if (attachment != null &&
          attachment.base64Data != null &&
          attachment.base64Data!.isNotEmpty) {
        parts.add({
          'inline_data': {
            'mime_type': attachment.mimeType,
            'data': attachment.base64Data,
          },
        });
      }

      final client = httpClient ?? http.Client();
      final response = await postGenerateContent(
        client: client,
        config: config,
        feature: 'coach',
        body: {
          'systemInstruction': systemInstructionFor(
            history,
            currentMessage: message,
          ),
          'contents': [
            ...buildHistoryContents(history, currentMessage: message),
            {'role': 'user', 'parts': parts},
          ],
          'generationConfig': AIConfig.coachGenerationConfig(
            config.temperature,
          ),
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // Throws a friendly error for truncated or blocked answers.
        final text = answerFromResponse(body);
        _lastCallSucceeded = true;
        _lastStatus = 'Gemini Active (${config.model})';
        return text;
      }

      // Non-200: never show raw provider or platform bodies to the user.
      _lastCallSucceeded = false;
      _lastStatus = 'Atlas AI error (HTTP ${response.statusCode})';
      throw GeminiApiException(
        message: userMessageForHttpError(
          response.statusCode,
          _errorMessageFrom(response.body),
        ),
        statusCode: response.statusCode,
      );
    } on GeminiApiException {
      rethrow;
    } on TimeoutException {
      _lastCallSucceeded = false;
      _lastStatus = 'Timed out after ${AIConfig.requestTimeout.inSeconds}s';
      throw const GeminiApiException(message: AIConfig.timeoutMessage);
    } on FormatException {
      _lastCallSucceeded = false;
      _lastStatus = 'Unreadable response';
      throw const GeminiApiException(message: unreadableResponseMessage);
    } catch (e) {
      _lastCallSucceeded = false;
      _lastStatus = 'Connection Error: $e';
      throw const GeminiApiException(
        message:
            'Unable to reach Atlas AI. Check your connection and try again.',
        isNetworkError: true,
      );
    }
  }

  /// Generates a tool-augmented agent response using Gemini Function Calling.
  Future<AgentResult> generateAgentResponse({
    required String message,
    required FitnessContext context,
    required List<CoachMessage> history,
    required List<AITool> tools,
    ChatAttachment? attachment,
  }) async {
    if (!config.isConfigured) {
      _lastCallSucceeded = false;
      final unavailable = unavailableException(config);
      _lastStatus = unavailable.message;
      throw unavailable;
    }

    try {
      final promptText = promptBuilder.buildPrompt(
        message: message,
        context: context,
        memory: memory,
      );

      final toolsJson = [
        {
          'function_declarations': tools
              .map((t) => t.toFunctionDeclaration())
              .toList(),
        },
      ];

      final parts = <Map<String, dynamic>>[
        {'text': promptText},
      ];

      if (attachment != null &&
          attachment.base64Data != null &&
          attachment.base64Data!.isNotEmpty) {
        parts.add({
          'inline_data': {
            'mime_type': attachment.mimeType,
            'data': attachment.base64Data,
          },
        });
      }

      final client = httpClient ?? http.Client();
      final response = await postGenerateContent(
        client: client,
        config: config,
        feature: 'coach',
        body: {
          'systemInstruction': systemInstructionFor(
            history,
            currentMessage: message,
          ),
          'contents': [
            ...buildHistoryContents(history, currentMessage: message),
            {'role': 'user', 'parts': parts},
          ],
          'tools': toolsJson,
          'generationConfig': AIConfig.coachGenerationConfig(
            config.temperature,
          ),
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        ensureCompleteResponse(body);
        final candidates = body['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final candidateContent =
              candidates.first['content'] as Map<String, dynamic>?;
          final resParts = candidateContent?['parts'] as List<dynamic>?;

          if (resParts != null && resParts.isNotEmpty) {
            // Check for Gemini function call
            final functionCallPart = resParts.firstWhere(
              (p) => p is Map && p.containsKey('functionCall'),
              orElse: () => null,
            );

            if (functionCallPart != null) {
              final functionCall =
                  functionCallPart['functionCall'] as Map<String, dynamic>;
              final toolName = functionCall['name'] as String;
              final toolArgs = Map<String, dynamic>.from(
                functionCall['args'] as Map? ?? {},
              );

              final tool = tools.firstWhere(
                (t) => t.name == toolName,
                orElse: () => throw GeminiApiException(
                  message: 'Tool requested by Gemini not found: $toolName',
                ),
              );

              final toolOutput = await tool.execute(toolArgs);
              final executedAction = AgentAction(
                id: 'act_${DateTime.now().millisecondsSinceEpoch}',
                toolName: toolName,
                action: toolArgs['action'] as String? ?? toolName,
                arguments: toolArgs,
                result: toolOutput,
                requiresConfirmation:
                    toolOutput['requires_confirmation'] == true,
                confirmationPrompt: toolOutput['prompt'] as String?,
                timestamp: DateTime.now(),
              );

              if (toolOutput['requires_confirmation'] == true) {
                final promptMsg =
                    toolOutput['prompt'] as String? ??
                    'Action requires confirmation.';
                return AgentResult(
                  responseText: promptMsg,
                  actionsExecuted: [executedAction],
                  pendingConfirmationAction: executedAction,
                  providerName: providerName,
                );
              }

              // Send function response back to Gemini to synthesize natural language output
              final followUpBody = <String, dynamic>{
                'systemInstruction': {
                  'parts': [
                    {'text': CoachSafetyRules.systemInstruction},
                  ],
                },
                'contents': [
                  {
                    'role': 'user',
                    'parts': [
                      {'text': promptText},
                    ],
                  },
                  {
                    'role': 'model',
                    'parts': [
                      {
                        'functionCall': {'name': toolName, 'args': toolArgs},
                      },
                    ],
                  },
                  {
                    'role': 'function',
                    'parts': [
                      {
                        'functionResponse': {
                          'name': toolName,
                          'response': toolOutput,
                        },
                      },
                    ],
                  },
                ],
                'tools': toolsJson,
                'generationConfig': AIConfig.coachGenerationConfig(
                  config.temperature,
                ),
              };

              final followUpResponse = await postGenerateContent(
                client: client,
                config: config,
                feature: 'coach',
                body: followUpBody,
              );

              if (followUpResponse.statusCode == 200) {
                final followUpJson =
                    jsonDecode(followUpResponse.body) as Map<String, dynamic>;
                try {
                  ensureCompleteResponse(followUpJson);
                } on GeminiApiException {
                  // Do not present a cut-off or blocked synthesis as an
                  // answer; fall back to the tool's own message below.
                  return AgentResult(
                    responseText:
                        'Executed $toolName: ${toolOutput['message'] ?? toolOutput.toString()}',
                    actionsExecuted: [executedAction],
                    providerName: providerName,
                  );
                }
                final followUpCandidates =
                    followUpJson['candidates'] as List<dynamic>?;
                if (followUpCandidates != null &&
                    followUpCandidates.isNotEmpty) {
                  final followUpParts =
                      (followUpCandidates.first['content']
                              as Map<String, dynamic>?)?['parts']
                          as List<dynamic>?;
                  if (followUpParts != null && followUpParts.isNotEmpty) {
                    final text = followUpParts.first['text'] as String?;
                    if (text != null && text.trim().isNotEmpty) {
                      _lastCallSucceeded = true;
                      _lastStatus = 'Gemini Active (${config.model})';
                      return AgentResult(
                        responseText: text.trim(),
                        actionsExecuted: [executedAction],
                        providerName: providerName,
                      );
                    }
                  }
                }
              }

              return AgentResult(
                responseText:
                    'Executed $toolName: ${toolOutput['message'] ?? toolOutput.toString()}',
                actionsExecuted: [executedAction],
                providerName: providerName,
              );
            } else {
              // Direct text response
              final text = resParts.first['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                _lastCallSucceeded = true;
                _lastStatus = 'Gemini Active (${config.model})';
                return AgentResult(
                  responseText: text.trim(),
                  providerName: providerName,
                );
              }
            }
          }
        }
      }

      _lastCallSucceeded = false;
      if (response.statusCode == 200) {
        // A readable 200 with nothing usable in it.
        _lastStatus = 'Empty agent response';
        throw const GeminiApiException(message: emptyResponseMessage);
      }
      _lastStatus = 'Atlas AI agent error (HTTP ${response.statusCode})';
      throw GeminiApiException(
        message: userMessageForHttpError(
          response.statusCode,
          _errorMessageFrom(response.body),
        ),
        statusCode: response.statusCode,
      );
    } on GeminiApiException {
      rethrow;
    } on TimeoutException {
      _lastCallSucceeded = false;
      _lastStatus =
          'Agent timed out after ${AIConfig.requestTimeout.inSeconds}s';
      throw const GeminiApiException(message: AIConfig.timeoutMessage);
    } on FormatException {
      _lastCallSucceeded = false;
      _lastStatus = 'Unreadable agent response';
      throw const GeminiApiException(message: unreadableResponseMessage);
    } catch (e) {
      _lastCallSucceeded = false;
      _lastStatus = 'Agent connection error: $e';
      throw const GeminiApiException(
        message:
            'Unable to reach Atlas AI. Check your connection and try again.',
        isNetworkError: true,
      );
    }
  }

  static const String truncatedMessage =
      "Atlas AI's answer was cut off before it finished. Please ask again, or ask for a shorter answer.";
  static const String blockedMessage =
      "Atlas AI couldn't answer that request. Try rephrasing it.";
  static const String incompleteMessage =
      "Atlas AI couldn't complete that request. Please try again.";
  static const String emptyResponseMessage =
      'Atlas AI returned an empty answer. Please try again.';
  static const String unreadableResponseMessage =
      'Atlas AI sent a response that could not be read. Please try again.';

  /// `finishReason` values that mean the answer is complete. Anything else
  /// (MAX_TOKENS, SAFETY, RECITATION, BLOCKLIST, ...) is not.
  static const Set<String> _completeFinishReasons = {
    'STOP',
    'FINISH_REASON_UNSPECIFIED',
  };

  /// Throws a user-safe [GeminiApiException] when Gemini's response is not a
  /// complete answer: the prompt was blocked (`promptFeedback.blockReason`),
  /// the answer was cut off (`finishReason: MAX_TOKENS`), or generation ended
  /// for any other non-success reason. Returns normally for `STOP`, or when
  /// no reason is given.
  static void ensureCompleteResponse(Map<String, dynamic> body) {
    final feedback = body['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] != null) {
      throw const GeminiApiException(message: blockedMessage);
    }
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const GeminiApiException(message: emptyResponseMessage);
    }
    final first = candidates.first;
    final reason = first is Map ? first['finishReason'] : null;
    if (reason == null || _completeFinishReasons.contains(reason)) return;
    if (reason == 'MAX_TOKENS') {
      throw const GeminiApiException(message: truncatedMessage);
    }
    const blocked = {
      'SAFETY',
      'RECITATION',
      'LANGUAGE',
      'BLOCKLIST',
      'PROHIBITED_CONTENT',
      'SPII',
      'IMAGE_SAFETY',
    };
    throw GeminiApiException(
      message: blocked.contains(reason) ? blockedMessage : incompleteMessage,
    );
  }

  /// The answer text of a complete Gemini response, or a friendly
  /// [GeminiApiException]. See [ensureCompleteResponse].
  static String answerFromResponse(Map<String, dynamic> body) {
    ensureCompleteResponse(body);
    final candidate = (body['candidates'] as List).first;
    final content = candidate is Map ? candidate['content'] : null;
    final parts = content is Map ? content['parts'] : null;
    if (parts is List && parts.isNotEmpty) {
      final first = parts.first;
      final text = first is Map ? first['text'] : null;
      if (text is String && text.trim().isNotEmpty) return text.trim();
    }
    throw const GeminiApiException(message: emptyResponseMessage);
  }

  /// The `error.message` of a JSON error body, or '' when the body is not
  /// the proxy's / Gemini's JSON error shape (for example an HTML page).
  static String _errorMessageFrom(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] is Map) {
        return (json['error']['message'] as String?) ?? '';
      }
    } catch (_) {}
    return '';
  }

  /// Shown when the app was built without the Supabase settings that locate
  /// the `ai-proxy` function.
  static const String backendNotConfiguredMessage =
      'Atlas AI is not set up in this build of the app: the Supabase URL and '
      'anon key were missing when it was built.';

  /// Shown when the AI backend is known but nobody is signed in.
  static const String notSignedInMessage = 'Sign in to use Atlas AI.';

  /// The error for a request that cannot be sent, with the real reason: a
  /// build without backend settings is not the same as a signed-out user.
  static GeminiApiException unavailableException(AIConfig config) {
    if (config.unavailableReason == AIUnavailableReason.backendNotConfigured) {
      return const GeminiApiException(
        message: backendNotConfiguredMessage,
        statusCode: 503,
      );
    }
    return const GeminiApiException(
      message: notSignedInMessage,
      statusCode: 401,
    );
  }

  /// Why Atlas AI cannot be used right now, or null when it can.
  AIUnavailableReason? get unavailableReason => config.unavailableReason;

  /// Messages the ai-proxy writes for the user. Only these are shown as
  /// they are; everything else is replaced by a short generic message, so no
  /// provider body, HTML page or token ever reaches the chat.
  static const List<String> _proxyUserMessages = [
    'Sign in to use Atlas AI.',
    'Your session expired. Sign in again.',
    'Daily AI limit reached. Upgrade to Atlas Pro for more.',
    'Daily AI limit reached. It resets at midnight UTC.',
    'Atlas AI is not configured on the server.',
    showcaseBusyMessage,
    showcaseNotEnabledMessage,
  ];

  /// The proxy's message when anonymous Showcase traffic is over its limit.
  static const String showcaseBusyMessage =
      'The Showcase AI is busy right now. Please try again in a minute.';

  /// The proxy's message when the server has not been set up for Showcase AI.
  static const String showcaseNotEnabledMessage =
      'Showcase AI is not enabled on the server yet.';

  /// A short, user-safe message for a non-200 response.
  static String userMessageForHttpError(int statusCode, String upstream) {
    if ((statusCode == 401 || statusCode == 429 || statusCode == 503) &&
        _proxyUserMessages.contains(upstream)) {
      return upstream;
    }
    switch (statusCode) {
      case 401:
        return 'Please sign in again to use Atlas AI.';
      case 403:
        return 'Atlas AI is not available for this account right now.';
      case 400:
        return "Atlas AI couldn't process that request. Try rephrasing it or using a smaller photo.";
      case 413:
        return 'That message or photo is too large. Try a smaller photo.';
      case 429:
        return 'Atlas AI is busy right now. Please try again in a minute.';
      default:
        return 'Atlas AI is temporarily unavailable. Please try again in a moment.';
    }
  }
}

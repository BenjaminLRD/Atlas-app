/// Represents an action requested or executed by the AI Agent via [AITool]s.
class AgentAction {
  final String id;
  final String toolName;
  final String action;
  final Map<String, dynamic> arguments;
  final Map<String, dynamic>? result;
  final bool requiresConfirmation;
  final bool isConfirmed;
  final String? confirmationPrompt;
  final DateTime timestamp;

  const AgentAction({
    required this.id,
    required this.toolName,
    required this.action,
    required this.arguments,
    this.result,
    this.requiresConfirmation = false,
    this.isConfirmed = false,
    this.confirmationPrompt,
    required this.timestamp,
  });

  AgentAction copyWith({
    String? id,
    String? toolName,
    String? action,
    Map<String, dynamic>? arguments,
    Map<String, dynamic>? result,
    bool? requiresConfirmation,
    bool? isConfirmed,
    String? confirmationPrompt,
    DateTime? timestamp,
  }) {
    return AgentAction(
      id: id ?? this.id,
      toolName: toolName ?? this.toolName,
      action: action ?? this.action,
      arguments: arguments ?? this.arguments,
      result: result ?? this.result,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      confirmationPrompt: confirmationPrompt ?? this.confirmationPrompt,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tool': toolName,
    'action': action,
    'arguments': arguments,
    if (result != null) 'result': result,
    'requires_confirmation': requiresConfirmation,
    'is_confirmed': isConfirmed,
    if (confirmationPrompt != null) 'confirmation_prompt': confirmationPrompt,
    'timestamp': timestamp.toIso8601String(),
  };
}

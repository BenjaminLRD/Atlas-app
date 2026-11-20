import 'agent_action.dart';

/// Complete result returned by the [AIAgent] orchestrator.
class AgentResult {
  final String responseText;
  final List<AgentAction> actionsExecuted;
  final AgentAction? pendingConfirmationAction;
  final bool isOfflineFallback;
  final String providerName;

  const AgentResult({
    required this.responseText,
    this.actionsExecuted = const [],
    this.pendingConfirmationAction,
    this.isOfflineFallback = false,
    this.providerName = 'AI Agent',
  });

  bool get hasPendingConfirmation => pendingConfirmationAction != null;

  Map<String, dynamic> toJson() => {
    'response_text': responseText,
    'actions_executed': actionsExecuted.map((a) => a.toJson()).toList(),
    if (pendingConfirmationAction != null)
      'pending_confirmation': pendingConfirmationAction!.toJson(),
    'is_offline_fallback': isOfflineFallback,
    'provider': providerName,
  };
}

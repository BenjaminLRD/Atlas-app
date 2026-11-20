import 'dart:async';

/// Base contract for all executable AI agent tools.
abstract class AITool {
  /// Unique identifier/name of the tool matching function calling conventions (e.g. 'workout_tool').
  String get name;

  /// Human and model readable description explaining tool capabilities and when to call it.
  String get description;

  /// JSON Schema definition of parameters accepted by this tool.
  Map<String, dynamic> get parametersSchema;

  /// Whether this tool performs destructive/mutating writes requiring user confirmation.
  bool get requiresConfirmation => false;

  /// Executes the tool with the provided arguments and returns structured JSON output.
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments);

  /// Formats this tool into Gemini Function Declaration JSON schema.
  Map<String, dynamic> toFunctionDeclaration() {
    return {
      'name': name,
      'description': description,
      'parameters': parametersSchema,
    };
  }
}

/// Represents the execution outcome of an [AITool].
class ToolExecutionResult {
  final String toolName;
  final Map<String, dynamic> arguments;
  final Map<String, dynamic> result;
  final bool isSuccess;
  final String? errorMessage;
  final bool requiresConfirmation;
  final String? confirmationPrompt;

  const ToolExecutionResult({
    required this.toolName,
    required this.arguments,
    required this.result,
    this.isSuccess = true,
    this.errorMessage,
    this.requiresConfirmation = false,
    this.confirmationPrompt,
  });

  Map<String, dynamic> toJson() => {
    'tool': toolName,
    'arguments': arguments,
    'result': result,
    'success': isSuccess,
    if (errorMessage != null) 'error': errorMessage,
    'requires_confirmation': requiresConfirmation,
    if (confirmationPrompt != null) 'confirmation_prompt': confirmationPrompt,
  };
}

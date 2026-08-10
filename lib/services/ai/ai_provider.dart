import '../../models/coach_message.dart';
import '../../models/fitness_context.dart';

/// Abstract interface defining the AI Provider contract for fitness coaching responses.
abstract class AIProvider {
  /// Generates a context-aware response based on the user's input message,
  /// current [FitnessContext], and previous conversation [history].
  Future<String> generateResponse({
    required String message,
    required FitnessContext context,
    required List<CoachMessage> history,
  });
}

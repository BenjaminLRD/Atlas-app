import 'dart:async';
import 'dart:io';
import '../../services/supabase/supabase_client.dart';

/// Maps raw technical runtime exceptions and HTTP errors to clear,
/// reassuring, user-friendly messages for athlete UI presentations.
class ErrorMessageMapper {
  /// Maps an [error] object to a friendly title and subtitle description.
  static ({String title, String message}) map(Object? error) {
    if (error == null) {
      return (
        title: 'Something went wrong',
        message: 'An unexpected issue occurred. Please try again.',
      );
    }

    final errStr = error.toString().toLowerCase();

    // 1. Network & Offline Errors
    if (error is SocketException ||
        errStr.contains('socketexception') ||
        errStr.contains('network unavailable') ||
        errStr.contains('offline') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('connection refused')) {
      return (
        title: 'No Internet Connection',
        message:
            'Unable to connect to Atlas servers. Check your internet connection and try again.',
      );
    }

    // 2. Timeout Exceptions
    if (error is TimeoutException || errStr.contains('timeout')) {
      return (
        title: 'Request Timed Out',
        message:
            'The server took too long to respond. Please check your signal and try again.',
      );
    }

    // 3. Authentication & Security Violations
    if (error is PostgresSecurityException ||
        errStr.contains('unauthorized') ||
        errStr.contains('permission denied') ||
        errStr.contains('rls violation')) {
      return (
        title: 'Access Restricted',
        message:
            'You do not have permission to access this resource or your session has expired.',
      );
    }

    // 4. AI Coach Rate Limit or Service Unavailable
    if (errStr.contains('gemini') ||
        errStr.contains('quota') ||
        errStr.contains('rate limit')) {
      return (
        title: 'AI Coach Busy',
        message:
            'Our AI fitness engine is experiencing high demand. Please try again in a few moments.',
      );
    }

    // 5. Default Fallback
    return (
      title: 'Unable to Load Data',
      message:
          'We encountered an issue loading your information. Please tap retry.',
    );
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_config.dart';

const String geminiApiBaseUrl =
    'https://generativelanguage.googleapis.com/v1beta/models';

/// Sends a Gemini `generateContent` request and returns the raw response.
///
/// With [AIConfig.usesProxy] the request is wrapped and posted to the Supabase
/// `ai-proxy` Edge Function with the user's access token; the function forwards
/// it to Gemini and returns Gemini's response unchanged, so callers parse both
/// paths the same way. Otherwise the developer key is sent in the
/// `x-goog-api-key` header, never in the URL.
///
/// [feature] names the quota bucket on the server (`coach` or `food_scan`).
/// Header that marks a request as an anonymous Showcase request.
const String showcaseHeader = 'x-atlas-showcase';

/// The Showcase proxy's hard request ceiling (ai-proxy SHOWCASE_MAX_BODY_BYTES).
const int showcaseMaxRequestBytes = 1250000;

Future<http.Response> postGenerateContent({
  required http.Client client,
  required AIConfig config,
  required Map<String, dynamic> body,
  required String feature,
  Duration timeout = AIConfig.requestTimeout,
}) async {
  if (config.usesShowcaseProxy) {
    // Showcase request: no user token, no user id. The proxy recognises it by
    // the header and the body flag, checks the anon key, and applies its own
    // limits for anonymous showcase traffic.
    final payload = jsonEncode({
      'model': config.model,
      'feature': feature,
      'showcase': true,
      'request': body,
    });
    // The Showcase proxy refuses a request over this size without reading it,
    // which leaves a big upload hanging until the timeout. Say so straight away.
    if (utf8.encode(payload).length > showcaseMaxRequestBytes) {
      return http.Response(
        jsonEncode({
          'error': {'code': 413, 'message': 'Request too large.'},
        }),
        413,
        headers: {'content-type': 'application/json'},
      );
    }
    final response = await client
        .post(
          Uri.parse(config.proxyUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.anonKey}',
            'apikey': config.anonKey,
            showcaseHeader: '1',
          },
          body: payload,
        )
        .timeout(timeout);
    // A server that has not been updated for Showcase answers a request with
    // no user token as "sign in". That is not what is wrong in Showcase Mode,
    // so say what is: the server is not set up for it yet.
    if (response.statusCode == 401 || response.statusCode == 403) {
      return http.Response(
        jsonEncode({
          'error': {
            'code': 503,
            'message': 'Showcase AI is not enabled on the server yet.',
          },
        }),
        503,
        headers: {'content-type': 'application/json'},
      );
    }
    return response;
  }
  if (config.usesProxy) {
    final token = config.accessTokenProvider?.call();
    if (token == null || token.isEmpty) {
      return http.Response(
        jsonEncode({
          'error': {'code': 401, 'message': 'Sign in to use Atlas AI.'},
        }),
        401,
        headers: {'content-type': 'application/json'},
      );
    }
    return client
        .post(
          Uri.parse(config.proxyUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'model': config.model,
            'feature': feature,
            'request': body,
          }),
        )
        .timeout(timeout);
  }

  return client
      .post(
        Uri.parse('$geminiApiBaseUrl/${config.model}:generateContent'),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': config.apiKey,
        },
        body: jsonEncode(body),
      )
      .timeout(timeout);
}

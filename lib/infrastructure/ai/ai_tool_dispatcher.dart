import 'package:cloud_functions/cloud_functions.dart';

import 'ai_tool_definitions.dart';
import 'ai_tool_result.dart';

class AiToolDispatcher {
  final FirebaseFunctions functions;

  const AiToolDispatcher(this.functions);

  Future<AiToolEnvelope> call(String toolName, Map<String, dynamic> args) async {
    if (!AiToolNames.allowlist.contains(toolName)) {
      return const AiToolEnvelope(
        success: false,
        error: AiToolError(code: 'TOOL_NOT_ALLOWED', message: 'Tool is not allowlisted.', retryable: false),
      );
    }

    try {
      final callable = functions.httpsCallable(toolName);
      final res = await callable.call(args);
      final data = res.data;
      if (data is Map) {
        return AiToolEnvelope.fromJson(Map<String, dynamic>.from(data));
      }
      return const AiToolEnvelope(
        success: false,
        error: AiToolError(code: 'BAD_RESPONSE', message: 'Tool response was not an object.', retryable: true),
      );
    } on FirebaseFunctionsException catch (e) {
      final message = switch (e.code) {
        'not-found' =>
          'Tool endpoint not found. This usually means Cloud Functions are not deployed to the current Firebase project (or deployed to a different region). Deploy Functions and retry.',
        _ => e.message ?? 'Cloud Functions error.',
      };
      return AiToolEnvelope(
        success: false,
        error: AiToolError(
          code: e.code,
          message: message,
          retryable: e.code == 'unavailable' || e.code == 'deadline-exceeded',
        ),
      );
    } catch (e) {
      return AiToolEnvelope(
        success: false,
        error: AiToolError(code: 'INTERNAL', message: e.toString(), retryable: true),
      );
    }
  }
}


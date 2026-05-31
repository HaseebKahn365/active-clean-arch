import 'package:cloud_functions/cloud_functions.dart';
import 'dart:developer' as dev;

import 'ai_tool_contracts.dart';
import 'ai_tool_definitions.dart';
import 'ai_tool_result.dart';

class AiToolDispatcher {
  final FirebaseFunctions functions;

  const AiToolDispatcher(this.functions);

  Future<AiToolEnvelope> call(
    String toolName,
    Map<String, dynamic> args, {
    String? sessionId,
  }) async {
    if (!AiToolNames.allowlist.contains(toolName)) {
      return AiToolEnvelope.failure(
        tool: toolName,
        errorCode: AiToolErrorCodes.validationError,
        message: 'Tool is not allowlisted.',
        retryable: false,
      );
    }

    final required =
        AiToolContracts.byName[toolName]?.requiredFields ?? const <String>[];
    final missing = required
        .where((field) {
          final value = args[field];
          return value == null || (value is String && value.trim().isEmpty);
        })
        .toList(growable: false);
    if (missing.isNotEmpty) {
      return AiToolEnvelope.failure(
        tool: toolName,
        errorCode: AiToolErrorCodes.missingParameter,
        message: 'Missing required parameter(s): ${missing.join(', ')}',
      );
    }

    try {
      dev.log('TOOL CALL START: $toolName');
      final callable = functions.httpsCallable(toolName);
      final payload = <String, dynamic>{...args};
      if (sessionId != null && sessionId.trim().isNotEmpty) {
        payload['sessionId'] = sessionId;
      }
      final res = await callable.call(payload);
      final data = res.data;
      if (data is Map) {
        final envelope = AiToolEnvelope.fromJson(
          Map<String, dynamic>.from(data),
        );
        final normalized = AiToolEnvelope(
          success: envelope.success,
          tool: envelope.tool == 'unknown_tool' ? toolName : envelope.tool,
          data: envelope.data,
          message: envelope.message,
          errorCode: envelope.errorCode,
          action: envelope.action,
          activityId: envelope.activityId,
          activityName: envelope.activityName,
          error: envelope.error,
        );
        if (normalized.success) {
          dev.log('TOOL CALL SUCCESS: $toolName');
        } else {
          dev.log(
            'TOOL CALL FAILED: $toolName errorCode=${normalized.errorCode ?? AiToolErrorCodes.internalError}',
          );
        }
        return normalized;
      }
      return AiToolEnvelope.failure(
        tool: toolName,
        errorCode: AiToolErrorCodes.validationError,
        message: 'Tool response was not an object.',
        retryable: true,
      );
    } on FirebaseFunctionsException catch (e) {
      final message = switch (e.code) {
        'not-found' =>
          'Tool endpoint not found. This usually means Cloud Functions are not deployed to the current Firebase project (or deployed to a different region). Deploy Functions and retry.',
        _ => e.message ?? 'Cloud Functions error.',
      };
      final errorCode = switch (e.code) {
        'not-found' => AiToolErrorCodes.notFound,
        'permission-denied' => AiToolErrorCodes.permissionDenied,
        _ => AiToolErrorCodes.internalError,
      };
      dev.log('TOOL CALL FAILED: $toolName errorCode=$errorCode');
      return AiToolEnvelope.failure(
        tool: toolName,
        errorCode: errorCode,
        message: message,
        retryable: e.code == 'unavailable' || e.code == 'deadline-exceeded',
      );
    } catch (e) {
      dev.log(
        'TOOL CALL FAILED: $toolName errorCode=${AiToolErrorCodes.internalError}',
      );
      return AiToolEnvelope.failure(
        tool: toolName,
        errorCode: AiToolErrorCodes.internalError,
        message: e.toString(),
        retryable: true,
      );
    }
  }

  Future<void> abortSession(String sessionId) async {
    if (sessionId.trim().isEmpty) return;
    try {
      final callable = functions.httpsCallable('abortAiSession');
      await callable.call(<String, dynamic>{'sessionId': sessionId});
      dev.log('TOOL CALL SUCCESS: abortAiSession');
    } catch (e) {
      dev.log(
        'TOOL CALL FAILED: abortAiSession errorCode=${AiToolErrorCodes.internalError}',
      );
    }
  }
}

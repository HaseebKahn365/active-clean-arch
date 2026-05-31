class AiToolError {
  final String code;
  final String message;
  final bool retryable;

  const AiToolError({
    required this.code,
    required this.message,
    required this.retryable,
  });

  factory AiToolError.fromJson(Map<String, dynamic> json) => AiToolError(
    code: (json['code'] ?? '').toString(),
    message: (json['message'] ?? '').toString(),
    retryable: json['retryable'] == true,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    'retryable': retryable,
  };
}

class AiToolEnvelope {
  final bool success;
  final String tool;
  final Map<String, dynamic> data;
  final String message;
  final String markdownFallback;
  final String? errorCode;

  // Legacy compatibility fields used by existing UI components.
  final String? action;
  final String? activityId;
  final String? activityName;
  final AiToolError? error;

  const AiToolEnvelope({
    required this.success,
    this.tool = '',
    this.data = const {},
    this.message = '',
    this.markdownFallback = '',
    this.errorCode,
    this.action,
    this.activityId,
    this.activityName,
    this.error,
  });

  factory AiToolEnvelope.success({
    required String tool,
    Map<String, dynamic> data = const {},
    String message = '',
    String markdownFallback = '',
    String? activityId,
    String? activityName,
    String? action,
  }) {
    return AiToolEnvelope(
      success: true,
      tool: tool,
      data: data,
      message: message,
      markdownFallback: markdownFallback,
      errorCode: null,
      action: action,
      activityId: activityId,
      activityName: activityName,
    );
  }

  factory AiToolEnvelope.failure({
    required String tool,
    required String errorCode,
    required String message,
    String markdownFallback = '',
    bool retryable = false,
    Map<String, dynamic> data = const {},
    String? activityId,
    String? activityName,
    String? action,
  }) {
    return AiToolEnvelope(
      success: false,
      tool: tool,
      data: data,
      message: message,
      markdownFallback: markdownFallback,
      errorCode: errorCode,
      action: action,
      activityId: activityId,
      activityName: activityName,
      error: AiToolError(
        code: errorCode,
        message: message,
        retryable: retryable,
      ),
    );
  }

  factory AiToolEnvelope.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final error = json['error'];
    final parsedError = error is Map<String, dynamic>
        ? AiToolError.fromJson(error)
        : null;
    final parsedSuccess = json['success'] == true || json['ok'] == true;
    final parsedTool = (json['tool'] ?? json['action'] ?? '').toString();
    final parsedMessage = (json['message'] ?? parsedError?.message ?? '')
        .toString();
    final parsedMarkdownFallback = (json['markdownFallback'] ?? '').toString();
    final parsedErrorCode = json['errorCode']?.toString() ?? parsedError?.code;
    return AiToolEnvelope(
      success: parsedSuccess,
      tool: parsedTool.isEmpty ? 'unknown_tool' : parsedTool,
      data: rawData is Map<String, dynamic> ? rawData : <String, dynamic>{},
      message: parsedMessage,
      markdownFallback: parsedMarkdownFallback,
      errorCode: parsedErrorCode,
      action: json['action']?.toString(),
      activityId: json['activityId']?.toString(),
      activityName: json['activityName']?.toString(),
      error: parsedError,
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'tool': tool,
    'data': data,
    'message': message,
    'markdownFallback': markdownFallback,
    'errorCode': errorCode,
    if (action != null) 'action': action,
    if (activityId != null) 'activityId': activityId,
    if (activityName != null) 'activityName': activityName,
    if (error != null) 'error': error!.toJson(),
  };
}

class AiToolError {
  final String code;
  final String message;
  final bool retryable;

  const AiToolError({required this.code, required this.message, required this.retryable});

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
  final String? action;
  final String? activityId;
  final String? activityName;
  final String? message;
  final Map<String, dynamic>? data;
  final AiToolError? error;

  const AiToolEnvelope({
    required this.success,
    this.action,
    this.activityId,
    this.activityName,
    this.message,
    this.data,
    this.error,
  });

  factory AiToolEnvelope.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final error = json['error'];
    return AiToolEnvelope(
      success: json['success'] == true || json['ok'] == true, // Handle legacy 'ok'
      action: json['action']?.toString(),
      activityId: json['activityId']?.toString(),
      activityName: json['activityName']?.toString(),
      message: json['message']?.toString(),
      data: data is Map<String, dynamic> ? data : null,
      error: error is Map<String, dynamic> ? AiToolError.fromJson(error) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        if (action != null) 'action': action,
        if (activityId != null) 'activityId': activityId,
        if (activityName != null) 'activityName': activityName,
        if (message != null) 'message': message,
        if (data != null) 'data': data,
        if (error != null) 'error': error!.toJson(),
      };
}


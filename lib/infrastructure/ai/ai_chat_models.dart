enum AiChatRole { user, assistant, tool, analytics }

class AiChatMessage {
  final String id;
  final AiChatRole role;
  final String text;

  /// When present, this message represents a tool call or tool result.
  final Map<String, dynamic>? payload;

  const AiChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.payload,
  });
}


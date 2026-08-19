import 'package:active/presentation/pages/agent/models/pending_action.dart';
import 'package:active/presentation/pages/agent/services/agent_service.dart';
import 'package:active/presentation/pages/agent/widgets/confirm_action_card.dart';

enum ChatRole { user, assistant, system }

enum MessageStatus { sending, streaming, complete, error }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.status = MessageStatus.complete,
    this.toolsUsed = const [],
    this.usage,
    this.elapsed,
    this.pendingAction,
    this.confirmOutcome,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final ChatRole role;
  String text;
  MessageStatus status;
  List<String> toolsUsed;

  /// Tokens billed for this exchange; null until the response completes.
  TokenUsage? usage;

  /// Wall-clock time the exchange took.
  Duration? elapsed;

  /// A destructive action awaiting the user's confirmation.
  PendingAction? pendingAction;

  /// Set once the user has accepted or declined [pendingAction].
  ConfirmOutcome? confirmOutcome;

  final DateTime createdAt;

  ChatMessage copyWith({
    String? text,
    MessageStatus? status,
    List<String>? toolsUsed,
    TokenUsage? usage,
    Duration? elapsed,
    PendingAction? pendingAction,
    ConfirmOutcome? confirmOutcome,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      status: status ?? this.status,
      toolsUsed: toolsUsed ?? this.toolsUsed,
      usage: usage ?? this.usage,
      elapsed: elapsed ?? this.elapsed,
      pendingAction: pendingAction ?? this.pendingAction,
      confirmOutcome: confirmOutcome ?? this.confirmOutcome,
      createdAt: createdAt,
    );
  }
}

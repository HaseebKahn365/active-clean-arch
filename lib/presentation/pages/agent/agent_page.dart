import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import 'package:active/data/datasources/database_helper.dart';
import 'package:active/presentation/pages/agent/models/chat_message.dart';
import 'package:active/presentation/pages/agent/models/pending_action.dart';
import 'package:active/presentation/pages/agent/widgets/confirm_action_card.dart';
import 'package:active/presentation/pages/agent/services/agent_service.dart';
import 'package:active/presentation/pages/agent/widgets/chat_bubble.dart';
import 'package:active/presentation/pages/agent/widgets/suggestion_chips.dart';

class AgentPage extends StatefulWidget {
  const AgentPage({super.key});

  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage> {
  final List<ChatMessage> _messages = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();

  AgentService? _agent;
  String? _initError;
  bool _isBusy = false;
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _initAgent();
  }

  void _initAgent() {
    try {
      _agent = AgentService();
    } catch (e, st) {
      _initError = e.toString();
      dev.log(
        'Agent unavailable — initialization failed: $e',
        name: kAgentLogName,
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  String _nextId() => '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _isBusy) return;

    final agent = _agent;
    if (agent == null) return;

    final pendingId = _nextId();

    setState(() {
      _isBusy = true;
      _inputController.clear();
      _messages.add(
        ChatMessage(id: _nextId(), role: ChatRole.user, text: text),
      );
      _messages.add(
        ChatMessage(
          id: pendingId,
          role: ChatRole.assistant,
          text: '',
          status: MessageStatus.sending,
        ),
      );
    });
    _scrollToBottom();

    final turnWatch = Stopwatch()..start();

    try {
      final buffer = StringBuffer();
      final liveTools = <String>[];

      void updatePending(void Function(ChatMessage current) mutate) {
        final index = _messages.indexWhere((m) => m.id == pendingId);
        if (index == -1) return;
        mutate(_messages[index]);
      }

      final response = await agent.send(
        text,
        onToolStart: (label) {
          if (!mounted) return;
          setState(() {
            liveTools.add(label);
            updatePending((current) {
              _messages[_messages.indexOf(current)] = current.copyWith(
                toolsUsed: List.of(liveTools),
              );
            });
          });
          _scrollToBottom();
        },
        onDelta: (delta) {
          if (!mounted) return;
          buffer.write(delta);
          setState(() {
            updatePending((current) {
              _messages[_messages.indexOf(current)] = current.copyWith(
                text: buffer.toString(),
                status: MessageStatus.streaming,
              );
            });
          });
          _scrollToBottom();
        },
      );

      turnWatch.stop();
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m.id == pendingId);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            text: response.text,
            status: MessageStatus.complete,
            toolsUsed: response.toolsUsed,
            usage: response.usage,
            elapsed: turnWatch.elapsed,
            pendingAction: response.pendingAction,
          );
        }
        _isBusy = false;
      });
    } catch (e, st) {
      dev.log(
        'Turn failed, showing error bubble: $e',
        name: kAgentLogName,
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m.id == pendingId);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            text: _friendlyError(e),
            status: MessageStatus.error,
          );
        }
        _isBusy = false;
      });
    }
    _scrollToBottom();
  }

  /// Maps an error to a headline. Only claims a specific cause when the error
  /// unambiguously says so — a wrong guess sends you debugging the wrong
  /// thing. The raw message is always appended so this can never disagree
  /// with what the debug console reports.
  String _friendlyError(Object error) {
    final raw = error.toString();

    String? headline;
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('Connection closed')) {
      headline = "**Couldn't reach the network.**\n\n"
          'Check your internet connection and try again.';
    } else if (raw.contains('PERMISSION_DENIED') || raw.contains('403')) {
      headline = '**Access to the AI service was denied.**\n\n'
          'The Firebase AI Logic API may not be enabled for this project.';
    } else if (raw.contains('RESOURCE_EXHAUSTED') || raw.contains('429')) {
      headline = '**Rate limit reached.**\n\nGive it a moment and try again.';
    } else if (raw.contains('was not found') ||
        raw.contains('NOT_FOUND') ||
        raw.contains('does not exist')) {
      headline = "**The model `${AgentService.modelName}` wasn't found.**\n\n"
          'Check the model name, or that this project has access to it.';
    }

    final detail = '```\n$raw\n```';
    return headline == null
        ? '**Something went wrong.**\n\n$detail'
        : '$headline\n\n$detail';
  }

  Future<void> _resolvePendingAction(
    ChatMessage message,
    ConfirmOutcome outcome,
  ) async {
    final action = message.pendingAction;
    if (action == null) return;

    if (outcome == ConfirmOutcome.confirmed) {
      try {
        switch (action.kind) {
          case PendingActionKind.deleteActivity:
            await DatabaseHelper.instance.deleteActivity(action.targetId);
            dev.log(
              'Deleted activity "${action.targetName}" (id ${action.targetId}) '
              'after user confirmation',
              name: kAgentLogName,
            );
          case PendingActionKind.deleteRecord:
            await DatabaseHelper.instance.deleteRecord(action.targetId);
            dev.log(
              'Deleted record ${action.targetId} after user confirmation',
              name: kAgentLogName,
            );
        }
      } catch (e, st) {
        dev.log(
          'Failed to apply confirmed action: $e',
          name: kAgentLogName,
          error: e,
          stackTrace: st,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } else {
      dev.log(
        'User cancelled deletion of "${action.targetName}"',
        name: kAgentLogName,
      );
    }

    if (!mounted) return;
    setState(() {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(confirmOutcome: outcome);
      }
    });
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _agent?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sessionTokens = _agent?.sessionUsage.totalTokens ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent'),
        actions: [
          if (sessionTokens > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              child: Tooltip(
                message: 'Tokens used this conversation',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      '$sessionTokens tok',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Clear conversation',
              onPressed: _isBusy ? null : _clearConversation,
            ),
        ],
      ),
      body: SafeArea(
        child: _initError != null
            ? _ErrorState(message: _initError!)
            : Column(
                children: [
                  Expanded(
                    child: _messages.isEmpty
                        ? _EmptyState(onSuggestionTapped: _send)
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            itemCount: _messages.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final action = message.pendingAction;
                              if (action == null) {
                                return ChatBubble(message: message);
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ChatBubble(message: message),
                                  const SizedBox(height: 8),
                                  ConfirmActionCard(
                                    action: action,
                                    resolved: message.confirmOutcome,
                                    onConfirm: () => _resolvePendingAction(
                                      message,
                                      ConfirmOutcome.confirmed,
                                    ),
                                    onCancel: () => _resolvePendingAction(
                                      message,
                                      ConfirmOutcome.cancelled,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  if (_messages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SuggestionChips(onSelected: _send),
                    ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            focusNode: _inputFocus,
                            enabled: !_isBusy,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _send,
                            decoration: InputDecoration(
                              hintText: 'Ask about your activity data…',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isBusy
                              ? null
                              : () => _send(_inputController.text),
                          icon: _isBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.arrow_upward, size: 20),
                          tooltip: 'Send',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestionTapped});

  final ValueChanged<String> onSuggestionTapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Icon(
          Icons.auto_awesome,
          size: 56,
          color: colorScheme.primary.withValues(alpha: 0.8),
        ),
        const SizedBox(height: 16),
        Text(
          'Ask about your activity',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'I can look up your logged records by activity and time period — '
          'yesterday, last week, a specific month, or compare activities.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        SuggestionChips(onSelected: onSuggestionTapped),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Agent unavailable',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

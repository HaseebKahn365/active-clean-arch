import 'dart:developer' as dev;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:active/data/datasources/database_helper.dart';
import 'package:active/presentation/pages/agent/models/chat_message.dart';
import 'package:active/presentation/pages/agent/models/pending_action.dart';
import 'package:active/presentation/pages/agent/services/agent_service.dart';
import 'package:active/presentation/pages/agent/widgets/chat_bubble.dart';
import 'package:active/presentation/pages/agent/widgets/confirm_action_card.dart';
import 'package:active/presentation/pages/agent/widgets/suggestion_chips.dart';
import 'package:active/presentation/theme/app_theme.dart';

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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sessionTokens = _agent?.sessionUsage.totalTokens ?? 0;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Text(
                    'Agent',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.getTextPrimary(isDark),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  if (sessionTokens > 0)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.getBorderSubtle(isDark),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '$sessionTokens tok',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                    ),
                  if (_messages.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceSubtle(isDark),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        padding: EdgeInsets.zero,
                        color: AppColors.getTextPrimary(isDark),
                        tooltip: 'Clear conversation',
                        onPressed: _isBusy ? null : _clearConversation,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Body content / Chat Stream
            Expanded(
              child: _initError != null
                  ? _ErrorState(message: _initError!)
                  : _messages.isEmpty
                      ? _EmptyState(onSuggestionTapped: _send)
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          itemCount: _messages.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
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

            // Suggestion Chips (when messages present)
            if (_messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SuggestionChips(onSelected: _send),
              ),

            // Chat Input Area (above floating nav bar)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceCard(isDark),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.getBorderSubtle(isDark),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocus,
                        enabled: !_isBusy,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(1000),
                        ],
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask about your activity data…',
                          hintStyle: TextStyle(
                            color: AppColors.getTextMuted(isDark),
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isBusy ? null : () => _send(_inputController.text),
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.getSurfaceDark(isDark),
                        foregroundColor: AppColors.getTextOnDark(isDark),
                        elevation: 0,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isBusy
                            ? _ButtonBusyIndicator(
                                key: const ValueKey('busy_wave'),
                                color: AppColors.getTextOnDark(isDark),
                              )
                            : const Icon(
                                Icons.arrow_upward_rounded,
                                key: ValueKey('arrow_icon'),
                                size: 20,
                              ),
                      ),
                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 36),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.getSurfaceSubtle(isDark),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              size: 32,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
        )
          .animate()
          .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 400.ms),
        const SizedBox(height: 16),
        Text(
          'Ask about your activity',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.getTextPrimary(isDark),
            letterSpacing: -0.3,
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 8),
        Text(
          'I can look up your logged records by activity and time period — '
          'yesterday, last week, a specific month, or compare activities.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondary(isDark),
            height: 1.4,
          ),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 28),
        SuggestionChips(onSelected: onSuggestionTapped)
          .animate()
          .fadeIn(duration: 400.ms, delay: 100.ms),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Agent unavailable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ButtonBusyIndicator extends StatefulWidget {
  const _ButtonBusyIndicator({super.key, required this.color});

  final Color color;

  @override
  State<_ButtonBusyIndicator> createState() => _ButtonBusyIndicatorState();
}

class _ButtonBusyIndicatorState extends State<_ButtonBusyIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final t = (_controller.value + (i * 0.25)) % 1.0;
            final height = 5.0 + (11.0 * math.sin(t * math.pi));
            return Container(
              width: 3.0,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        );
      },
    );
  }
}


import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection_container.dart';
import '../../../infrastructure/ai/ai_chat_models.dart';
import '../../../infrastructure/ai/ai_chat_service.dart';
import '../../../presentation/providers/activity_manager_provider.dart';
import '../../../presentation/providers/dashboard_ui_notifier.dart';
import '../../../domain/entities/activity.dart';
import '../../../presentation/widgets/chat/dynamic_analytics_widget.dart';

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final AiChatService _chat;
  late final ActivityController _activityController;

  int? _mentionStart;
  String _mentionQuery = '';
  List<Activity> _mentionMatches = const [];

  @override
  void initState() {
    super.initState();
    _chat = sl<AiChatService>();
    _activityController = sl<ActivityController>();
    _controller.addListener(_handleMentionTyping);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleMentionTyping);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleMentionTyping() {
    final value = _controller.value;
    final text = value.text;
    final cursor = value.selection.baseOffset;
    if (cursor < 0) {
      _closeMention();
      return;
    }

    final before = text.substring(0, cursor);
    final at = before.lastIndexOf('@');
    if (at == -1) {
      _closeMention();
      return;
    }

    // must be start-of-string or preceded by whitespace
    if (at > 0 && !RegExp(r'\s').hasMatch(before[at - 1])) {
      _closeMention();
      return;
    }

    final query = before.substring(at + 1);
    // stop if mention already terminated by whitespace/newline
    if (query.contains(RegExp(r'\s'))) {
      _closeMention();
      return;
    }

    final normalized = query.toLowerCase();
    final all = _activityController.activitiesMap.values.toList();
    all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final matches = normalized.isEmpty
        ? all.take(8).toList()
        : all.where((a) => a.name.toLowerCase().contains(normalized)).take(8).toList();

    setState(() {
      _mentionStart = at;
      _mentionQuery = query;
      _mentionMatches = matches;
    });
  }

  void _closeMention() {
    if (_mentionStart == null && _mentionMatches.isEmpty) return;
    setState(() {
      _mentionStart = null;
      _mentionQuery = '';
      _mentionMatches = const [];
    });
  }

  void _insertMention(Activity activity) {
    final start = _mentionStart;
    if (start == null) return;

    final value = _controller.value;
    final cursor = value.selection.baseOffset;
    if (cursor < 0) return;

    final text = value.text;
    final before = text.substring(0, start);
    final after = text.substring(cursor);

    // Insert both name and id for unambiguous tool use.
    // Format: @Name{activityId}
    final mention = '@${activity.name}{${activity.id}} ';
    final nextText = '$before$mention$after';
    final nextCursor = (before.length + mention.length);

    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
    _closeMention();
  }

  Future<void> _send() async {
    if (_chat.isBusy) return;
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    _closeMention();
    await _chat.sendUserMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dashboardState = ref.watch(dashboardUiProvider);
    final selectedId = dashboardState.selectedNodeId;
    final selectedActivity = selectedId != null ? _activityController.activitiesMap[selectedId] : null;

    // Build context map for AI
    final appContext = {
      'selectedActivityId': selectedId,
      'selectedActivityName': selectedActivity?.name,
      'selectedActivityStatus': selectedActivity?.status.toString(),
      'currentView': dashboardState.viewMode == DashboardViewMode.tree ? 'tree' : 'list',
      'todaySummary': {
        'runningCount': _activityController.activitiesMap.values.where((a) => a.status == ActivityStatus.running).length,
        // Add more summary info if needed
      },
    };
    _chat.updateContext(appContext);

    return AnimatedBuilder(
      animation: _chat,
      builder: (context, _) {
        final messages = _chat.messages;

        // Keep scrolled to bottom on new messages.
        scheduleMicrotask(() async {
          if (!_scrollController.hasClients) return;
          await Future.delayed(const Duration(milliseconds: 16));
          if (!_scrollController.hasClients) return;
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });

        return Scaffold(
          appBar: AppBar(
            title: const Text('AI Chat'),
            actions: [
              IconButton(
                tooltip: 'Clear',
                onPressed: _chat.isBusy ? null : _chat.reset,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: Column(
            children: [
              if (_chat.isBusy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    if (m.role == AiChatRole.tool) {
                      return _ToolCallCard(message: m);
                    }

                    if (m.role == AiChatRole.analytics) {
                      final payload = m.payload;
                      if (payload == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: DynamicAnalyticsWidget(payload: payload),
                      );
                    }

                    final isUser = m.role == AiChatRole.user;
                    final bg = isUser ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest;
                    final fg = isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
                    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;

                    return Align(
                      alignment: align,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 520),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: MarkdownBody(
                          data: m.text,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                            p: theme.textTheme.bodyMedium?.copyWith(color: fg),
                            strong: theme.textTheme.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.bold),
                            em: theme.textTheme.bodyMedium?.copyWith(color: fg, fontStyle: FontStyle.italic),
                            code: theme.textTheme.bodyMedium?.copyWith(
                              color: fg,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              fontFamily: 'monospace',
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (!_chat.isBusy && _mentionStart != null && _mentionMatches.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _MentionPicker(
                    query: _mentionQuery,
                    matches: _mentionMatches,
                    onPick: _insertMention,
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_chat.isBusy,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Ask Active… (type @ to mention an activity)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _chat.isBusy ? null : _send,
                        icon: const Icon(Icons.send),
                        label: const Text('Send'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MentionPicker extends StatelessWidget {
  final String query;
  final List<Activity> matches;
  final ValueChanged<Activity> onPick;

  const _MentionPicker({
    required this.query,
    required this.matches,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: matches.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.25)),
          itemBuilder: (context, index) {
            final a = matches[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.account_tree_outlined, size: 18),
              title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: query.isEmpty ? null : Text('id: ${a.id}', maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => onPick(a),
            );
          },
        ),
      ),
    );
  }
}

class _ToolCallCard extends StatelessWidget {
  final AiChatMessage message;
  const _ToolCallCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = message.payload ?? const <String, dynamic>{};
    final name = payload['name']?.toString() ?? 'tool';
    final status = payload['status']?.toString() ?? 'unknown';
    final result = payload['result'] as Map?;

    Color statusColor;
    IconData statusIcon;
    String statusText = status;

    switch (status) {
      case 'running':
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'Running...';
        break;
      case 'success':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Success';
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Failed';
        break;
      default:
        statusColor = theme.hintColor;
        statusIcon = Icons.help_outline;
    }

    final activityName = result?['activityName']?.toString();
    final messageText = result?['message']?.toString() ?? (status == 'running' ? 'Executing $name...' : null);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (status == 'running')
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
            if (activityName != null) ...[
              const SizedBox(height: 4),
              Text(
                activityName,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
            if (messageText != null) ...[
              const SizedBox(height: 4),
              Text(
                messageText,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (status == 'error' && result?['error'] != null) ...[
              const SizedBox(height: 4),
              Text(
                result!['error']['message']?.toString() ?? 'Unknown error',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


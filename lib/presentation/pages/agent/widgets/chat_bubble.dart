import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:active/presentation/pages/agent/models/chat_message.dart';
import 'package:active/presentation/pages/agent/services/agent_service.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bubbleColor = isUser
        ? colorScheme.primary
        : message.status == MessageStatus.error
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerHigh;

    final textColor = isUser
        ? colorScheme.onPrimary
        : message.status == MessageStatus.error
            ? colorScheme.onErrorContainer
            : colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser && message.toolsUsed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final tool in message.toolsUsed)
                    _ToolChip(label: tool),
                  // While tools run there is no text yet; say what is happening
                  // instead of leaving a silent gap.
                  if (message.text.isEmpty &&
                      (message.status == MessageStatus.sending ||
                          message.status == MessageStatus.streaming))
                    Text(
                      'reading your data…',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
            ),
            child: message.text.isEmpty &&
                    (message.status == MessageStatus.sending ||
                        message.status == MessageStatus.streaming)
                ? _TypingIndicator(color: textColor)
                : isUser
                    ? Text(
                        message.text,
                        style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                      )
                    : MarkdownBody(
                        data: message.text,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                          p: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                          strong: theme.textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                          listBullet: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                          tableHead: theme.textTheme.bodySmall?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                          tableBody: theme.textTheme.bodySmall?.copyWith(color: textColor),
                          tableBorder: TableBorder.all(
                            color: colorScheme.outline.withValues(alpha: 0.3),
                          ),
                          tableCellsPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          code: theme.textTheme.bodySmall?.copyWith(
                            color: textColor,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
          ),
          if (!isUser && message.usage != null && !message.usage!.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: _UsageFooter(
                usage: message.usage!,
                elapsed: message.elapsed,
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact token readout under a response. Tapping expands the breakdown.
class _UsageFooter extends StatefulWidget {
  const _UsageFooter({required this.usage, this.elapsed});

  final TokenUsage usage;
  final Duration? elapsed;

  @override
  State<_UsageFooter> createState() => _UsageFooterState();
}

class _UsageFooterState extends State<_UsageFooter> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final usage = widget.usage;

    final style = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      fontSize: 10.5,
    );

    final elapsed = widget.elapsed;
    final timing = elapsed == null
        ? ''
        : ' · ${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s';

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.data_usage,
                  size: 11,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Text('${usage.totalTokens} tokens$timing', style: style),
                const SizedBox(width: 2),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 12,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ],
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('prompt: ${usage.promptTokens}', style: style),
                    Text('response: ${usage.responseTokens}', style: style),
                    if (usage.thoughtTokens > 0)
                      Text('thinking: ${usage.thoughtTokens}', style: style),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 12, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.color});

  final Color color;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
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
    return SizedBox(
      width: 36,
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              final t = (_controller.value - (i * 0.2)) % 1.0;
              final scale = 0.5 + 0.5 * (1 - (2 * t - 1).abs());
              return Opacity(
                opacity: 0.4 + 0.6 * scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

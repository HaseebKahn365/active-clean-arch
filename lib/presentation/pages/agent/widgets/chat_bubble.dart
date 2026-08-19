import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:active/presentation/pages/agent/models/chat_message.dart';
import 'package:active/presentation/pages/agent/services/agent_service.dart';
import 'package:active/presentation/theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.role == ChatRole.user;

    final bubbleColor = isUser
        ? (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceDark)
        : message.status == MessageStatus.error
            ? (isDark ? AppColors.errorBgDark : AppColors.errorBg)
            : AppColors.getSurfaceCard(isDark);

    final textColor = isUser
        ? Colors.white
        : message.status == MessageStatus.error
            ? AppColors.error
            : AppColors.getTextPrimary(isDark);

    final isTyping = message.text.isEmpty &&
        (message.status == MessageStatus.sending ||
            message.status == MessageStatus.streaming);

    final isStreaming = message.status == MessageStatus.streaming && message.text.isNotEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Tool execution chips with animated shimmer
          if (!isUser && message.toolsUsed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (int i = 0; i < message.toolsUsed.length; i++)
                    _ToolChip(label: message.toolsUsed[i])
                      .animate(key: ValueKey('tool_${message.toolsUsed[i]}_$i'))
                      .fadeIn(duration: 200.ms)
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1, 1),
                        curve: Curves.easeOutBack,
                      ),
                  if (isTyping)
                    Text(
                      'reading your data…',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextMuted(isDark),
                        fontStyle: FontStyle.italic,
                      ),
                    )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(duration: 400.ms)
                      .shimmer(duration: 1200.ms, color: isDark ? Colors.white30 : Colors.black26),
                ],
              ),
            ),

          // iMessage-Style Liquid Animated Size Bubble
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: isUser ? Alignment.topRight : Alignment.topLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isUser ? 18 : 18,
                vertical: isUser ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: isUser
                    ? (isDark ? Border.all(color: AppColors.darkBorderSubtle) : null)
                    : Border.all(
                        color: message.status == MessageStatus.error
                            ? AppColors.error.withValues(alpha: 0.3)
                            : AppColors.getBorderCard(isDark),
                        width: 1,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: isTyping
                    ? _TypingIndicator(key: const ValueKey('typing'), color: textColor)
                    : isUser
                        ? Text(
                            message.text,
                            key: const ValueKey('user_text'),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 1.35,
                            ),
                          )
                        : AnimatedOpacity(
                            key: const ValueKey('assistant_text'),
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MarkdownBody(
                                  data: message.text,
                                  selectable: true,
                                  styleSheet: MarkdownStyleSheet(
                                    p: TextStyle(
                                      fontSize: 14.5,
                                      color: AppColors.getTextPrimary(isDark),
                                      height: 1.4,
                                    ),
                                    strong: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.getTextPrimary(isDark),
                                    ),
                                    h1: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.getTextPrimary(isDark),
                                    ),
                                    h2: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.getTextPrimary(isDark),
                                    ),
                                    h3: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.getTextPrimary(isDark),
                                    ),
                                    listBullet: TextStyle(
                                      color: AppColors.getTextPrimary(isDark),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    tableHead: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.getTextSecondary(isDark),
                                    ),
                                    tableBody: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.getTextPrimary(isDark),
                                    ),
                                    tableBorder: TableBorder.all(
                                      color: AppColors.getBorderSubtle(isDark),
                                      width: 1,
                                    ),
                                    tableCellsPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    code: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.getTextPrimary(isDark),
                                      backgroundColor: AppColors.getSurfaceSubtle(isDark),
                                      fontFamily: 'monospace',
                                    ),
                                    codeblockDecoration: BoxDecoration(
                                      color: AppColors.getSurfaceSubtle(isDark),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.getBorderSubtle(isDark)),
                                    ),
                                  ),
                                ),
                                if (isStreaming)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: _StreamingPulseCursor(color: AppColors.getTextPrimary(isDark)),
                                  ),
                              ],
                            ),
                          ),
              ),
            ),
          )
            .animate(key: ValueKey('bubble_${message.id}'))
            .fadeIn(duration: 200.ms, curve: Curves.easeOut)
            .scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1.0, 1.0),
              alignment: isUser ? Alignment.bottomRight : Alignment.bottomLeft,
              duration: 260.ms,
              curve: Curves.easeOutBack,
            )
            .slideY(
              begin: 0.1,
              end: 0,
              duration: 240.ms,
              curve: Curves.easeOutCubic,
            ),

          if (!isUser && message.usage != null && !message.usage!.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: _UsageFooter(
                usage: message.usage!,
                elapsed: message.elapsed,
              )
                .animate()
                .fadeIn(duration: 250.ms, delay: 100.ms),
            ),
        ],
      ),
    );
  }
}

/// A glowing breathing streaming cursor
class _StreamingPulseCursor extends StatelessWidget {
  const _StreamingPulseCursor({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 14,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(2),
      ),
    )
      .animate(onPlay: (c) => c.repeat(reverse: true))
      .fadeIn(duration: 350.ms, curve: Curves.easeInOut)
      .scaleXY(begin: 0.9, end: 1.1, duration: 350.ms);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usage = widget.usage;

    final style = TextStyle(
      fontSize: 10.5,
      color: AppColors.getTextMuted(isDark),
      fontWeight: FontWeight.w500,
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
                  Icons.data_usage_rounded,
                  size: 11,
                  color: AppColors.getTextMuted(isDark),
                ),
                const SizedBox(width: 4),
                Text('${usage.totalTokens} tokens$timing', style: style),
                const SizedBox(width: 2),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 12,
                  color: AppColors.getTextMuted(isDark),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.getBadgeTodayBg(isDark),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            size: 12,
            color: AppColors.getBadgeTodayIcon(isDark),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.getBadgeTodayText(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic wave bouncing typing indicator with sine-wave vertical oscillation
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({super.key, required this.color});

  final Color color;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return SizedBox(
            width: 46,
            height: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (i) {
                // Sine wave bounce calculation with phase delay
                final phase = (_controller.value * 2 * math.pi) - (i * 0.85);
                final sine = math.sin(phase);
                // Only bounce upward
                final bounce = sine > 0 ? sine : 0.0;
                final offsetY = -6.0 * bounce;
                final scale = 0.85 + (0.35 * bounce);
                final opacity = (0.4 + (0.6 * bounce)).clamp(0.0, 1.0);

                return Transform.translate(
                  offset: Offset(0, offsetY),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 7.5,
                        height: 7.5,
                        decoration: BoxDecoration(
                          color: widget.color,
                          shape: BoxShape.circle,
                          boxShadow: bounce > 0.4
                              ? [
                                  BoxShadow(
                                    color: widget.color.withValues(alpha: 0.35 * bounce),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

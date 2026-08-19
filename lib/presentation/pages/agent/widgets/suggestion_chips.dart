import 'package:flutter/material.dart';
import 'package:active/presentation/theme/app_theme.dart';

class SuggestionChips extends StatelessWidget {
  const SuggestionChips({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  static const _suggestions = [
    "What did I log yesterday?",
    "Show my totals for this week",
    "How am I doing this month?",
    "Compare all my activities this month",
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final text = _suggestions[i];
          return _SuggestionChipItem(
            text: text,
            isDark: isDark,
            onTap: () => onSelected(text),
          );
        },
      ),
    );
  }
}

class _SuggestionChipItem extends StatefulWidget {
  const _SuggestionChipItem({
    required this.text,
    required this.isDark,
    required this.onTap,
  });

  final String text;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_SuggestionChipItem> createState() => _SuggestionChipItemState();
}

class _SuggestionChipItemState extends State<_SuggestionChipItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkSurfaceCard : AppColors.lightBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.getBorderSubtle(widget.isDark),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(widget.isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

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
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final text = _suggestions[i];
          return ActionChip(
            label: Text(text, style: const TextStyle(fontSize: 12.5)),
            onPressed: () => onSelected(text),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

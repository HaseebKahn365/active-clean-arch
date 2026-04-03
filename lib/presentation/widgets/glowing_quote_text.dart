import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quote_provider.dart';

class GlowingQuoteText extends StatefulWidget {
  const GlowingQuoteText({super.key});

  @override
  State<GlowingQuoteText> createState() => _GlowingQuoteTextState();
}

class _GlowingQuoteTextState extends State<GlowingQuoteText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quoteProvider = context.watch<QuoteProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _showEditDialog(context, quoteProvider),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final glowFactor = _animation.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  colorScheme.onPrimary.withAlpha((25 + (10 * glowFactor)).toInt()),
                  colorScheme.onPrimary.withAlpha((15 + (10 * glowFactor)).toInt()),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: colorScheme.onPrimary.withAlpha((60 + (40 * glowFactor)).toInt()),
                width: 1.2,
              ),
            ),
            child: Text(
              quoteProvider.quote,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.0,
                color: colorScheme.onPrimary,
                fontStyle: FontStyle.italic,
                shadows: [
                  Shadow(
                    color: colorScheme.secondary.withAlpha((150 + (100 * glowFactor)).toInt()),
                    offset: const Offset(0, 0),
                    blurRadius: 8 + (8 * glowFactor),
                  ),
                  Shadow(
                    color: colorScheme.onPrimary.withAlpha((80 + (60 * glowFactor)).toInt()),
                    offset: const Offset(0, 0),
                    blurRadius: 12 + (12 * glowFactor),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, QuoteProvider provider) {
    final controller = TextEditingController(text: provider.quote);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Inspiring Quote'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter your project mission...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                provider.updateQuote(controller.text.trim().toUpperCase());
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

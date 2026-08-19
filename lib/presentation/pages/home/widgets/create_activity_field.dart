import 'package:flutter/material.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/theme/app_theme.dart';

export 'package:active/presentation/pages/home/models/activity.dart' show ActivityType;

class CreateActivityField extends StatefulWidget {
  const CreateActivityField({super.key, required this.onCreate});

  final void Function(String name, ActivityType type) onCreate;

  @override
  State<CreateActivityField> createState() => _CreateActivityFieldState();
}

class _CreateActivityFieldState extends State<CreateActivityField> {
  final _nameController = TextEditingController();
  ActivityType _type = ActivityType.count;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    widget.onCreate(name, _type);
    _nameController.clear();
    setState(() => _type = ActivityType.count);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCount = _type == ActivityType.count;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.getBorderCard(isDark),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.getTextPrimary(isDark),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Track something new starting today',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.getTextMuted(isDark),
            ),
          ),
          const SizedBox(height: 16),

          // Name Input Field
          TextField(
            controller: _nameController,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextPrimary(isDark),
            ),
            decoration: InputDecoration(
              hintText: 'Activity name',
              filled: true,
              fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              isDense: true,
              hintStyle: TextStyle(
                color: AppColors.getTextMuted(isDark),
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(
                  color: AppColors.getBorderSubtle(isDark),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(
                  color: AppColors.getBorderSubtle(isDark),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(
                  color: AppColors.getSurfaceDark(isDark),
                  width: 1.5,
                ),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),

          // Smooth Sliding Segmented Control (Count vs Time) & Submit Check Button
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.getBorderSubtle(isDark),
                      width: 1.5,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final pillWidth = constraints.maxWidth / 2;

                      return Stack(
                        children: [
                          // Sliding Pill Indicator
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            alignment: isCount ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              width: pillWidth,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.getSurfaceDark(isDark),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0.3)
                                        : Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Touch Targets & Text / Icons
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _type = ActivityType.count),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        AnimatedScale(
                                          scale: isCount ? 1.05 : 1.0,
                                          duration: const Duration(milliseconds: 200),
                                          child: Icon(
                                            Icons.tag_rounded,
                                            size: 16,
                                            color: isCount
                                                ? AppColors.getTextOnDark(isDark)
                                                : AppColors.getTextPrimary(isDark),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 200),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: isCount ? FontWeight.w800 : FontWeight.w600,
                                            color: isCount
                                                ? AppColors.getTextOnDark(isDark)
                                                : AppColors.getTextPrimary(isDark),
                                          ),
                                          child: const Text('Count'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _type = ActivityType.time),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        AnimatedScale(
                                          scale: !isCount ? 1.05 : 1.0,
                                          duration: const Duration(milliseconds: 200),
                                          child: Icon(
                                            Icons.schedule,
                                            size: 16,
                                            color: !isCount
                                                ? AppColors.getTextOnDark(isDark)
                                                : AppColors.getTextPrimary(isDark),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 200),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: !isCount ? FontWeight.w800 : FontWeight.w600,
                                            color: !isCount
                                                ? AppColors.getTextOnDark(isDark)
                                                : AppColors.getTextPrimary(isDark),
                                          ),
                                          child: const Text('Time'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 46,
                height: 46,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.getSurfaceDark(isDark),
                    foregroundColor: AppColors.getTextOnDark(isDark),
                    elevation: 0,
                  ),
                  child: const Icon(Icons.check, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

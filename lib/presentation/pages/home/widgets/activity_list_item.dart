import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:active/presentation/pages/home/models/activity.dart';
import 'package:active/presentation/theme/app_theme.dart';

class ActivityListItem extends StatefulWidget {
  const ActivityListItem({
    super.key,
    required this.activity,
    required this.stats,
    required this.onAddRecord,
    this.onDelete,
  });

  final Activity activity;
  final ActivityStats stats;
  final void Function(int quantity) onAddRecord;
  final VoidCallback? onDelete;

  @override
  State<ActivityListItem> createState() => _ActivityListItemState();
}

class _ActivityListItemState extends State<ActivityListItem> with SingleTickerProviderStateMixin {
  final _recordController = TextEditingController();
  bool _isExpanded = false;

  @override
  void dispose() {
    _recordController.dispose();
    super.dispose();
  }

  void _submitRecord() {
    final text = _recordController.text.trim();
    if (text.isEmpty) return;
    final quantity = int.tryParse(text);
    if (quantity == null || quantity == 0) return;

    final limitedQuantity = quantity.clamp(-1000, 1000);
    widget.onAddRecord(limitedQuantity);
    _recordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCount = widget.activity.type == ActivityType.count;
    final singleUnit = isCount ? 'count' : 'min';
    final hint = isCount ? 'Add count (max 1000)' : 'Add minutes (max 1000)';

    final best = widget.stats.bestDayTotal;
    final isRecordToday = best > 0 && widget.stats.todayTotal >= best;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isExpanded
              ? (isDark ? AppColors.darkBorderSubtle : AppColors.lightSurfaceDark.withValues(alpha: 0.25))
              : AppColors.getBorderCard(isDark),
          width: _isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: _isExpanded
            ? [
                BoxShadow(
                  color: isDark ? const Color(0x33000000) : const Color(0x0A000000),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Category Icon Box with subtle animated scale
                  AnimatedScale(
                    scale: _isExpanded ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isCount
                            ? AppColors.getCountIconBg(isDark)
                            : AppColors.getTimeIconBg(isDark),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isCount ? Icons.tag_rounded : Icons.schedule_rounded,
                        size: 22,
                        color: isCount
                            ? AppColors.getCountIcon(isDark)
                            : AppColors.getTimeIcon(isDark),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title and Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.activity.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextPrimary(isDark),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Badge (Today or Best) as subtitle so long values
                        // never squeeze the activity title.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _BestChip(
                            best: best,
                            unit: singleUnit,
                            isRecordToday: isRecordToday,
                            todayTotal: widget.stats.todayTotal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Delete Button
                  if (widget.onDelete != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.getTextSubtle(isDark),
                      ),
                      onPressed: widget.onDelete,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete activity',
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Buttery Smooth Expanded Content Area using AnimatedSize & AnimatedSwitcher
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? Container(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: AppColors.getBorderSubtle(isDark),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 15,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${widget.stats.entryCount} ${widget.stats.entryCount == 1 ? 'record entry' : 'record entries'} · ${widget.stats.totalQuantity} $singleUnit total',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.getTextSecondary(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 4 Period Pill Cards in Wrap
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _PeriodPill(
                              label: 'Today',
                              value: '${widget.stats.todayTotal}',
                            ),
                            _PeriodPill(
                              label: 'Weekly',
                              value: '${widget.stats.weekTotal}',
                            ),
                            _PeriodPill(
                              label: 'Monthly',
                              value: '${widget.stats.monthTotal}',
                            ),
                            _PeriodPill(
                              label: 'Yearly',
                              value: '${widget.stats.yearTotal}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Input Row for Logging Records
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _recordController,
                                keyboardType: const TextInputType.numberWithOptions(signed: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                                  _MaxValueInputFormatter(max: 1000, min: -1000),
                                ],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                                decoration: InputDecoration(
                                  hintText: hint,
                                  filled: true,
                                  fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                                  isDense: true,
                                  hintStyle: TextStyle(
                                    color: AppColors.getTextMuted(isDark),
                                    fontSize: 14,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
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
                                onSubmitted: (_) => _submitRecord(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 46,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _submitRecord,
                                style: ElevatedButton.styleFrom(
                                  shape: const CircleBorder(),
                                  padding: EdgeInsets.zero,
                                  backgroundColor: AppColors.getSurfaceDark(isDark),
                                  foregroundColor: AppColors.getTextOnDark(isDark),
                                  elevation: 0,
                                ),
                                child: const Icon(Icons.add, size: 22),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                    .animate()
                    .fadeIn(duration: 200.ms, curve: Curves.easeOut)
                    .slideY(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOutCubic)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MaxValueInputFormatter extends TextInputFormatter {
  final int max;
  final int min;

  const _MaxValueInputFormatter({required this.max, required this.min});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty || newValue.text == '-') {
      return newValue;
    }
    final parsed = int.tryParse(newValue.text);
    if (parsed == null) return oldValue;
    if (parsed > max || parsed < min) {
      return oldValue;
    }
    return newValue;
  }
}

class _BestChip extends StatelessWidget {
  const _BestChip({
    required this.best,
    required this.unit,
    required this.isRecordToday,
    required this.todayTotal,
  });

  final int best;
  final String unit;
  final bool isRecordToday;
  final int todayTotal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (best <= 0 && todayTotal <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceSubtle(isDark),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'No best yet',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.getBadgeBestText(isDark),
          ),
        ),
      );
    }

    final isTodayHighlight = isRecordToday || (best <= 0 && todayTotal > 0);
    final background = isTodayHighlight
        ? AppColors.getBadgeTodayBg(isDark)
        : AppColors.getBadgeBestBg(isDark);
    final textColor = isTodayHighlight
        ? AppColors.getBadgeTodayText(isDark)
        : AppColors.getBadgeBestText(isDark);
    final iconColor = isTodayHighlight
        ? AppColors.getBadgeTodayIcon(isDark)
        : AppColors.getBadgeBestIcon(isDark);

    final label = isRecordToday
        ? '$todayTotal today'
        : (best > 0 ? 'Best: $best $unit' : '$todayTotal today');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTodayHighlight
                ? Icons.local_fire_department_rounded
                : Icons.emoji_events_rounded,
            size: 14,
            color: iconColor,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.getBorderSubtle(isDark),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextMuted(isDark),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

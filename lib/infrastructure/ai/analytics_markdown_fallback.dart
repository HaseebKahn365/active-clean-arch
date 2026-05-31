import 'dart:developer' as dev;

/// Converts analytics widget payloads or raw tool result data into readable
/// markdown so the chat can always show something useful when a widget cannot
/// be rendered.
///
/// Priority of inputs:
/// 1. A structured widget payload (`widgetType` + data).
/// 2. Raw tool result data (`AiToolEnvelope.data`).
///
/// Returns `null` only when there is no usable data at all. Callers should
/// treat `null` as "show an honest short failure message".
abstract final class AnalyticsMarkdownFallbackRenderer {
  static String? render({
    Map<String, dynamic>? widgetPayload,
    Map<String, dynamic>? toolData,
    String? reason,
  }) {
    if (reason != null && reason.trim().isNotEmpty) {
      dev.log('WIDGET FALLBACK: $reason');
    }

    final fromWidget = widgetPayload != null
        ? _fromWidget(widgetPayload)
        : null;
    if (_usable(fromWidget)) {
      dev.log('WIDGET FALLBACK: rendering markdown from widget payload');
      return fromWidget;
    }

    final fromTool = toolData != null ? _fromToolData(toolData) : null;
    if (_usable(fromTool)) {
      dev.log('TOOL FALLBACK: rendering markdown from tool result');
      return fromTool;
    }

    return null;
  }

  static bool _usable(String? md) => md != null && md.trim().isNotEmpty;

  // ---------------------------------------------------------------------------
  // Widget payload → markdown
  // ---------------------------------------------------------------------------

  static String? _fromWidget(Map<String, dynamic> payload) {
    final type = payload['widgetType']?.toString();
    final title = payload['title']?.toString();
    final buffer = StringBuffer();

    if (title != null && title.trim().isNotEmpty) {
      buffer.writeln('## $title');
      buffer.writeln();
    }

    String? body;
    switch (type) {
      case 'metric_card':
        body = _metricCard(payload);
      case 'bar_chart':
      case 'line_chart':
        body = _seriesTable(payload);
      case 'donut_chart':
      case 'pie_chart':
        body = _labelValueTable(payload['data'], valueHeader: 'Value');
      case 'leaderboard':
        body = _leaderboard(payload['items']);
      case 'comparison_summary':
        body = _comparison(payload);
      default:
        body = _bestEffort(payload);
    }

    if (!_usable(body)) return null;
    buffer.writeln(body!.trim());

    final summary = _summaryLine(payload);
    if (summary != null) {
      buffer.writeln();
      buffer.writeln(summary);
    }

    return buffer.toString().trim();
  }

  static String? _metricCard(Map<String, dynamic> payload) {
    final value = payload['value']?.toString();
    if (value == null || value.trim().isEmpty) return null;
    final subtitle = payload['subtitle']?.toString();
    final trend = payload['trend']?.toString();
    final parts = <String>['**$value**'];
    if (subtitle != null && subtitle.trim().isNotEmpty) parts.add(subtitle);
    if (trend != null && trend.trim().isNotEmpty) parts.add('($trend)');
    return parts.join(' — ');
  }

  static String? _seriesTable(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is! Map) return null;
    final rawLabels = data['labels'];
    final rawSeries = data['series'];
    if (rawLabels is! List || rawLabels.isEmpty) return null;

    final labels = rawLabels.map((l) => l.toString()).toList();
    final seriesNames = <String>[];
    final seriesValues = <List<String>>[];

    if (rawSeries is List && rawSeries.isNotEmpty) {
      for (final s in rawSeries) {
        if (s is Map) {
          seriesNames.add(s['name']?.toString() ?? 'Value');
          final values = s['values'];
          seriesValues.add(
            values is List
                ? values.map(_formatNumber).toList()
                : const <String>[],
          );
        } else {
          // flat series like [300, 0]
          seriesNames.add('Value');
          seriesValues.add(rawSeries.map(_formatNumber).toList());
          break;
        }
      }
    }

    if (seriesNames.isEmpty) return null;

    final labelHeader = payload['xAxisLabel']?.toString() ?? 'Label';
    final header = '| $labelHeader | ${seriesNames.join(' | ')} |';
    final divider = '|${' --- |' * (seriesNames.length + 1)}';
    final rows = <String>[];
    for (var i = 0; i < labels.length; i++) {
      final cells = <String>[labels[i]];
      for (final values in seriesValues) {
        cells.add(i < values.length ? values[i] : '—');
      }
      rows.add('| ${cells.join(' | ')} |');
    }

    return [header, divider, ...rows].join('\n');
  }

  static String? _labelValueTable(dynamic data, {required String valueHeader}) {
    final pairs = _extractLabelValuePairs(data);
    if (pairs.isEmpty) return null;
    final header = '| Category | $valueHeader |';
    const divider = '| --- | ---: |';
    final rows = pairs
        .map((p) => '| ${p.$1} | ${_formatNumber(p.$2)} |')
        .toList();
    return [header, divider, ...rows].join('\n');
  }

  static String? _leaderboard(dynamic items) {
    if (items is! List || items.isEmpty) return null;
    final lines = <String>[];
    var rank = 1;
    for (final item in items) {
      if (item is! Map) continue;
      final label = item['label']?.toString() ?? item['name']?.toString();
      if (label == null) continue;
      final value = item['value']?.toString();
      final subtitle = item['subtitle']?.toString();
      final suffix = value != null && value.trim().isNotEmpty
          ? ' — $value'
          : '';
      final extra = subtitle != null && subtitle.trim().isNotEmpty
          ? ' ($subtitle)'
          : '';
      lines.add('$rank. $label$suffix$extra');
      rank++;
    }
    return lines.isEmpty ? null : lines.join('\n');
  }

  static String? _comparison(Map<String, dynamic> payload) {
    final items = payload['items'];
    if (items is! List || items.isEmpty) return null;
    final currentLabel = payload['currentPeriodLabel']?.toString() ?? 'Current';
    final previousLabel =
        payload['previousPeriodLabel']?.toString() ?? 'Previous';
    final header = '| Activity | $currentLabel | $previousLabel | Difference |';
    const divider = '| --- | ---: | ---: | ---: |';
    final rows = <String>[];
    for (final item in items) {
      if (item is! Map) continue;
      final label = item['label']?.toString();
      if (label == null) continue;
      final current = item['current']?.toString() ?? '—';
      final previous = item['previous']?.toString() ?? '—';
      final diff = item['difference']?.toString() ?? '—';
      rows.add('| $label | $current | $previous | $diff |');
    }
    return rows.isEmpty ? null : [header, divider, ...rows].join('\n');
  }

  /// Best-effort markdown when the widget type is unknown: inspect the shape of
  /// `data` and render whatever structure is present.
  static String? _bestEffort(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map && data['labels'] is List && (data['series'] is List)) {
      return _seriesTable(payload);
    }
    final pairs = _extractLabelValuePairs(data);
    if (pairs.isNotEmpty) {
      return _labelValueTable(data, valueHeader: 'Value');
    }
    if (payload['items'] is List) {
      return _leaderboard(payload['items']);
    }
    return null;
  }

  static String? _summaryLine(Map<String, dynamic> payload) {
    for (final key in ['insights', 'footer', 'description']) {
      final value = payload[key]?.toString();
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Raw tool data → markdown
  // ---------------------------------------------------------------------------

  static String? _fromToolData(Map<String, dynamic> data) {
    // Prefer an embedded widget payload if present.
    final embedded = data['widgetPayload'];
    if (embedded is Map) {
      final md = _fromWidget(Map<String, dynamic>.from(embedded));
      if (_usable(md)) return md;
    }

    // comparison-style payloads
    final comparison = data['comparisonItems'] ?? data['activities'];
    if (comparison is List &&
        comparison.isNotEmpty &&
        _looksLikeComparison(comparison)) {
      return _comparison({'items': comparison});
    }

    // label/value collections
    for (final key in ['categories', 'allocation', 'stats', 'matches']) {
      final value = data[key];
      final pairs = _extractLabelValuePairs(value);
      if (pairs.isNotEmpty) {
        return _labelValueTable(value, valueHeader: 'Value');
      }
    }

    // leaderboard-style items
    final items = data['items'] ?? data['running'];
    if (items is List && items.isNotEmpty) {
      final lb = _leaderboard(items);
      if (_usable(lb)) return lb;
    }

    // trend labels/values
    final labels = data['labels'];
    final values = data['values'];
    if (labels is List && values is List && labels.isNotEmpty) {
      final pairs = <(String, num)>[];
      for (var i = 0; i < labels.length; i++) {
        final v = i < values.length ? values[i] : 0;
        pairs.add((labels[i].toString(), v is num ? v : 0));
      }
      return _labelValueTable(
        pairs.map((p) => {'label': p.$1, 'value': p.$2}).toList(),
        valueHeader: 'Value',
      );
    }

    // single activity summaries
    final single = data['activity'];
    if (single is Map) {
      final name = single['name']?.toString();
      final total = single['totalDuration'] ?? single['totalCount'];
      if (name != null) {
        return total != null
            ? '**$name** — ${_formatNumber(total)}'
            : '**$name**';
      }
    }

    // direct scalar totals
    if (data.containsKey('totalCount') ||
        data.containsKey('totalDurationSeconds')) {
      final total = data['totalCount'] ?? data['totalDurationSeconds'];
      final unit = data['unit']?.toString() ?? '';
      return 'Total: **${_formatNumber(total)}**${unit.isNotEmpty ? ' $unit' : ''}';
    }

    return null;
  }

  static bool _looksLikeComparison(List<dynamic> list) {
    final first = list.first;
    return first is Map &&
        (first.containsKey('current') || first.containsKey('previous'));
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  static List<(String, num)> _extractLabelValuePairs(dynamic data) {
    final pairs = <(String, num)>[];

    if (data is List) {
      for (final element in data) {
        if (element is Map) {
          final label =
              element['label']?.toString() ??
              element['name']?.toString() ??
              element['activityName']?.toString();
          final value = _firstNumber(element);
          if (label != null && value != null) {
            pairs.add((label, value));
          } else if (element.length == 1) {
            final entry = element.entries.first;
            final v = _toNumber(entry.value);
            if (v != null) pairs.add((entry.key.toString(), v));
          }
        } else if (element is List && element.length >= 2) {
          final v = _toNumber(element[1]);
          if (v != null) pairs.add((element[0].toString(), v));
        }
      }
    } else if (data is Map) {
      // Skip series-shaped maps; those are handled elsewhere.
      if (data['labels'] is List && data['series'] is List) return pairs;
      for (final entry in data.entries) {
        final v = _toNumber(entry.value);
        if (v != null) pairs.add((entry.key.toString(), v));
      }
    }

    return pairs;
  }

  static num? _firstNumber(Map element) {
    final preferred =
        element['value'] ??
        element['seconds'] ??
        element['count'] ??
        element['duration'] ??
        element['totalCount'] ??
        element['amount'];
    final parsed = _toNumber(preferred);
    if (parsed != null) return parsed;
    for (final entry in element.entries) {
      if (entry.key == 'label' ||
          entry.key == 'name' ||
          entry.key == 'activityName') {
        continue;
      }
      final v = _toNumber(entry.value);
      if (v != null) return v;
    }
    return null;
  }

  static num? _toNumber(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  static String _formatNumber(dynamic value) {
    final n = _toNumber(value);
    if (n == null) return value?.toString() ?? '—';
    if (n is int) return n.toString();
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(1);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:active/presentation/pages/stats/widgets/monthly_heat_map.dart';

void main() {
  const red = Color(0xFFE53935);
  const green = Color(0xFF43A047);

  group('sampleRamp', () {
    test('starts at red and ends at green', () {
      expect(MonthlyHeatMap.sampleRamp(0.0), red);
      expect(MonthlyHeatMap.sampleRamp(1.0), green);
    });

    test('passes through orange then yellow in between', () {
      final third = MonthlyHeatMap.sampleRamp(1 / 3);
      final twoThirds = MonthlyHeatMap.sampleRamp(2 / 3);

      expect(third, MonthlyHeatMap.intensityRamp[1]); // orange
      expect(twoThirds, MonthlyHeatMap.intensityRamp[2]); // yellow
    });

    test('increases in green channel monotonically across the ramp', () {
      // The defining property of the ramp: as intensity rises, colour moves
      // steadily toward green rather than jumping around.
      var previous = -1;
      for (var i = 0; i <= 20; i++) {
        final g = (MonthlyHeatMap.sampleRamp(i / 20).g * 255).round();
        if (i > 0 && i <= 13) {
          // Red→orange→yellow: green channel climbs.
          expect(g, greaterThanOrEqualTo(previous),
              reason: 'green channel dropped at t=${i / 20}');
        }
        previous = g;
      }
    });

    test('clamps out-of-range input', () {
      expect(MonthlyHeatMap.sampleRamp(-1), red);
      expect(MonthlyHeatMap.sampleRamp(5), green);
    });
  });

  group('colorForQuantity', () {
    test('maps the month minimum to red and the maximum to green', () {
      expect(
        MonthlyHeatMap.colorForQuantity(
            qty: 10, minPositive: 10, maxPositive: 50),
        red,
      );
      expect(
        MonthlyHeatMap.colorForQuantity(
            qty: 50, minPositive: 10, maxPositive: 50),
        green,
      );
    });

    test('scales across the observed range, not from zero', () {
      // A clustered month (40..50) must still span the full ramp — this is
      // the bug the old zero-based scaling caused.
      final low = MonthlyHeatMap.colorForQuantity(
          qty: 40, minPositive: 40, maxPositive: 50);
      final high = MonthlyHeatMap.colorForQuantity(
          qty: 50, minPositive: 40, maxPositive: 50);

      expect(low, red);
      expect(high, green);
      expect(low, isNot(high));
    });

    test('midpoint of the range lands mid-ramp, not at either end', () {
      final mid = MonthlyHeatMap.colorForQuantity(
          qty: 30, minPositive: 10, maxPositive: 50);

      expect(mid, isNot(red));
      expect(mid, isNot(green));
    });

    test('a month with one distinct value shows it at full intensity', () {
      // Every day equal: no range exists, so treat it as "max" rather than
      // painting the whole month red.
      expect(
        MonthlyHeatMap.colorForQuantity(
            qty: 20, minPositive: 20, maxPositive: 20),
        green,
      );
    });

    test('adjacent values in a wide range are visibly different', () {
      final a = MonthlyHeatMap.colorForQuantity(
          qty: 10, minPositive: 0, maxPositive: 100);
      final b = MonthlyHeatMap.colorForQuantity(
          qty: 60, minPositive: 0, maxPositive: 100);

      // Compare on raw channel values; these should be far apart.
      final deltaR = ((a.r - b.r) * 255).abs();
      final deltaG = ((a.g - b.g) * 255).abs();
      expect(deltaR + deltaG, greaterThan(40));
    });
  });
}

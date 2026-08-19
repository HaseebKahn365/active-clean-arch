import 'package:flutter_test/flutter_test.dart';

import 'package:active/presentation/pages/agent/services/agent_service.dart';

void main() {
  group('TokenUsage', () {
    test('sums across model turns', () {
      const first = TokenUsage(
        promptTokens: 100,
        responseTokens: 20,
        totalTokens: 120,
      );
      const second = TokenUsage(
        promptTokens: 150,
        responseTokens: 40,
        thoughtTokens: 10,
        totalTokens: 200,
      );

      final combined = first + second;

      expect(combined.promptTokens, 250);
      expect(combined.responseTokens, 60);
      expect(combined.thoughtTokens, 10);
      expect(combined.totalTokens, 320);
    });

    test('isEmpty reflects a zero total', () {
      expect(const TokenUsage().isEmpty, isTrue);
      expect(const TokenUsage(totalTokens: 5).isEmpty, isFalse);
    });

    test('describes usage without thinking tokens', () {
      const usage = TokenUsage(
        promptTokens: 80,
        responseTokens: 25,
        totalTokens: 105,
      );
      expect(usage.toString(), 'prompt 80 + response 25 = 105 total');
    });

    test('includes thinking tokens in the description when present', () {
      const usage = TokenUsage(
        promptTokens: 80,
        responseTokens: 25,
        thoughtTokens: 12,
        totalTokens: 117,
      );
      expect(
        usage.toString(),
        'prompt 80 + response 25 + thinking 12 = 117 total',
      );
    });

    test('identity: adding empty usage changes nothing', () {
      const usage = TokenUsage(
        promptTokens: 10,
        responseTokens: 5,
        totalTokens: 15,
      );
      final result = usage + const TokenUsage();
      expect(result.totalTokens, 15);
      expect(result.promptTokens, 10);
    });
  });
}

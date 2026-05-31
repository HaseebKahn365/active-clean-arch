import 'package:active/infrastructure/ai/ai_tool_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiToolEnvelope wrapper', () {
    test('toJson always includes mandatory wrapper keys', () {
      final envelope = AiToolEnvelope.success(
        tool: 'pauseActivity',
        data: const {'activityId': 'a1'},
        message: 'Paused.',
      );

      final json = envelope.toJson();
      expect(json.containsKey('success'), isTrue);
      expect(json.containsKey('tool'), isTrue);
      expect(json.containsKey('data'), isTrue);
      expect(json.containsKey('message'), isTrue);
      expect(json.containsKey('errorCode'), isTrue);
      expect(json['errorCode'], isNull);
    });

    test('fromJson normalizes legacy action/ok shape', () {
      final envelope = AiToolEnvelope.fromJson({
        'ok': true,
        'action': 'resumeActivity',
        'message': 'Resumed.',
      });

      expect(envelope.success, isTrue);
      expect(envelope.tool, 'resumeActivity');
      expect(envelope.data, isA<Map<String, dynamic>>());
      expect(envelope.message, 'Resumed.');
    });
  });
}

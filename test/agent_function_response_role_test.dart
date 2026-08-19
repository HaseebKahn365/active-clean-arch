import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the tool-result role.
///
/// The Google AI (Developer API) backend rejects `role: 'function'` with
/// "Role 'function' is not supported", so AgentService must send tool results
/// as a 'user' Content rather than via Content.functionResponses().
void main() {
  group('function response serialization', () {
    final part = FunctionResponse('get_activity_summary', const {'total': 30});

    test('Content.functionResponses uses the role the backend rejects', () {
      // Documents *why* the helper is avoided. If a future SDK changes this to
      // 'user', this test fails and the workaround can be reconsidered.
      final json = Content.functionResponses([part]).toJson();
      expect(json['role'], 'function');
    });

    test('the role AgentService sends is accepted by the backend', () {
      final json = Content('user', [part]).toJson();

      expect(json['role'], 'user');
      final parts = json['parts'] as List;
      expect(parts, hasLength(1));
      expect(
        (parts.first as Map)['functionResponse'],
        containsPair('name', 'get_activity_summary'),
      );
    });
  });
}

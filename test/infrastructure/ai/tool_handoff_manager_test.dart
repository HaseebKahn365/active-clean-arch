import 'package:active/domain/entities/activity.dart';
import 'package:active/infrastructure/ai/ai_tool_definitions.dart';
import 'package:active/infrastructure/ai/tool_handoff_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToolHandoffManager', () {
    const manager = ToolHandoffManager();

    final now = DateTime(2026, 1, 1);
    final Map<String, Activity> activities = {
      'a1': Activity(
        id: 'a1',
        name: 'Practical MLOps',
        parentId: null,
        childrenIds: const [],
        status: ActivityStatus.paused,
        type: ActivityType.timeBased,
        totalSeconds: 0,
        createdAt: now,
        updatedAt: now,
      ),
      'a2': Activity(
        id: 'a2',
        name: 'Study',
        parentId: null,
        childrenIds: const [],
        status: ActivityStatus.running,
        type: ActivityType.timeBased,
        totalSeconds: 0,
        createdAt: now,
        updatedAt: now,
      ),
    };

    test('fills missing activityId from selected activity context', () {
      final result = manager.resolve(
        tool: AiToolNames.pauseActivity,
        args: const {},
        appContext: const {'selectedActivityId': 'a2'},
        activities: activities,
      );

      expect(result.isReady, isTrue);
      expect(result.resolvedArgs['activityId'], 'a2');
      expect(result.usedContext, isTrue);
    });

    test('resolves activityId by unique name search hint', () {
      final result = manager.resolve(
        tool: AiToolNames.resumeActivity,
        args: const {'activityName': 'Practical MLOps'},
        appContext: const {},
        activities: activities,
      );

      expect(result.isReady, isTrue);
      expect(result.resolvedArgs['activityId'], 'a1');
      expect(result.usedSearch, isTrue);
    });

    test('returns missingRequired when unresolved', () {
      final result = manager.resolve(
        tool: AiToolNames.finishActivity,
        args: const {},
        appContext: const {},
        activities: activities,
      );

      expect(result.isReady, isFalse);
      expect(result.missingRequired, contains('activityId'));
    });
  });
}

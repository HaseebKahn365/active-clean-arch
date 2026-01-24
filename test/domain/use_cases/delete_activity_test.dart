import 'package:flutter_test/flutter_test.dart';
import 'package:active/domain/entities/activity.dart';
import 'package:active/domain/entities/activity_event.dart';
import 'package:active/domain/entities/count_record.dart';
import 'package:active/domain/repositories/activity_repository.dart';
import 'package:active/domain/use_cases/activity/delete_activity_use_case.dart';
import 'package:active/domain/use_cases/activity/pause_activity_use_case.dart';

class MockActivityRepository implements ActivityRepository {
  final Map<String, Activity> activities = {};
  final List<ActivityEvent> events = [];

  @override
  Future<List<Activity>> getAllActivities() async => activities.values.toList();

  @override
  Future<Activity?> getActivityById(String id) async => activities[id];

  @override
  Future<void> saveActivity(Activity activity, {SaveReason reason = SaveReason.immediate}) async {
    activities[activity.id] = activity;
  }

  @override
  Future<void> deleteActivity(String id) async {
    activities.remove(id);
  }

  @override
  Future<void> updateActivity(Activity activity, {SaveReason reason = SaveReason.immediate}) async {
    activities[activity.id] = activity;
  }

  @override
  Future<void> saveEvent(ActivityEvent event) async {
    events.add(event);
  }

  @override
  Future<List<ActivityEvent>> getAllEvents() async => List.from(events);

  @override
  Future<List<ActivityEvent>> getUnsyncedEvents() async {
    return events.where((e) => !e.isSynced).toList();
  }

  @override
  Future<void> markEventAsSynced(String id) async {
    final index = events.indexWhere((e) => e.id == id);
    if (index != -1) {
      // Note: ActivityEvent is immutable
    }
  }

  @override
  Future<void> saveCountRecord(CountRecord record) async {}

  @override
  Future<List<CountRecord>> getAllCountRecords() async => [];

  @override
  Future<List<CountRecord>> getCountRecordsForActivity(String activityId) async => [];

  @override
  Future<void> deleteCountRecord(String id) async {}
}

void main() {
  late DeleteActivityUseCase deleteActivityUseCase;
  late PauseActivityUseCase pauseActivityUseCase;
  late MockActivityRepository mockRepository;

  setUp(() {
    mockRepository = MockActivityRepository();
    pauseActivityUseCase = PauseActivityUseCase(mockRepository);
    deleteActivityUseCase = DeleteActivityUseCase(mockRepository, pauseActivityUseCase);
  });

  test('should reattach children to parent when an activity is deleted', () async {
    final now = DateTime.now();
    final grandpa = Activity(
      id: 'grandpa',
      name: 'Grandpa',
      childrenIds: const ['parent'],
      status: ActivityStatus.paused,
      totalSeconds: 0,
      type: ActivityType.timeBased,
      createdAt: now,
      updatedAt: now,
    );
    final parent = Activity(
      id: 'parent',
      name: 'Parent',
      parentId: 'grandpa',
      childrenIds: const ['child1', 'child2'],
      status: ActivityStatus.paused,
      totalSeconds: 0,
      type: ActivityType.timeBased,
      createdAt: now,
      updatedAt: now,
    );
    final child1 = Activity(
      id: 'child1',
      name: 'Child 1',
      parentId: 'parent',
      childrenIds: const [],
      status: ActivityStatus.paused,
      totalSeconds: 0,
      type: ActivityType.timeBased,
      createdAt: now,
      updatedAt: now,
    );
    final child2 = Activity(
      id: 'child2',
      name: 'Child 2',
      parentId: 'parent',
      childrenIds: const [],
      status: ActivityStatus.paused,
      totalSeconds: 0,
      type: ActivityType.timeBased,
      createdAt: now,
      updatedAt: now,
    );

    mockRepository.activities['grandpa'] = grandpa;
    mockRepository.activities['parent'] = parent;
    mockRepository.activities['child1'] = child1;
    mockRepository.activities['child2'] = child2;

    // Act: Delete Parent
    await deleteActivityUseCase.execute('parent');

    // Assert:
    // 1. Parent is deleted
    expect(mockRepository.activities.containsKey('parent'), false);

    // 2. Grandpa's children are now [child1, child2] (parent removed, children added)
    final updatedGrandpa = mockRepository.activities['grandpa']!;
    expect(updatedGrandpa.childrenIds, containsAll(['child1', 'child2']));
    expect(updatedGrandpa.childrenIds.contains('parent'), false);

    // 3. Child1 and Child2 parentId is now grandpa
    expect(mockRepository.activities['child1']!.parentId, 'grandpa');
    expect(mockRepository.activities['child2']!.parentId, 'grandpa');
  });

  test('should make children roots when a root activity is deleted', () async {
    final now = DateTime.now();
    // Arrange: Parent (Root) -> Child1
    final parent = Activity(
      id: 'parent',
      name: 'Parent',
      parentId: null,
      childrenIds: const ['child1'],
      status: ActivityStatus.paused,
      totalSeconds: 0,
      type: ActivityType.timeBased,
      createdAt: now,
      updatedAt: now,
    );
    final child1 = Activity(
      id: 'child1',
      name: 'Child 1',
      parentId: 'parent',
      childrenIds: const [],
      status: ActivityStatus.paused,
      totalSeconds: 0,
      type: ActivityType.timeBased,
      createdAt: now,
      updatedAt: now,
    );

    mockRepository.activities['parent'] = parent;
    mockRepository.activities['child1'] = child1;

    // Act: Delete Parent
    await deleteActivityUseCase.execute('parent');

    // Assert:
    expect(mockRepository.activities.containsKey('parent'), false);
    expect(mockRepository.activities['child1']!.parentId, null);
  });
}

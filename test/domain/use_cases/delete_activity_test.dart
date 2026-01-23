import 'package:flutter_test/flutter_test.dart';
import 'package:active/domain/entities/activity.dart';
import 'package:active/domain/repositories/activity_repository.dart';
import 'package:active/domain/use_cases/activity/delete_activity_use_case.dart';

class MockActivityRepository implements ActivityRepository {
  final Map<String, Activity> activities = {};

  @override
  Future<List<Activity>> getAllActivities() async => activities.values.toList();

  @override
  Future<Activity?> getActivityById(String id) async => activities[id];

  @override
  Future<void> saveActivity(Activity activity) async {
    activities[activity.id] = activity;
  }

  @override
  Future<void> deleteActivity(String id) async {
    activities.remove(id);
  }

  @override
  Future<void> updateActivity(Activity activity) async {
    activities[activity.id] = activity;
  }
}

void main() {
  late DeleteActivityUseCase deleteActivityUseCase;
  late MockActivityRepository mockRepository;

  setUp(() {
    mockRepository = MockActivityRepository();
    deleteActivityUseCase = DeleteActivityUseCase(mockRepository);
  });

  test('should reattach children to parent when an activity is deleted', () async {
    // Arrange: Create Grandpa -> Parent -> Child1, Child2
    const grandpa = Activity(
      id: 'grandpa',
      name: 'Grandpa',
      childrenIds: ['parent'],
      status: ActivityStatus.paused,
      totalSeconds: 0,
    );
    const parent = Activity(
      id: 'parent',
      name: 'Parent',
      parentId: 'grandpa',
      childrenIds: ['child1', 'child2'],
      status: ActivityStatus.paused,
      totalSeconds: 0,
    );
    const child1 = Activity(
      id: 'child1',
      name: 'Child 1',
      parentId: 'parent',
      childrenIds: [],
      status: ActivityStatus.paused,
      totalSeconds: 0,
    );
    const child2 = Activity(
      id: 'child2',
      name: 'Child 2',
      parentId: 'parent',
      childrenIds: [],
      status: ActivityStatus.paused,
      totalSeconds: 0,
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
    // Arrange: Parent (Root) -> Child1
    const parent = Activity(
      id: 'parent',
      name: 'Parent',
      parentId: null,
      childrenIds: ['child1'],
      status: ActivityStatus.paused,
      totalSeconds: 0,
    );
    const child1 = Activity(
      id: 'child1',
      name: 'Child 1',
      parentId: 'parent',
      childrenIds: [],
      status: ActivityStatus.paused,
      totalSeconds: 0,
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

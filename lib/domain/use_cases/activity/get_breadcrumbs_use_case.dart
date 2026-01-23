import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';

class GetBreadcrumbsUseCase {
  final ActivityRepository repository;

  GetBreadcrumbsUseCase(this.repository);

  /// Returns a list of Activities from root to the current activity.
  Future<List<Activity>> execute(String activityId) async {
    final List<Activity> breadcrumbs = [];
    String? currentId = activityId;

    while (currentId != null) {
      final activity = await repository.getActivityById(currentId);
      if (activity == null) break;

      breadcrumbs.insert(0, activity);
      currentId = activity.parentId;
    }

    return breadcrumbs;
  }
}

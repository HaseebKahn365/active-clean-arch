import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../infrastructure/database/sqlite_service.dart';
import '../../infrastructure/auth/google_auth_service.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../data/repositories/sync_repository_impl.dart';
import '../../data/repositories/in_memory_activity_repository.dart';
import '../../domain/use_cases/activity/get_breadcrumbs_use_case.dart';
import '../../domain/use_cases/activity/get_activities_use_case.dart';
import '../../domain/use_cases/activity/delete_activity_use_case.dart';
import '../../domain/use_cases/activity/start_activity_use_case.dart';
import '../../domain/use_cases/activity/pause_activity_use_case.dart';
import '../../domain/use_cases/activity/complete_activity_use_case.dart';
import '../../domain/use_cases/activity/checkpoint_activity_use_case.dart';
import '../../domain/use_cases/activity/create_activity_use_case.dart';
import '../../domain/use_cases/activity/update_activity_use_case.dart';
import '../../domain/use_cases/activity/toggle_pin_use_case.dart';
import '../../domain/use_cases/activity/move_activity_use_case.dart';
import '../../domain/use_cases/activity/calculate_cumulative_duration_use_case.dart';
import '../../domain/use_cases/activity/update_activity_duration_use_case.dart';
import '../../domain/use_cases/activity/add_count_use_case.dart';
import '../../domain/use_cases/activity/get_activity_total_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../presentation/providers/activity_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/sync_provider.dart';
import '../../presentation/providers/theme_provider.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // External
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);
  sl.registerLazySingleton(() => Connectivity());

  final sharedPrefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPrefs);

  // Infrastructure
  sl.registerLazySingleton(() => SqliteService.instance);
  sl.registerLazySingleton(() => GoogleAuthService());

  // Presentation / State Management
  sl.registerFactory(() => AppAuthProvider(sl()));
  sl.registerFactory(
    () => ActivityController(
      getActivitiesUseCase: sl(),
      deleteActivityUseCase: sl(),
      startActivityUseCase: sl(),
      pauseActivityUseCase: sl(),
      completeActivityUseCase: sl(),
      checkpointActivityUseCase: sl(),
      createActivityUseCase: sl(),
      getBreadcrumbsUseCase: sl(),
      updateActivityUseCase: sl(),
      togglePinUseCase: sl(),
      moveActivityUseCase: sl(),
      calculateCumulativeDurationUseCase: sl(),
      updateActivityDurationUseCase: sl(),
      addCountUseCase: sl(),
      getActivityTotalUseCase: sl(),
    ),
  );
  sl.registerFactory(() => SyncController(activityRepository: sl(), syncRepository: sl(), connectivity: sl()));
  sl.registerLazySingleton(() => ThemeProvider(sl()));

  // Use Cases
  sl.registerLazySingleton(() => GetActivitiesUseCase(sl()));
  sl.registerLazySingleton(() => DeleteActivityUseCase(sl(), sl()));
  sl.registerLazySingleton(() => StartActivityUseCase(sl()));
  sl.registerLazySingleton(() => PauseActivityUseCase(sl()));
  sl.registerLazySingleton(() => CompleteActivityUseCase(sl(), sl()));
  sl.registerLazySingleton(() => CheckpointActivityUseCase(sl()));
  sl.registerLazySingleton(() => CreateActivityUseCase(sl()));
  sl.registerLazySingleton(() => GetBreadcrumbsUseCase(sl()));
  sl.registerLazySingleton(() => UpdateActivityUseCase(sl()));
  sl.registerLazySingleton(() => TogglePinUseCase(sl()));
  sl.registerLazySingleton(() => MoveActivityUseCase(sl()));
  sl.registerLazySingleton(() => CalculateCumulativeDurationUseCase());
  sl.registerLazySingleton(() => UpdateActivityDurationUseCase(sl()));
  sl.registerLazySingleton(() => AddCountUseCase(sl()));
  sl.registerLazySingleton(() => GetActivityTotalUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ActivityRepository>(() => InMemoryActivityRepository());
  sl.registerLazySingleton<SyncRepository>(() => SyncRepositoryImpl(sl()));
}

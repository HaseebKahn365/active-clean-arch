import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../infrastructure/database/sqlite_service.dart';
import '../../infrastructure/auth/google_auth_service.dart';
import '../../infrastructure/notifications/notification_service.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../data/repositories/sql_activity_repository.dart';
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
import '../../domain/use_cases/activity/clear_all_data_use_case.dart';
import '../../domain/repositories/backup_repository.dart';
import '../../data/repositories/backup_repository_impl.dart';
import '../../domain/use_cases/backup/create_backup_use_case.dart';
import '../../domain/use_cases/backup/get_backup_history_use_case.dart';
import '../../domain/use_cases/backup/restore_backup_use_case.dart';
import '../../presentation/providers/backup_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../presentation/providers/activity_manager_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/theme_provider.dart';
import '../../presentation/providers/stats_provider.dart';
import '../../application/services/activity_timer_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // External
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);
  sl.registerLazySingleton(() => FirebaseStorage.instance);
  sl.registerLazySingleton(() => Connectivity());

  final sharedPrefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPrefs);

  // Infrastructure
  sl.registerLazySingleton(() => SqliteService.instance);
  sl.registerLazySingleton(() => GoogleAuthService());

  // Services
  sl.registerLazySingleton(() => ActivityTimerService());
  sl.registerLazySingleton(() => NotificationService());

  // Presentation / State Management
  sl.registerLazySingleton(() => AppAuthProvider(sl()));
  sl.registerLazySingleton(
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
      clearAllDataUseCase: sl(),
      timerService: sl(),
      notificationService: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => BackupController(
      createBackupUseCase: sl(),
      getBackupHistoryUseCase: sl(),
      restoreBackupUseCase: sl(),
      authProvider: sl(),
    ),
  );
  sl.registerLazySingleton(() => ThemeProvider(sl()));
  sl.registerLazySingleton(() => StatsController(repository: sl(), activityController: sl()));

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
  sl.registerLazySingleton(() => ClearAllDataUseCase(sl()));

  sl.registerLazySingleton(() => CreateBackupUseCase(sl(), sl()));
  sl.registerLazySingleton(() => GetBackupHistoryUseCase(sl()));
  sl.registerLazySingleton(() => RestoreBackupUseCase(sl(), sl()));

  // Repository
  sl.registerLazySingleton<ActivityRepository>(() => SqlActivityRepository(sl()));

  sl.registerLazySingleton<BackupRepository>(() => BackupRepositoryImpl(sl(), sl()));
}

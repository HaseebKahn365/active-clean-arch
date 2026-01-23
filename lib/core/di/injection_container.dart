import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../infrastructure/database/sqlite_service.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../data/repositories/activity_repository_impl.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../data/repositories/sync_repository_impl.dart';
import '../../domain/use_cases/activity/get_activities_use_case.dart';
import '../../domain/use_cases/activity/delete_activity_use_case.dart';
import '../../domain/use_cases/activity/start_activity_use_case.dart';
import '../../domain/use_cases/activity/pause_activity_use_case.dart';
import '../../domain/use_cases/activity/complete_activity_use_case.dart';
import '../../domain/use_cases/activity/checkpoint_activity_use_case.dart';
import '../../presentation/providers/activity_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/sync_provider.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // External
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);
  sl.registerLazySingleton(() => Connectivity());

  // Presentation / State Management
  sl.registerFactory(() => AppAuthProvider());
  sl.registerFactory(
    () => ActivityController(
      getActivitiesUseCase: sl(),
      deleteActivityUseCase: sl(),
      startActivityUseCase: sl(),
      pauseActivityUseCase: sl(),
      completeActivityUseCase: sl(),
      checkpointActivityUseCase: sl(),
    ),
  );
  sl.registerFactory(() => SyncController(activityRepository: sl(), syncRepository: sl(), connectivity: sl()));

  // Use Cases
  sl.registerLazySingleton(() => GetActivitiesUseCase(sl()));
  sl.registerLazySingleton(() => DeleteActivityUseCase(sl(), sl()));
  sl.registerLazySingleton(() => StartActivityUseCase(sl()));
  sl.registerLazySingleton(() => PauseActivityUseCase(sl()));
  sl.registerLazySingleton(() => CompleteActivityUseCase(sl(), sl()));
  sl.registerLazySingleton(() => CheckpointActivityUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ActivityRepository>(() => ActivityRepositoryImpl(sl()));
  sl.registerLazySingleton<SyncRepository>(() => SyncRepositoryImpl(sl()));

  // Infrastructure
  sl.registerLazySingleton(() => SqliteService.instance);
}

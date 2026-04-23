import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/injection_container.dart';
import 'activity_manager_provider.dart';
import 'auth_provider.dart';
import 'stats_provider.dart';

// Bridge Providers to allow Riverpod to access existing Provider logic
final activityControllerProvider = ChangeNotifierProvider<ActivityController>((ref) {
  return sl<ActivityController>();
});

final authControllerProvider = ChangeNotifierProvider<AppAuthProvider>((ref) {
  return sl<AppAuthProvider>();
});

final statsControllerProvider = ChangeNotifierProvider<StatsController>((ref) {
  return sl<StatsController>();
});

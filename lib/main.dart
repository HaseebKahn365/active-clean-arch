import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'firebase_options.dart';
import 'core/di/injection_container.dart' as di;
import 'presentation/providers/activity_manager_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/theme_notifier.dart';
import 'presentation/providers/stats_provider.dart';
import 'infrastructure/notifications/notification_service.dart';
import 'application/services/background_service.dart';
import 'presentation/pages/activity_detail_page.dart';
import 'data/migrations/event_compression_migration.dart';
import 'domain/repositories/activity_repository.dart';
import 'infrastructure/database/sqlite_service.dart';

import 'presentation/theme/app_theme.dart';
import 'presentation/pages/auth/sign_in_page.dart';
import 'presentation/pages/dashboard/dashboard_page.dart';
import 'presentation/pages/stats/global_stats_page.dart';
import 'presentation/pages/stats/activity_stats_page.dart';
import 'presentation/widgets/mac_swipe_back_navigator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase must be initialized before any Firebase services are accessed
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Initialize Dependency Injection
  await di.init();

  // 2.1 Run Event Compression Migration
  final migration = EventCompressionMigration(di.sl<ActivityRepository>(), di.sl<SqliteService>());
  await migration.run();

  // 3. Initialize Notification Service (now includes channel creation)
  await di.sl<NotificationService>().init();

  // 4. Initialize Background Service Configuration
  await BackgroundServiceInstance.initialize();

  runApp(
    ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => di.sl<AppAuthProvider>()),
          ChangeNotifierProvider(create: (_) => di.sl<ActivityController>()..loadActivities()),
          ChangeNotifierProvider(create: (_) => di.sl<StatsController>()..loadData()),
        ],
        child: const ActiveApp(),
      ),
    ),
  );
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class ActiveApp extends ConsumerStatefulWidget {
  const ActiveApp({super.key});

  @override
  ConsumerState<ActiveApp> createState() => _ActiveAppState();
}

class _ActiveAppState extends ConsumerState<ActiveApp> {
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _notificationSubscription = di.sl<NotificationService>().onResponse.listen((payload) {
      if (payload != null && payload.isNotEmpty) {
        _navigatorKey.currentState?.pushNamed(payload);
      }
    });
  }

  Future<void> _requestNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      // The init() already happened in main(), so we just need to make sure permissions are granted
      // For Android 13+, we need to request POST_NOTIFICATIONS
      final androidPlugin = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeNotifierProvider);

    return MaterialApp(
      title: 'Active',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(themeState.colorProfile, Brightness.light),
      darkTheme: AppTheme.getTheme(themeState.colorProfile, Brightness.dark),
      themeMode: themeState.themeMode,

      builder: (context, child) => MacSwipeBackNavigator(navigatorKey: _navigatorKey, child: child!),
      home: const AuthGate(),
      routes: {'/stats/global': (context) => const GlobalStatsPage()},
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/stats/activity/') ?? false) {
          final id = settings.name!.replaceFirst('/stats/activity/', '');
          return MaterialPageRoute(
            builder: (context) => ActivityStatsPage(activityId: id),
            settings: settings,
          );
        }
        if (settings.name?.startsWith('/activity/') ?? false) {
          final id = settings.name!.replaceFirst('/activity/', '');
          return MaterialPageRoute(
            builder: (context) => ActivityDetailPage(activityId: id),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) {
          return const SignInPage();
        }
        return const DashboardPage();
      },
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/di/injection_container.dart' as di;
import 'presentation/providers/activity_manager_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/backup_provider.dart';
import 'presentation/providers/stats_provider.dart';
import 'infrastructure/notifications/notification_service.dart';
import 'application/services/background_service.dart';
import 'presentation/pages/activity_detail_page.dart';

import 'presentation/theme/app_theme.dart';
import 'presentation/pages/auth/sign_in_page.dart';
import 'presentation/pages/dashboard/dashboard_page.dart';
import 'presentation/pages/stats/global_stats_page.dart';
import 'presentation/pages/stats/activity_stats_page.dart';
import 'presentation/widgets/mac_swipe_back_navigator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Dependency Injection
  await di.init();

  // Initialize Notification Service
  await di.sl<NotificationService>().init();

  // Initialize Background Service
  await BackgroundServiceInstance.initialize();

  // Initialize Firebase infrastructure
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => di.sl<AppAuthProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ActivityController>()..loadActivities()),
        ChangeNotifierProxyProvider<AppAuthProvider, SyncController>(
          create: (_) => di.sl<SyncController>(),
          update: (_, auth, sync) {
            if (sync != null) {
              sync.init(auth.userId);
            }
            return sync!;
          },
        ),
        ChangeNotifierProvider(create: (_) => di.sl<ThemeProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<BackupController>()),
        ChangeNotifierProvider(create: (_) => di.sl<StatsController>()..loadData()),
      ],
      child: const ActiveApp(),
    ),
  );
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class ActiveApp extends StatefulWidget {
  const ActiveApp({super.key});

  @override
  State<ActiveApp> createState() => _ActiveAppState();
}

class _ActiveAppState extends State<ActiveApp> {
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _notificationSubscription = di.sl<NotificationService>().onResponse.listen((payload) {
      if (payload != null && payload.isNotEmpty) {
        _navigatorKey.currentState?.pushNamed(payload);
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Active',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(themeProvider.colorProfile, Brightness.light),
      darkTheme: AppTheme.getTheme(themeProvider.colorProfile, Brightness.dark),
      themeMode: themeProvider.themeMode,

      builder: (context, child) => MacSwipeBackNavigator(navigatorKey: _navigatorKey, child: child!),
      home: const AuthGate(),
      routes: {'/stats/global': (context) => const GlobalStatsPage()},
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/stats/activity/') ?? false) {
          final id = settings.name!.replaceFirst('/stats/activity/', '');
          return MaterialPageRoute(builder: (context) => ActivityStatsPage(activityId: id));
        }
        if (settings.name?.startsWith('/activity/') ?? false) {
          final id = settings.name!.replaceFirst('/activity/', '');
          return MaterialPageRoute(builder: (context) => ActivityDetailPage(activityId: id));
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

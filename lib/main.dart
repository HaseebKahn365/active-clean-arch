import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/di/injection_container.dart' as di;
import 'presentation/providers/activity_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/pages/auth/sign_in_page.dart';
import 'presentation/pages/dashboard/dashboard_page.dart';
import 'presentation/widgets/mac_swipe_back_navigator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Dependency Injection
  await di.init();

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
      ],
      child: const ActiveApp(),
    ),
  );
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class ActiveApp extends StatelessWidget {
  const ActiveApp({super.key});

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

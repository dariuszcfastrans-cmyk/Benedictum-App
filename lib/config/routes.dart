import 'package:go_router/go_router.dart';

import '../features/auth/auth_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/home/home_screen.dart';
import '../features/report/report_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';

/// Konfiguracja nawigacji aplikacji Benedictum (GoRouter).
abstract final class AppRoutes {
  static const String splash = '/';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String report = '/report';
  static const String settings = '/settings';
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: AppRoutes.report,
        builder: (context, state) => const ReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}

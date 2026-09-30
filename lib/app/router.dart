import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../features/analyzer/analyzer_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/vanity/vanity_screen.dart';
import '../providers/session_provider.dart';
import '../widgets/floating_nav.dart';

abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const analyzer = '/analyzer';
  static const vanity = '/vanity';
  static const profile = '/profile';
}

Page<void> _page(Widget child) => NoTransitionPage(child: child);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      if (!s.ready) return loc == Routes.splash ? null : Routes.splash;
      if (!s.loggedIn) return loc == Routes.login ? null : Routes.login;
      if (!s.onboarded) return loc == Routes.onboarding ? null : Routes.onboarding;
      if (loc == Routes.splash || loc == Routes.login || loc == Routes.onboarding) return Routes.analyzer;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        pageBuilder: (_, _) => _page(const ColoredBox(color: SM.bg)),
      ),
      GoRoute(path: Routes.login, pageBuilder: (_, _) => _page(const LoginScreen())),
      GoRoute(path: Routes.onboarding, pageBuilder: (_, _) => _page(const OnboardingScreen())),
      // 탭을 바꿀 때마다 화면을 새로 그려서 프로토타입처럼 맨 위에서 페이드 인해요.
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: Routes.analyzer, pageBuilder: (_, _) => _page(const AnalyzerScreen())),
          GoRoute(path: Routes.vanity, pageBuilder: (_, _) => _page(const VanityScreen())),
          GoRoute(path: Routes.profile, pageBuilder: (_, _) => _page(const ProfileScreen())),
        ],
      ),
    ],
  );
});

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SM.bg,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          FloatingNav(location: location),
        ],
      ),
    );
  }
}

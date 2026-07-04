import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hr_superapp/features/auth/application/auth_controller.dart';
import 'package:hr_superapp/features/auth/domain/user_role.dart';
import 'package:hr_superapp/features/home/presentation/home_shell.dart';
import 'package:hr_superapp/features/auth/presentation/sign_in_screen.dart';

/// Route table with declarative RBAC guards.
/// Each protected branch declares the [Capability] it requires; the redirect
/// re-evaluates whenever the auth state changes (via refreshListenable).
abstract final class Routes {
  static const signIn = '/sign-in';
  static const home = '/';
  static const platformAdmin = '/platform'; // super admin
  static const countryContent = '/country-content'; // country admin
  static const companyDashboard = '/company'; // tenant admin
  static const selfService = '/me'; // employee
  static const cvBuilder = '/cv-builder'; // public (guest-friendly)
}

const _routeCapabilities = <String, Capability>{
  Routes.platformAdmin: Capability.managePlatform,
  Routes.countryContent: Capability.manageCountryContent,
  Routes.companyDashboard: Capability.manageTenant,
  Routes.selfService: Capability.useSelfService,
};

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ValueNotifier<int>(0);
  ref
    ..onDispose(authState.dispose)
    ..listen(authStateProvider, (_, __) => authState.value++);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: authState,
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final path = state.matchedLocation;

      // Public routes: CV builder & job board are open to guests.
      final isPublic = path == Routes.signIn || path.startsWith(Routes.cvBuilder);

      if (!user.isAuthenticated && !isPublic) return Routes.signIn;
      if (user.isAuthenticated && path == Routes.signIn) return Routes.home;

      // Capability guard for protected branches.
      for (final entry in _routeCapabilities.entries) {
        if (path.startsWith(entry.key) && !user.can(entry.value)) {
          return Routes.home;
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeShell(),
      ),
      // Feature branches (screens land here as modules are implemented):
      // GoRoute(path: Routes.platformAdmin, ...)
      // GoRoute(path: Routes.countryContent, ...)
      // GoRoute(path: Routes.companyDashboard, ...)
      // GoRoute(path: Routes.selfService, ...)
      // GoRoute(path: Routes.cvBuilder, ...)
    ],
  );
});

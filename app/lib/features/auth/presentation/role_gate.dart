import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hr_superapp/features/auth/application/auth_controller.dart';
import 'package:hr_superapp/features/auth/domain/user_role.dart';
import 'package:hr_superapp/l10n/app_localizations.dart';

/// RBAC wrapper widget — renders [child] only when the current user holds
/// every required [Capability]; otherwise renders [fallback] (default: nothing).
///
/// ```dart
/// RoleGate(
///   requires: {Capability.runPayroll},
///   child: PayrollDashboardButton(),
/// )
/// ```
///
/// UX-layer guard only: the database RLS re-checks every operation.
class RoleGate extends ConsumerWidget {
  const RoleGate({
    super.key,
    required this.requires,
    required this.child,
    this.fallback,
  });

  final Set<Capability> requires;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user.role.canAll(requires)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Route-level variant: full-screen "not authorized" instead of hiding.
class RoleGateScreen extends ConsumerWidget {
  const RoleGateScreen({
    super.key,
    required this.requires,
    required this.child,
  });

  final Set<Capability> requires;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user.role.canAll(requires)) return child;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.notAuthorized,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

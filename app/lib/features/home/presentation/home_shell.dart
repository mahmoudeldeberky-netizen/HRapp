import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hr_superapp/core/providers/app_settings_providers.dart';
import 'package:hr_superapp/features/auth/application/auth_controller.dart';
import 'package:hr_superapp/features/auth/domain/user_role.dart';
import 'package:hr_superapp/features/auth/presentation/role_gate.dart';
import 'package:hr_superapp/l10n/app_localizations.dart';

/// Role-aware home: each card is wrapped in a [RoleGate], so every role sees
/// exactly the modules its capabilities allow.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.toggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          IconButton(
            tooltip: l10n.toggleLanguage,
            icon: const Icon(Icons.translate),
            onPressed: () => ref.read(localeProvider.notifier).toggle(),
          ),
          if (user.isAuthenticated)
            IconButton(
              tooltip: l10n.signOut,
              icon: const Icon(Icons.logout),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RoleGate(
            requires: const {Capability.managePlatform},
            child: _ModuleCard(
              icon: Icons.admin_panel_settings_outlined,
              title: l10n.modulePlatformAdmin,
            ),
          ),
          RoleGate(
            requires: const {Capability.manageCountryContent},
            child: _ModuleCard(
              icon: Icons.gavel_outlined,
              title: l10n.moduleCountryContent,
            ),
          ),
          RoleGate(
            requires: const {Capability.manageTenant},
            child: _ModuleCard(
              icon: Icons.business_outlined,
              title: l10n.moduleCompanyDashboard,
            ),
          ),
          RoleGate(
            requires: const {Capability.useSelfService},
            child: _ModuleCard(
              icon: Icons.person_outline,
              title: l10n.moduleSelfService,
            ),
          ),
          RoleGate(
            requires: const {Capability.useCvBuilder},
            child: _ModuleCard(
              icon: Icons.description_outlined,
              title: l10n.moduleCvBuilder,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        contentPadding:
            const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 8),
        onTap: () {}, // feature routes attach here as modules ship
      ),
    );
  }
}

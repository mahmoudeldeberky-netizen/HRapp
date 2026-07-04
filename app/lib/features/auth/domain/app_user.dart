import 'package:equatable/equatable.dart';

import 'package:hr_superapp/features/auth/domain/user_role.dart';

/// Authenticated user identity as the domain sees it (pure Dart, no SDK types).
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.role,
    this.tenantId,
    this.countryScope,
    this.email,
    this.fullName,
  });

  final String id;
  final UserRole role;

  /// Company workspace for tenant admins & employees; null for platform roles.
  final String? tenantId;

  /// ISO country code a country admin moderates; null otherwise.
  final String? countryScope;

  final String? email;
  final String? fullName;

  bool can(Capability capability) => role.can(capability);

  static const guest = AppUser(id: '', role: UserRole.guest);

  bool get isAuthenticated => id.isNotEmpty;

  @override
  List<Object?> get props => [id, role, tenantId, countryScope, email, fullName];
}

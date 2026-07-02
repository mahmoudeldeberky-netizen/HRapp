/// Role-Based Access Control — role and capability model.
///
/// Security note: these checks control UX only. The database (RLS) and
/// Edge Functions re-enforce every permission server-side.
enum UserRole {
  superAdmin('super_admin'),
  countryAdmin('country_admin'),
  tenantAdmin('tenant_admin'),
  employee('employee'),
  guest('guest');

  const UserRole(this.wire);

  /// Value as stored in the database / JWT claim.
  final String wire;

  static UserRole fromWire(String? value) => UserRole.values.firstWhere(
        (r) => r.wire == value,
        orElse: () => UserRole.guest,
      );
}

/// Fine-grained capabilities. Screens/actions declare the capability they
/// need instead of hardcoding role names, so the matrix can evolve in one place.
enum Capability {
  // Platform
  managePlatform, // global analytics, subscriptions, feature flags
  manageCountryContent, // upload/publish laws & rule-sets
  // Tenant
  manageTenant, // company settings, employees, policies
  runPayroll,
  manageRecruitment,
  viewTeamDashboards,
  // Self-service
  useSelfService, // attendance, leave requests, payslips, profile
  // Public
  useCvBuilder,
  applyToJobs,
}

const Map<UserRole, Set<Capability>> _matrix = {
  UserRole.superAdmin: {...Capability.values},
  UserRole.countryAdmin: {
    Capability.manageCountryContent,
    Capability.useCvBuilder,
  },
  UserRole.tenantAdmin: {
    Capability.manageTenant,
    Capability.runPayroll,
    Capability.manageRecruitment,
    Capability.viewTeamDashboards,
    Capability.useSelfService,
    Capability.useCvBuilder,
  },
  UserRole.employee: {
    Capability.useSelfService,
    Capability.useCvBuilder,
    Capability.applyToJobs,
  },
  UserRole.guest: {
    Capability.useCvBuilder,
    Capability.applyToJobs,
  },
};

extension UserRoleX on UserRole {
  bool can(Capability capability) => _matrix[this]!.contains(capability);

  bool canAll(Iterable<Capability> capabilities) => capabilities.every(can);
}

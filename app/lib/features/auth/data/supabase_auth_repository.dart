import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hr_superapp/features/auth/domain/app_user.dart';
import 'package:hr_superapp/features/auth/domain/auth_repository.dart';
import 'package:hr_superapp/features/auth/domain/user_role.dart';

/// Supabase implementation. The authoritative role/tenant live in the
/// `profiles` row (mirrored into JWT claims for RLS); we read the profile
/// after every auth state change.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AppUser> watchUser() async* {
    yield await currentUser();
    await for (final state in _client.auth.onAuthStateChange) {
      yield state.session == null ? AppUser.guest : await _loadProfile();
    }
  }

  @override
  Future<AppUser> currentUser() async {
    if (_client.auth.currentSession == null) return AppUser.guest;
    return _loadProfile();
  }

  Future<AppUser> _loadProfile() async {
    final authUser = _client.auth.currentUser!;
    final row = await _client
        .from('profiles')
        .select('role, tenant_id, country_scope, full_name')
        .eq('id', authUser.id)
        .maybeSingle();

    return AppUser(
      id: authUser.id,
      email: authUser.email,
      role: UserRole.fromWire(row?['role'] as String?),
      tenantId: row?['tenant_id'] as String?,
      countryScope: row?['country_scope'] as String?,
      fullName: row?['full_name'] as String?,
    );
  }

  @override
  Future<void> signInWithOtp({required String email}) =>
      _client.auth.signInWithOtp(email: email);

  @override
  Future<AppUser> verifyOtp({required String email, required String token}) async {
    await _client.auth.verifyOTP(email: email, token: token, type: OtpType.email);
    return _loadProfile();
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}

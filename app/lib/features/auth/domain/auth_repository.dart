import 'package:hr_superapp/features/auth/domain/app_user.dart';

/// Domain contract — implemented by the data layer (Supabase), overridable
/// with fakes in tests.
abstract interface class AuthRepository {
  Stream<AppUser> watchUser();

  Future<AppUser> currentUser();

  Future<void> signInWithOtp({required String email});

  Future<AppUser> verifyOtp({required String email, required String token});

  Future<void> signOut();
}

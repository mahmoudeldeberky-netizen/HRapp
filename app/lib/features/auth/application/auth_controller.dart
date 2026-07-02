import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hr_superapp/features/auth/data/supabase_auth_repository.dart';
import 'package:hr_superapp/features/auth/domain/app_user.dart';
import 'package:hr_superapp/features/auth/domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(Supabase.instance.client),
);

/// Reactive current user — the single source of truth for RBAC in the UI.
final authStateProvider = StreamProvider<AppUser>(
  (ref) => ref.watch(authRepositoryProvider).watchUser(),
);

/// Synchronous convenience view (guest while loading).
final currentUserProvider = Provider<AppUser>(
  (ref) => ref.watch(authStateProvider).valueOrNull ?? AppUser.guest,
);

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> requestOtp(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signInWithOtp(email: email));
  }

  Future<void> verifyOtp({required String email, required String token}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.verifyOtp(email: email, token: token),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.signOut);
  }
}

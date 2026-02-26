import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AsyncValue.loading()) {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    try {
      final hasTokens = await _repo.hasTokens();
      if (hasTokens) {
        final user = await _repo.getMe();
        state = AsyncValue.data(user);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    String preferredLocale = 'en',
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.register(
        email: email,
        password: password,
        displayName: displayName,
        preferredLocale: preferredLocale,
      );
      final user = await _repo.getMe();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      await _repo.login(email: email, password: password);
      final user = await _repo.getMe();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncValue.data(null);
  }

  Future<void> refreshUser() async {
    try {
      final user = await _repo.getMe();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

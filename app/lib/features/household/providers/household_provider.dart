import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/household.dart';
import '../repositories/household_repository.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) => HouseholdRepository());

final householdsProvider = FutureProvider<List<Household>>((ref) async {
  // Wait for auth — don't fetch if not logged in
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;
  if (user == null) return [];

  return ref.read(householdRepositoryProvider).getMyHouseholds();
});

/// Wraps the active household with a loading flag so the router
/// can distinguish "still loading" from "no household."
class ActiveHouseholdState {
  final Household? household;
  final bool isLoading;

  const ActiveHouseholdState({this.household, this.isLoading = true});

  ActiveHouseholdState copyWith({Household? household, bool? isLoading}) {
    return ActiveHouseholdState(
      household: household ?? this.household,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final activeHouseholdProvider =
    StateNotifierProvider<ActiveHouseholdNotifier, ActiveHouseholdState>((ref) {
  return ActiveHouseholdNotifier(ref);
});

class ActiveHouseholdNotifier extends StateNotifier<ActiveHouseholdState> {
  final Ref _ref;

  ActiveHouseholdNotifier(this._ref) : super(const ActiveHouseholdState(isLoading: true)) {
    // Listen for auth changes — reload when user logs in
    _ref.listen(authStateProvider, (prev, next) {
      final user = next.valueOrNull;
      if (user != null && (prev?.valueOrNull == null || prev?.isLoading == true)) {
        _loadActive();
      } else if (user == null) {
        state = const ActiveHouseholdState(household: null, isLoading: false);
      }
    });
  }

  Future<void> _loadActive() async {
    state = const ActiveHouseholdState(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(AppConstants.keyActiveHouseholdId);

      final households = await _ref.read(householdsProvider.future);
      if (households.isEmpty) {
        state = const ActiveHouseholdState(household: null, isLoading: false);
        return;
      }

      if (savedId != null) {
        final match = households.where((h) => h.id == savedId);
        state = ActiveHouseholdState(
          household: match.isNotEmpty ? match.first : households.first,
          isLoading: false,
        );
      } else {
        state = ActiveHouseholdState(
          household: households.first,
          isLoading: false,
        );
      }
    } catch (_) {
      state = const ActiveHouseholdState(household: null, isLoading: false);
    }
  }

  Future<void> setActive(Household household) async {
    state = ActiveHouseholdState(household: household, isLoading: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyActiveHouseholdId, household.id);
  }

  Future<void> refresh() async {
    _ref.invalidate(householdsProvider);
    await _loadActive();
  }
}

final membersProvider = FutureProvider.family<List<HouseholdMember>, String>((ref, householdId) async {
  return ref.read(householdRepositoryProvider).getMembers(householdId);
});

/// Provides the current user's HouseholdMember for the active household.
/// Used for permission checks (canManage, isAdmin, role).
final currentMemberProvider = FutureProvider<HouseholdMember?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;
  if (user == null) return null;

  final householdState = ref.watch(activeHouseholdProvider);
  final household = householdState.household;
  if (household == null) return null;

  final members = await ref.watch(membersProvider(household.id).future);
  try {
    return members.firstWhere((m) => m.userId == user.id);
  } catch (_) {
    return null;
  }
});

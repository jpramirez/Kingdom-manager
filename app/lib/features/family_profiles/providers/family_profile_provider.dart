import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_profile.dart';
import '../repositories/family_profile_repository.dart';

final familyProfileRepositoryProvider =
    Provider<FamilyProfileRepository>((ref) => FamilyProfileRepository());

final familyProfilesProvider =
    FutureProvider.family<List<FamilyProfile>, String>(
        (ref, householdId) async {
  return ref.read(familyProfileRepositoryProvider).getFamily(householdId);
});

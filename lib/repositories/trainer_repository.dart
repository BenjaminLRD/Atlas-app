import '../data/local_storage.dart';
import '../models/app_user.dart';
import '../models/coach_note.dart';
import '../models/gym.dart';
import '../models/trainer_profile.dart';

/// Abstract contract for gym, trainer profile, assignment, and coach note operations.
abstract class TrainerRepository {
  Future<Gym> getGymDetails(String gymId);
  Future<TrainerProfile> getTrainerProfile(String trainerId);
  Future<List<TrainerProfile>> getGymTrainers(String gymId);
  Future<List<AppUser>> getAssignedMembers(String trainerId);
  Future<TrainerProfile> assignMember({
    required String trainerId,
    required String memberId,
  });
  Future<TrainerProfile> removeMemberAssignment({
    required String trainerId,
    required String memberId,
  });
  Future<List<CoachNote>> getMemberCoachNotes({required String memberId});
  Future<CoachNote> addCoachNote(CoachNote note);
}

/// Local-first implementation of [TrainerRepository] backed by LocalStorage and mock data.
class LocalTrainerRepository implements TrainerRepository {
  const LocalTrainerRepository();

  @override
  Future<Gym> getGymDetails(String gymId) async {
    return LocalStorage.getGym();
  }

  @override
  Future<TrainerProfile> getTrainerProfile(String trainerId) async {
    return LocalStorage.getTrainerProfile();
  }

  @override
  Future<List<TrainerProfile>> getGymTrainers(String gymId) async {
    return [
      LocalStorage.getTrainerProfile(),
      TrainerProfile(
        id: 'tp_02',
        userId: 'usr_trainer_02',
        gymId: gymId,
        displayName: 'Coach Vanlalruata',
        specializations: const ['Cardio & Endurnace', 'Functional Fitness'],
        assignedMemberIds: const ['usr_m_04', 'usr_m_05'],
        bio: 'Functional fitness specialist focused on stamina and VO2 max training.',
        rating: 4.8,
        yearsExperience: 6,
        createdAt: DateTime(2024, 2, 1),
      ),
    ];
  }

  @override
  Future<List<AppUser>> getAssignedMembers(String trainerId) async {
    final profile = await getTrainerProfile(trainerId);
    final now = DateTime.now();

    final allMockMembers = [
      AppUser(
        id: 'usr_local',
        email: 'zothana@aizawlgym.com',
        displayName: 'Zothanmawia (You)',
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
      ),
      AppUser(
        id: 'usr_m_01',
        email: 'lalhruaia@gmail.com',
        displayName: 'Lalhruaia Varte',
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now,
      ),
      AppUser(
        id: 'usr_m_02',
        email: 'vaneisanga@gmail.com',
        displayName: 'Vaneisanga Sailo',
        createdAt: now.subtract(const Duration(days: 45)),
        updatedAt: now,
      ),
      AppUser(
        id: 'usr_m_03',
        email: 'remruati@gmail.com',
        displayName: 'Remruati Ralte',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
      ),
    ];

    return allMockMembers
        .where((m) => profile.assignedMemberIds.contains(m.id))
        .toList();
  }

  @override
  Future<TrainerProfile> assignMember({
    required String trainerId,
    required String memberId,
  }) async {
    final profile = await getTrainerProfile(trainerId);
    if (!profile.assignedMemberIds.contains(memberId)) {
      final updatedIds = List<String>.from(profile.assignedMemberIds)..add(memberId);
      final updated = profile.copyWith(assignedMemberIds: updatedIds);
      await LocalStorage.saveTrainerProfile(updated);
      return updated;
    }
    return profile;
  }

  @override
  Future<TrainerProfile> removeMemberAssignment({
    required String trainerId,
    required String memberId,
  }) async {
    final profile = await getTrainerProfile(trainerId);
    final updatedIds = List<String>.from(profile.assignedMemberIds)..remove(memberId);
    final updated = profile.copyWith(assignedMemberIds: updatedIds);
    await LocalStorage.saveTrainerProfile(updated);
    return updated;
  }

  @override
  Future<List<CoachNote>> getMemberCoachNotes({required String memberId}) async {
    return LocalStorage.getCoachNotes(memberId: memberId);
  }

  @override
  Future<CoachNote> addCoachNote(CoachNote note) async {
    await LocalStorage.saveCoachNote(note);
    return note;
  }
}

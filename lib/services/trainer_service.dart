import '../models/app_user.dart';
import '../models/coach_note.dart';
import '../models/gym.dart';
import '../models/trainer_profile.dart';
import '../repositories/trainer_repository.dart';

/// Business service managing trainer profiles, gym memberships, member assignments, and coach notes.
class TrainerService {
  final TrainerRepository repository;

  const TrainerService({
    this.repository = const LocalTrainerRepository(),
  });

  /// Fetches gym details.
  Future<Gym> getGymDetails({String gymId = 'gym_aizawl_01'}) async {
    return repository.getGymDetails(gymId);
  }

  /// Fetches trainer profile for active coach.
  Future<TrainerProfile> getTrainerProfile({String trainerId = 'tp_01'}) async {
    return repository.getTrainerProfile(trainerId);
  }

  /// Fetches all active gym trainers.
  Future<List<TrainerProfile>> getGymTrainers({String gymId = 'gym_aizawl_01'}) async {
    return repository.getGymTrainers(gymId);
  }

  /// Fetches list of member AppUsers assigned to a trainer.
  Future<List<AppUser>> getAssignedMembers({String trainerId = 'tp_01'}) async {
    return repository.getAssignedMembers(trainerId);
  }

  /// Assigns a gym member to a trainer profile.
  Future<TrainerProfile> assignMember({
    required String trainerId,
    required String memberId,
  }) async {
    return repository.assignMember(trainerId: trainerId, memberId: memberId);
  }

  /// Removes a member assignment from a trainer.
  Future<TrainerProfile> removeMemberAssignment({
    required String trainerId,
    required String memberId,
  }) async {
    return repository.removeMemberAssignment(
      trainerId: trainerId,
      memberId: memberId,
    );
  }

  /// Fetches coach notes recorded for a member.
  Future<List<CoachNote>> getMemberCoachNotes({required String memberId}) async {
    return repository.getMemberCoachNotes(memberId: memberId);
  }

  /// Adds a new coach note for a member.
  Future<CoachNote> addCoachNote({
    required String trainerId,
    required String memberId,
    required String noteText,
    String category = 'general',
  }) async {
    final note = CoachNote(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      trainerId: trainerId,
      memberId: memberId,
      noteText: noteText,
      category: category,
      createdAt: DateTime.now(),
    );
    return repository.addCoachNote(note);
  }
}

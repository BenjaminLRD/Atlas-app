import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/coach_note.dart';
import 'package:aizawl_gym/models/gym.dart';
import 'package:aizawl_gym/models/trainer_profile.dart';
import 'package:aizawl_gym/models/user_role.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';
import 'package:aizawl_gym/repositories/trainer_repository.dart';
import 'package:aizawl_gym/services/ai/trainer_ai_assistant.dart';
import 'package:aizawl_gym/services/trainer_service.dart';
import 'package:aizawl_gym/services/supabase/supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('UserRole Enum Tests', () {
    test('UserRole properties and parsing', () {
      expect(UserRole.member.isMember, isTrue);
      expect(UserRole.trainer.isTrainer, isTrue);
      expect(UserRole.admin.isAdmin, isTrue);

      expect(UserRoleExtension.fromString('trainer'), equals(UserRole.trainer));
      expect(UserRoleExtension.fromString('admin'), equals(UserRole.admin));
      expect(UserRoleExtension.fromString('member'), equals(UserRole.member));
    });
  });

  group('Gym and Trainer Models Unit Tests', () {
    test('Gym default instance and JSON serialization', () {
      final gym = Gym.defaultGym();
      expect(gym.name, equals('Aizawl Gym Main Hub'));
      expect(gym.memberCount, equals(248));

      final json = gym.toJson();
      expect(json['name'], equals('Aizawl Gym Main Hub'));

      final parsed = Gym.fromJson(json);
      expect(parsed.name, equals('Aizawl Gym Main Hub'));
    });

    test('TrainerProfile default instance and JSON serialization', () {
      final profile = TrainerProfile.defaultTrainer();
      expect(profile.displayName, equals('Coach Lalthanmawia'));
      expect(profile.rating, equals(4.95));

      final json = profile.toJson();
      expect(json['displayName'], equals('Coach Lalthanmawia'));

      final parsed = TrainerProfile.fromJson(json);
      expect(parsed.displayName, equals('Coach Lalthanmawia'));
    });

    test('CoachNote model creation and JSON serialization', () {
      final note = CoachNote(
        id: 'note_test_1',
        trainerId: 'tp_01',
        memberId: 'usr_local',
        noteText: 'Focus on progressive overload on bench press.',
        category: 'training',
        createdAt: DateTime.now(),
      );

      final json = note.toJson();
      expect(json['category'], equals('training'));

      final parsed = CoachNote.fromJson(json);
      expect(parsed.noteText, equals('Focus on progressive overload on bench press.'));
    });
  });

  group('LocalTrainerRepository Unit Tests', () {
    test('getGymDetails and getTrainerProfile return valid default data', () async {
      const repo = LocalTrainerRepository();
      final gym = await repo.getGymDetails('gym_aizawl_01');
      final trainer = await repo.getTrainerProfile('tp_01');

      expect(gym.name, contains('Aizawl Gym'));
      expect(trainer.displayName, contains('Coach'));
    });

    test('assignMember and removeMemberAssignment update assigned list', () async {
      const repo = LocalTrainerRepository();
      final updated = await repo.assignMember(trainerId: 'tp_01', memberId: 'usr_new_99');
      expect(updated.assignedMemberIds, contains('usr_new_99'));

      final removed = await repo.removeMemberAssignment(trainerId: 'tp_01', memberId: 'usr_new_99');
      expect(removed.assignedMemberIds.contains('usr_new_99'), isFalse);
    });

    test('addCoachNote persists and retrieves note', () async {
      const repo = LocalTrainerRepository();
      final note = CoachNote(
        id: 'note_unit_01',
        trainerId: 'tp_01',
        memberId: 'usr_local',
        noteText: 'Unit test coach note text.',
        category: 'nutrition',
        createdAt: DateTime.now(),
      );

      await repo.addCoachNote(note);
      final notes = await repo.getMemberCoachNotes(memberId: 'usr_local');
      expect(notes.any((n) => n.noteText.contains('Unit test coach note text.')), isTrue);
    });
  });

  group('TrainerService Unit Tests', () {
    test('TrainerService fetches gym, profile, and assigned members', () async {
      const service = TrainerService();
      final gym = await service.getGymDetails();
      final profile = await service.getTrainerProfile();
      final members = await service.getAssignedMembers();

      expect(gym.name, isNotEmpty);
      expect(profile.displayName, isNotEmpty);
      expect(members.isNotEmpty, isTrue);
    });
  });

  group('TrainerAIAssistant Unit Tests', () {
    test('generateMemberSummary evaluates context snapshot', () {
      final provider = FitnessProvider.instance;
      final contextSnapshot = provider.buildFitnessContext();
      const assistant = TrainerAIAssistant();

      final summary = assistant.generateMemberSummary(
        context: contextSnapshot,
        memberName: 'Zothanmawia',
      );

      expect(summary.memberName, equals('Zothanmawia'));
      expect(summary.readinessStatus, isNotEmpty);
      expect(summary.keyInsights.length, greaterThanOrEqualTo(3));
      expect(summary.summaryText, contains('Zothanmawia'));
    });
  });

  group('FitnessProvider Trainer Integration Tests', () {
    test('setUserRole updates role and triggers trainer data loading', () async {
      final provider = FitnessProvider.instance;
      expect(provider.userRole, equals(UserRole.member));
      expect(provider.isTrainer, isFalse);

      await provider.setUserRole(UserRole.trainer);
      expect(provider.userRole, equals(UserRole.trainer));
      expect(provider.isTrainer, isTrue);
      expect(provider.activeGym, isNotNull);
      expect(provider.activeTrainerProfile, isNotNull);
      expect(provider.assignedMembers.length, greaterThanOrEqualTo(1));
    });

    test('addCoachNote and assignMemberToTrainer update provider state', () async {
      final provider = FitnessProvider.instance;
      await provider.setUserRole(UserRole.trainer);

      final initialCount = provider.assignedMembers.length;
      await provider.assignMemberToTrainer('usr_m_01');
      expect(provider.assignedMembers.length, greaterThanOrEqualTo(initialCount));

      final note = await provider.addCoachNote(
        memberId: 'usr_local',
        noteText: 'Provider note test.',
        category: 'general',
      );

      expect(note.noteText, equals('Provider note test.'));
      final notes = await provider.getMemberCoachNotes('usr_local');
      expect(notes.any((n) => n.noteText == 'Provider note test.'), isTrue);
    });
  });
}

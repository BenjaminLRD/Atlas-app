import '../data/local_storage.dart';
import '../models/equipment.dart';
import '../models/user_equipment_profile.dart';

/// Abstract contract for equipment profile retrieval, storage, and catalog querying.
abstract class EquipmentRepository {
  Future<UserEquipmentProfile> getProfile({String userId = 'local_user'});
  Future<void> saveProfile(UserEquipmentProfile profile);
  List<Equipment> getAllEquipment();
  List<Equipment> getEquipmentByCategory(EquipmentCategory category);
  Future<void> resetToFullGym({String userId = 'local_user'});
}

/// Production implementation of [EquipmentRepository] backed by local persistent storage.
class LocalEquipmentRepository implements EquipmentRepository {
  const LocalEquipmentRepository();

  @override
  Future<UserEquipmentProfile> getProfile({
    String userId = 'local_user',
  }) async {
    return LocalStorage.getUserEquipmentProfile();
  }

  @override
  Future<void> saveProfile(UserEquipmentProfile profile) async {
    await LocalStorage.saveUserEquipmentProfile(profile);
  }

  @override
  List<Equipment> getAllEquipment() {
    return Equipment.masterCatalog();
  }

  @override
  List<Equipment> getEquipmentByCategory(EquipmentCategory category) {
    return Equipment.masterCatalog()
        .where((e) => e.category == category)
        .toList();
  }

  @override
  Future<void> resetToFullGym({String userId = 'local_user'}) async {
    final fullGym = UserEquipmentProfile.fullCommercialGym(userId: userId);
    await LocalStorage.saveUserEquipmentProfile(fullGym);
  }
}

import '../data/local_storage.dart';
import '../models/subscription.dart';

/// Abstract repository defining data contract for user subscription operations.
abstract class SubscriptionRepository {
  Future<Subscription> getSubscription({String? userId});
  Future<void> saveSubscription(Subscription subscription);
  Future<void> clearSubscription();
}

/// Local-first implementation of [SubscriptionRepository] backed by LocalStorage.
class LocalSubscriptionRepository implements SubscriptionRepository {
  const LocalSubscriptionRepository();

  @override
  Future<Subscription> getSubscription({String? userId}) async {
    return LocalStorage.getSubscription(userId: userId ?? 'usr_local');
  }

  @override
  Future<void> saveSubscription(Subscription subscription) async {
    await LocalStorage.saveSubscription(subscription);
  }

  @override
  Future<void> clearSubscription() async {
    await LocalStorage.clearSubscription();
  }
}

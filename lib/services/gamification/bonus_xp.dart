import '../../data/local_storage.dart';
import '../cloud/cloud_session.dart';
import 'xp_service.dart';

/// Awards [amount] bonus XP to the athlete.
typedef XpAwarder = Future<void> Function(int amount);

/// The XP was not given because the signed-in account could not be
/// determined, so it could not be given to the right athlete.
class XpIdentityException implements Exception {
  const XpIdentityException(this.message);

  final String message;

  @override
  String toString() => 'XpIdentityException: $message';
}

/// Where services that give bonus XP (referrals, friend challenges) send it,
/// without knowing about the app-level state.
///
/// By default the XP is saved straight to the athlete's XP and progress
/// through [XPService], to the account from [currentUserId], so an award is
/// never lost when no screen state exists.
/// The app state (`FitnessProvider`) replaces [awarder] with its own `addXP`,
/// which saves the same way and also refreshes what is on screen; it puts the
/// default back when it is disposed.
class BonusXp {
  const BonusXp._();

  /// The id used when nobody is signed in, the same fallback the app state
  /// uses.
  static const String defaultUserId = 'usr_local';

  /// The athlete bonus XP belongs to: the account stored by sign-in (the same
  /// one the app state works with), or [defaultUserId] when nobody is signed in.
  ///
  /// If a cloud account is signed in but it is not the stored one (or none is
  /// stored), the right athlete cannot be told and this throws
  /// [XpIdentityException] instead of guessing.
  static String currentUserId() {
    final stored = LocalStorage.getAppUser()?.id;
    final signedIn = CloudSession.userId;
    if (signedIn != null && stored != signedIn) {
      throw const XpIdentityException(
        'the signed-in account does not match the stored account',
      );
    }
    return stored ?? defaultUserId;
  }

  /// Source label stored with these awards.
  static const String source = 'manual_bonus';

  /// Saves the XP without refreshing any screen state.
  static Future<void> saveOnly(int amount) async {
    await XPService.instance.awardXP(
      userId: currentUserId(),
      amount: amount,
      source: source,
    );
  }

  /// What services call. Replaced by the app state while it is alive.
  static XpAwarder awarder = saveOnly;
}

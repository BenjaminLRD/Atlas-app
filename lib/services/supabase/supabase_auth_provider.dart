import 'dart:async';
import '../../models/app_user.dart';
import '../auth/auth_provider.dart';
import 'supabase_client.dart';

/// Supabase implementation of [AuthProvider] managing authentication sessions
/// and mapping Supabase user payload responses into [AppUser] domain models.
class SupabaseAuthProvider implements AuthProvider {
  final SupabaseClientManager _clientManager;
  final StreamController<AppUser?> _authStreamController =
      StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  SupabaseAuthProvider({SupabaseClientManager? clientManager})
      : _clientManager = clientManager ?? SupabaseClientManager.instance;

  @override
  Stream<AppUser?> get authStateChanges => _authStreamController.stream;

  @override
  Future<AppUser?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<bool> isAuthenticated() async {
    return _currentUser != null;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw const FormatException('Email and password must not be empty.');
    }

    final query = _clientManager.from('users');
    final existing = await query.select('email', email);

    Map<String, dynamic> userRecord;
    if (existing.isNotEmpty) {
      userRecord = existing.first;
    } else {
      userRecord = {
        'id': 'sp_usr_${DateTime.now().millisecondsSinceEpoch}',
        'email': email,
        'user_metadata': {
          'display_name': email.split('@')[0],
        },
        'created_at': DateTime.now().toIso8601String(),
      };
      await query.insert(userRecord);
    }

    final appUser = mapSupabaseUserToAppUser(userRecord);
    _currentUser = appUser;
    _authStreamController.add(appUser);
    return appUser;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw const FormatException('Email and password must not be empty.');
    }

    final userRecord = {
      'id': 'sp_usr_${DateTime.now().millisecondsSinceEpoch}',
      'email': email,
      'user_metadata': {
        'display_name': displayName ?? email.split('@')[0],
      },
      'created_at': DateTime.now().toIso8601String(),
    };

    await _clientManager.from('users').insert(userRecord);

    final appUser = mapSupabaseUserToAppUser(userRecord);
    _currentUser = appUser;
    _authStreamController.add(appUser);
    return appUser;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStreamController.add(null);
  }

  /// Map Supabase user payload map into an [AppUser] domain model.
  static AppUser mapSupabaseUserToAppUser(Map<String, dynamic> userMap) {
    final meta = userMap['user_metadata'] as Map<String, dynamic>? ?? {};
    final email = userMap['email'] as String? ?? '';
    final id = userMap['id'] as String? ?? 'sp_${email.hashCode}';
    final displayName = meta['display_name'] as String? ??
        (email.contains('@') ? email.split('@')[0] : 'Gym Member');
    final profileImageUrl = meta['avatar_url'] as String?;
    final createdAtStr = userMap['created_at'] as String?;
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
        : DateTime.now();

    return AppUser(
      id: id,
      email: email,
      displayName: displayName,
      profileImageUrl: profileImageUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  void dispose() {
    _authStreamController.close();
  }
}

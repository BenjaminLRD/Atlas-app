import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/local_storage.dart';
import '../models/app_user.dart';
import '../models/user_profile.dart';
import '../services/auth/auth_service.dart';

/// Explicit authentication lifecycle states
enum AuthStatus { unauthenticated, loading, authenticated, error }

/// Flutter [ChangeNotifier] managing live authentication lifecycle, current active user identity,
/// profile state, credential validation, and reactive UI broadcasting.
class AppAuthProvider extends ChangeNotifier {
  static AppAuthProvider? _instance;
  final AuthService _authService;

  AuthStatus _status = AuthStatus.unauthenticated;
  AppUser? _currentUser;
  UserProfile? _currentProfile;
  String? _errorMessage;
  StreamSubscription<AppUser?>? _authSubscription;

  AppAuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService.instance {
    _init();
  }

  /// Global singleton accessor
  static AppAuthProvider get instance => _instance ??= AppAuthProvider();

  /// Custom singleton injector (useful for testing)
  static void setInstance(AppAuthProvider provider) {
    _instance = provider;
  }

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  String? get userId => _currentUser?.id;
  UserProfile? get currentProfile =>
      _currentProfile ?? LocalStorage.getUserProfile();
  UserProfile? get profile => currentProfile;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _currentUser != null;
  bool get isLoggedIn => isAuthenticated;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isUnauthenticated => _status == AuthStatus.unauthenticated;

  void _init() {
    _authSubscription = _authService.authStateChanges.listen((user) {
      if (user != null) {
        _currentUser = user;
        _currentProfile = LocalStorage.getUserProfile();
        _status = AuthStatus.authenticated;
        _errorMessage = null;
      } else {
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    });

    // Check cached session on startup
    final cachedUser = _authService.currentUser;
    if (cachedUser != null) {
      _currentUser = cachedUser;
      _currentProfile = LocalStorage.getUserProfile();
      _status = AuthStatus.authenticated;
    }
  }

  /// Restores active session from secure storage or local disk
  Future<AppUser?> restoreSession() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.restoreSession();
      if (user != null) {
        _currentUser = user;
        _currentProfile = LocalStorage.getUserProfile();
        _status = AuthStatus.authenticated;
        _errorMessage = null;
      } else {
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
      return user;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Registers a new user account with email, password, and optional profile metadata
  Future<bool> register({
    required String email,
    required String password,
    String? username,
    String? displayName,
    UserProfile? initialProfile,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final name = displayName ?? username;
      final user = await _authService.signUp(
        email: email.trim(),
        password: password,
        displayName: name,
      );

      _currentUser = user;
      if (initialProfile != null) {
        initialProfile.userId = user.id;
        initialProfile.email = user.email;
        if (name != null && name.isNotEmpty && initialProfile.name.isEmpty) {
          initialProfile.name = name;
        }
        await LocalStorage.saveUserProfile(initialProfile);
        _currentProfile = initialProfile;
      } else {
        final defaultProf = UserProfile.defaultProfile(email: user.email);
        defaultProf.userId = user.id;
        if (name != null && name.isNotEmpty) {
          defaultProf.name = name;
        }
        await LocalStorage.saveUserProfile(defaultProf);
        _currentProfile = defaultProf;
      }

      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e is FormatException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Authenticates an existing user account with email and password credentials
  Future<bool> login({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signIn(
        email: email.trim(),
        password: password,
      );

      _currentUser = user;
      _currentProfile = LocalStorage.getUserProfile();
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e is FormatException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Terminates current authenticated user session and purges local credentials
  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authService.signOut();
    } finally {
      _currentUser = null;
      _currentProfile = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Requests a password reset link for the specified email address
  Future<bool> resetPassword(String email) async {
    _errorMessage = null;
    try {
      await _authService.resetPassword(email: email.trim());
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e is FormatException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Alias for register()
  Future<bool> signUp({
    required String email,
    required String password,
    String? username,
    String? displayName,
    UserProfile? initialProfile,
  }) => register(
    email: email,
    password: password,
    username: username,
    displayName: displayName,
    initialProfile: initialProfile,
  );

  /// Alias for login()
  Future<bool> signIn({required String email, required String password}) =>
      login(email: email, password: password);

  /// Alias for logout()
  Future<void> signOut() => logout();

  /// Updates and persists the athlete's user profile
  Future<void> updateProfile(UserProfile updatedProfile) async {
    if (_currentUser != null) {
      updatedProfile.userId = _currentUser!.id;
    }
    await LocalStorage.saveUserProfile(updatedProfile);
    _currentProfile = updatedProfile;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

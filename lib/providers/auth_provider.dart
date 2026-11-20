import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/local_storage.dart';
import '../models/app_user.dart';
import '../models/user_profile.dart';
import '../services/auth/auth_service.dart';

/// Sealed authentication states representing current session status.
abstract class AuthenticationState {
  const AuthenticationState();
}

/// State indicating an active authentication or session restore operation in progress.
class AuthenticationLoading extends AuthenticationState {
  const AuthenticationLoading();
}

/// State indicating an active authenticated session for [user].
class Authenticated extends AuthenticationState {
  final AppUser user;
  const Authenticated(this.user);
}

/// State indicating no active session exists or authentication failed.
class Unauthenticated extends AuthenticationState {
  final String? reason;
  const Unauthenticated([this.reason]);
}

/// Flutter [ChangeNotifier] managing live authentication lifecycle, current active user identity,
/// profile state, credential validation, and reactive UI broadcasting.
class AuthProvider extends ChangeNotifier {
  static AuthProvider? _instance;
  final AuthService _authService;

  AuthenticationState _state = const Unauthenticated();
  AppUser? _currentUser;
  UserProfile? _currentProfile;
  String? _errorMessage;
  StreamSubscription<AppUser?>? _authSubscription;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService.instance {
    _init();
  }

  /// Global singleton accessor
  static AuthProvider get instance => _instance ??= AuthProvider();

  /// Custom singleton injector (useful for testing)
  static void setInstance(AuthProvider provider) {
    _instance = provider;
  }

  static void resetInstance() {
    _instance = null;
  }

  AuthenticationState get state => _state;
  AppUser? get currentUser => _currentUser;
  String? get userId => _currentUser?.id;
  String? get email => _currentUser?.email;
  UserProfile? get currentProfile =>
      _currentProfile ?? LocalStorage.getUserProfile();
  UserProfile? get profile => currentProfile;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _state is Authenticated && _currentUser != null;
  bool get isLoggedIn => isAuthenticated;
  bool get isLoading => _state is AuthenticationLoading;
  bool get isUnauthenticated => _state is Unauthenticated;

  void _init() {
    _authSubscription = _authService.authStateChanges.listen((user) {
      if (user != null) {
        _currentUser = user;
        _currentProfile = LocalStorage.getUserProfile();
        _state = Authenticated(user);
        _errorMessage = null;
      } else {
        _currentUser = null;
        _state = const Unauthenticated();
      }
      notifyListeners();
    });

    // Check cached session on startup
    final cachedUser = _authService.currentUser;
    if (cachedUser != null) {
      _currentUser = cachedUser;
      _currentProfile = LocalStorage.getUserProfile();
      _state = Authenticated(cachedUser);
    }
  }

  /// Restores active session from secure storage or local disk
  Future<AppUser?> restoreSession() async {
    _state = const AuthenticationLoading();
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.restoreSession();
      if (user != null) {
        _currentUser = user;
        _currentProfile = LocalStorage.getUserProfile();
        _state = Authenticated(user);
        _errorMessage = null;
      } else {
        _currentUser = null;
        _state = const Unauthenticated();
      }
      notifyListeners();
      return user;
    } catch (e) {
      _state = Unauthenticated(e.toString());
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Registers a new user account with email, password, and optional profile metadata
  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
    String? username,
    UserProfile? initialProfile,
  }) async {
    _state = const AuthenticationLoading();
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

      _state = Authenticated(user);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _state = Unauthenticated(e.toString());
      _errorMessage = e is FormatException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Authenticates user with email and password credentials
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _state = const AuthenticationLoading();
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signIn(
        email: email.trim(),
        password: password,
      );

      _currentUser = user;
      _currentProfile = LocalStorage.getUserProfile();
      _state = Authenticated(user);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _state = Unauthenticated(e.toString());
      _errorMessage = e is FormatException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Signs out active user and clears cached session
  Future<void> signOut() async {
    _state = const AuthenticationLoading();
    notifyListeners();

    await _authService.signOut();
    _currentUser = null;
    _currentProfile = null;
    _state = const Unauthenticated();
    _errorMessage = null;
    notifyListeners();
  }

  /// Dispatches password reset email
  Future<void> resetPassword({required String email}) async {
    await _authService.resetPassword(email: email);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

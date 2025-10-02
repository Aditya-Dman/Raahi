import 'supabase_auth_service.dart';
import 'login_persistence.dart';

// Updated User session management with Supabase support
class UserSession {
  static AppUser? _currentUser;
  static final SupabaseAuthService _authService = SupabaseAuthService();

  // Initialize session on app start - check for saved login
  static Future<void> initialize() async {
    // First try to get user from Supabase session
    _currentUser = await _authService.getSavedUserSession();

    // If no Supabase session, check for locally saved login data
    if (_currentUser == null) {
      final isLoggedIn = await LoginPersistence.isLoggedIn();
      if (isLoggedIn) {
        final userData = await LoginPersistence.getSavedUserData();
        if (userData != null) {
          // Create a user object from saved data
          _currentUser = AppUser(
            id: userData['email'] ?? '', // Use email as ID for simplicity
            fullName: userData['fullName'] ?? '',
            email: userData['email'] ?? '',
            userType: userData['userType'] ?? 'Tourist',
            nationality: userData['nationality'] ?? '',
            digitalId: userData['digitalId'] ?? '',
            createdAt: DateTime.now(),
          );
        }
      }
    }
  }

  static void setCurrentUser(AppUser user) {
    _currentUser = user;
    // Save login data for persistence
    LoginPersistence.saveUserLogin(
      fullName: user.fullName,
      email: user.email,
      userType: user.userType,
      nationality: user.nationality,
      digitalId: user.digitalId,
    );
  }

  static AppUser? getCurrentUser() {
    return _currentUser;
  }

  static Future<void> logout() async {
    await _authService.signOut();
    await LoginPersistence.clearLoginData(); // Clear persistent login data
    _currentUser = null;
  }

  static bool isLoggedIn() {
    return _currentUser != null && _authService.isAuthenticated;
  }

  static String getUserName() {
    return _currentUser?.fullName ?? 'Guest User';
  }

  static String getUserEmail() {
    return _currentUser?.email ?? '';
  }

  static String getUserType() {
    return _currentUser?.userType ?? 'Tourist';
  }

  static String getNationality() {
    return _currentUser?.nationality ?? 'Unknown';
  }

  static String getDigitalId() {
    return _currentUser?.digitalId ?? '0000000000';
  }

  static String getUserId() {
    return _currentUser?.id ?? '';
  }

  // Refresh user data from Supabase
  static Future<void> refreshUserData() async {
    if (_authService.isAuthenticated) {
      _currentUser = await _authService.getCurrentUser();
    }
  }

  // Update user profile information
  static Future<void> updateUserProfile({
    String? fullName,
    String? userType,
    String? nationality,
  }) async {
    if (_currentUser != null) {
      _currentUser = AppUser(
        id: _currentUser!.id,
        fullName: fullName ?? _currentUser!.fullName,
        email: _currentUser!.email,
        userType: userType ?? _currentUser!.userType,
        nationality: nationality ?? _currentUser!.nationality,
        digitalId: _currentUser!.digitalId,
        createdAt: _currentUser!.createdAt,
      );

      // Update persistence storage
      await LoginPersistence.updateUserData(
        fullName: fullName,
        userType: userType,
        nationality: nationality,
      );
    }
  }

  // Create admin user session (for testing/demo purposes)
  static void setAdminUser() {
    final adminUser = AppUser(
      id: 'admin-user-id',
      fullName: 'Admin User',
      email: 'admin@raahi.com',
      userType: 'Administrator',
      nationality: 'System',
      digitalId: 'ADMIN001',
      createdAt: DateTime.now(),
    );
    setCurrentUser(adminUser);
  }
}

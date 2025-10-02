import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String userType;
  final String nationality;
  final String digitalId;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.userType,
    required this.nationality,
    required this.digitalId,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? '',
      email: map['email'] ?? '',
      userType: map['user_type'] ?? '',
      nationality: map['nationality'] ?? '',
      digitalId: map['digital_id'] ?? '',
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'user_type': userType,
      'nationality': nationality,
      'digital_id': digitalId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class SupabaseAuthService {
  static final SupabaseAuthService _instance = SupabaseAuthService._internal();
  factory SupabaseAuthService() => _instance;
  SupabaseAuthService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  // Sign up new user
  Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String password,
    required String userType,
    required String nationality,
    required String digitalId,
  }) async {
    try {
      // Create auth user
      final authResponse = await _supabaseService.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'user_type': userType,
          'nationality': nationality,
          'digital_id': digitalId,
        },
      );

      if (authResponse.user != null) {
        // Insert user profile data
        await _supabaseService.insert('user_profiles', {
          'id': authResponse.user!.id,
          'full_name': fullName,
          'email': email,
          'user_type': userType,
          'nationality': nationality,
          'digital_id': digitalId,
          'created_at': DateTime.now().toIso8601String(),
        });

        return {'success': true, 'message': 'Account created successfully!'};
      } else {
        return {'success': false, 'message': 'Failed to create account'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Sign in user
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final authResponse = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        // Get user profile
        var userProfile = await getUserProfile(authResponse.user!.id);

        // If profile doesn't exist, create it from auth metadata
        if (userProfile == null) {
          await _createProfileFromAuthUser(authResponse.user!);
          userProfile = await getUserProfile(authResponse.user!.id);
        }

        if (userProfile != null) {
          await _saveUserSession(userProfile);
          return {'success': true, 'user': userProfile};
        } else {
          return {'success': false, 'message': 'Failed to create user profile'};
        }
      } else {
        return {'success': false, 'message': 'Invalid credentials'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Sign out user
  Future<void> signOut() async {
    await _supabaseService.signOut();
    await _clearUserSession();
  }

  // Get user profile from database
  Future<AppUser?> getUserProfile(String userId) async {
    try {
      final response = await _supabaseService.selectWhere(
        'user_profiles',
        'id',
        userId,
      );
      if (response.isNotEmpty) {
        return AppUser.fromMap(response.first);
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Get current user
  Future<AppUser?> getCurrentUser() async {
    final user = _supabaseService.currentUser;
    if (user != null) {
      return await getUserProfile(user.id);
    }
    return null;
  }

  // Check if user is authenticated
  bool get isAuthenticated => _supabaseService.isAuthenticated;

  // Create profile from auth user metadata
  Future<void> _createProfileFromAuthUser(User authUser) async {
    try {
      final metadata = authUser.userMetadata ?? {};
      await _supabaseService.insert('user_profiles', {
        'id': authUser.id,
        'full_name': metadata['full_name'] ?? 'User',
        'email': authUser.email ?? '',
        'user_type': metadata['user_type'] ?? 'Tourist',
        'nationality': metadata['nationality'] ?? 'Unknown',
        'digital_id': metadata['digital_id'] ?? _generateDigitalId(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error creating profile from auth user: $e');
    }
  }

  // Generate a digital ID (10 digits)
  String _generateDigitalId() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    return timestamp.toString().substring(timestamp.toString().length - 10);
  }

  // Save user session locally
  Future<void> _saveUserSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_full_name', user.fullName);
    await prefs.setString('user_email', user.email);
    await prefs.setString('user_type', user.userType);
    await prefs.setString('user_nationality', user.nationality);
    await prefs.setString('user_digital_id', user.digitalId);
  }

  // Clear user session
  Future<void> _clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Get saved user session
  Future<AppUser?> getSavedUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId != null && isAuthenticated) {
      return AppUser(
        id: userId,
        fullName: prefs.getString('user_full_name') ?? '',
        email: prefs.getString('user_email') ?? '',
        userType: prefs.getString('user_type') ?? '',
        nationality: prefs.getString('user_nationality') ?? '',
        digitalId: prefs.getString('user_digital_id') ?? '',
        createdAt: DateTime.now(),
      );
    }
    return null;
  }

  // Listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabaseService.authStateChanges;
}

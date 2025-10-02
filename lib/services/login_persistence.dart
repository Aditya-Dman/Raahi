import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LoginPersistence {
  static const String _userDataKey = 'saved_user_data';
  static const String _isLoggedInKey = 'is_logged_in';

  // Save user login data
  static Future<void> saveUserLogin({
    required String fullName,
    required String email,
    required String userType,
    required String nationality,
    required String digitalId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userData = {
        'fullName': fullName,
        'email': email,
        'userType': userType,
        'nationality': nationality,
        'digitalId': digitalId,
        'loginTimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(_userDataKey, jsonEncode(userData));
      await prefs.setBool(_isLoggedInKey, true);

      print('✅ User login saved successfully');
    } catch (e) {
      print('❌ Error saving user login: $e');
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLoggedInKey) ?? false;
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  // Get saved user data
  static Future<Map<String, dynamic>?> getSavedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userDataKey);

      if (userDataString != null) {
        return jsonDecode(userDataString) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Error getting saved user data: $e');
      return null;
    }
  }

  // Clear login data (for logout)
  static Future<void> clearLoginData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDataKey);
      await prefs.setBool(_isLoggedInKey, false);

      print('✅ Login data cleared successfully');
    } catch (e) {
      print('❌ Error clearing login data: $e');
    }
  }

  // Update user data (when profile is edited)
  static Future<void> updateUserData({
    String? fullName,
    String? userType,
    String? nationality,
  }) async {
    try {
      final currentData = await getSavedUserData();
      if (currentData != null) {
        currentData['fullName'] = fullName ?? currentData['fullName'];
        currentData['userType'] = userType ?? currentData['userType'];
        currentData['nationality'] = nationality ?? currentData['nationality'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userDataKey, jsonEncode(currentData));

        print('✅ User data updated successfully');
      }
    } catch (e) {
      print('❌ Error updating user data: $e');
    }
  }
}

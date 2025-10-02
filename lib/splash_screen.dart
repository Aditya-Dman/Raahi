import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'main.dart';
import 'services/login_persistence.dart';
import 'services/user_session.dart' as user_session;
import 'services/supabase_auth_service.dart';
import 'widgets/localized_text.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      // Show splash for at least 2 seconds
      await Future.delayed(const Duration(seconds: 2));

      // Check if user is logged in
      final isLoggedIn = await LoginPersistence.isLoggedIn();

      if (isLoggedIn) {
        // Get saved user data
        final userData = await LoginPersistence.getSavedUserData();

        if (userData != null) {
          // Restore user session
          final user = AppUser(
            id: userData['email'], // Using email as ID for simplicity
            fullName: userData['fullName'],
            email: userData['email'],
            userType: userData['userType'],
            nationality: userData['nationality'],
            digitalId: userData['digitalId'],
            createdAt: DateTime.now(),
          );

          user_session.UserSession.setCurrentUser(user);

          // Navigate to dashboard
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const DashboardPage()),
            );
          }
        } else {
          // No valid user data, go to welcome page
          _goToWelcomePage();
        }
      } else {
        // Not logged in, go to welcome page
        _goToWelcomePage();
      }
    } catch (e) {
      print('Error checking login status: $e');
      _goToWelcomePage();
    }
  }

  void _goToWelcomePage() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B2F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  'assets/sounds/logo.jpg',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to icon if image fails to load
                    return Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3F3D56)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 60,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // App Name
            LocalizedStrings.appName(context),

            const SizedBox(height: 8),

            // Tagline
            LocalizedStrings.appTagline(context),

            const SizedBox(height: 40),

            // Loading Indicator
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.8),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Loading Text
            LocalizedStrings.loading(context),
          ],
        ),
      ),
    );
  }
}

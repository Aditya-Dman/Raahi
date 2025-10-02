import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'splash_screen.dart';
import 'services/supabase_service.dart';
import 'services/user_session.dart' as user_session;
import 'services/supabase_debug.dart';
import 'services/language_service.dart';
import 'services/dashboard_data_provider.dart';
import 'widgets/localized_text.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable all debug overlays and banners
  debugPaintSizeEnabled = false;
  debugRepaintRainbowEnabled = false;
  debugRepaintTextRainbowEnabled = false;

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize user session
  await user_session.UserSession.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => LanguageNotifier()..loadSavedLanguage(),
        ),
        ChangeNotifierProvider(create: (context) => DashboardDataProvider()),
      ],
      child: Consumer<LanguageNotifier>(
        builder: (context, languageNotifier, child) {
          return MaterialApp(
            title: 'Raahi - Smart Tourist Safety System',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6C63FF),
              ),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            locale: languageNotifier.currentLocale,
            localizationsDelegates: const [
              // AppLocalizations.delegate, // Will be generated
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en', 'US'), Locale('hi', 'IN')],
            home: const SplashScreen(),
            debugShowCheckedModeBanner: false,
            showPerformanceOverlay: false,
            showSemanticsDebugger: false,
            debugShowMaterialGrid: false,
            checkerboardRasterCacheImages: false,
            checkerboardOffscreenLayers: false,
            builder: (context, widget) {
              // Ensure no debug overlays or banners are shown
              return widget!;
            },
          );
        },
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B2F),
      body: CustomScrollView(
        slivers: [
          // Modern AppBar
          SliverAppBar(
            elevation: 0,
            backgroundColor: const Color(0xFF1A1347),
            pinned: true,
            expandedHeight: 80,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1347), Color(0xFF2D1B69)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/sounds/logo.jpg',
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback to icon if image fails to load
                                  return Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF6C63FF),
                                          Color(0xFF4ECDC4),
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.shield_outlined,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          LocalizedStrings.appName(context),
                        ],
                      ),
                      // Responsive Navigation
                      if (MediaQuery.of(context).size.width >= 768)
                        Row(
                          children: [
                            ...[
                              'Features',
                              'Technology',
                              'Testimonials',
                              'Contact',
                            ].map((item) => _ModernNavLink(item)),
                            const SizedBox(width: 24),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginPage(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            // Debug button for Supabase
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SupabaseDebugScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.amber,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Debug DB',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6C63FF),
                                    Color(0xFF4ECDC4),
                                  ],
                                ),
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SignUpPage(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Get Started',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        // Mobile: Simple login button
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Hero Section
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: MediaQuery.of(context).size.width >= 768 ? 80 : 40,
                horizontal: MediaQuery.of(context).size.width >= 768 ? 24 : 16,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F0B2F),
                    Color(0xFF2D1B69),
                    Color(0xFF6C63FF),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.7, 1.0],
                ),
              ),
              child: Column(
                children: [
                  // Main Headline
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF4ECDC4), Color(0xFF6C63FF)],
                    ).createShader(bounds),
                    child: Text(
                      'Transforming Tourist Safety',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width >= 768
                            ? 56
                            : 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  SizedBox(
                    height: MediaQuery.of(context).size.width >= 768 ? 16 : 8,
                  ),

                  Text(
                    'Across Incredible India',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width >= 768
                          ? 48
                          : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),

                  SizedBox(
                    height: MediaQuery.of(context).size.width >= 768 ? 32 : 20,
                  ),

                  // Subtitle
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width >= 768
                          ? 800
                          : double.infinity,
                    ),
                    child: Text(
                      'Every year, 2.5 million foreign tourists and 1.8 billion domestic tourists visit India. Our AI-powered safety ecosystem ensures their security through real-time monitoring, emergency response, and blockchain-verified digital identities.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width >= 768
                            ? 20
                            : 16,
                        color: const Color(0xFFE0E0E0),
                        height: 1.6,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  SizedBox(
                    height: MediaQuery.of(context).size.width >= 768 ? 48 : 32,
                  ),

                  SizedBox(
                    height: MediaQuery.of(context).size.width >= 768 ? 48 : 32,
                  ),

                  // CTA Buttons
                  if (MediaQuery.of(context).size.width >= 768)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C63FF).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Get Started',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpPage(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFF4ECDC4),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    // Mobile: Stacked buttons
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6C63FF,
                                  ).withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginPage(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Get Started',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignUpPage(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFF4ECDC4),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Challenge Section
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFFF8F9FA),
              padding: EdgeInsets.symmetric(
                vertical: MediaQuery.of(context).size.width >= 768 ? 80 : 40,
                horizontal: MediaQuery.of(context).size.width >= 768 ? 24 : 16,
              ),
              child: Column(
                children: [
                  Text(
                    "The Challenge We're Solving",
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width >= 768
                          ? 42
                          : 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D1B69),
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.width >= 768 ? 20 : 16,
                  ),
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width >= 768
                          ? 700
                          : double.infinity,
                    ),
                    child: Text(
                      "India's tourism industry faces critical safety challenges that impact both tourists and the economy",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width >= 768
                            ? 20
                            : 16,
                        color: const Color(0xFF6B7280),
                        height: 1.6,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.width >= 768 ? 60 : 40,
                  ),
                  Wrap(
                    spacing: MediaQuery.of(context).size.width >= 768 ? 32 : 16,
                    runSpacing: MediaQuery.of(context).size.width >= 768
                        ? 32
                        : 20,
                    alignment: WrapAlignment.center,
                    children: [
                      _ModernChallengeCard(
                        color: const Color(0xFFEF4444),
                        title: '₹2.3L Cr',
                        subtitle: 'Annual tourism revenue at risk',
                        icon: Icons.trending_down_rounded,
                      ),
                      _ModernChallengeCard(
                        color: const Color(0xFFF97316),
                        title: '15-20 min',
                        subtitle: 'Average emergency response time',
                        icon: Icons.access_time_rounded,
                      ),
                      _ModernChallengeCard(
                        color: const Color(0xFFEAB308),
                        title: '67%',
                        subtitle: 'Tourists concerned about safety',
                        icon: Icons.security_rounded,
                      ),
                      _ModernChallengeCard(
                        color: const Color(0xFF8B5CF6),
                        title: '12+',
                        subtitle: 'Languages creating barriers',
                        icon: Icons.language_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernNavLink extends StatelessWidget {
  final String label;
  const _ModernNavLink(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          foregroundColor: Colors.white70,
          overlayColor: Colors.white.withOpacity(0.1),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _ModernChallengeCard extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ModernChallengeCard({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: isMobile ? double.infinity : (isDesktop ? 280 : 250),
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isDesktop ? 16 : 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: isDesktop ? 32 : 28),
          ),
          SizedBox(height: isDesktop ? 20 : 16),
          Text(
            title,
            style: TextStyle(
              fontSize: isDesktop ? 32 : 28,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: isDesktop ? 12 : 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14,
              color: const Color(0xFF6B7280),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

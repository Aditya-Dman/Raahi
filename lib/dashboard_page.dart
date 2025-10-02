import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'widgets/simple_map_widget.dart';
import 'widgets/chatbase_webview.dart';
import 'widgets/language_selection_widget.dart';
import 'widgets/localized_text.dart';
import 'login_page.dart';
import 'kyc_update_screen.dart';
import 'digital_id_screen.dart';
import 'places_list_screen.dart';
import 'emergency_contacts_screen.dart';
import 'services/supabase_data_service.dart';
import 'services/supabase_auth_service.dart';
import 'services/health_service.dart';
import 'services/emergency_alert_service.dart' as alert_service;
import 'services/user_session.dart' as user_session;
import 'services/login_persistence.dart';
import 'services/dashboard_data_provider.dart';
import 'models/emergency_contact.dart' as db_contact;
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

// Simple ChatMessage class for placeholder functionality
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  bool isTracking = false;
  bool isOnline = false;
  late HealthService _healthService;
  HealthData? _currentHealthData;
  ActivityData? _currentActivityData;

  // Navigation state
  String _currentPage = 'overview';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Chat placeholders (actual chat functionality is in ChatbaseWebView)
  final List<dynamic> _chatMessages = [];
  final TextEditingController _messageController = TextEditingController();
  bool _isTyping = false;

  // KYC Status
  String _kycStatus =
      'not_submitted'; // not_submitted, pending, verified, rejected
  bool _isLoadingKYC = true;

  List<Map<String, dynamic>> _getLocalizedMenuItems(BuildContext context) {
    return [
      {
        'title': LocalizedStrings.overview(context),
        'icon': Icons.dashboard_outlined,
        'key': 'overview',
      },
      {
        'title': LocalizedStrings.gps(context),
        'icon': Icons.gps_fixed,
        'key': 'gps',
      },
      {
        'title': LocalizedStrings.safetyEmergency(context),
        'icon': Icons.shield_outlined,
        'key': 'safetyEmergency',
      },
      {
        'title': LocalizedStrings.aiAssistant(context),
        'icon': Icons.smart_toy_outlined,
        'key': 'aiAssistant',
      },
      {
        'title': LocalizedStrings.iot(context),
        'icon': Icons.device_hub_outlined,
        'key': 'iot',
      },
      {
        'title': LocalizedStrings.digitalId(context),
        'icon': Icons.badge_outlined,
        'key': 'id',
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _healthService = HealthService();
    _healthService.startHealthMonitoring();

    // Initialize emergency service with demo contacts
    _initializeEmergencyService();

    // Load KYC status
    _loadKYCStatus();

    // Request permissions for phone access
    _requestPermissions();

    // Listen to health data updates
    _healthService.healthDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _currentHealthData = data;
        });
      }
    });

    _healthService.activityDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _currentActivityData = data;
        });
      }
    });

    // Initialize with current data
    _currentHealthData = _healthService.getCurrentHealthData();
    _currentActivityData = _healthService.getCurrentActivityData();
  }

  void _initializeEmergencyService() {
    // The emergency service is now initialized empty
    // Users can add their own emergency contacts through the UI
    print('🔧 Emergency service initialized - ready for user contacts');
  }

  Future<void> _loadKYCStatus() async {
    try {
      final authService = SupabaseAuthService();
      final currentUser = await authService.getCurrentUser();

      if (currentUser != null) {
        final dataService = SupabaseDataService();
        final status = await dataService.getKYCStatus(currentUser.id);

        if (mounted) {
          setState(() {
            _kycStatus = status;
            _isLoadingKYC = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _kycStatus = 'not_submitted';
            _isLoadingKYC = false;
          });
        }
      }
    } catch (e) {
      print('Error loading KYC status: $e');
      if (mounted) {
        setState(() {
          _kycStatus = 'not_submitted';
          _isLoadingKYC = false;
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    try {
      // Request phone permission
      final phoneStatus = await Permission.phone.request();

      // Request SMS permission for emergency alerts
      final smsStatus = await Permission.sms.request();

      // Request location permission for GPS tracking
      final locationStatus = await Permission.location.request();

      if (phoneStatus.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizedStrings.phonePermissionMessage(context)),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      if (smsStatus.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizedStrings.smsPermissionMessage(context)),
              backgroundColor: Color(0xFFD2B48C), // Warm beige
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      if (locationStatus.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                LocalizedStrings.locationPermissionMessage(context),
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Handle permission error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permissions: $e'),
            backgroundColor: const Color(0xFFD2B48C), // Warm beige
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _healthService.stopHealthMonitoring();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          // Header Section with Hamburger Menu
          Container(
            padding: EdgeInsets.all(
              MediaQuery.of(context).size.width < 600 ? 16 : 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Color(0xFFFEF2F2), // Red-50
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFD2B48C), // Soft beige shadow
                  blurRadius: 15,
                  spreadRadius: -5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Hamburger Menu Button with glow effect
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFD2B48C, // Warm beige
                          ).withOpacity(0.15), // Much softer glow
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      icon: const Icon(
                        Icons.menu,
                        color: Color(0xFFD2B48C), // Warm beige for menu icon
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Current Page Title with glow effect
                  Expanded(
                    child: Text(
                      _currentPage,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD2B48C), // Warm beige for title
                        shadows: [
                          Shadow(
                            blurRadius: 6, // Reduced glow intensity
                            color: Color(0xFFD2B48C), // Warm beige glow
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Status indicators for mobile removed - no longer needed
                  // User Profile and Logout with red theme
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFD2B48C, // Warm beige
                          ).withOpacity(0.15), // Softer shadow
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'logout') {
                          await user_session.UserSession.logout();
                          await LoginPersistence.clearLoginData();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 16),
                              const SizedBox(width: 8),
                              Text(user_session.UserSession.getUserName()),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'digitalId',
                          child: Row(
                            children: [
                              const Icon(Icons.badge, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'ID: ${user_session.UserSession.getDigitalId()}',
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, size: 16),
                              SizedBox(width: 8),
                              Text('Logout'),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFD2B48C), // Warm beige
                              Color(0xFFC19A6B), // Darker beige
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFD2B48C,
                              ).withOpacity(0.25), // Warm beige shadow
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content Area
          Expanded(child: _buildCurrentPage()),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFD2B48C), // Warm beige
                  Color(0xFFC19A6B), // Darker beige
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Text(
                    'Raahi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.white,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    'Welcome, ${user_session.UserSession.getUserName()}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      shadows: [
                        Shadow(
                          blurRadius: 5,
                          color: Colors.white,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                // Status indicators in drawer - made more compact with glow effects
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isTracking
                              ? const Color(0xFF10B981)
                              : const Color(
                                  0xFFD2B48C,
                                ), // Warm beige for inactive
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isTracking
                                          ? const Color(0xFF10B981)
                                          : const Color(
                                              0xFFD2B48C,
                                            )) // Warm beige for inactive
                                      .withOpacity(0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          isTracking ? 'Tracking' : 'Not Tracking',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                blurRadius: 3,
                                color: Colors.white,
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Removed offline status indicator - no longer needed
                    ],
                  ),
                ),
              ],
            ),
          ),
          ..._getLocalizedMenuItems(context).map(
            (item) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: _currentPage == item['key']
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFD2B48C), // Warm beige
                          Color(0xFFC19A6B), // Darker beige
                        ],
                      )
                    : null,
                boxShadow: _currentPage == item['key']
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFFD2B48C,
                          ).withOpacity(0.25), // Warm beige shadow
                          blurRadius: 12,
                          spreadRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: const Color(
                            0xFFD2B48C,
                          ).withOpacity(0.15), // Soft beige glow
                          blurRadius: 20,
                          spreadRadius: 3,
                          offset: const Offset(0, 0),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: ListTile(
                leading: Container(
                  decoration: BoxDecoration(
                    boxShadow: _currentPage == item['key']
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    item['icon'],
                    color: _currentPage == item['key']
                        ? Colors.white
                        : const Color(0xFF6B7280),
                    size: _currentPage == item['key'] ? 24 : 22,
                  ),
                ),
                title: item['title'],
                selected: _currentPage == item['key'],
                onTap: () {
                  setState(() {
                    _currentPage = item['key'];
                  });
                  Navigator.pop(context); // Close drawer
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case 'overview':
        return _buildOverviewTab();
      case 'gps':
        return _buildGPSTrackingTab();
      case 'safetyEmergency':
        return _buildEmergencyTab();
      case 'aiAssistant':
        return ChatbaseWebView(agentId: 'hsQKeM8HRconRfdAMHuSf');
      case 'iot':
        return _buildIoTDevicesTab();
      case 'id':
        return _buildDigitalIDTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Consumer<DashboardDataProvider>(
      builder: (context, dashboardData, child) {
        if (dashboardData.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading dashboard data...'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 20 : 12),
          child: Column(
            children: [
              // Stats Cards - Responsive Layout
              if (isDesktop)
                // Desktop: Row layout
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Safety Score',
                        value: dashboardData.safetyScoreFormatted,
                        icon: Icons.shield_outlined,
                        color: dashboardData.getSafetyScoreColor(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Location Updates',
                        value: dashboardData.locationUpdatesFormatted,
                        icon: Icons.location_on_outlined,
                        color: dashboardData.getLocationUpdatesColor(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Days Remaining',
                        value: dashboardData.remainingDaysFormatted,
                        icon: Icons.calendar_today_outlined,
                        color: dashboardData.getRemainingDaysColor(),
                      ),
                    ),
                  ],
                )
              else
                // Mobile: 2x2 Grid
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Safety Score',
                            value: dashboardData.safetyScoreFormatted,
                            icon: Icons.shield_outlined,
                            color: dashboardData.getSafetyScoreColor(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            title: 'Location Updates',
                            value: dashboardData.locationUpdatesFormatted,
                            icon: Icons.location_on_outlined,
                            color: dashboardData.getLocationUpdatesColor(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Days Remaining',
                            value: dashboardData.remainingDaysFormatted,
                            icon: Icons.calendar_today_outlined,
                            color: dashboardData.getRemainingDaysColor(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              SizedBox(height: isDesktop ? 24 : 16),

              // Profile and Quick Actions - Responsive Layout
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Information
                    Expanded(flex: 1, child: _ProfileInformationCard()),
                    const SizedBox(width: 20),
                    // Quick Actions
                    Expanded(
                      flex: 1,
                      child: _QuickActionsCard(
                        isTracking: isTracking,
                        onTrackingToggle: (value) =>
                            setState(() => isTracking = value),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _ProfileInformationCard(),
                    const SizedBox(height: 12),
                    _QuickActionsCard(
                      isTracking: isTracking,
                      onTrackingToggle: (value) =>
                          setState(() => isTracking = value),
                    ),
                  ],
                ),

              SizedBox(height: isDesktop ? 24 : 16),

              // KYC Update Section
              _KYCUpdateCard(),

              SizedBox(height: isDesktop ? 24 : 16),

              // Tourist Services Row
              _TouristServicesSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGPSTrackingTab() {
    return Column(
      children: [
        // GPS Tracking Controls
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GPS Tracking Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isTracking ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isTracking
                              ? 'GPS Tracking Active'
                              : 'GPS Tracking Inactive',
                          style: TextStyle(
                            color: isTracking ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    // Toggle tracking state
                    // Note: GoogleMapWidget automatically tracks location when initialized
                    isTracking = !isTracking;
                  });
                },
                icon: Icon(isTracking ? Icons.stop : Icons.play_arrow),
                label: Text(isTracking ? 'Stop Tracking' : 'Start Tracking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTracking ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Real Google Map Widget
        Expanded(
          child: SimpleMapWidget(
            showSafetyZones: false,
            showTouristServices: false,
            showRouteHistory: true,
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyTab() {
    return Padding(
      padding: EdgeInsets.all(
        MediaQuery.of(context).size.width < 600 ? 16 : 20,
      ),
      child: Column(
        children: [
          _EmergencySOSCard(),
          const SizedBox(height: 20),
          _EmergencyContactsCard(),
        ],
      ),
    );
  }

  // Note: This method is kept for compatibility but not used
  // AI chat functionality is now handled by ChatbaseWebView
  // ignore: unused_element
  Widget _buildAIChatTab() {
    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFD2B48C),
                      Color(0xFFC19A6B),
                    ], // Warm beige gradient
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFD2B48C,
                      ).withOpacity(0.25), // Warm beige shadow
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Travel Assistant',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    Text(
                      'Ask me anything about travel safety and app features',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Chat Messages Area
        Expanded(
          child: _chatMessages.isEmpty
              ? _buildEmptyChatState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(_chatMessages[index]);
                  },
                ),
        ),

        // Typing Indicator
        if (_isTyping)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.grey[600]!,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI is typing...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Message Input Area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Ask me about travel safety, app features...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Start a conversation!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me about travel safety, app features, or anything you need help with.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'What are the emergency numbers?',
                'How to stay safe?',
                'Travel tips?',
              ].map((suggestion) => _buildSuggestionChip(suggestion)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return GestureDetector(
      onTap: () {
        _messageController.text = suggestion;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
        ),
        child: Text(
          suggestion,
          style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(0xFF3B82F6)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white
                      : const Color(0xFF2D3748),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF2D3748),
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _chatMessages.add(
        ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });

    try {
      // Placeholder AI response since real chat is handled by ChatbaseWebView
      await Future.delayed(const Duration(seconds: 1));
      final aiResponse =
          'This chat is a placeholder. Please use the AI Assistant tab for real AI chat.';

      setState(() {
        _isTyping = false;
        _chatMessages.add(
          ChatMessage(
            text: aiResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      setState(() {
        _isTyping = false;
        _chatMessages.add(
          ChatMessage(
            text:
                'Sorry, I\'m having trouble responding right now. Please try again later.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    }
  }

  Widget _buildIoTDevicesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connected Devices Section
            _buildSectionHeader('Connected Devices', Icons.devices),
            const SizedBox(height: 16),
            _buildConnectedDevices(),

            const SizedBox(height: 24),

            // Health Monitoring Section
            _buildSectionHeader('Health Monitoring', Icons.monitor_heart),
            const SizedBox(height: 16),
            _buildHealthMonitoring(),

            const SizedBox(height: 24),

            // Activity Tracking Section
            _buildSectionHeader('Activity Tracking', Icons.fitness_center),
            const SizedBox(height: 16),
            _buildActivityTracking(),

            const SizedBox(height: 24),

            // Emergency Health Alerts Section
            _buildSectionHeader('Health Alerts', Icons.warning_amber),
            const SizedBox(height: 16),
            _buildHealthAlerts(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF805AD5), size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedDevices() {
    final devices = _healthService.getConnectedDevices();

    return Column(
      children: devices
          .map(
            (device) => _buildDeviceCard({
              'name': device.name,
              'type': device.typeString,
              'status': device.isConnected ? 'Connected' : 'Disconnected',
              'battery': device.batteryLevel,
              'icon': _getDeviceIcon(device.type),
              'color': device.isConnected
                  ? _getDeviceColor(device.type)
                  : const Color(0xFF9CA3AF),
            }),
          )
          .toList(),
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.smartWatch:
        return Icons.watch;
      case DeviceType.fitnessTracker:
        return Icons.fitness_center;
      case DeviceType.healthMonitor:
        return Icons.monitor_heart;
    }
  }

  Color _getDeviceColor(DeviceType type) {
    switch (type) {
      case DeviceType.smartWatch:
        return const Color(0xFF48BB78);
      case DeviceType.fitnessTracker:
        return const Color(0xFF4299E1);
      case DeviceType.healthMonitor:
        return const Color(0xFF9F7AEA);
    }
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final isConnected = device['status'] == 'Connected';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected
              ? (device['color'] as Color)
              : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (device['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              device['icon'] as IconData,
              color: device['color'] as Color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  device['type'] as String,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConnected
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  device['status'] as String,
                  style: TextStyle(
                    color: isConnected
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isConnected) ...[
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      constraints: const BoxConstraints(maxWidth: 70),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.battery_std,
                            size: 16,
                            color: _getBatteryColor(device['battery'] as int),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${device['battery']}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(int battery) {
    if (battery > 50) return Colors.green;
    if (battery > 20) return Colors.orange;
    return Colors.red;
  }

  Widget _buildHealthMonitoring() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildHealthMetric(
                  'Heart Rate',
                  '${_currentHealthData?.heartRate.round() ?? 72} BPM',
                  Icons.favorite,
                  Colors.red,
                  _currentHealthData?.heartRateStatus ?? 'Normal',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildHealthMetric(
                  'Blood Oxygen',
                  '${_currentHealthData?.bloodOxygen.round() ?? 98}%',
                  Icons.air,
                  Colors.blue,
                  _currentHealthData?.bloodOxygenStatus ?? 'Excellent',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildHealthMetric(
                  'Body Temperature',
                  '${_currentHealthData?.bodyTemperature.toStringAsFixed(1) ?? '98.6'}°F',
                  Icons.thermostat,
                  Colors.orange,
                  _currentHealthData?.temperatureStatus ?? 'Normal',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildHealthMetric(
                  'Stress Level',
                  _currentHealthData?.stressLevel ?? 'Low',
                  Icons.psychology,
                  Colors.green,
                  'Good',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Trigger immediate health data sync
                    _healthService.startHealthMonitoring();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Health data synced successfully'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Sync Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF805AD5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('View History'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric(
    String title,
    String value,
    IconData icon,
    Color color,
    String status,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTracking() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 400;
              if (isMobile) {
                return Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildActivityCircle(
                      'Steps',
                      '${_currentActivityData?.steps ?? 8432}',
                      '${_currentActivityData?.stepGoal ?? 10000}',
                      _currentActivityData?.stepProgress ?? 0.84,
                      Colors.blue,
                    ),
                    _buildActivityCircle(
                      'Calories',
                      '${_currentActivityData?.calories ?? 320}',
                      '${_currentActivityData?.calorieGoal ?? 450}',
                      _currentActivityData?.calorieProgress ?? 0.71,
                      Colors.orange,
                    ),
                    _buildActivityCircle(
                      'Distance',
                      _currentActivityData?.distance.toStringAsFixed(1) ??
                          '6.2',
                      _currentActivityData?.distanceGoal.toStringAsFixed(1) ??
                          '8.0',
                      _currentActivityData?.distanceProgress ?? 0.78,
                      Colors.green,
                    ),
                  ],
                );
              } else {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActivityCircle(
                      'Steps',
                      '${_currentActivityData?.steps ?? 8432}',
                      '${_currentActivityData?.stepGoal ?? 10000}',
                      _currentActivityData?.stepProgress ?? 0.84,
                      Colors.blue,
                    ),
                    _buildActivityCircle(
                      'Calories',
                      '${_currentActivityData?.calories ?? 320}',
                      '${_currentActivityData?.calorieGoal ?? 450}',
                      _currentActivityData?.calorieProgress ?? 0.71,
                      Colors.orange,
                    ),
                    _buildActivityCircle(
                      'Distance',
                      _currentActivityData?.distance.toStringAsFixed(1) ??
                          '6.2',
                      _currentActivityData?.distanceGoal.toStringAsFixed(1) ??
                          '8.0',
                      _currentActivityData?.distanceProgress ?? 0.78,
                      Colors.green,
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),
          _buildSleepTracking(),
        ],
      ),
    );
  }

  Widget _buildActivityCircle(
    String title,
    String current,
    String goal,
    double progress,
    Color color,
  ) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 4),
                ),
              ),
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      current,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      '/${goal.split('.')[0]}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSleepTracking() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.bedtime, color: Colors.indigo.shade600, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 250;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sleep Quality',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isMobile) ...[
                      Text(
                        _currentActivityData?.sleepDurationText ?? '7h 32m',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.indigo.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Deep: 2h 15m • REM: 1h 45m',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.indigo.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      Text(
                        '${_currentActivityData?.sleepDurationText ?? '7h 32m'} • Deep: 2h 15m • REM: 1h 45m',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.indigo.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            5,
                            (index) => Icon(
                              Icons.star,
                              size: 16,
                              color:
                                  index <
                                      (_currentActivityData?.sleepQuality ?? 4)
                                  ? Colors.amber
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        Text(
                          _currentActivityData?.sleepQualityText ?? 'Excellent',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthAlerts() {
    final alerts = _healthService.getHealthAlerts();

    return Column(
      children: alerts
          .map(
            (alert) => _buildAlertCard({
              'title': alert.title,
              'message': alert.message,
              'time': alert.timeAgo,
              'severity': alert.severity.name,
              'icon': _getAlertIcon(alert.icon),
            }),
          )
          .toList(),
    );
  }

  IconData _getAlertIcon(String iconName) {
    switch (iconName) {
      case 'heart':
        return Icons.favorite;
      case 'water':
        return Icons.water_drop;
      case 'warning':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    Color alertColor;
    Color backgroundColor;

    switch (alert['severity']) {
      case 'high':
        alertColor = Colors.red;
        backgroundColor = Colors.red.shade50;
        break;
      case 'medium':
        alertColor = Colors.orange;
        backgroundColor = Colors.orange.shade50;
        break;
      default:
        alertColor = Colors.blue;
        backgroundColor = Colors.blue.shade50;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: alertColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(alert['icon'] as IconData, color: alertColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: alertColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert['message'] as String,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  alert['time'] as String,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalIDTab() {
    return const DigitalIDScreen();
  }

  Widget _buildIDField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _KYCUpdateCard() {
    if (_isLoadingKYC) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                const Color(0xFFD2B48C).withOpacity(0.7),
                const Color(0xFFDDC0A3).withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    Color cardColor;
    Color statusColor;
    String statusText;
    String titleText;
    String subtitleText;
    IconData iconData;
    bool isSubmitted = false;

    switch (_kycStatus) {
      case 'pending':
        cardColor = const Color(0xFFFFB74D); // Orange
        statusColor = Colors.orange.shade800;
        statusText = 'Pending Review';
        titleText = 'KYC Under Review';
        subtitleText = 'Your documents are being verified';
        iconData = Icons.hourglass_empty;
        isSubmitted = true;
        break;
      case 'verified':
        cardColor = const Color(0xFF66BB6A); // Green
        statusColor = Colors.green.shade800;
        statusText = 'Verified ✓';
        titleText = 'KYC Verified';
        subtitleText = 'Your identity has been successfully verified';
        iconData = Icons.verified_user;
        isSubmitted = true;
        break;
      case 'rejected':
        cardColor = const Color(0xFFEF5350); // Red
        statusColor = Colors.red.shade800;
        statusText = 'Rejected';
        titleText = 'KYC Rejected';
        subtitleText = 'Please resubmit with correct documents';
        iconData = Icons.error_outline;
        isSubmitted = false;
        break;
      default: // not_submitted
        cardColor = const Color(0xFFD2B48C); // Beige
        statusColor = Colors.orange.shade800;
        statusText = 'Update Required';
        titleText = 'KYC Verification';
        subtitleText = 'Complete your profile verification';
        iconData = Icons.verified_user_outlined;
        isSubmitted = false;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [cardColor, cardColor.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(iconData, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitleText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _kycStatus == 'verified'
                  ? 'Your account is fully verified and all features are available.'
                  : _kycStatus == 'pending'
                  ? 'We are reviewing your documents. This typically takes 1-3 business days.'
                  : _kycStatus == 'rejected'
                  ? 'Your KYC was rejected. Please check your documents and resubmit.'
                  : 'Verify your identity to access all features and ensure account security.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (!isSubmitted || _kycStatus == 'rejected')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const KYCUpdateScreen(),
                      ),
                    );

                    // If KYC was submitted, refresh the status
                    if (result == true) {
                      _loadKYCStatus();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: cardColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _kycStatus == 'rejected' ? 'Resubmit KYC' : 'Update KYC',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Debug button for prototype demonstration
            if (isSubmitted && _kycStatus != 'not_submitted')
              Column(
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          final supabaseDataService = SupabaseDataService();
                          final authService = SupabaseAuthService();
                          final currentUser = await authService
                              .getCurrentUser();

                          if (currentUser != null) {
                            final success = await supabaseDataService
                                .resetKYCForDemo(currentUser.id);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'KYC reset for demo - you can submit again!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadKYCStatus(); // Refresh the status
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to reset KYC'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          print('Error resetting KYC: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error resetting KYC'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Reset for Demo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 8 : 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: isDesktop ? 24 : 20),
              ),
              const Spacer(),
            ],
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isDesktop ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isDesktop ? 14 : 12,
              color: const Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInformationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedStrings.profile(context),
          SizedBox(height: isDesktop ? 20 : 16),
          _ProfileItem(
            icon: Icons.person_outline,
            label: 'Name',
            value: user_session.UserSession.getUserName(),
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          _ProfileItem(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user_session.UserSession.getUserEmail(),
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          _ProfileItem(
            icon: Icons.flag_outlined,
            label: 'Nationality',
            value: user_session.UserSession.getNationality(),
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          _ProfileItem(
            icon: Icons.calendar_today_outlined,
            label: 'Entry Date',
            value: '9/16/2025',
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          _ProfileItem(
            icon: Icons.exit_to_app_outlined,
            label: 'Exit Date',
            value: '9/23/2025',
          ),
          SizedBox(height: isDesktop ? 20 : 16),
          // Language Selection
          const LanguageSelectionButton(),
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Row(
      children: [
        Icon(icon, color: const Color(0xFF718096), size: isDesktop ? 20 : 18),
        SizedBox(width: isDesktop ? 12 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isDesktop ? 12 : 11,
                  color: const Color(0xFF718096),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D3748),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final bool isTracking;
  final Function(bool) onTrackingToggle;

  const _QuickActionsCard({
    required this.isTracking,
    required this.onTrackingToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3748),
            ),
          ),
          SizedBox(height: isDesktop ? 20 : 16),

          // Enable Tracking Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onTrackingToggle(!isTracking),
              icon: Icon(
                isTracking ? Icons.stop : Icons.play_arrow,
                size: isDesktop ? 20 : 18,
              ),
              label: Text(
                isTracking ? 'Disable Tracking' : 'Enable Tracking',
                style: TextStyle(fontSize: isDesktop ? 14 : 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isTracking
                    ? Colors.red
                    : const Color(0xFF38A169),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isDesktop ? 12 : 10),
              ),
            ),
          ),

          SizedBox(height: isDesktop ? 12 : 10),

          // Emergency Contacts Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmergencyContactsScreen(),
                  ),
                );
              },
              icon: Icon(Icons.contacts_outlined, size: isDesktop ? 20 : 18),
              label: Text(
                'Emergency Contacts',
                style: TextStyle(fontSize: isDesktop ? 14 : 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF718096),
                side: const BorderSide(color: Color(0xFF718096)),
                padding: EdgeInsets.symmetric(vertical: isDesktop ? 12 : 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TouristServicesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tourist Services',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3748),
            ),
          ),
          SizedBox(height: isDesktop ? 20 : 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isDesktop
                ? 4
                : 2, // 4 columns on desktop, 2 on mobile
            crossAxisSpacing: isDesktop ? 16 : 12,
            mainAxisSpacing: isDesktop ? 16 : 12,
            childAspectRatio: isDesktop ? 1.1 : 1.0, // Adjust card proportions
            children: [
              _ServiceCard(
                icon: Icons.restaurant_outlined,
                title: 'Restaurants',
                subtitle: 'Find nearby dining',
                color: const Color(0xFFD2B48C), // Beige theme
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlacesListScreen(
                        category: 'restaurants',
                        categoryTitle: 'Restaurants',
                      ),
                    ),
                  );
                },
              ),
              _ServiceCard(
                icon: Icons.hotel_outlined,
                title: 'Hotels',
                subtitle: 'Book accommodation',
                color: const Color(0xFFC19A6B), // Secondary beige
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlacesListScreen(
                        category: 'hotels',
                        categoryTitle: 'Hotels',
                      ),
                    ),
                  );
                },
              ),
              _ServiceCard(
                icon: Icons.tour_outlined,
                title: 'Tour Guides',
                subtitle: 'Expert local guides',
                color: const Color(0xFFD2B48C), // Beige theme
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlacesListScreen(
                        category: 'tour_guides',
                        categoryTitle: 'Tour Guides',
                      ),
                    ),
                  );
                },
              ),
              _ServiceCard(
                icon: Icons.place_outlined,
                title: 'Tourist Places',
                subtitle: 'Discover attractions',
                color: const Color(0xFFC19A6B), // Secondary beige
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlacesListScreen(
                        category: 'tourist_places',
                        categoryTitle: 'Tourist Places',
                      ),
                    ),
                  );
                },
              ),
              _ServiceCard(
                icon: Icons.local_pharmacy_outlined,
                title: 'Medical',
                subtitle: 'Healthcare services',
                color: const Color(0xFFD2B48C), // Beige theme
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlacesListScreen(
                        category: 'medical',
                        categoryTitle: 'Medical',
                      ),
                    ),
                  );
                },
              ),
              _ServiceCard(
                icon: Icons.local_taxi_outlined,
                title: 'Transport',
                subtitle: 'Book rides & trips',
                color: const Color(0xFFC19A6B), // Secondary beige
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlacesListScreen(
                        category: 'transport',
                        categoryTitle: 'Transport',
                      ),
                    ),
                  );
                },
              ),
              _ServiceCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Shopping',
                subtitle: 'Local markets & malls',
                color: const Color(0xFFD2B48C), // Beige theme
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlacesListScreen(
                        category: 'shopping',
                        categoryTitle: 'Shopping',
                      ),
                    ),
                  );
                },
              ),
              _ServiceCard(
                icon: Icons.contact_emergency_outlined,
                title: 'Emergency Contacts',
                subtitle: 'Manage your contacts',
                color: const Color(0xFFC19A6B), // Secondary beige
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmergencyContactsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 16 : 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 12 : 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: isDesktop ? 24 : 20),
            ),
            SizedBox(height: isDesktop ? 8 : 6),
            Text(
              title,
              style: TextStyle(
                fontSize: isDesktop ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D3748),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isDesktop ? 4 : 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: isDesktop ? 12 : 10,
                color: const Color(0xFF718096),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencySOSCard extends StatefulWidget {
  @override
  _EmergencySOSCardState createState() => _EmergencySOSCardState();
}

class _EmergencySOSCardState extends State<_EmergencySOSCard> {
  Timer? _timer;
  int _countdown = 3;
  bool _isPressed = false;
  bool _sosTriggered = false;

  // Audio players for sound effects
  final AudioPlayer _buzzerPlayer = AudioPlayer();
  final AudioPlayer _sentPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // Preload sound assets
    _loadSounds();
  }

  Future<void> _loadSounds() async {
    try {
      // Set buzzer to loop mode
      await _buzzerPlayer.setReleaseMode(ReleaseMode.loop);
      // Set alert sent to play once
      await _sentPlayer.setReleaseMode(ReleaseMode.stop);
      print('Sound assets loaded successfully');
    } catch (e) {
      print('Error loading sounds: $e');
    }
  }

  void _startSOS() {
    setState(() {
      _isPressed = true;
      _countdown = 3;
      _sosTriggered = false;
    });

    // Start playing buzzer sound on loop
    _buzzerPlayer.play(AssetSource('sounds/alarm_buzzer.mp3'));
    print('Buzzer started');

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
      });

      if (_countdown <= 0) {
        _triggerSOS();
        timer.cancel();
      }
    });
  }

  void _cancelSOS() {
    _timer?.cancel();
    // Stop buzzer sound
    _buzzerPlayer.stop();
    print('Buzzer stopped');
    setState(() {
      _isPressed = false;
      _countdown = 3;
    });
  }

  @override
  void dispose() {
    // Clean up audio resources
    _buzzerPlayer.dispose();
    _sentPlayer.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _triggerSOS() {
    // Stop buzzer sound
    _buzzerPlayer.stop();
    print('Buzzer stopped, alert triggered');

    setState(() {
      _sosTriggered = true;
      _isPressed = false;
    });

    // Play sent sound
    _sentPlayer.play(AssetSource('sounds/alert_sent.mp3'));
    print('Alert sent sound played');

    // Send SOS alert
    _sendSOSAlert();

    // Reset after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _sosTriggered = false;
        });
      }
    });
  }

  Future<void> _sendSOSAlert() async {
    // Show immediate feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚨 Sending Emergency Alert...'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // Send enhanced SOS alert using emergency service - Pass context!
      final alert_service.EmergencyAlertService emergencyService =
          alert_service.EmergencyAlertService();
      final result = await emergencyService.sendSOSAlert(
        'Emergency SOS triggered from Raahi Safety App - Immediate assistance required!',
        context, // Pass the context to enable interactive dialog approach
      );

      if (result['success']) {
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ SOS ALERT SENT!\n'
              '${result['contactsNotified']} emergency contacts notified\n'
              'Location shared: ${result['location'] ? 'Yes' : 'No'}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        // Show detailed results dialog
        _showAlertResultsDialog(result);
      } else {
        // Show error feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Alert failed: ${result['error'] ?? 'Unknown error'}',
            ),
            backgroundColor: const Color(0xFFD2B48C), // Warm beige
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Fallback error handling
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Emergency alert failed: $e'),
          backgroundColor: const Color(0xFFD2B48C), // Warm beige
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showAlertResultsDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Emergency Alert Sent'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ ${result['contactsNotified']} contacts notified'),
              const SizedBox(height: 8),
              if (result['successfulContacts'].isNotEmpty) ...[
                const Text(
                  '📞 Contacts reached:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...result['successfulContacts'].map<Widget>(
                  (contact) =>
                      Text('• $contact', style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 8),
              ],
              if (result['failedContacts'].isNotEmpty) ...[
                const Text(
                  '⚠️ Failed contacts:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...result['failedContacts'].map<Widget>(
                  (contact) =>
                      Text('• $contact', style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                '📍 Location: ${result['location'] ? 'Shared' : 'Unavailable'}',
              ),
              const SizedBox(height: 8),
              const Text('🕒 Alert ID: ', style: TextStyle(fontSize: 10)),
              Text(
                result['alertId'] ?? 'Unknown',
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showEmergencyActions();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'More Actions',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEmergencyActions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Emergency Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _EmergencyActionButton(
                icon: Icons.phone,
                text: 'Call Police (100)',
                color: Colors.blue,
                onPressed: () => _makeEmergencyCall('100'),
              ),
              _EmergencyActionButton(
                icon: Icons.local_hospital,
                text: 'Call Medical (108)',
                color: Colors.red,
                onPressed: () => _makeEmergencyCall('108'),
              ),
              _EmergencyActionButton(
                icon: Icons.help,
                text: 'Tourist Helpline (1363)',
                color: Colors.green,
                onPressed: () => _makeEmergencyCall('1363'),
              ),
              _EmergencyActionButton(
                icon: Icons.location_on,
                text: 'Share Location Again',
                color: Colors.orange,
                onPressed: () => _shareLocationAgain(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _makeEmergencyCall(String number) async {
    Navigator.of(context).pop(); // Close bottom sheet
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not make call: $e')));
    }
  }

  Future<void> _shareLocationAgain() async {
    Navigator.of(context).pop(); // Close bottom sheet
    final alert_service.EmergencyAlertService emergencyService =
        alert_service.EmergencyAlertService();
    await emergencyService.shareLocation(
      'Follow-up location sharing after SOS alert',
      context, // Pass the context to enable interactive dialog approach
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📍 Location shared again with emergency contacts'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Dispose method moved down to include audio resources

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    final buttonSize = isDesktop ? 120.0 : 100.0;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Emergency SOS',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3748),
            ),
          ),
          SizedBox(height: isDesktop ? 20 : 16),
          GestureDetector(
            onLongPressStart: (_) => _startSOS(),
            onLongPressEnd: (_) => _cancelSOS(),
            onTap: () {
              // Short tap does nothing, must hold
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hold the button for 3 seconds to send SOS'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                color: _sosTriggered
                    ? Colors.green
                    : _isPressed
                    ? Colors.red.shade700
                    : const Color(0xFFE53E3E),
                shape: BoxShape.circle,
                boxShadow: _isPressed
                    ? [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_sosTriggered) ...[
                    const Icon(Icons.check, color: Colors.white, size: 40),
                    Text(
                      'SENT!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 12 : 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else if (_isPressed) ...[
                    Text(
                      '$_countdown',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 48 : 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 24 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'EMERGENCY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 12 : 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          Text(
            _isPressed
                ? 'Hold to send SOS alert...'
                : 'Press and hold for 3 seconds to send SOS alert',
            style: TextStyle(
              fontSize: isDesktop ? 14 : 12,
              color: _isPressed ? Colors.red : const Color(0xFF718096),
              fontWeight: _isPressed ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmergencyActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  const _EmergencyActionButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 18),
          label: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 3,
          ),
        ),
      ),
    );
  }
}

class _EmergencyContactsCard extends StatefulWidget {
  @override
  State<_EmergencyContactsCard> createState() => _EmergencyContactsCardState();
}

class _EmergencyContactsCardState extends State<_EmergencyContactsCard> {
  final alert_service.EmergencyAlertService emergencyService =
      alert_service.EmergencyAlertService();
  List<db_contact.EmergencyContact> _savedContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedContacts();
  }

  Future<void> _loadSavedContacts() async {
    try {
      final authService = SupabaseAuthService();
      final currentUser = await authService.getCurrentUser();

      if (currentUser != null) {
        final dataService = SupabaseDataService();
        final contacts = await dataService.getEmergencyContacts(currentUser.id);

        setState(() {
          _savedContacts = contacts;
          _isLoading = false;
        });

        print(
          '📞 Loaded ${contacts.length} saved emergency contacts for Safety Emergency page',
        );
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading emergency contacts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Emergency Contacts',
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  // Navigate to Emergency Contacts screen in Overview
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmergencyContactsScreen(),
                    ),
                  );
                  // Refresh contacts if something was added/changed
                  if (result == true) {
                    _loadSavedContacts();
                  }
                },
                icon: const Icon(Icons.manage_accounts, size: 18),
                label: Text(isDesktop ? 'Manage Contacts' : 'Manage'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3182CE),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 16 : 12,
                    vertical: isDesktop ? 12 : 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 20 : 16),

          // Emergency Service Contacts (Fixed)
          _ContactItem(
            name: 'Police Emergency',
            number: '100',
            icon: Icons.local_police_outlined,
            isEmergencyService: true,
          ),
          _ContactItem(
            name: 'Medical Emergency',
            number: '108',
            icon: Icons.medical_services_outlined,
            isEmergencyService: true,
          ),
          _ContactItem(
            name: 'Distress Number',
            number: '121',
            icon: Icons.emergency_outlined,
            isEmergencyService: true,
          ),
          _ContactItem(
            name: 'Tourist Helpline',
            number: '1363',
            icon: Icons.support_agent_outlined,
            isEmergencyService: true,
          ),

          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ] else ...[
            // Saved Personal Emergency Contacts from Database
            if (_savedContacts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Your Emergency Contacts',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A5568),
                ),
              ),
              const SizedBox(height: 8),
              ..._savedContacts.map(
                (contact) => _ContactItem(
                  name: contact.name,
                  number: contact.phoneNumber,
                  icon: _getContactIcon(contact.relationship),
                  isEmergencyService: false,
                  onDelete:
                      null, // Remove edit/delete from Safety Emergency page
                  onEdit: null,
                ),
              ),
            ],

            if (_savedContacts.isEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.contacts_outlined, color: Colors.blue, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'No personal emergency contacts found',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add emergency contacts in Overview page to see them here for quick SOS alerts',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  IconData _getContactIcon(String relationship) {
    switch (relationship.toLowerCase()) {
      case 'father':
      case 'dad':
        return Icons.man;
      case 'mother':
      case 'mom':
        return Icons.woman;
      case 'family':
        return Icons.family_restroom_outlined;
      case 'friend':
        return Icons.person_outline;
      case 'spouse':
      case 'husband':
      case 'wife':
        return Icons.favorite_outline;
      default:
        return Icons.contact_phone_outlined;
    }
  }
}

class _ContactItem extends StatelessWidget {
  final String name;
  final String number;
  final IconData icon;
  final bool isEmergencyService;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _ContactItem({
    required this.name,
    required this.number,
    required this.icon,
    this.isEmergencyService = false,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Padding(
      padding: EdgeInsets.only(bottom: isDesktop ? 12 : 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF3182CE), size: isDesktop ? 20 : 18),
          SizedBox(width: isDesktop ? 12 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: isDesktop ? 14 : 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                Text(
                  number,
                  style: TextStyle(
                    fontSize: isDesktop ? 12 : 11,
                    color: const Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Only show call button - no edit/delete for Safety Emergency page
              IconButton(
                onPressed: () => _makePhoneCall(context, number),
                icon: Icon(
                  Icons.call,
                  color: const Color(0xFF38A169),
                  size: isDesktop ? 20 : 18,
                ),
                padding: EdgeInsets.all(isDesktop ? 8 : 6),
                tooltip: 'Call $name',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    // Clean the phone number (remove spaces and special characters except +)
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    try {
      // First try CALL action (direct call)
      final Uri callUri = Uri.parse('tel:$cleanNumber');
      bool launched = await launchUrl(
        callUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // If CALL fails, try DIAL action (opens dialer)
        final Uri dialUri = Uri.parse('tel:$cleanNumber');
        launched = await launchUrl(dialUri, mode: LaunchMode.platformDefault);
      }

      if (!launched) {
        // Last resort - try different URL format
        final Uri legacyUri = Uri(scheme: 'tel', path: cleanNumber);
        launched = await launchUrl(legacyUri);
      }

      if (!launched) {
        throw 'Phone app not available';
      }
    } catch (e) {
      // Handle error - show snackbar with helpful message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open phone app. Please dial $cleanNumber manually.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }
}

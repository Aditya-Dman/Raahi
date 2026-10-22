import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math' as math;

import 'digital_id_screen.dart';
import 'emergency_contacts_screen.dart';
import 'login_page.dart';
import 'rahi_chat_screen.dart';
import 'services/emergency_alert_service.dart' as alert_service;
import 'services/user_session.dart' as user_session;
import 'widgets/language_selection_widget.dart';
import 'widgets/simple_map_widget.dart';
import 'app_theme.dart';
import 'emergency_history_screen.dart';
import 'privacy_security_screen.dart';
import 'services/role_access.dart';
import 'l10n/app_localizations.dart';

String _text(BuildContext context, String english, String hindi) =>
    Localizations.localeOf(context).languageCode == 'hi' ? hindi : english;

String _roleLabel(RaahiRole role, bool isHindi) {
  if (!isHindi) return RoleAccess.label(role);
  return switch (role) {
    RaahiRole.tourist => 'पर्यटक',
    RaahiRole.emergencyResponder => 'आपातकालीन प्रत्युत्तरकर्ता',
    RaahiRole.policeOfficer => 'पुलिस अधिकारी',
    RaahiRole.tourismOfficer => 'पर्यटन अधिकारी',
    RaahiRole.administrator => 'प्रशासक',
  };
}

String _roleDescription(RaahiRole role, bool isHindi) {
  if (!isHindi) return RoleAccess.description(role);
  return switch (role) {
    RaahiRole.tourist => 'व्यक्तिगत सुरक्षा उपकरण और आपका अपना सुरक्षा डेटा।',
    RaahiRole.emergencyResponder =>
      'सौंपे गए आपातकालीन अलर्ट और प्रतिक्रिया इतिहास।',
    RaahiRole.policeOfficer => 'अधिकृत सुरक्षा घटनाएँ और अलर्ट इतिहास।',
    RaahiRole.tourismOfficer => 'पर्यटन सुरक्षा रुझान और समेकित जानकारी।',
    RaahiRole.administrator => 'सिस्टम प्रबंधन और अधिकृत सुरक्षा रिकॉर्ड।',
  };
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool _isSendingAlert = false;
  bool _isOffline = false;
  bool _isShakeDialogVisible = false;
  DateTime? _lastShakePrompt;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _watchConnectivity();
    _watchForShake();
  }

  void _watchForShake() {
    _accelerometerSubscription = userAccelerometerEventStream().listen(
      (event) {
        if (!mounted || _isSendingAlert || _isShakeDialogVisible) return;
        final magnitude = math.sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );
        final lastPrompt = _lastShakePrompt;
        if (magnitude < 15 ||
            lastPrompt != null &&
                DateTime.now().difference(lastPrompt) <
                    const Duration(seconds: 3)) {
          return;
        }
        _lastShakePrompt = DateTime.now();
        _showShakeSosConfirmation();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Shake detection unavailable: $error');
      },
    );
  }

  Future<void> _showShakeSosConfirmation() async {
    if (!mounted || _isShakeDialogVisible) return;
    _isShakeDialogVisible = true;
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isHindi ? 'SOS भेजें?' : 'Send SOS?'),
        content: Text(
          isHindi
              ? 'फोन हिलाया गया है। क्या आप अपने आपातकालीन संपर्कों को SOS भेजना चाहते हैं?'
              : 'Your phone was shaken. Do you want to send an SOS alert to your emergency contacts?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isHindi ? 'नहीं, मैं सुरक्षित हूँ' : "No, I'm safe"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isHindi ? 'हाँ, SOS भेजें' : 'Yes, send SOS'),
          ),
        ],
      ),
    );
    _isShakeDialogVisible = false;
    if (!mounted) return;
    if (shouldSend == true) {
      await _sendAlert(alert_service.AlertType.sos, shakeTriggered: true);
    } else {
      _showShakeCancellationMessage();
    }
  }

  void _showShakeCancellationMessage() {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isHindi ? 'SOS भेजना रद्द किया गया।' : 'SOS sending cancelled.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _watchConnectivity() async {
    final connectivity = Connectivity();
    final current = await connectivity.checkConnectivity();
    _setConnectivity(current);
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      _setConnectivity,
    );
  }

  void _setConnectivity(List<ConnectivityResult> results) {
    final offline =
        results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
    if (!mounted) return;
    setState(() => _isOffline = offline);
    if (!offline) {
      alert_service.EmergencyAlertService().flushQueuedAlerts(context);
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (!mounted || status.isGranted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _text(
            context,
            'Allow location access to use GPS tracking and sharing.',
            'GPS ट्रैकिंग और स्थान साझा करने के लिए स्थान की अनुमति दें।',
          ),
        ),
      ),
    );
  }

  void _select(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final titles = [
      l10n.dashboard,
      l10n.gps,
      l10n.safetyEmergency,
      l10n.digitalId,
      l10n.emergencyContact,
    ];
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.language,
            icon: const Icon(Icons.language_rounded),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const LanguageSelectionDialog(),
            ),
          ),
          title: Text(titles[_selectedIndex]),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'logout') {
                  await user_session.UserSession.logout();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'logout',
                  child: Text(isHindi ? 'लॉग आउट' : 'Sign out'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isOffline)
              Material(
                color: const Color(0xFFFFF1F2),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isHindi
                              ? 'ऑफ़लाइन सुरक्षा मोड: मार्ग और आपातकालीन कार्रवाइयाँ स्थानीय रूप से कतार में रखी जाएंगी।'
                              : 'Offline safety mode: route and emergency actions will be queued locally.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildHome(),
                  const _LocationPage(),
                  _buildEmergency(),
                  const DigitalIDScreen(),
                  const EmergencyContactsScreen(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _select,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: isHindi ? 'होम' : 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(Icons.location_on_rounded),
              label: 'GPS',
            ),
            NavigationDestination(
              icon: Icon(Icons.sos_outlined),
              selectedIcon: Icon(Icons.sos_rounded),
              label: 'SOS',
            ),
            NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge_rounded),
              label: isHindi ? 'आईडी' : 'ID',
            ),
            NavigationDestination(
              icon: Icon(Icons.contacts_outlined),
              selectedIcon: Icon(Icons.contacts_rounded),
              label: isHindi ? 'संपर्क' : 'Contacts',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHome() {
    final name = user_session.UserSession.getUserName();
    final role = RoleAccess.currentRole();
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _WelcomeCard(name: name, isHindi: isHindi),
        const SizedBox(height: 12),
        _RoleCard(role: role, isHindi: isHindi),
        if (RoleAccess.canReviewAssignedAlerts(role))
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: _RoleNotice(
              icon: Icons.assignment_outlined,
              title: 'Response workspace',
              message:
                  'Use this account for authorized emergency response and assigned incident follow-up.',
            ),
          ),
        if (RoleAccess.canManageUsers(role))
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: _RoleNotice(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Administrator workspace',
              message:
                  'System-management capabilities are limited to authorized administrator accounts.',
            ),
          ),
        const SizedBox(height: 20),
        Text(
          isHindi ? 'सुरक्षा उपकरण' : 'Safety tools',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.location_on_rounded,
                color: AppColors.sky,
                title: isHindi ? 'स्थान ट्रैक करें' : 'Track location',
                subtitle: isHindi
                    ? 'लाइव GPS मानचित्र खोलें'
                    : 'Open live GPS map',
                onTap: () => _select(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.sos_rounded,
                color: AppColors.danger,
                title: isHindi ? 'मदद लें' : 'Get help',
                subtitle: isHindi
                    ? 'आपातकालीन अलर्ट भेजें'
                    : 'Send an emergency alert',
                onTap: () => _select(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _WideAction(
          icon: Icons.badge_rounded,
          color: AppColors.teal,
          title: isHindi ? 'डिजिटल पर्यटक पहचान' : 'Digital tourist identity',
          subtitle: isHindi
              ? 'अपनी सत्यापित यात्रा पहचान दिखाने के लिए तैयार रखें।'
              : 'Keep your verified travel identity ready to show.',
          onTap: () => _select(3),
        ),
        const SizedBox(height: 12),
        _WideAction(
          icon: Icons.smart_toy_rounded,
          color: const Color(0xFF6558C8),
          title: isHindi ? 'AI यात्रा सहायक' : 'AI travel assistant',
          subtitle: isHindi
              ? 'यात्रा और सुरक्षा से जुड़े प्रश्न पूछें।'
              : 'Ask travel and safety questions.',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const RahiChatScreen())),
        ),
        const SizedBox(height: 12),
        _WideAction(
          icon: Icons.privacy_tip_outlined,
          color: AppColors.navy,
          title: isHindi ? 'गोपनीयता और सुरक्षा' : 'Privacy & security',
          subtitle: isHindi
              ? 'देखें कि Raahi आपकी सुरक्षा जानकारी को कैसे संभालता है।'
              : 'Review how Raahi handles your safety information.',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => PrivacySecurityScreen())),
        ),
        const SizedBox(height: 20),
        _InfoCard(
          icon: Icons.shield_outlined,
          title: isHindi
              ? 'Raahi के साथ सुरक्षित यात्रा करें'
              : 'Travel safely with Raahi',
          text: isHindi
              ? 'GPS चालू रखें, विश्वसनीय आपातकालीन संपर्क जोड़ें और तुरंत मदद के लिए SOS का उपयोग करें।'
              : 'Keep GPS enabled, add trusted emergency contacts, and use SOS when you need immediate help.',
        ),
      ],
    );
  }

  Widget _buildEmergency() {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text(
          isHindi
              ? 'अपनी स्थिति के अनुसार सही अलर्ट चुनें।'
              : 'Choose the alert that best describes your situation.',
          style: TextStyle(fontSize: 16, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 18),
        _EmergencyButton(
          label: isHindi ? 'SOS आपातकाल' : 'SOS emergency',
          description: isHindi
              ? 'अपने वर्तमान स्थान के साथ तत्काल अलर्ट भेजें।'
              : 'Send an urgent alert with your current location.',
          icon: Icons.sos_rounded,
          color: AppColors.danger,
          onPressed: () => _sendAlert(alert_service.AlertType.sos),
        ),
        _EmergencyButton(
          label: isHindi ? 'चिकित्सीय सहायता' : 'Medical assistance',
          description: isHindi
              ? 'चिकित्सीय आपातकाल के लिए सहायता मांगें।'
              : 'Request help for a medical emergency.',
          icon: Icons.medical_services_rounded,
          color: const Color(0xFFC45A28),
          onPressed: () => _sendAlert(alert_service.AlertType.medical),
        ),
        _EmergencyButton(
          label: isHindi ? 'सुरक्षा सहायता' : 'Security assistance',
          description: isHindi
              ? 'सुरक्षा संबंधी समस्या की रिपोर्ट करें।'
              : 'Report a safety or security concern.',
          icon: Icons.security_rounded,
          color: const Color(0xFF6558C8),
          onPressed: () => _sendAlert(alert_service.AlertType.security),
        ),
        _EmergencyButton(
          label: isHindi ? 'मेरा स्थान साझा करें' : 'Share my location',
          description: isHindi
              ? 'अपना वर्तमान स्थान संपर्कों को भेजें।'
              : 'Send your current location to your contacts.',
          icon: Icons.share_location_rounded,
          color: AppColors.sky,
          onPressed: () => _sendAlert(alert_service.AlertType.location),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _select(4),
          icon: const Icon(Icons.contacts_outlined),
          label: Text(
            isHindi
                ? 'आपातकालीन संपर्क प्रबंधित करें'
                : 'Manage emergency contacts',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EmergencyHistoryScreen()),
          ),
          icon: const Icon(Icons.history_rounded),
          label: Text(
            isHindi ? 'आपातकालीन इतिहास देखें' : 'View emergency history',
          ),
        ),
      ],
    );
  }

  Future<void> _sendAlert(
    alert_service.AlertType type, {
    bool shakeTriggered = false,
  }) async {
    if (_isSendingAlert) return;
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final shouldSend = shakeTriggered
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(
                isHindi
                    ? 'आपातकालीन अलर्ट की पुष्टि करें'
                    : 'Confirm emergency alert',
              ),
              content: Text(switch (type) {
                alert_service.AlertType.sos =>
                  isHindi
                      ? 'यह आपके आपातकालीन संपर्कों के लिए तत्काल SOS अलर्ट तैयार करेगा।'
                      : 'This will prepare an urgent SOS alert for your emergency contacts.',
                alert_service.AlertType.medical =>
                  isHindi
                      ? 'यह आपके संपर्कों के लिए चिकित्सीय सहायता अलर्ट तैयार करेगा।'
                      : 'This will prepare a medical assistance alert for your contacts.',
                alert_service.AlertType.security =>
                  isHindi
                      ? 'यह आपके संपर्कों के लिए सुरक्षा सहायता अलर्ट तैयार करेगा।'
                      : 'This will prepare a security assistance alert for your contacts.',
                alert_service.AlertType.location =>
                  isHindi
                      ? 'यह आपका वर्तमान स्थान आपके संपर्कों के साथ साझा करेगा।'
                      : 'This will share your current location with your contacts.',
              }),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(isHindi ? 'जारी रखें' : 'Continue'),
                ),
              ],
            ),
          );
    if (shouldSend != true || !mounted) return;
    if (_isOffline) {
      await alert_service.EmergencyAlertService().queueAlert(type);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHindi
                  ? 'ऑफ़लाइन: कनेक्शन वापस आने तक अलर्ट कतार में रखा गया है।'
                  : 'Offline: alert queued for connection recovery.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _isSendingAlert = true);
    final service = alert_service.EmergencyAlertService();
    late final Map<String, dynamic> result;
    switch (type) {
      case alert_service.AlertType.sos:
        result = await service.sendSOSAlert('', context);
      case alert_service.AlertType.medical:
        result = await service.sendMedicalAlert('', context);
      case alert_service.AlertType.security:
        result = await service.sendSecurityAlert('', context);
      case alert_service.AlertType.location:
        result = await service.shareLocation('', context);
    }
    if (!mounted) return;
    setState(() => _isSendingAlert = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? (result['message'] as String? ?? 'Alert sent.')
              : (result['error'] as String? ?? 'Could not send alert.'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }
}

class _LocationPage extends StatelessWidget {
  const _LocationPage();

  @override
  Widget build(BuildContext context) {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              Icon(Icons.my_location_rounded),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  isHindi
                      ? 'यह स्क्रीन खुली रहने तक लाइव GPS ट्रैकिंग सक्रिय है।'
                      : 'Live GPS tracking is active while this screen is open.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: SimpleMapWidget()),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String name;
  final bool isHindi;

  const _WelcomeCard({required this.name, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyDeep, AppColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(Icons.shield_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHindi ? 'वापसी पर स्वागत है' : 'Welcome back',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  name.isEmpty ? (isHindi ? 'यात्री' : 'Traveller') : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isHindi
                      ? 'हर यात्रा में आपका सुरक्षा साथी।'
                      : 'Your safety companion on every journey.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final RaahiRole role;
  final bool isHindi;

  const _RoleCard({required this.role, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.navy,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.white24,
          child: Icon(Icons.verified_user_outlined, color: Colors.white),
        ),
        title: Text(
          _roleLabel(role, isHindi),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          _roleDescription(role, isHindi),
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

class _RoleNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _RoleNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.teal.withValues(alpha: 0.08),
      child: ListTile(
        leading: Icon(icon, color: AppColors.teal),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(message),
      ),
    );
  }
}

class _WideAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WideAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.canvas,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(text, style: const TextStyle(color: Color(0xFF475569))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _EmergencyButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(description),
        trailing: IconButton(
          tooltip: label,
          onPressed: onPressed,
          icon: Icon(Icons.arrow_forward_rounded, color: color),
        ),
      ),
    );
  }
}

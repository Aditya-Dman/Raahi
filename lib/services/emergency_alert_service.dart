import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'supabase_data_service.dart';
import 'supabase_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;
  final ContactType type;

  EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
    required this.type,
  });
}

enum ContactType { police, hospital, embassy, personalContact, touristHelpline }

enum AlertType { sos, medical, security, location }

class EmergencyAlert {
  final String id;
  final DateTime timestamp;
  final Position? location;
  final AlertType type;
  final String message;
  final String userId;
  final bool isActive;
  final String status;
  final int contactsNotified;

  EmergencyAlert({
    required this.id,
    required this.timestamp,
    this.location,
    required this.type,
    required this.message,
    required this.userId,
    this.isActive = true,
    this.status = 'created',
    this.contactsNotified = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'latitude': location?.latitude,
      'longitude': location?.longitude,
      'type': type.toString(),
      'message': message,
      'userId': userId,
      'isActive': isActive,
      'status': status,
      'contactsNotified': contactsNotified,
    };
  }

  EmergencyAlert copyWith({String? status, int? contactsNotified}) {
    return EmergencyAlert(
      id: id,
      timestamp: timestamp,
      location: location,
      type: type,
      message: message,
      userId: userId,
      isActive: isActive,
      status: status ?? this.status,
      contactsNotified: contactsNotified ?? this.contactsNotified,
    );
  }

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) {
    final typeName = (json['type'] as String? ?? 'AlertType.sos')
        .split('.')
        .last;
    final type = AlertType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => AlertType.sos,
    );
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    return EmergencyAlert(
      id: json['id'] as String? ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      location: latitude == null || longitude == null
          ? null
          : Position(
              latitude: latitude,
              longitude: longitude,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            ),
      type: type,
      message: json['message'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      status: json['status'] as String? ?? 'created',
      contactsNotified: (json['contactsNotified'] as num?)?.toInt() ?? 0,
    );
  }
}

class EmergencyAlertService {
  static const MethodChannel _smsChannel = MethodChannel(
    'com.example.raahi/emergency_sms',
  );
  static const MethodChannel _emergencyCallChannel = MethodChannel(
    'com.example.raahi/emergency_call',
  );
  static final EmergencyAlertService _instance =
      EmergencyAlertService._internal();
  factory EmergencyAlertService() => _instance;
  EmergencyAlertService._internal();

  // Predefined emergency contacts for tourists in India
  final List<EmergencyContact> _defaultContacts = [
    EmergencyContact(
      name: 'Police Emergency',
      phone: '100',
      relationship: 'Emergency Services',
      type: ContactType.police,
    ),
    EmergencyContact(
      name: 'Medical Emergency',
      phone: '108',
      relationship: 'Emergency Services',
      type: ContactType.hospital,
    ),
    EmergencyContact(
      name: 'Tourist Helpline',
      phone: '1363',
      relationship: 'Tourist Support',
      type: ContactType.touristHelpline,
    ),
    EmergencyContact(
      name: 'Fire Emergency',
      phone: '101',
      relationship: 'Emergency Services',
      type: ContactType.police,
    ),
    EmergencyContact(
      name: 'Women Helpline',
      phone: '1091',
      relationship: 'Emergency Services',
      type: ContactType.police,
    ),
  ];

  // User's personal emergency contacts
  final List<EmergencyContact> _personalContacts = [];

  // Alert history
  final List<EmergencyAlert> _alertHistory = [];
  static const _historyKey = 'raahi_emergency_history';
  static const _queueKey = 'raahi_queued_alerts';
  static const _contactsKey = 'raahi_cached_emergency_contacts';

  // Getters
  List<EmergencyContact> get defaultContacts => _defaultContacts;
  List<EmergencyContact> get personalContacts => _personalContacts;
  List<EmergencyContact> get allContacts => [
    ..._defaultContacts,
    ..._personalContacts,
  ];
  List<EmergencyAlert> get alertHistory => _alertHistory;

  Future<void> loadAlertHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_historyKey);
    if (encoded == null) return;
    try {
      final decoded = jsonDecode(encoded) as List;
      _alertHistory
        ..clear()
        ..addAll(
          decoded.map(
            (item) => EmergencyAlert.fromJson(item as Map<String, dynamic>),
          ),
        );
    } catch (_) {
      await preferences.remove(_historyKey);
    }
  }

  Future<void> _persistAlertHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _historyKey,
      jsonEncode(_alertHistory.map((alert) => alert.toJson()).toList()),
    );
  }

  Future<void> queueAlert(AlertType type, {String additionalInfo = ''}) async {
    final preferences = await SharedPreferences.getInstance();
    final queued = preferences.getStringList(_queueKey) ?? [];
    queued.add(
      jsonEncode({
        'type': type.name,
        'additionalInfo': additionalInfo,
        'queuedAt': DateTime.now().toIso8601String(),
      }),
    );
    await preferences.setStringList(_queueKey, queued);
  }

  Future<int> queuedAlertCount() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_queueKey) ?? []).length;
  }

  Future<void> flushQueuedAlerts(BuildContext context) async {
    final preferences = await SharedPreferences.getInstance();
    final queued = preferences.getStringList(_queueKey) ?? [];
    if (queued.isEmpty) return;
    final remaining = <String>[];
    for (final encoded in queued) {
      try {
        final item = jsonDecode(encoded) as Map<String, dynamic>;
        final type = AlertType.values.firstWhere(
          (value) => value.name == item['type'],
          orElse: () => AlertType.sos,
        );
        final result = await sendEmergencyAlert(
          type: type,
          additionalInfo: item['additionalInfo'] as String? ?? '',
          context: context,
        );
        if (result['success'] != true) remaining.add(encoded);
      } catch (_) {
        remaining.add(encoded);
      }
    }
    if (remaining.isEmpty) {
      await preferences.remove(_queueKey);
    } else {
      await preferences.setStringList(_queueKey, remaining);
    }
  }

  Future<List<EmergencyContact>> loadCachedPersonalContacts() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getStringList(_contactsKey) ?? [];
    return encoded
        .map((value) {
          try {
            final map = jsonDecode(value) as Map<String, dynamic>;
            return EmergencyContact(
              name: map['name'] as String? ?? '',
              phone: map['phone'] as String? ?? '',
              relationship: map['relationship'] as String? ?? '',
              type: ContactType.personalContact,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<EmergencyContact>()
        .toList();
  }

  Future<void> _cachePersonalContacts(List<EmergencyContact> contacts) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _contactsKey,
      contacts
          .map(
            (contact) => jsonEncode({
              'name': contact.name,
              'phone': contact.phone,
              'relationship': contact.relationship,
            }),
          )
          .toList(),
    );
  }

  // Add personal emergency contact
  void addPersonalContact(EmergencyContact contact) {
    _personalContacts.add(contact);
    print('Added emergency contact: ${contact.name} (${contact.phone})');
    print('Total personal contacts: ${_personalContacts.length}');
  }

  // Load personal emergency contacts from database
  Future<void> loadPersonalContactsFromDatabase() async {
    try {
      print('🔧 Loading personal contacts from database...');

      // Get current user
      final authService = SupabaseAuthService();
      final currentUser = await authService.getCurrentUser();

      if (currentUser == null) {
        print('❌ No authenticated user found, cannot load personal contacts');
        return;
      }

      // Get saved emergency contacts from database
      final dataService = SupabaseDataService();
      final savedContacts = await dataService.getEmergencyContacts(
        currentUser.id,
      );

      print(
        '📞 Found ${savedContacts.length} saved emergency contacts in database',
      );

      // Clear existing personal contacts to avoid duplicates
      _personalContacts.clear();

      // Convert database contacts to EmergencyContact objects
      for (var dbContact in savedContacts) {
        final emergencyContact = EmergencyContact(
          name: dbContact.name,
          phone: dbContact.phoneNumber,
          relationship: dbContact.relationship,
          type: ContactType.personalContact, // All saved contacts are personal
        );
        _personalContacts.add(emergencyContact);
        print('✅ Loaded contact: ${dbContact.name} - ${dbContact.phoneNumber}');
      }
      await _cachePersonalContacts(_personalContacts);

      print('🎯 Total personal contacts loaded: ${_personalContacts.length}');
    } catch (e) {
      print('❌ Error loading personal contacts from database: $e');
    }
  }

  // Remove personal emergency contact
  void removePersonalContact(String phone) {
    _personalContacts.removeWhere((contact) => contact.phone == phone);
    print('Removed emergency contact: $phone');
    print('Total personal contacts: ${_personalContacts.length}');
  }

  // Generate location message
  String _generateLocationMessage(Position? location) {
    if (location == null) {
      return "Location unavailable";
    }

    return "Current Location:\n"
        "Latitude: ${location.latitude.toStringAsFixed(6)}\n"
        "Longitude: ${location.longitude.toStringAsFixed(6)}\n"
        "Accuracy: ${location.accuracy.toStringAsFixed(1)}m\n"
        "Time: ${DateTime.now().toString().substring(0, 19)}\n"
        "Google Maps: https://maps.google.com/?q=${location.latitude},${location.longitude}";
  }

  // Create emergency alert message
  String _createAlertMessage(
    AlertType type,
    Position? location,
    String additionalInfo,
  ) {
    String baseMessage = "";

    switch (type) {
      case AlertType.sos:
        baseMessage =
            "EMERGENCY SOS ALERT\n\n"
            "A tourist is in distress and needs immediate assistance!\n\n"
            "Tourist ID: ${_generateTouristId()}\n"
            "Alert Type: Emergency SOS\n"
            "Time: ${DateTime.now().toString().substring(0, 19)}\n\n";
        break;
      case AlertType.medical:
        baseMessage =
            "MEDICAL EMERGENCY ALERT\n\n"
            "Medical assistance required for tourist!\n\n"
            "Tourist ID: ${_generateTouristId()}\n"
            "Alert Type: Medical Emergency\n"
            "Time: ${DateTime.now().toString().substring(0, 19)}\n\n";
        break;
      case AlertType.security:
        baseMessage =
            "SECURITY ALERT\n\n"
            "Tourist safety concern reported!\n\n"
            "Tourist ID: ${_generateTouristId()}\n"
            "Alert Type: Security Issue\n"
            "Time: ${DateTime.now().toString().substring(0, 19)}\n\n";
        break;
      case AlertType.location:
        baseMessage =
            "LOCATION SHARING\n\n"
            "Tourist location shared for safety tracking.\n\n"
            "Tourist ID: ${_generateTouristId()}\n"
            "Alert Type: Location Update\n"
            "Time: ${DateTime.now().toString().substring(0, 19)}\n\n";
        break;
    }

    return "$baseMessage${_generateLocationMessage(location)}${additionalInfo.isNotEmpty ? "\n\nAdditional Info: $additionalInfo" : ""}\n\nThis is an automated alert from Raahi Tourist Safety App.";
  }

  // Generate unique tourist ID (simplified for now)
  String _generateTouristId() {
    // In real implementation, this would be from blockchain-based ID system
    return "T${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
  }

  // Make emergency call
  Future<bool> _makeEmergencyCall(String phone) async {
    try {
      final permission = await Permission.phone.request();
      if (!permission.isGranted) return false;
      final result = await _emergencyCallChannel.invokeMethod<bool>(
        'callEmergencyNumber',
        {'phone': phone},
      );
      return result ?? false;
    } catch (e) {
      print('Error making emergency call: $e');
      return false;
    }
  }

  // Get current location
  Future<Position?> _getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting location: $e');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (e2) {
        print('Error getting last known location: $e2');
        return null;
      }
    }
  }

  // ENHANCED SMS sending - Improved user experience
  Future<bool> _sendSmsAutomatic(String phone, String message) async {
    try {
      final result = await _smsChannel.invokeMethod<bool>('sendSms', {
        'phone': phone,
        'message': message,
      });
      return result ?? false;
    } catch (e) {
      print('Direct SMS failed for $phone: $e');
      return false;
    }
  }

  // Send emergency alert to all contacts - TRUE AUTOMATIC IMPLEMENTATION
  Future<Map<String, dynamic>> sendEmergencyAlert({
    required AlertType type,
    String additionalInfo = '',
    List<ContactType>? specificContactTypes,
    bool includeSms = true,
    bool includeCall = false,
    BuildContext? context,
  }) async {
    try {
      // Load saved emergency contacts from database before sending alerts
      await loadPersonalContactsFromDatabase();

      // Track our progress
      bool isProgressDialogShowing = false;
      BuildContext? dialogContext;

      // Get current location
      Position? currentLocation = await _getCurrentLocation();

      // Create alert message
      String alertMessage = _createAlertMessage(
        type,
        currentLocation,
        additionalInfo,
      );

      // Create shorter message version for SMS
      String shortMessage =
          "SOS EMERGENCY ALERT! Tourist in distress needs immediate help! "
          "Location: https://maps.google.com/?q=${currentLocation?.latitude ?? 28.6139},${currentLocation?.longitude ?? 77.2090}";

      // Create alert record
      EmergencyAlert alert = EmergencyAlert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        location: currentLocation,
        type: type,
        message: alertMessage,
        userId: _generateTouristId(),
      );

      // Add to history
      _alertHistory.insert(0, alert);
      await _persistAlertHistory();

      // Determine which contacts to notify
      List<EmergencyContact> contactsToNotify = allContacts;
      if (specificContactTypes != null) {
        contactsToNotify = allContacts
            .where((contact) => specificContactTypes.contains(contact.type))
            .toList();
      }

      // Filter for personal contacts for SMS
      List<EmergencyContact> personalContactsToNotify = contactsToNotify
          .where((contact) => contact.type == ContactType.personalContact)
          .toList();

      print('DEBUG: SOS Alert Analysis');
      print('Default contacts: ${_defaultContacts.length}');
      print('Personal contacts: ${_personalContacts.length}');
      print(
        'Total personal contacts to notify: ${personalContactsToNotify.length}',
      );

      // Show progress dialog if context is available
      if (context != null && personalContactsToNotify.isNotEmpty) {
        isProgressDialogShowing = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) {
            dialogContext = ctx;
            return AlertDialog(
              title: Row(
                children: const [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(width: 16),
                  Text('Sending SOS Alert'),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Contacting your emergency contacts...'),
                  SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            );
          },
        );
      }

      // Lists to track results
      List<String> successfulContacts = [];
      List<String> failedContacts = [];
      List<String> emergencyServicesReady = [];
      bool emergencyCallPlaced = false;

      if (includeSms && personalContactsToNotify.isNotEmpty) {
        final permission = await Permission.sms.request();
        if (!permission.isGranted) {
          failedContacts.addAll(
            personalContactsToNotify.map(
              (contact) => '${contact.name} (${contact.phone})',
            ),
          );
        }
      }

      // Try to send SMS to personal contacts automatically
      if (includeSms &&
          personalContactsToNotify.isNotEmpty &&
          failedContacts.isEmpty) {
        for (EmergencyContact contact in personalContactsToNotify) {
          bool success = await _sendSmsAutomatic(contact.phone, shortMessage);

          if (success) {
            successfulContacts.add('${contact.name} (${contact.phone})');
            print('Successfully initiated SMS to ${contact.name}');
          } else {
            failedContacts.add('${contact.name} (${contact.phone})');
            print('Failed to send SMS to ${contact.name}');
          }

          // Add small delay between messages
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      // Mark emergency services as ready
      for (EmergencyContact contact in contactsToNotify) {
        if (contact.type != ContactType.personalContact) {
          emergencyServicesReady.add('${contact.name} (${contact.phone})');
        }
      }

      // Auto-call police if requested
      if (includeCall) {
        for (EmergencyContact contact in contactsToNotify) {
          if (contact.type == ContactType.police) {
            emergencyCallPlaced =
                await _makeEmergencyCall(contact.phone) || emergencyCallPlaced;
          }
        }
      }

      if (type == AlertType.sos) {
        emergencyCallPlaced =
            await _makeEmergencyCall('112') || emergencyCallPlaced;
      }

      // Remove progress dialog if still showing
      if (isProgressDialogShowing && dialogContext != null) {
        Navigator.pop(dialogContext!);
      }

      // Vibrate device for feedback
      HapticFeedback.vibrate();

      final historyIndex = _alertHistory.indexWhere(
        (entry) => entry.id == alert.id,
      );
      if (historyIndex >= 0) {
        _alertHistory[historyIndex] = alert.copyWith(
          status: successfulContacts.isNotEmpty ? 'sent' : 'failed',
          contactsNotified: successfulContacts.length,
        );
        await _persistAlertHistory();
      }

      return {
        'success': successfulContacts.isNotEmpty,
        'alertId': alert.id,
        'contactsNotified': successfulContacts.length,
        'successfulContacts': successfulContacts,
        'failedContacts': failedContacts,
        'emergencyServicesReady': emergencyServicesReady,
        'emergencyCallPlaced': emergencyCallPlaced,
        'location': currentLocation != null,
        'message': successfulContacts.isNotEmpty
            ? emergencyCallPlaced
                  ? 'SOS sent to ${successfulContacts.length} contacts and 112 was called.'
                  : 'SOS Alert sent to ${successfulContacts.length} contacts!'
            : failedContacts.isNotEmpty
            ? emergencyCallPlaced
                  ? '112 was called, but SMS could not be sent to the saved contacts.'
                  : 'Could not send SMS to the saved emergency contacts. Check SMS permission, SIM service, and network.'
            : emergencyCallPlaced
            ? 'No saved personal emergency contacts were found. 112 was called.'
            : 'No saved personal emergency contacts were found.',
      };
    } catch (e) {
      print('Error sending emergency alert: $e');
      return {
        'success': false,
        'error': 'Failed to send emergency alert: $e',
        'contactsNotified': 0,
      };
    }
  }

  // Quick SOS alert with UI context
  Future<Map<String, dynamic>> sendSOSAlert([
    String additionalInfo = '',
    BuildContext? context,
  ]) async {
    return await sendEmergencyAlert(
      type: AlertType.sos,
      additionalInfo: additionalInfo,
      includeSms: true,
      includeCall: false,
      context: context,
    );
  }

  // Medical emergency alert
  Future<Map<String, dynamic>> sendMedicalAlert([
    String additionalInfo = '',
    BuildContext? context,
  ]) async {
    return await sendEmergencyAlert(
      type: AlertType.medical,
      additionalInfo: additionalInfo,
      specificContactTypes: [
        ContactType.hospital,
        ContactType.police,
        ContactType.personalContact,
      ],
      includeSms: true,
      includeCall: false,
      context: context,
    );
  }

  // Security alert
  Future<Map<String, dynamic>> sendSecurityAlert([
    String additionalInfo = '',
    BuildContext? context,
  ]) async {
    return await sendEmergencyAlert(
      type: AlertType.security,
      additionalInfo: additionalInfo,
      specificContactTypes: [
        ContactType.police,
        ContactType.touristHelpline,
        ContactType.personalContact,
      ],
      includeSms: true,
      includeCall: false,
      context: context,
    );
  }

  // Share location with contacts
  Future<Map<String, dynamic>> shareLocation([
    String additionalInfo = '',
    BuildContext? context,
  ]) async {
    return await sendEmergencyAlert(
      type: AlertType.location,
      additionalInfo: additionalInfo,
      includeSms: true,
      includeCall: false,
      context: context,
    );
  }

  // Clear alert history
  void clearAlertHistory() {
    _alertHistory.clear();
    SharedPreferences.getInstance().then((preferences) {
      preferences.remove(_historyKey);
    });
  }

  // Get nearest police station (mock implementation)
  EmergencyContact getNearestPoliceStation() {
    // In real implementation, this would use location to find nearest station
    return EmergencyContact(
      name: 'Nearest Police Station',
      phone: '100',
      relationship: 'Local Police',
      type: ContactType.police,
    );
  }
}

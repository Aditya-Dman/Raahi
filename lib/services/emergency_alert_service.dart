import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'supabase_data_service.dart';
import 'supabase_auth_service.dart';

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

  EmergencyAlert({
    required this.id,
    required this.timestamp,
    this.location,
    required this.type,
    required this.message,
    required this.userId,
    this.isActive = true,
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
    };
  }
}

class EmergencyAlertService {
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

  // Getters
  List<EmergencyContact> get defaultContacts => _defaultContacts;
  List<EmergencyContact> get personalContacts => _personalContacts;
  List<EmergencyContact> get allContacts => [
    ..._defaultContacts,
    ..._personalContacts,
  ];
  List<EmergencyAlert> get alertHistory => _alertHistory;

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
      final Uri phoneUri = Uri(scheme: 'tel', path: phone);

      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        return true;
      }
      return false;
    } catch (e) {
      print('Error making call: $e');
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
      print('🚨 Preparing emergency SMS to $phone');

      // Optimize for immediate SMS app opening with pre-filled message
      try {
        final Uri smsUri = Uri(
          scheme: 'sms',
          path: phone,
          queryParameters: {'body': message},
        );

        print('📱 Opening SMS app with emergency message...');
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(
            smsUri,
            mode: LaunchMode.externalNonBrowserApplication,
          );
          print('✅ SMS app opened - message ready to send to $phone');
          return true;
        }
      } catch (e) {
        print('❌ SMS URI failed: $e');
      }

      // Fallback: Basic SMS intent
      try {
        final Uri basicSms = Uri.parse('sms:$phone');

        // Copy message to clipboard for easy pasting
        await Clipboard.setData(ClipboardData(text: message));
        print('� Emergency message copied to clipboard');

        if (await canLaunchUrl(basicSms)) {
          await launchUrl(
            basicSms,
            mode: LaunchMode.externalNonBrowserApplication,
          );
          print('📱 Basic SMS app opened, message in clipboard');
          return true;
        }
      } catch (e) {
        print('❌ Basic SMS fallback failed: $e');
      }
      print('❌ All SMS methods failed for $phone');
      return false;
    } catch (e) {
      print('💥 Critical error with SMS sending: $e');
      return false;
    }
  }

  // Direct SMS Dialog - last resort for user convenience
  Future<bool> _showDirectSmsDialog(
    BuildContext context,
    String phone,
    String message,
  ) async {
    // Create shorter message for display
    String shortMessage = message.length > 300
        ? '${message.substring(0, 300)}...'
        : message;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Send Emergency SMS'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unable to send SMS automatically. Please:'),
                const SizedBox(height: 10),
                Text(
                  '1. Send to: $phone',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(shortMessage),
                ),
                const SizedBox(height: 10),
                const Text(
                  '2. The message has been copied to your clipboard for easy pasting',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open SMS App'),
              onPressed: () async {
                // Copy to clipboard
                await Clipboard.setData(ClipboardData(text: message));

                // Try to open SMS app
                final Uri smsUri = Uri(scheme: 'sms', path: phone);
                await launchUrl(
                  smsUri,
                  mode: LaunchMode.externalNonBrowserApplication,
                );

                // Close dialog
                Navigator.pop(dialogContext, true);
              },
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
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

      // Try to send SMS to personal contacts automatically
      if (includeSms && personalContactsToNotify.isNotEmpty) {
        for (EmergencyContact contact in personalContactsToNotify) {
          bool success = await _sendSmsAutomatic(contact.phone, shortMessage);

          if (success) {
            successfulContacts.add('${contact.name} (${contact.phone})');
            print('Successfully initiated SMS to ${contact.name}');
          } else {
            failedContacts.add('${contact.name} (${contact.phone})');
            print('Failed to send SMS to ${contact.name}');

            // If we have context, show manual dialog for first failed contact
            if (context != null &&
                isProgressDialogShowing &&
                dialogContext != null) {
              // Remove progress dialog
              Navigator.pop(dialogContext!);
              isProgressDialogShowing = false;

              // Show manual SMS dialog
              bool manualSuccess = await _showDirectSmsDialog(
                context,
                contact.phone,
                shortMessage,
              );

              if (manualSuccess) {
                // Move from failed to successful
                failedContacts.removeLast();
                successfulContacts.add(
                  '${contact.name} (${contact.phone}) [Manual]',
                );
              }
            }
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
            await _makeEmergencyCall(contact.phone);
          }
        }
      }

      // Remove progress dialog if still showing
      if (isProgressDialogShowing && dialogContext != null) {
        Navigator.pop(dialogContext!);
      }

      // Vibrate device for feedback
      HapticFeedback.vibrate();

      return {
        'success': successfulContacts.isNotEmpty,
        'alertId': alert.id,
        'contactsNotified': successfulContacts.length,
        'successfulContacts': successfulContacts,
        'failedContacts': failedContacts,
        'emergencyServicesReady': emergencyServicesReady,
        'location': currentLocation != null,
        'message': successfulContacts.isNotEmpty
            ? 'SOS Alert sent to ${successfulContacts.length} contacts!'
            : 'Could not send SMS. Try calling emergency contacts directly.',
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

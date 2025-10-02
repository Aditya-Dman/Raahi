import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

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

  // Create a shorter message for SMS
  String _createShortSmsMessage(Position? location, AlertType type) {
    String message = "EMERGENCY SOS! Tourist needs help! ";

    if (location != null) {
      message +=
          "Location: https://maps.google.com/?q=${location.latitude},${location.longitude}";
    } else {
      message += "Location unavailable";
    }

    return message;
  }

  // Automatic SMS sending method
  Future<bool> _sendAutomaticSms(String phone, String message) async {
    try {
      print('Attempting automatic SMS to $phone');

      // First try with SMS URI + body parameter
      try {
        final Uri smsUriWithBody = Uri(
          scheme: 'sms',
          path: phone,
          queryParameters: {'body': message},
        );

        if (await canLaunchUrl(smsUriWithBody)) {
          await launchUrl(
            smsUriWithBody,
            mode: LaunchMode.externalNonBrowserApplication,
          );
          return true;
        }
      } catch (e) {
        print('SMS URI with body failed: $e');
      }

      // Second try with just SMS URI and no parameters
      try {
        final Uri simpleSmsUri = Uri(scheme: 'sms', path: phone);

        if (await canLaunchUrl(simpleSmsUri)) {
          // Copy text to clipboard for easy pasting
          await Clipboard.setData(ClipboardData(text: message));
          await launchUrl(
            simpleSmsUri,
            mode: LaunchMode.externalNonBrowserApplication,
          );
          return true;
        }
      } catch (e) {
        print('Simple SMS URI failed: $e');
      }

      return false;
    } catch (e) {
      print('Critical error with SMS for $phone: $e');
      return false;
    }
  }

  // Make emergency call
  Future<bool> _makeEmergencyCall(String phone) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phone);

      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(
          phoneUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
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

  // Check SMS permissions
  Future<bool> _checkAndRequestSmsPermissions() async {
    try {
      var status = await Permission.sms.status;

      if (!status.isGranted) {
        status = await Permission.sms.request();
      }

      return status.isGranted;
    } catch (e) {
      print('Error checking SMS permissions: $e');
      return false;
    }
  }

  // Send emergency alert to all contacts - FULLY AUTOMATIC IMPLEMENTATION
  Future<Map<String, dynamic>> sendEmergencyAlert({
    required AlertType type,
    String additionalInfo = '',
    List<ContactType>? specificContactTypes,
    bool includeSms = true,
    bool includeCall = false,
    BuildContext? context,
  }) async {
    try {
      // Show progress dialog if context is provided
      BuildContext? dialogContext;
      if (context != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) {
            dialogContext = ctx;
            return AlertDialog(
              title: const Text('Sending Emergency Alerts'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(color: Colors.red),
                  SizedBox(height: 16),
                  Text('Contacting emergency services...'),
                ],
              ),
            );
          },
        );
      }

      // Get current location
      Position? currentLocation = await _getCurrentLocation();

      // Create alert message
      String alertMessage = _createAlertMessage(
        type,
        currentLocation,
        additionalInfo,
      );

      // Create shorter message for SMS
      String shortMessage = _createShortSmsMessage(currentLocation, type);

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

      // Request SMS permission if needed
      if (includeSms) {
        await _checkAndRequestSmsPermissions();
      }

      // Results tracking
      List<String> successfulContacts = [];
      List<String> failedContacts = [];
      List<String> emergencyServicesReady = [];

      // Try sending SMS automatically
      if (includeSms && personalContactsToNotify.isNotEmpty) {
        // Copy message to clipboard as fallback
        await Clipboard.setData(ClipboardData(text: shortMessage));

        // Process each contact
        for (EmergencyContact contact in personalContactsToNotify) {
          bool success = await _sendAutomaticSms(contact.phone, shortMessage);

          if (success) {
            successfulContacts.add('${contact.name} (${contact.phone})');
            print('SMS initiated for ${contact.name}');

            // Small delay between contacts to avoid overwhelming
            await Future.delayed(const Duration(milliseconds: 500));
          } else {
            failedContacts.add('${contact.name} (${contact.phone})');
            print('SMS failed for ${contact.name}');
          }
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

      // Vibrate device for feedback
      HapticFeedback.vibrate();

      // Dismiss dialog if shown
      if (dialogContext != null && context != null && context.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      // Determine success message
      String resultMessage;
      if (successfulContacts.isNotEmpty) {
        resultMessage =
            'SMS alerts sent to ${successfulContacts.length} contacts. Message was automatically filled in.';
      } else if (personalContactsToNotify.isEmpty) {
        resultMessage =
            'No personal emergency contacts found. Add emergency contacts first.';
      } else {
        resultMessage =
            'Could not send SMS. Message has been copied to clipboard.';
      }

      return {
        'success':
            successfulContacts.isNotEmpty || emergencyServicesReady.isNotEmpty,
        'alertId': alert.id,
        'contactsNotified': successfulContacts.length,
        'successfulContacts': successfulContacts,
        'failedContacts': failedContacts,
        'emergencyServicesReady': emergencyServicesReady,
        'location': currentLocation != null,
        'message': resultMessage,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'anomaly_detection_service.dart';
import 'emergency_alert_service_improved.dart' as emergency;
import 'dart:async';

// Different types of AI alerts
enum AIAlertType {
  lowRisk, // Minor anomalies - subtle notification
  mediumRisk, // Moderate anomalies - visible alert
  highRisk, // Severe anomalies - strong alert + recommendations
  critical, // Immediate danger - emergency protocols
}

enum AlertDeliveryMethod {
  inApp, // In-app notification only
  sound, // Sound alert
  vibration, // Haptic feedback
  visual, // Flash screen/colors
  emergency, // Trigger emergency contacts
}

// AI Alert data model
class AIAlert {
  final String id;
  final AIAlertType type;
  final String title;
  final String message;
  final List<String> recommendations;
  final DateTime timestamp;
  final AnomalyDetection? sourceAnomaly;
  final List<AlertDeliveryMethod> deliveryMethods;
  final bool isAcknowledged;
  final bool isResolved;

  AIAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.recommendations,
    required this.timestamp,
    this.sourceAnomaly,
    required this.deliveryMethods,
    this.isAcknowledged = false,
    this.isResolved = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.toString(),
    'title': title,
    'message': message,
    'recommendations': recommendations,
    'timestamp': timestamp.toIso8601String(),
    'deliveryMethods': deliveryMethods.map((e) => e.toString()).toList(),
    'isAcknowledged': isAcknowledged,
    'isResolved': isResolved,
  };
}

// Main AI Alert Service
class AIAlertService {
  static final AIAlertService _instance = AIAlertService._internal();
  factory AIAlertService() => _instance;
  AIAlertService._internal();

  // Alert management
  final List<AIAlert> _activeAlerts = [];
  final List<AIAlert> _alertHistory = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Alert callbacks for UI
  Function(AIAlert)? onNewAlert;
  Function(AIAlert)? onAlertResolved;

  // Configuration
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _emergencyAlertsEnabled = true;
  final double _alertThreshold = 0.6; // Minimum severity to trigger alerts

  // Getters
  List<AIAlert> get activeAlerts => List.unmodifiable(_activeAlerts);
  List<AIAlert> get alertHistory => List.unmodifiable(_alertHistory);
  bool get hasCriticalAlerts =>
      _activeAlerts.any((a) => a.type == AIAlertType.critical);
  bool get hasUnacknowledgedAlerts =>
      _activeAlerts.any((a) => !a.isAcknowledged);

  // Configuration getters/setters
  bool get soundEnabled => _soundEnabled;
  set soundEnabled(bool value) => _soundEnabled = value;

  bool get vibrationEnabled => _vibrationEnabled;
  set vibrationEnabled(bool value) => _vibrationEnabled = value;

  bool get emergencyAlertsEnabled => _emergencyAlertsEnabled;
  set emergencyAlertsEnabled(bool value) => _emergencyAlertsEnabled = value;

  // Process anomaly and determine if alert should be triggered
  Future<AIAlert?> processAnomaly(AnomalyDetection anomaly) async {
    try {
      debugPrint('🔍 Processing anomaly for alerting: ${anomaly.anomalyType}');

      // Skip if severity below threshold
      if (anomaly.severity < _alertThreshold) {
        debugPrint(
          '⏭️ Anomaly severity ${anomaly.severity} below threshold $_alertThreshold',
        );
        return null;
      }

      // Determine alert type based on severity and anomaly type
      AIAlertType alertType = _determineAlertType(anomaly);

      // Create alert message
      String title = _createAlertTitle(anomaly, alertType);
      String message = _createAlertMessage(anomaly, alertType);

      // Determine delivery methods
      List<AlertDeliveryMethod> deliveryMethods = _determineDeliveryMethods(
        alertType,
        anomaly,
      );

      // Create AI alert
      AIAlert alert = AIAlert(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        type: alertType,
        title: title,
        message: message,
        recommendations: anomaly.recommendations,
        timestamp: DateTime.now(),
        sourceAnomaly: anomaly,
        deliveryMethods: deliveryMethods,
      );

      // Trigger the alert
      await _triggerAlert(alert);

      return alert;
    } catch (e) {
      debugPrint('🔴 Error processing anomaly for alert: $e');
      return null;
    }
  }

  // Trigger alert with all specified delivery methods
  Future<void> _triggerAlert(AIAlert alert) async {
    try {
      debugPrint('🚨 Triggering ${alert.type} alert: ${alert.title}');

      // Add to active alerts
      _activeAlerts.add(alert);
      _alertHistory.add(alert);

      // Trigger delivery methods
      for (AlertDeliveryMethod method in alert.deliveryMethods) {
        await _executeDeliveryMethod(method, alert);
      }

      // Notify UI callback
      onNewAlert?.call(alert);

      // Auto-resolve low-risk alerts after delay
      if (alert.type == AIAlertType.lowRisk) {
        Timer(const Duration(minutes: 5), () {
          resolveAlert(alert.id, autoResolved: true);
        });
      }
    } catch (e) {
      debugPrint('🔴 Error triggering alert: $e');
    }
  }

  // Execute specific delivery method
  Future<void> _executeDeliveryMethod(
    AlertDeliveryMethod method,
    AIAlert alert,
  ) async {
    try {
      switch (method) {
        case AlertDeliveryMethod.inApp:
          // In-app notification handled by UI layer
          break;

        case AlertDeliveryMethod.sound:
          if (_soundEnabled) {
            await _playAlertSound(alert.type);
          }
          break;

        case AlertDeliveryMethod.vibration:
          if (_vibrationEnabled) {
            await _triggerVibration(alert.type);
          }
          break;

        case AlertDeliveryMethod.visual:
          // Visual alerts handled by UI layer
          break;

        case AlertDeliveryMethod.emergency:
          if (_emergencyAlertsEnabled && alert.type == AIAlertType.critical) {
            await _triggerEmergencyProtocol(alert);
          }
          break;
      }
    } catch (e) {
      debugPrint('🔴 Error executing delivery method $method: $e');
    }
  }

  // Play appropriate sound for alert type
  Future<void> _playAlertSound(AIAlertType type) async {
    try {
      String soundFile;
      switch (type) {
        case AIAlertType.lowRisk:
          return; // No sound for low risk
        case AIAlertType.mediumRisk:
          soundFile = 'alert_sent.mp3';
          break;
        case AIAlertType.highRisk:
        case AIAlertType.critical:
          soundFile = 'alarm_buzzer.mp3';
          break;
      }

      await _audioPlayer.play(AssetSource('sounds/$soundFile'));
      debugPrint('🔊 Played alert sound: $soundFile');
    } catch (e) {
      debugPrint('🔴 Error playing alert sound: $e');
    }
  }

  // Trigger haptic feedback for alert
  Future<void> _triggerVibration(AIAlertType type) async {
    try {
      switch (type) {
        case AIAlertType.lowRisk:
          await HapticFeedback.lightImpact();
          break;
        case AIAlertType.mediumRisk:
          await HapticFeedback.mediumImpact();
          break;
        case AIAlertType.highRisk:
          await HapticFeedback.heavyImpact();
          break;
        case AIAlertType.critical:
          // Multiple strong vibrations
          for (int i = 0; i < 3; i++) {
            await HapticFeedback.heavyImpact();
            await Future.delayed(const Duration(milliseconds: 300));
          }
          break;
      }
      debugPrint('📳 Triggered vibration for $type');
    } catch (e) {
      debugPrint('🔴 Error triggering vibration: $e');
    }
  }

  // Trigger emergency protocols for critical alerts
  Future<void> _triggerEmergencyProtocol(AIAlert alert) async {
    try {
      debugPrint('🆘 Triggering emergency protocol for critical alert');

      // Create emergency alert message
      String emergencyMessage =
          'AI SAFETY ALERT: ${alert.title}\n\n${alert.message}';
      if (alert.recommendations.isNotEmpty) {
        emergencyMessage +=
            '\n\nRecommendations:\n${alert.recommendations.join('\n')}';
      }

      // Send emergency alert to contacts
      final emergencyService = emergency.EmergencyAlertService();
      await emergencyService.sendEmergencyAlert(
        type: emergency.AlertType.security,
        additionalInfo: emergencyMessage,
      );

      debugPrint('📤 Emergency contacts notified of critical AI alert');
    } catch (e) {
      debugPrint('🔴 Error triggering emergency protocol: $e');
    }
  }

  // Determine alert type based on anomaly
  AIAlertType _determineAlertType(AnomalyDetection anomaly) {
    // Critical alerts (immediate danger)
    if (anomaly.severity >= 0.9) {
      return AIAlertType.critical;
    }

    // High-risk alerts based on anomaly type and severity
    if (anomaly.severity >= 0.8 ||
        _isCriticalAnomalyType(anomaly.anomalyType)) {
      return AIAlertType.highRisk;
    }

    // Medium-risk alerts
    if (anomaly.severity >= 0.6) {
      return AIAlertType.mediumRisk;
    }

    // Low-risk alerts
    return AIAlertType.lowRisk;
  }

  bool _isCriticalAnomalyType(String anomalyType) {
    return [
      'stress_level',
      'repetitive_behavior',
      'location', // When in dangerous/unknown area
    ].contains(anomalyType);
  }

  // Create alert title
  String _createAlertTitle(AnomalyDetection anomaly, AIAlertType alertType) {
    switch (alertType) {
      case AIAlertType.critical:
        return '🚨 CRITICAL SAFETY ALERT';
      case AIAlertType.highRisk:
        return '⚠️ HIGH RISK DETECTED';
      case AIAlertType.mediumRisk:
        return '📢 Safety Notice';
      case AIAlertType.lowRisk:
        return '💡 Behavior Update';
    }
  }

  // Create detailed alert message
  String _createAlertMessage(AnomalyDetection anomaly, AIAlertType alertType) {
    String baseMessage = anomaly.description;

    switch (alertType) {
      case AIAlertType.critical:
        return 'IMMEDIATE ATTENTION REQUIRED: $baseMessage\n\nEmergency contacts have been notified.';
      case AIAlertType.highRisk:
        return 'High-risk situation detected: $baseMessage\n\nPlease review safety recommendations.';
      case AIAlertType.mediumRisk:
        return 'Unusual pattern detected: $baseMessage\n\nConsider the provided recommendations.';
      case AIAlertType.lowRisk:
        return 'Minor behavioral variation: $baseMessage';
    }
  }

  // Determine which delivery methods to use
  List<AlertDeliveryMethod> _determineDeliveryMethods(
    AIAlertType alertType,
    AnomalyDetection anomaly,
  ) {
    switch (alertType) {
      case AIAlertType.critical:
        return [
          AlertDeliveryMethod.inApp,
          AlertDeliveryMethod.sound,
          AlertDeliveryMethod.vibration,
          AlertDeliveryMethod.visual,
          AlertDeliveryMethod.emergency,
        ];
      case AIAlertType.highRisk:
        return [
          AlertDeliveryMethod.inApp,
          AlertDeliveryMethod.sound,
          AlertDeliveryMethod.vibration,
          AlertDeliveryMethod.visual,
        ];
      case AIAlertType.mediumRisk:
        return [
          AlertDeliveryMethod.inApp,
          AlertDeliveryMethod.sound,
          AlertDeliveryMethod.vibration,
        ];
      case AIAlertType.lowRisk:
        return [AlertDeliveryMethod.inApp];
    }
  }

  // User acknowledges an alert
  void acknowledgeAlert(String alertId) {
    try {
      final alertIndex = _activeAlerts.indexWhere((a) => a.id == alertId);
      if (alertIndex != -1) {
        final alert = _activeAlerts[alertIndex];
        final acknowledgedAlert = AIAlert(
          id: alert.id,
          type: alert.type,
          title: alert.title,
          message: alert.message,
          recommendations: alert.recommendations,
          timestamp: alert.timestamp,
          sourceAnomaly: alert.sourceAnomaly,
          deliveryMethods: alert.deliveryMethods,
          isAcknowledged: true,
          isResolved: alert.isResolved,
        );

        _activeAlerts[alertIndex] = acknowledgedAlert;
        debugPrint('✅ Alert acknowledged: $alertId');
      }
    } catch (e) {
      debugPrint('🔴 Error acknowledging alert: $e');
    }
  }

  // Resolve an alert
  void resolveAlert(String alertId, {bool autoResolved = false}) {
    try {
      final alertIndex = _activeAlerts.indexWhere((a) => a.id == alertId);
      if (alertIndex != -1) {
        final alert = _activeAlerts.removeAt(alertIndex);
        onAlertResolved?.call(alert);
        debugPrint('🔄 Alert ${autoResolved ? 'auto-' : ''}resolved: $alertId');
      }
    } catch (e) {
      debugPrint('🔴 Error resolving alert: $e');
    }
  }

  // Clear all alerts
  void clearAllAlerts() {
    _activeAlerts.clear();
    debugPrint('🧹 All active alerts cleared');
  }

  // Get alerts by type
  List<AIAlert> getAlertsByType(AIAlertType type) {
    return _activeAlerts.where((a) => a.type == type).toList();
  }

  // Get alert statistics
  Map<String, dynamic> getAlertStatistics() {
    Map<AIAlertType, int> typeCounts = {};
    for (var alert in _alertHistory) {
      typeCounts[alert.type] = (typeCounts[alert.type] ?? 0) + 1;
    }

    return {
      'totalAlerts': _alertHistory.length,
      'activeAlerts': _activeAlerts.length,
      'criticalAlerts': typeCounts[AIAlertType.critical] ?? 0,
      'highRiskAlerts': typeCounts[AIAlertType.highRisk] ?? 0,
      'mediumRiskAlerts': typeCounts[AIAlertType.mediumRisk] ?? 0,
      'lowRiskAlerts': typeCounts[AIAlertType.lowRisk] ?? 0,
      'unacknowledgedAlerts': _activeAlerts
          .where((a) => !a.isAcknowledged)
          .length,
    };
  }

  // Test method to simulate different types of alerts
  Future<void> simulateAlert(AIAlertType type, {String? customMessage}) async {
    final testAnomaly = AnomalyDetection(
      anomalyType: 'test_${type.toString()}',
      severity: type == AIAlertType.critical
          ? 0.95
          : type == AIAlertType.highRisk
          ? 0.85
          : type == AIAlertType.mediumRisk
          ? 0.65
          : 0.45,
      description: customMessage ?? 'Test alert of type ${type.toString()}',
      detectedAt: DateTime.now(),
      evidence: {'test': true, 'type': type.toString()},
      recommendations: ['This is a test alert', 'No action required'],
    );

    await processAnomaly(testAnomaly);
    debugPrint('🎭 Simulated $type alert');
  }

  // Dispose resources
  void dispose() {
    _audioPlayer.dispose();
    _activeAlerts.clear();
    onNewAlert = null;
    onAlertResolved = null;
  }
}

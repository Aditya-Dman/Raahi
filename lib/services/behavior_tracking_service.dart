import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'anomaly_detection_service.dart';
import 'ai_alert_service.dart';

// Enhanced behavior tracking with pattern analysis
class BehaviorTrackingService {
  static final BehaviorTrackingService _instance =
      BehaviorTrackingService._internal();
  factory BehaviorTrackingService() => _instance;
  BehaviorTrackingService._internal();

  final AnomalyDetectionService _anomalyService = AnomalyDetectionService();
  final AIAlertService _alertService = AIAlertService();

  // Tracking state
  bool _isTracking = false;
  Timer? _trackingTimer;
  Position? _lastKnownPosition;
  DateTime? _lastActivityTime;
  String _currentActivity = 'unknown';

  // Behavior metrics
  double _currentStressLevel = 5.0; // 1-10 scale
  final List<double> _recentSpeeds = [];
  Map<String, dynamic> _contextData = {};

  // Activity recognition patterns
  final Map<String, Map<String, dynamic>> _activityPatterns = {
    'walking': {
      'speedRange': [0.5, 2.0], // m/s
      'indicators': ['steady_movement', 'low_speed'],
    },
    'running': {
      'speedRange': [2.0, 6.0], // m/s
      'indicators': ['fast_movement', 'elevated_heart_rate'],
    },
    'vehicle': {
      'speedRange': [8.0, 50.0], // m/s
      'indicators': ['high_speed', 'straight_lines'],
    },
    'stationary': {
      'speedRange': [0.0, 0.3], // m/s
      'indicators': ['no_movement', 'same_location'],
    },
    'tourist_activity': {
      'speedRange': [0.3, 1.5], // m/s
      'indicators': ['sightseeing', 'slow_movement', 'stops'],
    },
  };

  // Public getters
  bool get isTracking => _isTracking;
  String get currentActivity => _currentActivity;
  double get currentStressLevel => _currentStressLevel;
  Position? get lastKnownPosition => _lastKnownPosition;

  // Start behavior tracking
  Future<bool> startTracking() async {
    try {
      debugPrint('🎯 Starting behavior tracking...');

      if (_isTracking) {
        debugPrint('⚠️ Behavior tracking already active');
        return true;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('🔴 Location permission denied for behavior tracking');
          return false;
        }
      }

      _isTracking = true;

      // Start periodic behavior analysis
      _trackingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _analyzeBehavior();
      });

      // Initial behavior analysis
      await _analyzeBehavior();

      debugPrint('✅ Behavior tracking started successfully');
      return true;
    } catch (e) {
      debugPrint('🔴 Error starting behavior tracking: $e');
      return false;
    }
  }

  // Stop behavior tracking
  void stopTracking() {
    debugPrint('⏹️ Stopping behavior tracking...');
    _isTracking = false;
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  // Main behavior analysis function
  Future<void> _analyzeBehavior() async {
    try {
      if (!_isTracking) return;

      debugPrint('🔍 Analyzing current behavior...');

      // Get current location
      Position? currentPosition = await _getCurrentPosition();

      // Calculate movement metrics
      double movementSpeed = _calculateMovementSpeed(currentPosition);

      // Recognize current activity
      String detectedActivity = _recognizeActivity(
        movementSpeed,
        currentPosition,
      );

      // Update stress level based on various factors
      _updateStressLevel(detectedActivity, movementSpeed);

      // Update context data
      _updateContextData(currentPosition, detectedActivity);

      // Create behavior pattern
      BehaviorPattern pattern = BehaviorPattern(
        timestamp: DateTime.now(),
        location: currentPosition,
        movementSpeed: movementSpeed,
        activityType: detectedActivity,
        stressLevel: _currentStressLevel.round(),
        contextData: Map<String, dynamic>.from(_contextData),
      );

      // Send to anomaly detection service
      List<AnomalyDetection> anomalies = await _anomalyService
          .recordBehaviorPattern(pattern);

      // Handle detected anomalies
      if (anomalies.isNotEmpty) {
        await _handleDetectedAnomalies(anomalies);
      }

      // Update tracking state
      _lastKnownPosition = currentPosition;
      _lastActivityTime = DateTime.now();
      _currentActivity = detectedActivity;

      debugPrint(
        '📊 Behavior analysis complete: $detectedActivity (${movementSpeed.toStringAsFixed(1)} m/s)',
      );
    } catch (e) {
      debugPrint('🔴 Error analyzing behavior: $e');
    }
  }

  // Get current position safely
  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('⚠️ Could not get current position: $e');
      return _lastKnownPosition;
    }
  }

  // Calculate movement speed between positions
  double _calculateMovementSpeed(Position? currentPosition) {
    if (currentPosition == null || _lastKnownPosition == null) {
      return 0.0;
    }

    try {
      // Calculate distance
      double distance = Geolocator.distanceBetween(
        _lastKnownPosition!.latitude,
        _lastKnownPosition!.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );

      // Calculate time difference
      Duration timeDiff = currentPosition.timestamp.difference(
        _lastKnownPosition!.timestamp,
      );
      double timeInSeconds = timeDiff.inMilliseconds / 1000.0;

      if (timeInSeconds == 0) return 0.0;

      // Calculate speed in m/s
      double speed = distance / timeInSeconds;

      // Add to recent speeds for smoothing
      _recentSpeeds.add(speed);
      if (_recentSpeeds.length > 5) {
        _recentSpeeds.removeAt(0);
      }

      // Return smoothed speed
      return _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
    } catch (e) {
      debugPrint('⚠️ Error calculating movement speed: $e');
      return 0.0;
    }
  }

  // Recognize activity based on movement patterns
  String _recognizeActivity(double speed, Position? position) {
    try {
      // Check each activity pattern
      for (var entry in _activityPatterns.entries) {
        String activity = entry.key;
        Map<String, dynamic> pattern = entry.value;
        List<double> speedRange = List<double>.from(pattern['speedRange']);

        if (speed >= speedRange[0] && speed <= speedRange[1]) {
          // Additional context-based refinement
          if (activity == 'vehicle' && _isLikelyInVehicle(speed)) {
            return 'vehicle';
          } else if (activity == 'tourist_activity' &&
              _isLikelyTouristActivity(position)) {
            return 'tourist_activity';
          } else if (activity == 'walking' ||
              activity == 'running' ||
              activity == 'stationary') {
            return activity;
          }
        }
      }

      // Default classification based on speed
      if (speed < 0.3) return 'stationary';
      if (speed < 2.0) return 'walking';
      if (speed < 6.0) return 'running';
      return 'vehicle';
    } catch (e) {
      debugPrint('⚠️ Error recognizing activity: $e');
      return 'unknown';
    }
  }

  // Additional context checks for activity recognition
  bool _isLikelyInVehicle(double speed) {
    // Check for sustained high speed and straight-line movement
    return speed > 8.0 &&
        _recentSpeeds.length >= 3 &&
        _recentSpeeds.every((s) => s > 5.0);
  }

  bool _isLikelyTouristActivity(Position? position) {
    // Check if near tourist attractions or moving slowly with stops
    return _recentSpeeds.length >= 3 &&
        _recentSpeeds.any((s) => s < 0.5) &&
        _recentSpeeds.any((s) => s > 0.5);
  }

  // Update stress level based on behavior analysis
  void _updateStressLevel(String activity, double speed) {
    try {
      double newStressLevel = _currentStressLevel;

      // Adjust stress based on activity
      switch (activity) {
        case 'running':
          newStressLevel += 1.0; // Physical exertion
          break;
        case 'vehicle':
          if (speed > 20.0) newStressLevel += 0.5; // High-speed travel
          break;
        case 'stationary':
          if (_lastActivityTime != null &&
              DateTime.now().difference(_lastActivityTime!).inMinutes > 30) {
            newStressLevel += 0.3; // Extended inactivity
          }
          break;
        case 'tourist_activity':
          newStressLevel -= 0.2; // Relaxing activity
          break;
      }

      // Check for anomalous speed changes
      if (_recentSpeeds.isNotEmpty) {
        double avgSpeed =
            _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
        if ((speed - avgSpeed).abs() > 5.0) {
          newStressLevel += 0.5; // Sudden speed change
        }
      }

      // Check time-based stress factors
      int hour = DateTime.now().hour;
      if (hour < 6 || hour > 22) {
        newStressLevel += 0.3; // Late/early hours
      }

      // Natural stress decay over time
      if (_lastActivityTime != null) {
        Duration timeSinceLastUpdate = DateTime.now().difference(
          _lastActivityTime!,
        );
        if (timeSinceLastUpdate.inMinutes > 10) {
          newStressLevel -= 0.1; // Gradual stress reduction
        }
      }

      // Clamp stress level between 1-10
      _currentStressLevel = max(1.0, min(10.0, newStressLevel));
    } catch (e) {
      debugPrint('⚠️ Error updating stress level: $e');
    }
  }

  // Update context data for pattern analysis
  void _updateContextData(Position? position, String activity) {
    _contextData = {
      'timestamp': DateTime.now().toIso8601String(),
      'hour': DateTime.now().hour,
      'dayOfWeek': DateTime.now().weekday,
      'activity': activity,
      'stressLevel': _currentStressLevel,
      'speed': _recentSpeeds.isNotEmpty ? _recentSpeeds.last : 0.0,
      'isNightTime': DateTime.now().hour < 6 || DateTime.now().hour > 20,
      'locationAccuracy': position?.accuracy ?? 0.0,
      'hasRecentMovement': _recentSpeeds.any((s) => s > 0.5),
      'consecutiveStationary': _countConsecutiveStationaryPeriods(),
    };
  }

  int _countConsecutiveStationaryPeriods() {
    int count = 0;
    for (int i = _recentSpeeds.length - 1; i >= 0; i--) {
      if (_recentSpeeds[i] < 0.3) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  // Handle detected anomalies with AI alerting system
  Future<void> _handleDetectedAnomalies(
    List<AnomalyDetection> anomalies,
  ) async {
    try {
      for (var anomaly in anomalies) {
        debugPrint(
          '🚨 Anomaly detected: ${anomaly.anomalyType} (severity: ${anomaly.severity})',
        );

        // Log anomaly for analysis
        _logAnomaly(anomaly);

        // Process anomaly through AI alert system
        AIAlert? alert = await _alertService.processAnomaly(anomaly);

        if (alert != null) {
          debugPrint('📢 AI Alert triggered: ${alert.type} - ${alert.title}');
        }

        // Handle high-severity anomalies with additional protocols
        if (anomaly.severity > 0.8) {
          await _handleHighSeverityAnomaly(anomaly);
        }
      }
    } catch (e) {
      debugPrint('🔴 Error handling anomalies: $e');
    }
  }

  void _logAnomaly(AnomalyDetection anomaly) {
    // In a real app, this would log to a database or monitoring service
    debugPrint('📝 Anomaly Log: ${anomaly.toJson()}');
  }

  Future<void> _handleHighSeverityAnomaly(AnomalyDetection anomaly) async {
    // In a real app, this could trigger notifications, alerts, or safety protocols
    debugPrint('🚨 HIGH SEVERITY ANOMALY: ${anomaly.description}');
    debugPrint('🔧 Recommendations: ${anomaly.recommendations.join(', ')}');

    // Could implement:
    // - Send notification to emergency contacts
    // - Increase safety monitoring frequency
    // - Trigger automatic safety check-ins
    // - Alert safety monitoring services
  }

  // Manual stress level update (from user input or external sensors)
  void updateStressLevel(double newLevel) {
    _currentStressLevel = max(1.0, min(10.0, newLevel));
    debugPrint('📊 Stress level manually updated: $_currentStressLevel');
  }

  // Get current behavior insights
  Map<String, dynamic> getCurrentInsights() {
    return {
      'currentActivity': _currentActivity,
      'stressLevel': _currentStressLevel,
      'movementSpeed': _recentSpeeds.isNotEmpty ? _recentSpeeds.last : 0.0,
      'anomalyRisk': _anomalyService.getCurrentAnomalyRisk(),
      'isTracking': _isTracking,
      'lastUpdate': _lastActivityTime?.toIso8601String(),
      'recentSpeeds': _recentSpeeds,
      'contextData': _contextData,
      'anomaliesCount': _anomalyService.detectedAnomalies.length,
    };
  }

  // Get behavior pattern summary
  Map<String, dynamic> getBehaviorSummary() {
    return {
      'totalPatterns': _anomalyService.behaviorHistory.length,
      'isLearning': _anomalyService.isLearning,
      'hasBaseline': _anomalyService.baseline != null,
      'analytics': _anomalyService.getAnalyticsSummary(),
      'currentInsights': getCurrentInsights(),
    };
  }

  // Reset all behavior data
  void resetBehaviorData() {
    _anomalyService.clearAllData();
    _recentSpeeds.clear();
    _contextData.clear();
    _currentStressLevel = 5.0;
    _currentActivity = 'unknown';
    debugPrint('🔄 Behavior tracking data reset');
  }

  // Simulate behavior for testing
  Future<void> simulateBehaviorPattern(
    String activityType, {
    double? speed,
    double? stress,
  }) async {
    if (!_isTracking) return;

    Position? mockPosition =
        _lastKnownPosition ??
        Position(
          latitude: 28.6139 + (Random().nextDouble() - 0.5) * 0.01,
          longitude: 77.2090 + (Random().nextDouble() - 0.5) * 0.01,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: speed ?? Random().nextDouble() * 10,
          speedAccuracy: 0,
        );

    BehaviorPattern pattern = BehaviorPattern(
      timestamp: DateTime.now(),
      location: mockPosition,
      movementSpeed: speed ?? Random().nextDouble() * 10,
      activityType: activityType,
      stressLevel: (stress ?? (Random().nextDouble() * 10)).round(),
      contextData: {'simulated': true, 'test_pattern': activityType},
    );

    await _anomalyService.recordBehaviorPattern(pattern);
    debugPrint('🎭 Simulated behavior pattern: $activityType');
  }
}

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

// Data models for behavior pattern analysis
class BehaviorPattern {
  final DateTime timestamp;
  final Position? location;
  final double movementSpeed;
  final String activityType;
  final int stressLevel; // 1-10 scale
  final Map<String, dynamic> contextData;

  BehaviorPattern({
    required this.timestamp,
    this.location,
    required this.movementSpeed,
    required this.activityType,
    required this.stressLevel,
    required this.contextData,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'latitude': location?.latitude,
    'longitude': location?.longitude,
    'movementSpeed': movementSpeed,
    'activityType': activityType,
    'stressLevel': stressLevel,
    'contextData': contextData,
  };

  factory BehaviorPattern.fromJson(Map<String, dynamic> json) {
    Position? location;
    if (json['latitude'] != null && json['longitude'] != null) {
      location = Position(
        latitude: json['latitude'],
        longitude: json['longitude'],
        timestamp: DateTime.parse(json['timestamp']),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    return BehaviorPattern(
      timestamp: DateTime.parse(json['timestamp']),
      location: location,
      movementSpeed: json['movementSpeed']?.toDouble() ?? 0.0,
      activityType: json['activityType'] ?? 'unknown',
      stressLevel: json['stressLevel'] ?? 5,
      contextData: Map<String, dynamic>.from(json['contextData'] ?? {}),
    );
  }
}

class AnomalyDetection {
  final String anomalyType;
  final double severity; // 0.0 to 1.0
  final String description;
  final DateTime detectedAt;
  final Map<String, dynamic> evidence;
  final List<String> recommendations;

  AnomalyDetection({
    required this.anomalyType,
    required this.severity,
    required this.description,
    required this.detectedAt,
    required this.evidence,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
    'anomalyType': anomalyType,
    'severity': severity,
    'description': description,
    'detectedAt': detectedAt.toIso8601String(),
    'evidence': evidence,
    'recommendations': recommendations,
  };
}

class BehaviorBaseline {
  final Map<String, double> averageMetrics;
  final Map<String, double> standardDeviations;
  final List<String> commonLocations;
  final Map<int, List<String>> timePatterns; // hour -> activities
  final DateTime lastUpdated;

  BehaviorBaseline({
    required this.averageMetrics,
    required this.standardDeviations,
    required this.commonLocations,
    required this.timePatterns,
    required this.lastUpdated,
  });
}

// AI Anomaly Detection Service
class AnomalyDetectionService {
  static final AnomalyDetectionService _instance =
      AnomalyDetectionService._internal();
  factory AnomalyDetectionService() => _instance;
  AnomalyDetectionService._internal();

  final List<BehaviorPattern> _behaviorHistory = [];
  final List<AnomalyDetection> _detectedAnomalies = [];
  BehaviorBaseline? _baseline;
  bool _isLearning = true;
  final int _learningPeriodDays = 7;

  // Configuration thresholds
  static const double _anomalyThreshold = 2.0; // Standard deviations
  static const int _minPatternsForBaseline = 50;
  static const double _severityMultiplier = 0.5;

  // Public getters
  List<BehaviorPattern> get behaviorHistory =>
      List.unmodifiable(_behaviorHistory);
  List<AnomalyDetection> get detectedAnomalies =>
      List.unmodifiable(_detectedAnomalies);
  bool get isLearning => _isLearning;
  BehaviorBaseline? get baseline => _baseline;

  // Record new behavior pattern and analyze for anomalies
  Future<List<AnomalyDetection>> recordBehaviorPattern(
    BehaviorPattern pattern,
  ) async {
    try {
      debugPrint('🧠 Recording behavior pattern: ${pattern.activityType}');

      _behaviorHistory.add(pattern);

      // Keep only recent patterns (last 30 days)
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      _behaviorHistory.removeWhere((p) => p.timestamp.isBefore(cutoffDate));

      // Update baseline if we have enough data
      if (_behaviorHistory.length >= _minPatternsForBaseline) {
        await _updateBaseline();
      }

      // Detect anomalies if baseline exists
      List<AnomalyDetection> anomalies = [];
      if (_baseline != null && !_isLearning) {
        anomalies = await _detectAnomalies(pattern);
        _detectedAnomalies.addAll(anomalies);

        // Keep only recent anomalies
        _detectedAnomalies.removeWhere(
          (a) => a.detectedAt.isBefore(cutoffDate),
        );
      }

      debugPrint('🔍 Detected ${anomalies.length} anomalies');
      return anomalies;
    } catch (e) {
      debugPrint('🔴 Error recording behavior pattern: $e');
      return [];
    }
  }

  // Update behavior baseline using statistical analysis
  Future<void> _updateBaseline() async {
    try {
      debugPrint('📊 Updating behavior baseline...');

      if (_behaviorHistory.length < _minPatternsForBaseline) return;

      // Calculate average metrics
      Map<String, double> avgMetrics = {
        'movementSpeed': _calculateAverage(
          _behaviorHistory.map((p) => p.movementSpeed),
        ),
        'stressLevel': _calculateAverage(
          _behaviorHistory.map((p) => p.stressLevel.toDouble()),
        ),
        'hoursActive': _calculateAverageActiveHours(),
      };

      // Calculate standard deviations
      Map<String, double> stdDevs = {
        'movementSpeed': _calculateStandardDeviation(
          _behaviorHistory.map((p) => p.movementSpeed),
          avgMetrics['movementSpeed']!,
        ),
        'stressLevel': _calculateStandardDeviation(
          _behaviorHistory.map((p) => p.stressLevel.toDouble()),
          avgMetrics['stressLevel']!,
        ),
        'hoursActive': _calculateStandardDeviation(
          _behaviorHistory.map((p) => p.timestamp.hour.toDouble()),
          avgMetrics['hoursActive']!,
        ),
      };

      // Identify common locations
      List<String> commonLocations = _identifyCommonLocations();

      // Analyze time patterns
      Map<int, List<String>> timePatterns = _analyzeTimePatterns();

      _baseline = BehaviorBaseline(
        averageMetrics: avgMetrics,
        standardDeviations: stdDevs,
        commonLocations: commonLocations,
        timePatterns: timePatterns,
        lastUpdated: DateTime.now(),
      );

      // Stop learning mode after sufficient data
      final learningCutoff = DateTime.now().subtract(
        Duration(days: _learningPeriodDays),
      );
      if (_behaviorHistory.any((p) => p.timestamp.isBefore(learningCutoff))) {
        _isLearning = false;
        debugPrint('🎓 Learning mode completed - anomaly detection active');
      }
    } catch (e) {
      debugPrint('🔴 Error updating baseline: $e');
    }
  }

  // Detect anomalies by comparing current pattern with baseline
  Future<List<AnomalyDetection>> _detectAnomalies(
    BehaviorPattern pattern,
  ) async {
    List<AnomalyDetection> anomalies = [];

    if (_baseline == null) return anomalies;

    try {
      // 1. Movement speed anomaly
      double speedDeviation = _calculateZScore(
        pattern.movementSpeed,
        _baseline!.averageMetrics['movementSpeed']!,
        _baseline!.standardDeviations['movementSpeed']!,
      );

      if (speedDeviation.abs() > _anomalyThreshold) {
        anomalies.add(
          AnomalyDetection(
            anomalyType: 'movement_speed',
            severity: min(speedDeviation.abs() * _severityMultiplier, 1.0),
            description: speedDeviation > 0
                ? 'Unusually fast movement detected'
                : 'Unusually slow movement detected',
            detectedAt: DateTime.now(),
            evidence: {
              'currentSpeed': pattern.movementSpeed,
              'averageSpeed': _baseline!.averageMetrics['movementSpeed'],
              'deviation': speedDeviation,
            },
            recommendations: speedDeviation > 0
                ? ['Check if user is in a vehicle', 'Verify location safety']
                : ['Check if user needs assistance', 'Monitor for distress'],
          ),
        );
      }

      // 2. Stress level anomaly
      double stressDeviation = _calculateZScore(
        pattern.stressLevel.toDouble(),
        _baseline!.averageMetrics['stressLevel']!,
        _baseline!.standardDeviations['stressLevel']!,
      );

      if (stressDeviation > _anomalyThreshold) {
        anomalies.add(
          AnomalyDetection(
            anomalyType: 'stress_level',
            severity: min(stressDeviation * _severityMultiplier, 1.0),
            description: 'Elevated stress level detected',
            detectedAt: DateTime.now(),
            evidence: {
              'currentStress': pattern.stressLevel,
              'averageStress': _baseline!.averageMetrics['stressLevel'],
              'deviation': stressDeviation,
            },
            recommendations: [
              'Check user wellbeing',
              'Suggest relaxation techniques',
              'Monitor for safety concerns',
            ],
          ),
        );
      }

      // 3. Time pattern anomaly
      int currentHour = pattern.timestamp.hour;
      List<String> expectedActivities =
          _baseline!.timePatterns[currentHour] ?? [];

      if (expectedActivities.isNotEmpty &&
          !expectedActivities.contains(pattern.activityType)) {
        anomalies.add(
          AnomalyDetection(
            anomalyType: 'time_pattern',
            severity: 0.6,
            description: 'Unusual activity for this time of day',
            detectedAt: DateTime.now(),
            evidence: {
              'currentActivity': pattern.activityType,
              'expectedActivities': expectedActivities,
              'hour': currentHour,
            },
            recommendations: [
              'Verify user safety',
              'Check for schedule changes',
              'Monitor location',
            ],
          ),
        );
      }

      // 4. Location anomaly
      if (pattern.location != null) {
        bool isKnownLocation = _isLocationKnown(pattern.location!);
        if (!isKnownLocation) {
          double distanceFromKnown = _calculateDistanceFromKnownLocations(
            pattern.location!,
          );

          if (distanceFromKnown > 5000) {
            // 5km threshold
            anomalies.add(
              AnomalyDetection(
                anomalyType: 'location',
                severity: min(distanceFromKnown / 10000, 1.0), // Scale by 10km
                description: 'User in unfamiliar location',
                detectedAt: DateTime.now(),
                evidence: {
                  'currentLocation':
                      '${pattern.location!.latitude}, ${pattern.location!.longitude}',
                  'distanceFromKnown': distanceFromKnown,
                },
                recommendations: [
                  'Increase safety monitoring',
                  'Share location with emergency contacts',
                  'Check local safety information',
                ],
              ),
            );
          }
        }
      }

      // 5. Activity pattern anomaly
      var recentActivities = _behaviorHistory
          .where(
            (p) => p.timestamp.isAfter(
              DateTime.now().subtract(const Duration(hours: 2)),
            ),
          )
          .map((p) => p.activityType)
          .toList();

      if (recentActivities.length >= 3) {
        Map<String, int> activityCounts = {};
        for (String activity in recentActivities) {
          activityCounts[activity] = (activityCounts[activity] ?? 0) + 1;
        }

        // Check for repetitive behavior
        if (activityCounts.values.any((count) => count >= 3)) {
          anomalies.add(
            AnomalyDetection(
              anomalyType: 'repetitive_behavior',
              severity: 0.7,
              description: 'Repetitive behavior pattern detected',
              detectedAt: DateTime.now(),
              evidence: {
                'recentActivities': recentActivities,
                'activityCounts': activityCounts,
              },
              recommendations: [
                'Check for signs of distress',
                'Monitor user wellbeing',
                'Consider intervention',
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('🔴 Error detecting anomalies: $e');
    }

    return anomalies;
  }

  // Helper methods for statistical calculations
  double _calculateAverage(Iterable<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculateStandardDeviation(Iterable<double> values, double mean) {
    if (values.isEmpty) return 0.0;
    double variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
        values.length;
    return sqrt(variance);
  }

  double _calculateZScore(double value, double mean, double stdDev) {
    if (stdDev == 0) return 0.0;
    return (value - mean) / stdDev;
  }

  double _calculateAverageActiveHours() {
    if (_behaviorHistory.isEmpty) return 12.0; // Default noon

    List<int> hours = _behaviorHistory.map((p) => p.timestamp.hour).toList();
    return hours.reduce((a, b) => a + b) / hours.length;
  }

  List<String> _identifyCommonLocations() {
    if (_behaviorHistory.isEmpty) return [];

    Map<String, int> locationCounts = {};

    for (var pattern in _behaviorHistory) {
      if (pattern.location != null) {
        // Round to approximate location (for privacy)
        String locationKey =
            '${pattern.location!.latitude.toStringAsFixed(2)},${pattern.location!.longitude.toStringAsFixed(2)}';
        locationCounts[locationKey] = (locationCounts[locationKey] ?? 0) + 1;
      }
    }

    // Return locations visited more than 5 times
    return locationCounts.entries
        .where((e) => e.value >= 5)
        .map((e) => e.key)
        .toList();
  }

  Map<int, List<String>> _analyzeTimePatterns() {
    Map<int, Map<String, int>> hourlyActivities = {};

    for (var pattern in _behaviorHistory) {
      int hour = pattern.timestamp.hour;
      hourlyActivities[hour] ??= {};
      hourlyActivities[hour]![pattern.activityType] =
          (hourlyActivities[hour]![pattern.activityType] ?? 0) + 1;
    }

    Map<int, List<String>> patterns = {};
    for (var entry in hourlyActivities.entries) {
      // Get activities that occur more than once in this hour
      patterns[entry.key] = entry.value.entries
          .where((e) => e.value > 1)
          .map((e) => e.key)
          .toList();
    }

    return patterns;
  }

  bool _isLocationKnown(Position location) {
    for (String knownLoc in _baseline?.commonLocations ?? []) {
      List<String> coords = knownLoc.split(',');
      if (coords.length == 2) {
        double lat = double.tryParse(coords[0]) ?? 0;
        double lng = double.tryParse(coords[1]) ?? 0;

        double distance = Geolocator.distanceBetween(
          location.latitude,
          location.longitude,
          lat,
          lng,
        );

        if (distance < 1000) return true; // Within 1km
      }
    }
    return false;
  }

  double _calculateDistanceFromKnownLocations(Position location) {
    double minDistance = double.infinity;

    for (String knownLoc in _baseline?.commonLocations ?? []) {
      List<String> coords = knownLoc.split(',');
      if (coords.length == 2) {
        double lat = double.tryParse(coords[0]) ?? 0;
        double lng = double.tryParse(coords[1]) ?? 0;

        double distance = Geolocator.distanceBetween(
          location.latitude,
          location.longitude,
          lat,
          lng,
        );

        if (distance < minDistance) {
          minDistance = distance;
        }
      }
    }

    return minDistance == double.infinity ? 0 : minDistance;
  }

  // Get current anomaly risk score (0-100)
  double getCurrentAnomalyRisk() {
    if (_detectedAnomalies.isEmpty) return 0.0;

    // Consider only recent anomalies (last 2 hours)
    final recentCutoff = DateTime.now().subtract(const Duration(hours: 2));
    final recentAnomalies = _detectedAnomalies
        .where((a) => a.detectedAt.isAfter(recentCutoff))
        .toList();

    if (recentAnomalies.isEmpty) return 0.0;

    // Calculate weighted risk score
    double totalRisk = 0.0;
    for (var anomaly in recentAnomalies) {
      double weight = _getAnomalyWeight(anomaly.anomalyType);
      totalRisk += anomaly.severity * weight;
    }

    return min(totalRisk * 100, 100.0);
  }

  double _getAnomalyWeight(String anomalyType) {
    switch (anomalyType) {
      case 'stress_level':
        return 1.5;
      case 'location':
        return 1.3;
      case 'movement_speed':
        return 1.0;
      case 'repetitive_behavior':
        return 1.2;
      case 'time_pattern':
        return 0.8;
      default:
        return 1.0;
    }
  }

  // Clear all data (for testing/reset)
  void clearAllData() {
    _behaviorHistory.clear();
    _detectedAnomalies.clear();
    _baseline = null;
    _isLearning = true;
    debugPrint('🧹 Anomaly detection data cleared');
  }

  // Get summary statistics
  Map<String, dynamic> getAnalyticsSummary() {
    return {
      'totalPatterns': _behaviorHistory.length,
      'totalAnomalies': _detectedAnomalies.length,
      'currentRisk': getCurrentAnomalyRisk(),
      'isLearning': _isLearning,
      'hasBaseline': _baseline != null,
      'learningProgress': min(
        _behaviorHistory.length / _minPatternsForBaseline,
        1.0,
      ),
      'commonActivities': _getMostCommonActivities(),
      'anomalyTypes': _getAnomalyTypeDistribution(),
    };
  }

  List<String> _getMostCommonActivities() {
    Map<String, int> activityCounts = {};
    for (var pattern in _behaviorHistory) {
      activityCounts[pattern.activityType] =
          (activityCounts[pattern.activityType] ?? 0) + 1;
    }

    var sorted = activityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).map((e) => e.key).toList();
  }

  Map<String, int> _getAnomalyTypeDistribution() {
    Map<String, int> distribution = {};
    for (var anomaly in _detectedAnomalies) {
      distribution[anomaly.anomalyType] =
          (distribution[anomaly.anomalyType] ?? 0) + 1;
    }
    return distribution;
  }
}

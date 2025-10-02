import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'anomaly_detection_service.dart';
import 'behavior_tracking_service.dart';

class SafetyScoreService {
  static const String _keyLocationHistory = 'location_history';
  static const String _keyLastSafetyScore = 'last_safety_score';
  static const String _keyLocationUpdateCount = 'location_update_count';
  static const String _keyTripStartDate = 'trip_start_date';
  static const String _keyTripDuration = 'trip_duration_days';

  // Safety factors weights
  static const double _timeOfDayWeight = 0.25; // 25% - Day vs Night
  static const double _locationTypeWeight =
      0.30; // 30% - Area type (tourist, residential, etc.)
  static const double _weatherWeight = 0.15; // 15% - Weather conditions
  static const double _crimeDataWeight = 0.20; // 20% - Historical crime data
  static const double _userBehaviorWeight =
      0.10; // 10% - User movement patterns

  /// Calculate comprehensive safety score based on current conditions
  static Future<double> calculateSafetyScore() async {
    try {
      final position = await _getCurrentLocation();
      if (position == null) {
        return 75.0; // Default score if location unavailable
      }

      double score = 0.0;

      // 1. Time of Day Factor (0-100)
      score += _calculateTimeOfDayScore() * _timeOfDayWeight;

      // 2. Location Type Factor (0-100)
      score +=
          await _calculateLocationTypeScore(position) * _locationTypeWeight;

      // 3. Weather Factor (0-100) - placeholder for now
      score += _calculateWeatherScore() * _weatherWeight;

      // 4. Crime Data Factor (0-100) - simulated based on area
      score += _calculateCrimeScore(position) * _crimeDataWeight;

      // 5. User Behavior Factor (0-100)
      score += await _calculateUserBehaviorScore() * _userBehaviorWeight;

      // Ensure score is between 0-100
      score = score.clamp(0.0, 100.0);

      // Save the calculated score
      await _saveSafetyScore(score);

      return score;
    } catch (e) {
      debugPrint('🔴 Error calculating safety score: $e');
      return await _getLastSafetyScore();
    }
  }

  /// Get current location if permissions are available
  static Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('🔴 Error getting location: $e');
      return null;
    }
  }

  /// Calculate safety score based on time of day
  /// Night time (10 PM - 6 AM) = lower score
  /// Day time (6 AM - 10 PM) = higher score
  static double _calculateTimeOfDayScore() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 6 && hour < 18) {
      // Daytime (6 AM - 6 PM): High safety
      return 90.0;
    } else if (hour >= 18 && hour < 22) {
      // Evening (6 PM - 10 PM): Medium safety
      return 75.0;
    } else {
      // Night (10 PM - 6 AM): Lower safety
      return 55.0;
    }
  }

  /// Calculate safety score based on location type
  /// Uses reverse geocoding and area analysis
  static Future<double> _calculateLocationTypeScore(Position position) async {
    // This is a simplified version - in production, you'd use:
    // - Reverse geocoding APIs
    // - Places API to identify area type
    // - Government safety databases

    // For now, simulate based on coordinates
    // Tourist areas and city centers typically safer
    final lat = position.latitude;
    final lng = position.longitude;

    // Simulate area safety based on rough geographical patterns
    // This would be replaced with real data in production
    if (_isLikelyTouristArea(lat, lng)) {
      return 85.0; // Tourist areas generally safer
    } else if (_isLikelyUrbanCenter(lat, lng)) {
      return 80.0; // Urban centers have good infrastructure
    } else if (_isLikelyResidential(lat, lng)) {
      return 75.0; // Residential areas moderately safe
    } else {
      return 65.0; // Remote/unknown areas less predictable
    }
  }

  /// Simplified area type detection (would use real APIs in production)
  static bool _isLikelyTouristArea(double lat, double lng) {
    // This would check against tourism databases
    // For now, return random but consistent based on location
    return (lat * lng * 1000).toInt().abs() % 10 < 3;
  }

  static bool _isLikelyUrbanCenter(double lat, double lng) {
    // This would check population density APIs
    return (lat * lng * 1000).toInt().abs() % 10 < 5;
  }

  static bool _isLikelyResidential(double lat, double lng) {
    // This would check land use APIs
    return (lat * lng * 1000).toInt().abs() % 10 < 7;
  }

  /// Calculate weather-based safety score
  /// Good weather = higher score, severe weather = lower score
  static double _calculateWeatherScore() {
    // This would integrate with weather APIs like OpenWeatherMap
    // For now, simulate seasonal patterns
    final month = DateTime.now().month;

    if (month >= 3 && month <= 5 || month >= 9 && month <= 11) {
      // Spring/Fall: Generally good weather
      return 85.0;
    } else if (month >= 6 && month <= 8) {
      // Summer: Hot but generally safe
      return 80.0;
    } else {
      // Winter: Potentially harsh weather
      return 70.0;
    }
  }

  /// Calculate crime-based safety score using historical data
  static double _calculateCrimeScore(Position position) {
    // This would integrate with:
    // - Police crime databases
    // - Government safety statistics
    // - Local safety reporting APIs

    // For now, simulate based on area patterns
    final lat = position.latitude;
    final lng = position.longitude;

    // Simulate crime data based on location hash
    final locationHash = (lat * lng * 10000).toInt().abs() % 100;

    if (locationHash < 20) {
      return 95.0; // Very safe area
    } else if (locationHash < 40) {
      return 85.0; // Safe area
    } else if (locationHash < 60) {
      return 75.0; // Moderate area
    } else if (locationHash < 80) {
      return 65.0; // Caution needed
    } else {
      return 50.0; // High caution area
    }
  }

  /// Calculate user behavior-based safety score with AI anomaly detection
  /// Regular patterns = higher score, erratic movement = lower score
  /// Enhanced with anomaly detection and behavior pattern analysis
  static Future<double> _calculateUserBehaviorScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_keyLocationHistory) ?? [];

      if (historyJson.length < 3) {
        return 75.0; // Default score for new users
      }

      // Analyze movement patterns (existing logic)
      List<Map<String, dynamic>> locations = historyJson
          .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
          .toList();

      // Calculate movement consistency
      int rapidMovements = 0;

      for (int i = 1; i < locations.length; i++) {
        final prev = locations[i - 1];
        final curr = locations[i];

        final distance = Geolocator.distanceBetween(
          prev['latitude'],
          prev['longitude'],
          curr['latitude'],
          curr['longitude'],
        );

        final timeDiff = DateTime.parse(
          curr['timestamp'],
        ).difference(DateTime.parse(prev['timestamp'])).inMinutes;

        if (timeDiff > 0) {
          final speed = distance / timeDiff; // meters per minute
          if (speed > 500) {
            // Very fast movement (>30 km/h equivalent)
            rapidMovements++;
          }
        }
      }

      // Base score from movement patterns
      double behaviorScore = 85.0;

      // Penalize erratic movement
      if (rapidMovements > locations.length * 0.3) {
        behaviorScore -= 20.0; // High movement variability
      } else if (rapidMovements > locations.length * 0.1) {
        behaviorScore -= 10.0; // Some movement variability
      }

      // ENHANCED: Integrate AI anomaly detection
      try {
        final anomalyService = AnomalyDetectionService();
        final behaviorTracker = BehaviorTrackingService();

        // Factor in anomaly risk
        double anomalyRisk = anomalyService.getCurrentAnomalyRisk();
        if (anomalyRisk > 0) {
          // Reduce score based on anomaly risk (0-100 scale)
          double anomalyPenalty =
              (anomalyRisk / 100) * 30.0; // Max 30 point penalty
          behaviorScore -= anomalyPenalty;

          debugPrint(
            '🔍 Anomaly risk: ${anomalyRisk.toStringAsFixed(1)}% - penalty: ${anomalyPenalty.toStringAsFixed(1)}',
          );
        }

        // Factor in current behavior insights
        Map<String, dynamic> insights = behaviorTracker.getCurrentInsights();

        // Stress level adjustment
        double stressLevel = insights['stressLevel'] ?? 5.0;
        if (stressLevel > 7.0) {
          behaviorScore -=
              (stressLevel - 7.0) * 5.0; // Reduce score for high stress
        } else if (stressLevel < 4.0) {
          behaviorScore +=
              (4.0 - stressLevel) * 2.0; // Small bonus for low stress
        }

        // Activity type bonus/penalty
        String currentActivity = insights['currentActivity'] ?? 'unknown';
        switch (currentActivity) {
          case 'tourist_activity':
            behaviorScore += 5.0; // Bonus for tourist activities
            break;
          case 'stationary':
            // Small penalty if stationary for too long at night
            if (DateTime.now().hour < 6 || DateTime.now().hour > 22) {
              behaviorScore -= 3.0;
            }
            break;
          case 'unknown':
            behaviorScore -= 2.0; // Small penalty for unknown activity
            break;
        }

        // Recent anomalies impact
        if (anomalyService.detectedAnomalies.isNotEmpty) {
          final recentAnomalies = anomalyService.detectedAnomalies
              .where(
                (a) => a.detectedAt.isAfter(
                  DateTime.now().subtract(const Duration(hours: 1)),
                ),
              )
              .toList();

          if (recentAnomalies.isNotEmpty) {
            double totalSeverity = recentAnomalies.fold(
              0.0,
              (sum, a) => sum + a.severity,
            );
            behaviorScore -=
                totalSeverity *
                10.0; // Reduce score based on recent anomaly severity
          }
        }
      } catch (anomalyError) {
        debugPrint('⚠️ Error integrating anomaly detection: $anomalyError');
        // Continue with basic calculation if anomaly detection fails
      }

      return behaviorScore.clamp(
        30.0,
        100.0,
      ); // Extended range for anomaly impact
    } catch (e) {
      debugPrint('🔴 Error calculating user behavior score: $e');
      return 75.0;
    }
  }

  /// Track location update and increment counter
  static Future<void> trackLocationUpdate(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Increment location update counter
      final currentCount = prefs.getInt(_keyLocationUpdateCount) ?? 0;
      await prefs.setInt(_keyLocationUpdateCount, currentCount + 1);

      // Save location to history
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': position.accuracy,
      };

      final historyJson = prefs.getStringList(_keyLocationHistory) ?? [];
      historyJson.add(jsonEncode(locationData));

      // Keep only last 100 locations to prevent storage bloat
      if (historyJson.length > 100) {
        historyJson.removeAt(0);
      }

      await prefs.setStringList(_keyLocationHistory, historyJson);

      debugPrint(
        '📍 Location tracked: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('🔴 Error tracking location: $e');
    }
  }

  /// Get current location update count
  static Future<int> getLocationUpdateCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLocationUpdateCount) ?? 0;
  }

  /// Initialize trip with duration
  static Future<void> initializeTrip(int durationDays) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTripStartDate, DateTime.now().toIso8601String());
    await prefs.setInt(_keyTripDuration, durationDays);
    await prefs.setInt(_keyLocationUpdateCount, 0); // Reset counter
  }

  /// Get remaining days in trip
  static Future<int> getRemainingDays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startDateString = prefs.getString(_keyTripStartDate);
      final durationDays = prefs.getInt(_keyTripDuration) ?? 7;

      if (startDateString == null) {
        // No trip initialized, create default
        await initializeTrip(7);
        return 7;
      }

      final startDate = DateTime.parse(startDateString);
      final endDate = startDate.add(Duration(days: durationDays));
      final remaining = endDate.difference(DateTime.now()).inDays;

      return remaining.clamp(0, durationDays);
    } catch (e) {
      debugPrint('🔴 Error getting remaining days: $e');
      return 7; // Default
    }
  }

  /// Save calculated safety score
  static Future<void> _saveSafetyScore(double score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLastSafetyScore, score);
  }

  /// Get last calculated safety score
  static Future<double> _getLastSafetyScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyLastSafetyScore) ?? 75.0;
  }

  /// Start real-time location monitoring for safety tracking
  static Future<void> startLocationMonitoring() async {
    try {
      // Check permissions first
      final position = await _getCurrentLocation();
      if (position == null) {
        debugPrint('🔴 Cannot start monitoring: Location permission denied');
        return;
      }

      // Track initial location
      await trackLocationUpdate(position);

      debugPrint('🟢 Location monitoring started');
    } catch (e) {
      debugPrint('🔴 Error starting location monitoring: $e');
    }
  }

  /// Get formatted safety score with percentage
  static String formatSafetyScore(double score) {
    return '${score.round()}%';
  }

  /// Get safety level description
  static String getSafetyLevel(double score) {
    if (score >= 85) return 'Very Safe';
    if (score >= 75) return 'Safe';
    if (score >= 65) return 'Moderate';
    if (score >= 50) return 'Caution';
    return 'High Alert';
  }

  /// Reset all data (for testing or trip reset)
  static Future<void> resetAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLocationHistory);
    await prefs.remove(_keyLastSafetyScore);
    await prefs.remove(_keyLocationUpdateCount);
    await prefs.remove(_keyTripStartDate);
    await prefs.remove(_keyTripDuration);
    debugPrint('🔄 All safety data reset');
  }
}

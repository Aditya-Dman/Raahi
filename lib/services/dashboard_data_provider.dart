import 'package:flutter/material.dart';
import 'dart:async';
import 'safety_score_service.dart';
import 'behavior_tracking_service.dart';
import 'anomaly_detection_service.dart';

class DashboardDataProvider extends ChangeNotifier {
  // Real-time data values
  double _safetyScore = 75.0;
  int _locationUpdates = 0;
  int _remainingDays = 7;
  bool _isLoading = true;
  Timer? _updateTimer;

  // AI Anomaly Detection & Behavior Tracking
  final BehaviorTrackingService _behaviorTracker = BehaviorTrackingService();
  final AnomalyDetectionService _anomalyService = AnomalyDetectionService();
  double _anomalyRisk = 0.0;
  String _currentActivity = 'unknown';
  double _stressLevel = 5.0;

  // Getters
  double get safetyScore => _safetyScore;
  int get locationUpdates => _locationUpdates;
  int get remainingDays => _remainingDays;
  bool get isLoading => _isLoading;
  double get anomalyRisk => _anomalyRisk;
  String get currentActivity => _currentActivity;
  double get stressLevel => _stressLevel;
  bool get isBehaviorTracking => _behaviorTracker.isTracking;

  // Formatted getters for UI
  String get safetyScoreFormatted =>
      SafetyScoreService.formatSafetyScore(_safetyScore);
  String get safetyLevel => SafetyScoreService.getSafetyLevel(_safetyScore);
  String get locationUpdatesFormatted => _locationUpdates.toString();
  String get remainingDaysFormatted => _remainingDays.toString();
  String get anomalyRiskFormatted => '${_anomalyRisk.toStringAsFixed(1)}%';
  String get stressLevelFormatted => '${_stressLevel.toStringAsFixed(1)}/10';

  DashboardDataProvider() {
    _initializeData();
    _startPeriodicUpdates();
  }

  /// Initialize dashboard data on startup
  Future<void> _initializeData() async {
    try {
      debugPrint('📊 Initializing dashboard data...');

      // Load initial data
      await _loadAllData();

      // Start location monitoring
      await SafetyScoreService.startLocationMonitoring();

      // Initialize AI behavior tracking
      bool behaviorTrackingStarted = await _behaviorTracker.startTracking();
      debugPrint(
        '🧠 Behavior tracking ${behaviorTrackingStarted ? 'started' : 'failed to start'}',
      );

      _isLoading = false;
      notifyListeners();

      debugPrint('✅ Dashboard data initialized successfully');
    } catch (e) {
      debugPrint('🔴 Error initializing dashboard data: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load all data from services
  Future<void> _loadAllData() async {
    await Future.wait([
      _loadSafetyScore(),
      _loadLocationUpdates(),
      _loadRemainingDays(),
      _loadBehaviorInsights(),
    ]);
  }

  /// Load current safety score
  Future<void> _loadSafetyScore() async {
    try {
      final score = await SafetyScoreService.calculateSafetyScore();
      if (_safetyScore != score) {
        _safetyScore = score;
        debugPrint('📊 Safety score updated: $safetyScoreFormatted');
      }
    } catch (e) {
      debugPrint('🔴 Error loading safety score: $e');
    }
  }

  /// Load location update count
  Future<void> _loadLocationUpdates() async {
    try {
      final updates = await SafetyScoreService.getLocationUpdateCount();
      if (_locationUpdates != updates) {
        _locationUpdates = updates;
        debugPrint('📍 Location updates: $locationUpdatesFormatted');
      }
    } catch (e) {
      debugPrint('🔴 Error loading location updates: $e');
    }
  }

  /// Load remaining trip days
  Future<void> _loadRemainingDays() async {
    try {
      final days = await SafetyScoreService.getRemainingDays();
      if (_remainingDays != days) {
        _remainingDays = days;
        debugPrint('📅 Remaining days: $remainingDaysFormatted');
      }
    } catch (e) {
      debugPrint('🔴 Error loading remaining days: $e');
    }
  }

  /// Load AI behavior insights and anomaly data
  Future<void> _loadBehaviorInsights() async {
    try {
      if (_behaviorTracker.isTracking) {
        // Get current insights
        Map<String, dynamic> insights = _behaviorTracker.getCurrentInsights();

        // Update anomaly risk
        double newAnomalyRisk = insights['anomalyRisk'] ?? 0.0;
        if (_anomalyRisk != newAnomalyRisk) {
          _anomalyRisk = newAnomalyRisk;
          debugPrint('🔍 Anomaly risk updated: $anomalyRiskFormatted');
        }

        // Update current activity
        String newActivity = insights['currentActivity'] ?? 'unknown';
        if (_currentActivity != newActivity) {
          _currentActivity = newActivity;
          debugPrint('🎯 Current activity: $newActivity');
        }

        // Update stress level
        double newStressLevel = insights['stressLevel'] ?? 5.0;
        if ((_stressLevel - newStressLevel).abs() > 0.1) {
          _stressLevel = newStressLevel;
          debugPrint('😰 Stress level: $stressLevelFormatted');
        }

        // Log high-risk situations
        if (_anomalyRisk > 70.0) {
          debugPrint('🚨 HIGH ANOMALY RISK DETECTED: $anomalyRiskFormatted');
        }
      }
    } catch (e) {
      debugPrint('🔴 Error loading behavior insights: $e');
    }
  }

  /// Start periodic updates (every 30 seconds)
  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isLoading) {
        refreshData();
      }
    });
    debugPrint('⏰ Started periodic dashboard updates (30s interval)');
  }

  /// Manually refresh all data
  Future<void> refreshData() async {
    try {
      debugPrint('🔄 Refreshing dashboard data...');
      await _loadAllData();
      notifyListeners();
      debugPrint('✅ Dashboard data refreshed');
    } catch (e) {
      debugPrint('🔴 Error refreshing dashboard data: $e');
    }
  }

  /// Force safety score recalculation
  Future<void> recalculateSafetyScore() async {
    try {
      debugPrint('🧮 Recalculating safety score...');
      final score = await SafetyScoreService.calculateSafetyScore();
      _safetyScore = score;
      notifyListeners();
      debugPrint('✅ Safety score recalculated: $safetyScoreFormatted');
    } catch (e) {
      debugPrint('🔴 Error recalculating safety score: $e');
    }
  }

  /// Simulate location update (for testing)
  Future<void> simulateLocationUpdate() async {
    try {
      debugPrint('🎯 Simulating location update...');

      // For testing purposes, manually increment counter
      _locationUpdates += 1;

      // Recalculate safety score with new data
      await recalculateSafetyScore();

      notifyListeners();
      debugPrint(
        '✅ Location update simulated - Count: $locationUpdatesFormatted',
      );
    } catch (e) {
      debugPrint('🔴 Error simulating location update: $e');
    }
  }

  /// Initialize a new trip
  Future<void> initializeTrip(int durationDays) async {
    try {
      debugPrint('🧳 Initializing new trip: $durationDays days');

      await SafetyScoreService.initializeTrip(durationDays);
      await _loadAllData();
      notifyListeners();

      debugPrint('✅ Trip initialized successfully');
    } catch (e) {
      debugPrint('🔴 Error initializing trip: $e');
    }
  }

  /// Reset all data
  Future<void> resetData() async {
    try {
      debugPrint('🔄 Resetting all dashboard data...');

      await SafetyScoreService.resetAllData();

      // Reset local values
      _safetyScore = 75.0;
      _locationUpdates = 0;
      _remainingDays = 7;

      notifyListeners();
      debugPrint('✅ All data reset successfully');
    } catch (e) {
      debugPrint('🔴 Error resetting data: $e');
    }
  }

  /// Get safety score color based on value
  Color getSafetyScoreColor() {
    if (_safetyScore >= 85) return const Color(0xFF38A169); // Green
    if (_safetyScore >= 75) return const Color(0xFF3182CE); // Blue
    if (_safetyScore >= 65) return const Color(0xFFD69E2E); // Yellow
    if (_safetyScore >= 50) return const Color(0xFFE53E3E); // Orange
    return const Color(0xFF9B2C2C); // Red
  }

  /// Get location updates color (always blue for now)
  Color getLocationUpdatesColor() {
    return const Color(0xFF3182CE); // Blue
  }

  /// Get remaining days color
  Color getRemainingDaysColor() {
    if (_remainingDays > 5) return const Color(0xFF38A169); // Green
    if (_remainingDays > 2) return const Color(0xFFD69E2E); // Yellow
    return const Color(0xFFE53E3E); // Red
  }

  /// Clean up resources
  @override
  void dispose() {
    _updateTimer?.cancel();
    _behaviorTracker
        .stopTracking(); // Stop behavior tracking when provider is disposed
    super.dispose();
  }

  /// Get comprehensive behavior analytics
  Map<String, dynamic> getBehaviorAnalytics() {
    return _behaviorTracker.getBehaviorSummary();
  }

  /// Get recent anomalies detected
  List<AnomalyDetection> getRecentAnomalies() {
    final recentCutoff = DateTime.now().subtract(const Duration(hours: 24));
    return _anomalyService.detectedAnomalies
        .where((a) => a.detectedAt.isAfter(recentCutoff))
        .toList();
  }

  /// Manually update stress level (from user input or external sensors)
  void updateStressLevel(double newLevel) {
    _behaviorTracker.updateStressLevel(newLevel);
    _stressLevel = newLevel;
    notifyListeners();
    debugPrint('👤 User updated stress level: $stressLevelFormatted');
  }

  /// Reset behavior tracking data
  void resetBehaviorData() {
    _behaviorTracker.resetBehaviorData();
    _anomalyRisk = 0.0;
    _currentActivity = 'unknown';
    _stressLevel = 5.0;
    notifyListeners();
    debugPrint('🔄 Behavior data reset');
  }

  /// Simulate behavior patterns for testing
  Future<void> simulateBehaviorPattern(
    String activityType, {
    double? speed,
    double? stress,
  }) async {
    await _behaviorTracker.simulateBehaviorPattern(
      activityType,
      speed: speed,
      stress: stress,
    );
    await _loadBehaviorInsights();
    notifyListeners();
    debugPrint('🎭 Simulated behavior: $activityType');
  }

  /// Check if user is in a potentially unsafe situation based on AI analysis
  bool isHighRiskSituation() {
    return _anomalyRisk > 80.0 || _stressLevel > 8.5 || _safetyScore < 40.0;
  }

  /// Get safety recommendations based on current behavior analysis
  List<String> getSafetyRecommendations() {
    List<String> recommendations = [];

    if (_anomalyRisk > 70.0) {
      recommendations.add(
        'High anomaly risk detected - consider reaching out to emergency contacts',
      );
    }

    if (_stressLevel > 8.0) {
      recommendations.add(
        'Elevated stress detected - take a moment to relax and assess your situation',
      );
    }

    if (_currentActivity == 'stationary' &&
        (DateTime.now().hour < 6 || DateTime.now().hour > 22)) {
      recommendations.add(
        'Extended stationary period during night hours - ensure you are in a safe location',
      );
    }

    if (_safetyScore < 50.0) {
      recommendations.add(
        'Low safety score - consider moving to a safer area or contacting local authorities',
      );
    }

    // Get recent anomalies for specific recommendations
    final recentAnomalies = getRecentAnomalies();
    for (var anomaly in recentAnomalies.take(3)) {
      recommendations.addAll(anomaly.recommendations);
    }

    return recommendations.toSet().toList(); // Remove duplicates
  }
}

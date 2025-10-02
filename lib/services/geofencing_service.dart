import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_alert_service.dart';
import 'anomaly_detection_service.dart';
import 'safety_score_service.dart';
import 'map_service.dart';
import 'supabase_data_service.dart';
import 'user_session.dart' as user_session;

/// AI-driven Geofencing Service
/// - Monitors user location in the background
/// - Detects entry into high-risk zones (static polygons + dynamic AI risk)
/// - Triggers smart alerts via AIAlertService
class GeofencingService {
  static final GeofencingService _instance = GeofencingService._internal();
  factory GeofencingService() => _instance;
  GeofencingService._internal();

  StreamSubscription<Position>? _positionSub;
  final AIAlertService _alertService = AIAlertService();
  final AnomalyDetectionService _anomalyService = AnomalyDetectionService();
  final SupabaseDataService _dataService = SupabaseDataService();

  // Debounce to avoid spamming alerts
  DateTime? _lastAlertAt;
  String? _lastAlertZoneId;
  
  // Configurable settings with defaults
  bool _enabled = true;
  double _safetyThreshold = 65.0;
  double _anomalyThreshold = 60.0;
  Duration _minAlertInterval = const Duration(minutes: 5);
  bool _persistToSupabase = true;
  
  bool _running = false;

  // Settings keys for SharedPreferences
  static const String _keyEnabled = 'geofencing_enabled';
  static const String _keySafetyThreshold = 'geofencing_safety_threshold';
  static const String _keyAnomalyThreshold = 'geofencing_anomaly_threshold';
  static const String _keyAlertInterval = 'geofencing_alert_interval_minutes';
  static const String _keyPersistToSupabase = 'geofencing_persist_supabase';

  bool get isRunning => _running;
  bool get isEnabled => _enabled;
  double get safetyThreshold => _safetyThreshold;
  double get anomalyThreshold => _anomalyThreshold;
  Duration get alertInterval => _minAlertInterval;
  bool get persistToSupabase => _persistToSupabase;

  Future<void> start() async {
    if (_running) {
      debugPrint('⚠️ Geofencing already running');
      return;
    }

    // Load settings from SharedPreferences
    await _loadSettings();

    // Ensure location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('🔴 Geofencing cannot start: location permission denied');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      debugPrint('🔴 Geofencing cannot start: location permission deniedForever');
      return;
    }

    // Kick off safety score location monitoring once (records history)
    await SafetyScoreService.startLocationMonitoring();

    // Optionally initialize static zones on map layer
    try {
      MapService.addSafetyZones();
    } catch (_) {}

    // Start listening for position updates (balanced accuracy, 30s/50m)
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.balanced,
        distanceFilter: 50,
        timeLimit: Duration(seconds: 30),
      ),
    ).listen(_onPosition);

    _running = true;
    debugPrint('🟢 Geofencing service started');
  }

  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _running = false;
    debugPrint('⏹️ Geofencing service stopped');
  }

  Future<void> _onPosition(Position pos) async {
    try {
      // Update map services for any listeners/visuals
      try {
        MapService.updateLocation(LatLng(pos.latitude, pos.longitude));
        MapService.addRoutePoint(LatLng(pos.latitude, pos.longitude));
      } catch (_) {}

      // Persist to safety score history
      await SafetyScoreService.trackLocationUpdate(pos);

      // Evaluate risk (0-100, lower is riskier in our scoring)
      final safetyScore = await SafetyScoreService.calculateSafetyScore();
      final anomalyRisk = _anomalyService.getCurrentAnomalyRisk(); // 0-100

      // Static polygon-based high-risk detection from MapService polygons
      final insideHighRiskPolygon = _isInsideHighRiskPolygon(
        LatLng(pos.latitude, pos.longitude),
      );

      // Heuristics for high-risk determination (using configurable thresholds)
      final bool isHighRisk = _enabled && (
          insideHighRiskPolygon || 
          safetyScore < _safetyThreshold || 
          anomalyRisk > _anomalyThreshold
      );

      if (isHighRisk) {
        final zoneId = insideHighRiskPolygon ? _findZoneId(LatLng(pos.latitude, pos.longitude)) : 'dynamic-risk';
        if (_shouldAlert(zoneId)) {
          await _triggerHighRiskAlert(
            safetyScore: safetyScore,
            anomalyRisk: anomalyRisk,
            position: pos,
            zoneId: zoneId,
          );
        }
      }
    } catch (e) {
      debugPrint('🔴 Geofencing processing error: $e');
    }
  }

  bool _shouldAlert(String zoneId) {
    final now = DateTime.now();
    if (_lastAlertAt == null) {
      _lastAlertAt = now;
      _lastAlertZoneId = zoneId;
      return true;
    }

    final sameZone = _lastAlertZoneId == zoneId;
    final due = now.difference(_lastAlertAt!) >= _minAlertInterval;

    if (!sameZone || due) {
      _lastAlertAt = now;
      _lastAlertZoneId = zoneId;
      return true;
    }
    return false;
  }

  bool _isInsideHighRiskPolygon(LatLng p) {
    try {
      for (final poly in MapService.safetyZones) {
        // Convention: polygons with id containing 'caution' or 'danger' are riskier
        final id = poly.polygonId.value.toLowerCase();
        if (id.contains('caution') || id.contains('danger') || id.contains('high_risk')) {
          if (_pointInPolygon(p, poly.points)) return true;
        }
      }
    } catch (_) {}
    return false;
  }

  String _findZoneId(LatLng p) {
    try {
      for (final poly in MapService.safetyZones) {
        final id = poly.polygonId.value;
        if (_pointInPolygon(p, poly.points)) return id;
      }
    } catch (_) {}
    return 'unknown-zone';
  }

  // Ray casting algorithm for point-in-polygon
  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int j = 0; j < polygon.length; j++) {
      LatLng a = polygon[j];
      LatLng b = polygon[(j + 1) % polygon.length];

      if (((a.latitude > point.latitude) != (b.latitude > point.latitude)) &&
          (point.longitude <
              (b.longitude - a.longitude) *
                      (point.latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  Future<void> _triggerHighRiskAlert({
    required double safetyScore,
    required double anomalyRisk,
    required Position position,
    required String zoneId,
  }) async {
    try {
      final severity = _computeSeverity(safetyScore, anomalyRisk);

      final anomaly = AnomalyDetection(
        anomalyType: 'geofence_high_risk',
        severity: severity,
        description:
            'High-risk area detected near (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}).',
        detectedAt: DateTime.now(),
        evidence: {
          'safetyScore': safetyScore,
          'anomalyRisk': anomalyRisk,
          'zoneId': zoneId,
          'coords': '${position.latitude},${position.longitude}',
        },
        recommendations: [
          'Avoid this area if possible',
          'Switch to a safer route',
          'Keep your emergency contacts informed',
        ],
      );

      await _alertService.processAnomaly(anomaly);
      
      // Persist to Supabase if enabled
      if (_persistToSupabase) {
        await _persistAlertToSupabase(anomaly, position, zoneId);
      }
      
      debugPrint('🚨 Geofence high-risk alert issued (zone: $zoneId, sev: ${severity.toStringAsFixed(2)})');
    } catch (e) {
      debugPrint('🔴 Error triggering high-risk alert: $e');
    }
  }

  double _computeSeverity(double safetyScore, double anomalyRisk) {
    // Convert safetyScore (0-100 safe) to risk (0-1 where higher is worse)
    final safetyRisk = (100.0 - safetyScore).clamp(0.0, 100.0) / 100.0;
    final anomaly = anomalyRisk.clamp(0.0, 100.0) / 100.0;

    // Weighted blend giving more weight to very low safety and high anomaly
    final severity = (0.55 * safetyRisk) + (0.45 * anomaly);
    return severity.clamp(0.0, 1.0);
  }

  // Settings management
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_keyEnabled) ?? true;
      _safetyThreshold = prefs.getDouble(_keySafetyThreshold) ?? 65.0;
      _anomalyThreshold = prefs.getDouble(_keyAnomalyThreshold) ?? 60.0;
      _minAlertInterval = Duration(minutes: prefs.getInt(_keyAlertInterval) ?? 5);
      _persistToSupabase = prefs.getBool(_keyPersistToSupabase) ?? true;
      debugPrint('📋 Geofencing settings loaded');
    } catch (e) {
      debugPrint('🔴 Error loading geofencing settings: $e');
    }
  }

  Future<void> updateSettings({
    bool? enabled,
    double? safetyThreshold,
    double? anomalyThreshold,
    Duration? alertInterval,
    bool? persistToSupabase,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (enabled != null) {
        _enabled = enabled;
        await prefs.setBool(_keyEnabled, enabled);
      }
      if (safetyThreshold != null) {
        _safetyThreshold = safetyThreshold.clamp(0.0, 100.0);
        await prefs.setDouble(_keySafetyThreshold, _safetyThreshold);
      }
      if (anomalyThreshold != null) {
        _anomalyThreshold = anomalyThreshold.clamp(0.0, 100.0);
        await prefs.setDouble(_keyAnomalyThreshold, _anomalyThreshold);
      }
      if (alertInterval != null) {
        _minAlertInterval = alertInterval;
        await prefs.setInt(_keyAlertInterval, alertInterval.inMinutes);
      }
      if (persistToSupabase != null) {
        _persistToSupabase = persistToSupabase;
        await prefs.setBool(_keyPersistToSupabase, persistToSupabase);
      }
      
      debugPrint('💾 Geofencing settings updated');
    } catch (e) {
      debugPrint('🔴 Error updating geofencing settings: $e');
    }
  }

  // Supabase persistence
  Future<void> _persistAlertToSupabase(AnomalyDetection anomaly, Position position, String zoneId) async {
    try {
      final currentUser = user_session.UserSession.getCurrentUser();
      if (currentUser == null) return;

      await _dataService.saveGeofenceAlert(
        userId: currentUser.id,
        latitude: position.latitude,
        longitude: position.longitude,
        alertType: anomaly.anomalyType,
        zoneId: zoneId,
        severity: anomaly.severity,
        evidence: anomaly.evidence,
      );

      debugPrint('💾 Geofence alert persisted to Supabase');
    } catch (e) {
      debugPrint('🔴 Error persisting to Supabase: $e');
    }
  }

  // Get current risk level for UI display
  Future<Map<String, dynamic>> getCurrentRiskLevel() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final safetyScore = await SafetyScoreService.calculateSafetyScore();
      final anomalyRisk = _anomalyService.getCurrentAnomalyRisk();
      final insideHighRiskPolygon = _isInsideHighRiskPolygon(
        LatLng(position.latitude, position.longitude),
      );

      final isHighRisk = _enabled && (
          insideHighRiskPolygon || 
          safetyScore < _safetyThreshold || 
          anomalyRisk > _anomalyThreshold
      );

      return {
        'isHighRisk': isHighRisk,
        'safetyScore': safetyScore,
        'anomalyRisk': anomalyRisk,
        'insideHighRiskPolygon': insideHighRiskPolygon,
        'severity': _computeSeverity(safetyScore, anomalyRisk),
        'position': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      };
    } catch (e) {
      debugPrint('🔴 Error getting current risk level: $e');
      return {
        'isHighRisk': false,
        'safetyScore': 75.0,
        'anomalyRisk': 0.0,
        'insideHighRiskPolygon': false,
        'severity': 0.0,
      };
    }
  }
}

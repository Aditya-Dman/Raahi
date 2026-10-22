import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_data_service.dart';
import '../services/user_session.dart' as user_session;

class SimpleMapWidget extends StatefulWidget {
  const SimpleMapWidget({super.key});

  @override
  State<SimpleMapWidget> createState() => _SimpleMapWidgetState();
}

class _SimpleMapWidgetState extends State<SimpleMapWidget> {
  static const _routeKey = 'raahi_active_route';
  static const _lastLocationKey = 'raahi_last_location';
  static const _routeStartKey = 'raahi_route_start';
  static const _routeStartedAtKey = 'raahi_route_started_at';
  static const _routeEndedAtKey = 'raahi_route_ended_at';
  static const LatLng _fallbackLocation = LatLng(28.6139, 77.2090);

  final MapController _mapController = MapController();
  final SupabaseDataService _dataService = SupabaseDataService();
  StreamSubscription<Position>? _locationSubscription;
  Position? _position;
  String? _locationMessage;
  List<LatLng> _route = [];
  bool _isTracking = false;
  DateTime? _trackingStartedAt;
  DateTime? _trackingEndedAt;
  LatLng? _routeStart;
  double _distanceMeters = 0;
  DateTime? _lastCloudSave;

  @override
  void initState() {
    super.initState();
    _restoreRoute();
    _loadLocation();
  }

  Future<void> _restoreRoute() async {
    final preferences = await SharedPreferences.getInstance();
    final lastLocation = preferences.getStringList(_lastLocationKey);
    if (lastLocation != null && lastLocation.length == 2) {
      final latitude = double.tryParse(lastLocation[0]);
      final longitude = double.tryParse(lastLocation[1]);
      if (latitude != null && longitude != null && mounted) {
        setState(
          () => _position = Position(
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
        );
      }
    }
    final encoded = preferences.getString(_routeKey);
    final start = preferences.getStringList(_routeStartKey);
    if (start != null && start.length == 2) {
      _routeStart = LatLng(double.parse(start[0]), double.parse(start[1]));
    }
    final startedAt = preferences.getString(_routeStartedAtKey);
    final endedAt = preferences.getString(_routeEndedAtKey);
    _trackingStartedAt = startedAt == null
        ? null
        : DateTime.tryParse(startedAt);
    _trackingEndedAt = endedAt == null ? null : DateTime.tryParse(endedAt);
    if (encoded == null) return;

    try {
      final points = (jsonDecode(encoded) as List).map((point) {
        final values = point as List;
        return LatLng(
          (values[0] as num).toDouble(),
          (values[1] as num).toDouble(),
        );
      }).toList();
      if (mounted) setState(() => _route = points);
      _distanceMeters = _calculateRouteDistance(points);
    } catch (_) {
      await preferences.remove(_routeKey);
    }
  }

  Future<void> _persistRoute() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _routeKey,
      jsonEncode(
        _route.map((point) => [point.latitude, point.longitude]).toList(),
      ),
    );
  }

  Future<void> _persistRouteMetadata() async {
    final preferences = await SharedPreferences.getInstance();
    if (_routeStart != null) {
      await preferences.setStringList(_routeStartKey, [
        _routeStart!.latitude.toString(),
        _routeStart!.longitude.toString(),
      ]);
    }
    if (_trackingStartedAt != null) {
      await preferences.setString(
        _routeStartedAtKey,
        _trackingStartedAt!.toIso8601String(),
      );
    }
    if (_trackingEndedAt != null) {
      await preferences.setString(
        _routeEndedAtKey,
        _trackingEndedAt!.toIso8601String(),
      );
    }
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(
        () => _locationMessage = 'Turn on location services to track you.',
      );
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(
        () => _locationMessage = 'Allow location permission to track you.',
      );
      return false;
    }
    return true;
  }

  Future<void> _loadLocation() async {
    try {
      if (!await _ensureLocationPermission()) return;
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _position = position;
        _locationMessage = null;
      });
      await _persistLastLocation(position);
      _moveTo(position, zoom: 16);
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationMessage = 'Unable to read your current location.',
        );
      }
    }
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _locationSubscription?.cancel();
      _locationSubscription = null;
      if (mounted) {
        setState(() {
          _isTracking = false;
          _trackingEndedAt = DateTime.now();
        });
        if (_position != null) {
          await _persistLastLocation(_position!);
        }
      }

      await _persistRoute();
      await _persistRouteMetadata();
      return;
    }

    if (!await _ensureLocationPermission()) return;
    await _loadLocation();
    if (!mounted || _position == null) return;

    setState(() {
      _isTracking = true;
      _trackingStartedAt ??= DateTime.now();
      _trackingEndedAt = null;
      _routeStart ??= LatLng(_position!.latitude, _position!.longitude);
      if (_route.isEmpty) {
        _route = [LatLng(_position!.latitude, _position!.longitude)];
      }
    });
    await _persistRoute();
    await _persistRouteMetadata();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(_recordPosition);
  }

  Future<void> _persistLastLocation(Position position) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_lastLocationKey, [
      position.latitude.toString(),
      position.longitude.toString(),
    ]);
  }

  Future<void> _recordPosition(Position position) async {
    if (!mounted || !_isTracking || position.accuracy > 100) return;

    final point = LatLng(position.latitude, position.longitude);
    final previous = _route.isEmpty ? null : _route.last;
    if (previous != null) {
      final segment = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      );
      if (segment < 3) return;
      _distanceMeters += segment;
    }

    setState(() {
      _position = position;
      _route = [..._route, point];
      _locationMessage = null;
    });
    _moveTo(position, zoom: 17);
    await _persistRoute();
    await _persistRouteMetadata();

    // Cloud history is best-effort; the local route remains available offline.
    final now = DateTime.now();
    final userId = user_session.UserSession.getUserId();
    if (userId.isNotEmpty &&
        (_lastCloudSave == null ||
            now.difference(_lastCloudSave!) >= const Duration(seconds: 15))) {
      _lastCloudSave = now;
      await _dataService.saveUserLocation(
        userId: userId,
        latitude: point.latitude,
        longitude: point.longitude,
        locationName: 'Tracked route',
      );
    }
  }

  void _moveTo(Position position, {required double zoom}) {
    _mapController.move(LatLng(position.latitude, position.longitude), zoom);
  }

  Future<void> _clearRoute() async {
    await _persistEmptyRoute();
    if (mounted) {
      setState(() {
        _route = [];
        _distanceMeters = 0;
        _trackingStartedAt = null;
        _trackingEndedAt = null;
        _routeStart = null;
      });
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_routeStartKey);
    await preferences.remove(_routeStartedAtKey);
    await preferences.remove(_routeEndedAtKey);
  }

  Future<void> _persistEmptyRoute() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_routeKey);
  }

  @override
  Widget build(BuildContext context) {
    final current = _position == null
        ? _fallbackLocation
        : LatLng(_position!.latitude, _position!.longitude);
    final elapsed = _trackingStartedAt == null
        ? ''
        : _formatDuration(DateTime.now().difference(_trackingStartedAt!));

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: current,
            initialZoom: _position == null ? 12 : 16,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.raahi',
            ),
            if (_route.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _route,
                    strokeWidth: 5,
                    color: const Color(0xFF2563EB),
                  ),
                ],
              ),
            if (_position != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: current,
                    width: 52,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.my_location_rounded,
                          color: Color(0xFF1D4ED8),
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(
                    _isTracking
                        ? Icons.radio_button_checked_rounded
                        : Icons.route_rounded,
                    color: _isTracking
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isTracking
                              ? 'Tracking your route'
                              : 'Route tracking',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          _route.length < 2
                              ? 'Start tracking to draw your path'
                              : '${_formatDistance(_distanceMeters)}  •  ${_route.length} points'
                                    '${elapsed.isEmpty ? '' : '  •  $elapsed'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        if (!_isTracking && _route.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Summary  •  ${_formatDistance(_distanceMeters)}  •  '
                              '${_averageSpeedKmh.toStringAsFixed(1)} km/h  •  '
                              '${_route.length} points\n'
                              'Started: ${_formatCoordinate(_routeStart)}  •  '
                              'Ended: ${_formatCoordinate(_route.isEmpty ? null : _route.last)}\n'
                              'Date: ${_trackingEndedAt == null ? 'Not available' : _formatDate(_trackingEndedAt!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _toggleTracking,
                    icon: Icon(
                      _isTracking
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(_isTracking ? 'Stop' : 'Start'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isTracking
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 104,
          right: 14,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'center-location',
                onPressed: () {
                  if (_position == null) {
                    _loadLocation();
                  } else {
                    _moveTo(_position!, zoom: 16);
                  }
                },
                child: const Icon(Icons.my_location_rounded),
              ),
              if (_route.isNotEmpty) ...[
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'clear-route',
                  onPressed: _isTracking ? null : _clearRoute,
                  tooltip: 'Clear route',
                  child: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
        ),
        if (_locationMessage != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.location_off_outlined),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_locationMessage!)),
                    TextButton(
                      onPressed: _loadLocation,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  double _calculateRouteDistance(List<LatLng> points) {
    var distance = 0.0;
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      distance += Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
    }
    return distance;
  }

  double get _averageSpeedKmh {
    final started = _trackingStartedAt;
    final ended = _trackingEndedAt;
    if (started == null || ended == null || _distanceMeters == 0) return 0;
    final hours = ended.difference(started).inSeconds / 3600;
    return hours <= 0 ? 0 : (_distanceMeters / 1000) / hours;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String _formatCoordinate(LatLng? point) {
    if (point == null) return 'Not available';
    return '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }
}

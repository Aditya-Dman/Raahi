import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

class MapService {
  static GoogleMapController? _controller;
  static final StreamController<LatLng> _locationStream =
      StreamController<LatLng>.broadcast();
  static LatLng? _currentLocation;
  static final Set<Marker> _markers = {};
  static final Set<Polygon> _safetyZones = {};
  static final Set<Polyline> _routeHistory = {};

  // Initialize map controller
  static void onMapCreated(GoogleMapController controller) {
    _controller = controller;
  }

  // Get current location stream
  static Stream<LatLng> get locationStream => _locationStream.stream;

  // Update current location
  static void updateLocation(LatLng location) {
    _currentLocation = location;
    _locationStream.add(location);
    _addCurrentLocationMarker(location);
  }

  // Add current location marker
  static void _addCurrentLocationMarker(LatLng location) {
    _markers.removeWhere(
      (marker) => marker.markerId.value == 'current_location',
    );
    _markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Current Location'),
      ),
    );
  }

  // Add safety zones
  static void addSafetyZones() {
    _safetyZones.clear();

    // Safe zone - Tourist area (Red Fort vicinity)
    _safetyZones.add(
      Polygon(
        polygonId: const PolygonId('safe_zone_tourist'),
        points: [
          const LatLng(28.6560, 77.2410), // Red Fort area
          const LatLng(28.6580, 77.2410),
          const LatLng(28.6580, 77.2430),
          const LatLng(28.6560, 77.2430),
        ],
        fillColor: Colors.green.withOpacity(0.3),
        strokeColor: Colors.green,
        strokeWidth: 2,
      ),
    );

    // Caution zone - Busy market area
    _safetyZones.add(
      Polygon(
        polygonId: const PolygonId('caution_zone_market'),
        points: [
          const LatLng(28.6500, 77.2300),
          const LatLng(28.6520, 77.2300),
          const LatLng(28.6520, 77.2320),
          const LatLng(28.6500, 77.2320),
        ],
        fillColor: Colors.orange.withOpacity(0.3),
        strokeColor: Colors.orange,
        strokeWidth: 2,
      ),
    );

    // High-risk zone - Isolated area
    _safetyZones.add(
      Polygon(
        polygonId: const PolygonId('high_risk_zone_isolated'),
        points: [
          const LatLng(28.6400, 77.2200),
          const LatLng(28.6420, 77.2200),
          const LatLng(28.6420, 77.2220),
          const LatLng(28.6400, 77.2220),
        ],
        fillColor: Colors.red.withOpacity(0.3),
        strokeColor: Colors.red,
        strokeWidth: 2,
      ),
    );

    // Danger zone - Construction/restricted area
    _safetyZones.add(
      Polygon(
        polygonId: const PolygonId('danger_zone_construction'),
        points: [
          const LatLng(28.6350, 77.2150),
          const LatLng(28.6370, 77.2150),
          const LatLng(28.6370, 77.2170),
          const LatLng(28.6350, 77.2170),
        ],
        fillColor: Colors.red.withOpacity(0.4),
        strokeColor: Colors.red,
        strokeWidth: 3,
      ),
    );

    // Additional safe zones around major landmarks
    _safetyZones.add(
      Polygon(
        polygonId: const PolygonId('safe_zone_connaught'),
        points: [
          const LatLng(28.6304, 77.2177), // Connaught Place
          const LatLng(28.6324, 77.2177),
          const LatLng(28.6324, 77.2197),
          const LatLng(28.6304, 77.2197),
        ],
        fillColor: Colors.green.withOpacity(0.3),
        strokeColor: Colors.green,
        strokeWidth: 2,
      ),
    );
  }

  // Add tourist service markers
  static void addTouristServiceMarkers() {
    // Restaurant markers
    _markers.add(
      Marker(
        markerId: const MarkerId('restaurant_1'),
        position: const LatLng(28.6149, 77.2100),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(
          title: 'Karim Restaurant',
          snippet: 'Famous Mughlai cuisine',
        ),
      ),
    );

    // Hotel markers
    _markers.add(
      Marker(
        markerId: const MarkerId('hotel_1'),
        position: const LatLng(28.6150, 77.2095),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: 'Hotel Delhi Heights',
          snippet: '4-star accommodation',
        ),
      ),
    );

    // Tourist attraction markers
    _markers.add(
      Marker(
        markerId: const MarkerId('attraction_1'),
        position: const LatLng(28.6162, 77.2089),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: const InfoWindow(
          title: 'Red Fort',
          snippet: 'Historical monument',
        ),
      ),
    );

    // Emergency services
    _markers.add(
      Marker(
        markerId: const MarkerId('police_1'),
        position: const LatLng(28.6145, 77.2080),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(
          title: 'Police Station',
          snippet: 'Emergency services',
        ),
      ),
    );
  }

  // Get markers
  static Set<Marker> get markers => _markers;

  // Get safety zones
  static Set<Polygon> get safetyZones => _safetyZones;

  // Get route history
  static Set<Polyline> get routeHistory => _routeHistory;

  // Move camera to location
  static void moveToLocation(LatLng location) {
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 15),
      ),
    );
  }

  // Add route point to history
  static void addRoutePoint(LatLng point) {
    List<LatLng> routePoints = [];
    if (_routeHistory.isNotEmpty) {
      routePoints = _routeHistory.first.points;
    }
    routePoints.add(point);

    _routeHistory.clear();
    _routeHistory.add(
      Polyline(
        polylineId: const PolylineId('route_history'),
        points: routePoints,
        color: Colors.blue,
        width: 3,
      ),
    );
  }

  // Calculate safety score for location
  static double calculateSafetyScore(LatLng location) {
    // Mock implementation - in real app, this would use AI/ML
    // Check if location is in safe zone
    for (var zone in _safetyZones) {
      if (zone.polygonId.value.contains('safe')) {
        return 85.0; // High safety score
      }
    }
    return 65.0; // Moderate safety score
  }
}

// Location simulation service for demo
class LocationSimulator {
  static Timer? _timer;
  static int _step = 0;
  static final List<LatLng> _demoRoute = [
    const LatLng(28.6139, 77.2090), // Starting point
    const LatLng(28.6145, 77.2095),
    const LatLng(28.6150, 77.2100),
    const LatLng(28.6155, 77.2105),
    const LatLng(28.6160, 77.2110),
  ];

  static void startSimulation() {
    _timer?.cancel();
    _step = 0;

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_step < _demoRoute.length) {
        MapService.updateLocation(_demoRoute[_step]);
        MapService.addRoutePoint(_demoRoute[_step]);
        _step++;
      } else {
        _step = 0; // Loop back
      }
    });
  }

  static void stopSimulation() {
    _timer?.cancel();
  }
}

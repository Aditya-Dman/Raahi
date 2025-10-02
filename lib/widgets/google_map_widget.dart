import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class GoogleMapWidget extends StatefulWidget {
  final bool showSafetyZones;
  final bool showTouristServices;
  final bool showRouteHistory;

  const GoogleMapWidget({
    super.key,
    this.showSafetyZones = false,
    this.showTouristServices = false,
    this.showRouteHistory = false,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(28.6139, 77.2090); // Default to Delhi
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _routeHistory = [];
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTrackingLocation = false;
  bool _locationPermissionGranted = false;

  // Sample safety zones for Delhi
  final Set<Polygon> _safetyZones = {
    Polygon(
      polygonId: const PolygonId('safe_zone_1'),
      points: const [
        LatLng(28.6129, 77.2080),
        LatLng(28.6149, 77.2080),
        LatLng(28.6149, 77.2100),
        LatLng(28.6129, 77.2100),
      ],
      fillColor: Colors.green.withOpacity(0.3),
      strokeColor: Colors.green,
      strokeWidth: 2,
    ),
    Polygon(
      polygonId: const PolygonId('caution_zone_1'),
      points: const [
        LatLng(28.6100, 77.2050),
        LatLng(28.6120, 77.2050),
        LatLng(28.6120, 77.2070),
        LatLng(28.6100, 77.2070),
      ],
      fillColor: Colors.orange.withOpacity(0.3),
      strokeColor: Colors.orange,
      strokeWidth: 2,
    ),
    Polygon(
      polygonId: const PolygonId('restricted_zone_1'),
      points: const [
        LatLng(28.6170, 77.2120),
        LatLng(28.6190, 77.2120),
        LatLng(28.6190, 77.2140),
        LatLng(28.6170, 77.2140),
      ],
      fillColor: Colors.red.withOpacity(0.3),
      strokeColor: Colors.red,
      strokeWidth: 2,
    ),
  };

  // Sample tourist services markers
  final Set<Marker> _touristMarkers = {
    Marker(
      markerId: const MarkerId('hospital_1'),
      position: const LatLng(28.6145, 77.2095),
      infoWindow: const InfoWindow(
        title: 'Hospital',
        snippet: 'Emergency Medical Services',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ),
    Marker(
      markerId: const MarkerId('police_1'),
      position: const LatLng(28.6155, 77.2105),
      infoWindow: const InfoWindow(
        title: 'Police Station',
        snippet: 'Emergency Services',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    ),
    Marker(
      markerId: const MarkerId('tourist_info_1'),
      position: const LatLng(28.6165, 77.2115),
      infoWindow: const InfoWindow(
        title: 'Tourist Information',
        snippet: 'Help and Information Center',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ),
  };

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _initializeMarkers();
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    try {
      // Request location permission
      final permission = await Permission.location.request();

      if (permission.isGranted) {
        if (mounted) {
          setState(() {
            _locationPermissionGranted = true;
          });
        }
        await _getCurrentLocation();
      } else {
        // Set default location even if permission denied so map still shows
        if (mounted) {
          setState(() {
            _locationPermissionGranted = false;
            _currentLocation = const LatLng(28.6139, 77.2090); // Delhi default
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required for GPS tracking'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error requesting location permission: $e');
      // Fallback to default location on any error
      if (mounted) {
        setState(() {
          _locationPermissionGranted = false;
          _currentLocation = const LatLng(28.6139, 77.2090); // Delhi default
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!_locationPermissionGranted) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // Add timeout
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentLocation, zoom: 15),
          ),
        );

        _updateCurrentLocationMarker();
      }
    } catch (e) {
      print('Error getting current location: $e');
      // Use last known position as fallback
      try {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null && mounted) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
        }
      } catch (e2) {
        print('Error getting last known location: $e2');
      }
    }
  }

  void _updateCurrentLocationMarker() {
    setState(() {
      _markers.removeWhere(
        (marker) => marker.markerId.value == 'current_location',
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation,
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    });
  }

  void _initializeMarkers() {
    if (widget.showTouristServices) {
      setState(() {
        _markers.addAll(_touristMarkers);
      });
    }
  }

  void startLocationTracking() {
    if (!_locationPermissionGranted || _isTrackingLocation) return;

    setState(() {
      _isTrackingLocation = true;
      _routeHistory.clear();
    });

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            final newLocation = LatLng(position.latitude, position.longitude);

            setState(() {
              _currentLocation = newLocation;
              _routeHistory.add(newLocation);
            });

            _updateCurrentLocationMarker();
            _updateRoutePolyline();

            // Auto-center camera on current location
            _mapController?.animateCamera(CameraUpdate.newLatLng(newLocation));
          },
        );
  }

  void stopLocationTracking() {
    _stopLocationTracking();
  }

  void _stopLocationTracking() {
    if (mounted) {
      setState(() {
        _isTrackingLocation = false;
      });
    }
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  void _updateRoutePolyline() {
    if (!widget.showRouteHistory || _routeHistory.length < 2) return;

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_history'),
          points: _routeHistory,
          color: Colors.blue,
          width: 3,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          initialCameraPosition: CameraPosition(
            target: _currentLocation,
            zoom: 12,
          ),
          markers: _markers,
          polylines: widget.showRouteHistory ? _polylines : {},
          polygons: widget.showSafetyZones ? _safetyZones : {},
          myLocationEnabled: _locationPermissionGranted,
          myLocationButtonEnabled: true,
          mapType: MapType.normal,
          zoomControlsEnabled: true,
          compassEnabled: true,
          trafficEnabled: false,
          buildingsEnabled: true,
        ),
        // Location permission prompt
        if (!_locationPermissionGranted)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 48,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Location Permission Required',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please grant location permission to view the map and enable GPS tracking.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _requestLocationPermission,
                        child: const Text('Grant Permission'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Tracking status indicator
        if (_isTrackingLocation)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'GPS Tracking Active',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Public methods for external control
  bool get isTracking => _isTrackingLocation;

  void centerOnCurrentLocation() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation, zoom: 15),
        ),
      );
    }
  }
}

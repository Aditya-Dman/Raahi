import 'package:flutter/material.dart';
import 'dart:async';

// Mock location class
class Location {
  final double latitude;
  final double longitude;
  final String? name;
  final String? description;
  
  const Location(this.latitude, this.longitude, {this.name, this.description});
  
  @override
  String toString() => 'Location($latitude, $longitude)';
}

// Mock map service for demonstration
class MockMapService {
  static final StreamController<Location> _locationController = StreamController<Location>.broadcast();
  static Timer? _trackingTimer;
  static bool _isTracking = false;
  static Location? _currentLocation;
  static final List<Location> _routeHistory = [];
  static final List<MapMarker> _markers = [];

  // Demo locations in Delhi
  static final List<Location> _demoRoute = [
    const Location(28.6139, 77.2090, name: 'Red Fort Area'),
    const Location(28.6145, 77.2095, name: 'Chandni Chowk'),
    const Location(28.6150, 77.2100, name: 'Jama Masjid'),
    const Location(28.6155, 77.2105, name: 'Raj Ghat'),
    const Location(28.6160, 77.2110, name: 'India Gate'),
  ];

  static int _routeIndex = 0;

  static Stream<Location> get locationStream => _locationController.stream;
  static Location? get currentLocation => _currentLocation;
  static List<Location> get routeHistory => _routeHistory;
  static List<MapMarker> get markers => _markers;
  static bool get isTracking => _isTracking;

  static void startTracking() {
    if (_isTracking) return;
    
    _isTracking = true;
    _trackingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final location = _demoRoute[_routeIndex % _demoRoute.length];
      _updateLocation(location);
      _routeIndex++;
    });
  }

  static void stopTracking() {
    _isTracking = false;
    _trackingTimer?.cancel();
  }

  static void _updateLocation(Location location) {
    _currentLocation = location;
    _routeHistory.add(location);
    _locationController.add(location);
  }

  static void addTouristServiceMarkers() {
    _markers.clear();
    _markers.addAll([
      MapMarker(
        id: 'restaurant_1',
        location: const Location(28.6149, 77.2100, name: 'Karim Restaurant'),
        type: MarkerType.restaurant,
        description: 'Famous Mughlai cuisine',
      ),
      MapMarker(
        id: 'hotel_1',
        location: const Location(28.6150, 77.2095, name: 'Hotel Delhi Heights'),
        type: MarkerType.hotel,
        description: '4-star accommodation',
      ),
      MapMarker(
        id: 'attraction_1',
        location: const Location(28.6162, 77.2089, name: 'Red Fort'),
        type: MarkerType.attraction,
        description: 'Historical monument',
      ),
      MapMarker(
        id: 'hospital_1',
        location: const Location(28.6145, 77.2080, name: 'AIIMS'),
        type: MarkerType.medical,
        description: 'Emergency medical services',
      ),
      MapMarker(
        id: 'police_1',
        location: const Location(28.6140, 77.2085, name: 'Police Station'),
        type: MarkerType.emergency,
        description: 'Emergency services',
      ),
    ]);
  }

  static double calculateSafetyScore(Location location) {
    // Mock safety calculation based on area
    if (location.name?.contains('Red Fort') ?? false) return 85.0;
    if (location.name?.contains('Chandni Chowk') ?? false) return 75.0;
    if (location.name?.contains('India Gate') ?? false) return 90.0;
    return 70.0;
  }

  static void dispose() {
    _trackingTimer?.cancel();
    _locationController.close();
  }
}

enum MarkerType { restaurant, hotel, attraction, medical, emergency, guide }

class MapMarker {
  final String id;
  final Location location;
  final MarkerType type;
  final String description;

  MapMarker({
    required this.id,
    required this.location,
    required this.type,
    required this.description,
  });

  Color get color {
    switch (type) {
      case MarkerType.restaurant:
        return Colors.red;
      case MarkerType.hotel:
        return Colors.blue;
      case MarkerType.attraction:
        return Colors.purple;
      case MarkerType.medical:
        return Colors.green;
      case MarkerType.emergency:
        return Colors.orange;
      case MarkerType.guide:
        return Colors.teal;
    }
  }

  IconData get icon {
    switch (type) {
      case MarkerType.restaurant:
        return Icons.restaurant;
      case MarkerType.hotel:
        return Icons.hotel;
      case MarkerType.attraction:
        return Icons.place;
      case MarkerType.medical:
        return Icons.local_hospital;
      case MarkerType.emergency:
        return Icons.local_police;
      case MarkerType.guide:
        return Icons.person;
    }
  }
}

// Mock map widget
class MockMapWidget extends StatefulWidget {
  final bool showSafetyZones;
  final bool showTouristServices;
  final bool showRouteHistory;
  final Function(Location)? onLocationTap;

  const MockMapWidget({
    super.key,
    this.showSafetyZones = true,
    this.showTouristServices = true,
    this.showRouteHistory = true,
    this.onLocationTap,
  });

  @override
  State<MockMapWidget> createState() => _MockMapWidgetState();
}

class _MockMapWidgetState extends State<MockMapWidget> {
  late StreamSubscription<Location> _locationSubscription;
  Location? _currentLocation;

  @override
  void initState() {
    super.initState();
    MockMapService.addTouristServiceMarkers();
    _locationSubscription = MockMapService.locationStream.listen((location) {
      setState(() {
        _currentLocation = location;
      });
    });
  }

  @override
  void dispose() {
    _locationSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.green.shade50,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Mock map background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 120,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Interactive Map View',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Real-time GPS tracking and safety zones',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // Current location indicator
          if (_currentLocation != null)
            Positioned(
              top: 80,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.my_location, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentLocation!.name ?? 'Current Location',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Safety zones indicator
          if (widget.showSafetyZones)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.security, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Safe Zone',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Tourist services markers
          if (widget.showTouristServices)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: MockMapService.markers.length,
                  itemBuilder: (context, index) {
                    final marker = MockMapService.markers[index];
                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: marker.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(marker.icon, color: marker.color, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  marker.location.name ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  marker.description,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // Map controls
          Positioned(
            top: 150,
            right: 20,
            child: Column(
              children: [
                _MapControlButton(
                  icon: Icons.zoom_in,
                  onPressed: () {},
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.zoom_out,
                  onPressed: () {},
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.my_location,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapControlButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.grey.shade700),
        iconSize: 20,
      ),
    );
  }
}
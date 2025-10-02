import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/geofencing_service.dart';
import '../services/map_service.dart';

class EnhancedMapWidget extends StatefulWidget {
  final double height;
  final bool showRiskZones;
  final bool showCurrentLocation;

  const EnhancedMapWidget({
    super.key,
    this.height = 300,
    this.showRiskZones = true,
    this.showCurrentLocation = true,
  });

  @override
  State<EnhancedMapWidget> createState() => _EnhancedMapWidgetState();
}

class _EnhancedMapWidgetState extends State<EnhancedMapWidget> {
  GoogleMapController? _controller;
  final GeofencingService _geofencingService = GeofencingService();
  
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  Set<Circle> _circles = {};
  
  bool _isLoading = true;
  Map<String, dynamic> _currentRisk = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    await _loadRiskZones();
    await _updateCurrentRisk();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission != LocationPermission.denied && 
          permission != LocationPermission.deniedForever) {
        _currentPosition = await Geolocator.getCurrentPosition();
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadRiskZones() async {
    Set<Marker> markers = {};
    Set<Polygon> polygons = {};
    Set<Circle> circles = {};

    // Add current location marker
    if (widget.showCurrentLocation && _currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
        ),
      );

      // Add risk circle around current location
      final riskLevel = await _geofencingService.getCurrentRiskLevel();
      final isHighRisk = riskLevel['isHighRisk'] ?? false;
      final severity = riskLevel['severity']?.toDouble() ?? 0.0;

      Color circleColor;
      if (isHighRisk) {
        if (severity > 0.8) {
          circleColor = Colors.red;
        } else if (severity > 0.6) {
          circleColor = Colors.orange;
        } else {
          circleColor = Colors.yellow;
        }
      } else {
        circleColor = Colors.green;
      }

      circles.add(
        Circle(
          circleId: const CircleId('risk_indicator'),
          center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          radius: 200, // 200m radius
          fillColor: circleColor.withOpacity(0.2),
          strokeColor: circleColor,
          strokeWidth: 2,
        ),
      );
    }

    // Add static risk zones from MapService
    if (widget.showRiskZones) {
      try {
        MapService.addSafetyZones();
        for (final polygon in MapService.safetyZones) {
          final id = polygon.polygonId.value.toLowerCase();
          
          Color polygonColor;
          if (id.contains('danger') || id.contains('high_risk')) {
            polygonColor = Colors.red;
          } else if (id.contains('caution')) {
            polygonColor = Colors.orange;
          } else if (id.contains('safe')) {
            polygonColor = Colors.green;
          } else {
            polygonColor = Colors.blue;
          }

          polygons.add(
            Polygon(
              polygonId: polygon.polygonId,
              points: polygon.points,
              fillColor: polygonColor.withOpacity(0.3),
              strokeColor: polygonColor,
              strokeWidth: 2,
            ),
          );

          // Add center marker for each zone
          if (polygon.points.isNotEmpty) {
            final center = _calculatePolygonCenter(polygon.points);
            markers.add(
              Marker(
                markerId: MarkerId('zone_${polygon.polygonId.value}'),
                position: center,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  polygonColor == Colors.red ? BitmapDescriptor.hueRed :
                  polygonColor == Colors.orange ? BitmapDescriptor.hueOrange :
                  polygonColor == Colors.green ? BitmapDescriptor.hueGreen :
                  BitmapDescriptor.hueBlue,
                ),
                infoWindow: InfoWindow(
                  title: _getZoneTitle(id),
                  snippet: _getZoneDescription(id),
                ),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error loading safety zones: $e');
      }
    }

    // Add tourist service markers
    try {
      MapService.addTouristServiceMarkers();
      markers.addAll(MapService.markers);
    } catch (e) {
      debugPrint('Error loading service markers: $e');
    }

    setState(() {
      _markers = markers;
      _polygons = polygons;
      _circles = circles;
    });
  }

  Future<void> _updateCurrentRisk() async {
    try {
      final risk = await _geofencingService.getCurrentRiskLevel();
      setState(() => _currentRisk = risk);
    } catch (e) {
      debugPrint('Error updating current risk: $e');
    }
  }

  LatLng _calculatePolygonCenter(List<LatLng> points) {
    double lat = 0;
    double lng = 0;
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  String _getZoneTitle(String id) {
    if (id.contains('danger') || id.contains('high_risk')) {
      return '⚠️ High Risk Zone';
    } else if (id.contains('caution')) {
      return '🟡 Caution Zone';
    } else if (id.contains('safe')) {
      return '🟢 Safe Zone';
    }
    return '📍 Zone';
  }

  String _getZoneDescription(String id) {
    if (id.contains('danger') || id.contains('high_risk')) {
      return 'Avoid this area if possible';
    } else if (id.contains('caution')) {
      return 'Exercise caution in this area';
    } else if (id.contains('safe')) {
      return 'This area is generally safe';
    }
    return 'Unknown zone type';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading map...'),
            ],
          ),
        ),
      );
    }

    final initialPosition = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(28.6139, 77.2090); // Default to Delhi

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _controller = controller;
                MapService.onMapCreated(controller);
              },
              initialCameraPosition: CameraPosition(
                target: initialPosition,
                zoom: 15,
              ),
              markers: _markers,
              polygons: _polygons,
              circles: _circles,
              myLocationEnabled: widget.showCurrentLocation,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: true,
              compassEnabled: true,
            ),
            
            // Risk level indicator overlay
            if (_currentRisk.isNotEmpty)
              Positioned(
                top: 16,
                left: 16,
                child: _buildRiskIndicator(),
              ),

            // Legend
            if (widget.showRiskZones)
              Positioned(
                bottom: 16,
                right: 16,
                child: _buildLegend(),
              ),

            // Refresh button
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                onPressed: () async {
                  setState(() => _isLoading = true);
                  await _initializeMap();
                },
                backgroundColor: Colors.white,
                child: const Icon(Icons.refresh, color: Color(0xFF6C63FF)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskIndicator() {
    final isHighRisk = _currentRisk['isHighRisk'] ?? false;
    final severity = _currentRisk['severity']?.toDouble() ?? 0.0;

    Color color;
    String text;
    IconData icon;

    if (isHighRisk) {
      if (severity > 0.8) {
        color = Colors.red;
        text = 'HIGH RISK';
        icon = Icons.warning;
      } else if (severity > 0.6) {
        color = Colors.orange;
        text = 'MODERATE';
        icon = Icons.error_outline;
      } else {
        color = Colors.yellow[700]!;
        text = 'LOW RISK';
        icon = Icons.info_outline;
      }
    } else {
      color = Colors.green;
      text = 'SAFE';
      icon = Icons.shield;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Risk Zones',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          _buildLegendItem(Colors.red, 'High Risk'),
          _buildLegendItem(Colors.orange, 'Caution'),
          _buildLegendItem(Colors.green, 'Safe'),
          _buildLegendItem(Colors.blue, 'Your Location'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withOpacity(0.7),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

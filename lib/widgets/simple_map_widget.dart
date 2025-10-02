import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SimpleMapWidget extends StatefulWidget {
  final bool showSafetyZones;
  final bool showTouristServices;
  final bool showRouteHistory;

  const SimpleMapWidget({
    super.key,
    this.showSafetyZones = false,
    this.showTouristServices = false,
    this.showRouteHistory = false,
  });

  @override
  State<SimpleMapWidget> createState() => _SimpleMapWidgetState();
}

class _SimpleMapWidgetState extends State<SimpleMapWidget> {
  GoogleMapController? _mapController;

  // Default location: Delhi, India
  static const LatLng _initialLocation = LatLng(28.6139, 77.2090);

  // Sample markers for tourist services
  final Set<Marker> _markers = {
    Marker(
      markerId: const MarkerId('police_1'),
      position: const LatLng(28.6169, 77.2090),
      infoWindow: const InfoWindow(
        title: 'Police Station',
        snippet: 'Connaught Place Police Station',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    ),
    Marker(
      markerId: const MarkerId('hospital_1'),
      position: const LatLng(28.6119, 77.2090),
      infoWindow: const InfoWindow(
        title: 'Hospital',
        snippet: 'All India Institute of Medical Sciences',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ),
    Marker(
      markerId: const MarkerId('embassy_1'),
      position: const LatLng(28.6149, 77.2120),
      infoWindow: const InfoWindow(
        title: 'Embassy',
        snippet: 'Tourist Help Center',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ),
  };

  // Sample safety zones
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
  };

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          initialCameraPosition: const CameraPosition(
            target: _initialLocation,
            zoom: 12,
          ),
          markers: widget.showTouristServices ? _markers : {},
          polygons: widget.showSafetyZones ? _safetyZones : {},
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapType: MapType.normal,
          zoomControlsEnabled: true,
          compassEnabled: true,
          trafficEnabled: false,
          buildingsEnabled: true,
        ),
        // Simple overlay to show map is working
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Google Maps Active',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

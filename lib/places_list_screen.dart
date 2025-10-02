import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/places_service.dart';

class PlacesListScreen extends StatefulWidget {
  final String category;
  final String categoryTitle;

  const PlacesListScreen({
    super.key,
    required this.category,
    required this.categoryTitle,
  });

  @override
  _PlacesListScreenState createState() => _PlacesListScreenState();
}

class _PlacesListScreenState extends State<PlacesListScreen> {
  List<Place> places = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNearbyPlaces();
  }

  Future<void> _loadNearbyPlaces() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get current location
      final position = await PlacesService.getCurrentLocation();
      if (position == null) {
        setState(() {
          errorMessage = 'Location permission required to find nearby places';
          isLoading = false;
        });
        return;
      }

      // Search for nearby places
      final nearbyPlaces = await PlacesService.searchNearbyPlaces(
        latitude: position.latitude,
        longitude: position.longitude,
        placeType: widget.category,
      );

      setState(() {
        places = nearbyPlaces;
        isLoading = false;

        // Check if no places found and provide helpful message
        if (nearbyPlaces.isEmpty) {
          errorMessage =
              'No ${widget.categoryTitle.toLowerCase()} found nearby.\n\n'
              'This might be because:\n'
              '• Google Places API key needs to be configured\n'
              '• No places of this type in your area\n'
              '• Network connectivity issues\n\n'
              'Check the console for API error details.';
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load nearby places: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nearby ${widget.categoryTitle}'),
        backgroundColor: const Color(0xFFD2B48C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD2B48C), Color(0xFFF5F5DC)],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Getting your location...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Searching for nearby places',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNearbyPlaces,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFD2B48C),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (places.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'No ${widget.categoryTitle.toLowerCase()} found nearby',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNearbyPlaces,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: places.length,
        itemBuilder: (context, index) {
          final place = places[index];
          return _buildPlaceCard(place);
        },
      ),
    );
  }

  Widget _buildPlaceCard(Place place) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFFFFAF0)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                image: DecorationImage(
                  image: NetworkImage(place.photoUrl),
                  fit: BoxFit.cover,
                  onError: (error, stackTrace) {},
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                  ),
                ),
              ),
            ),
            // Content section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          place.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B4513),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: place.isOpen
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          place.statusText,
                          style: TextStyle(
                            color: place.isOpen
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Rating and price
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade600, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        place.rating.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8B4513),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        place.priceText,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.location_on,
                        color: const Color(0xFFD2B48C),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${place.distance.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Color(0xFF8B4513),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Address
                  Text(
                    place.address,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _makePhoneCall(place.phoneNumber),
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD2B48C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openDirections(place),
                          icon: const Icon(Icons.directions, size: 18),
                          label: const Text('Directions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFD2B48C),
                            side: const BorderSide(color: Color(0xFFD2B48C)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);

    try {
      await launchUrl(launchUri);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not make phone call: $e'),
          backgroundColor: const Color(0xFFD2B48C),
        ),
      );
    }
  }

  Future<void> _openDirections(Place place) async {
    try {
      // Try multiple mapping apps in order of preference
      final List<Uri> mapUris = [
        // Google Maps with navigation
        Uri.parse('google.navigation:q=${place.latitude},${place.longitude}'),
        // Google Maps website with directions
        Uri(
          scheme: 'https',
          host: 'maps.google.com',
          path: '/maps',
          queryParameters: {
            'daddr': '${place.latitude},${place.longitude}',
            'dir_action': 'navigate',
          },
        ),
        // Apple Maps (for iOS devices)
        Uri.parse('maps://?daddr=${place.latitude},${place.longitude}'),
        // Fallback to web version
        Uri(
          scheme: 'https',
          host: 'www.google.com',
          path: '/maps/dir/',
          queryParameters: {
            'destination': '${place.latitude},${place.longitude}',
            'destination_place_id': place.id.isNotEmpty ? place.id : null,
          }..removeWhere((key, value) => value == null),
        ),
      ];

      bool opened = false;
      for (final uri in mapUris) {
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            opened = true;
            break;
          }
        } catch (e) {
          print('Failed to open $uri: $e');
          continue;
        }
      }

      if (!opened) {
        // Last resort: copy coordinates to clipboard and show instructions
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open maps app. Coordinates: ${place.latitude}, ${place.longitude}',
            ),
            backgroundColor: const Color(0xFFD2B48C),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Copy',
              textColor: Colors.white,
              onPressed: () {
                // You can implement clipboard copy here if needed
              },
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening directions: $e'),
          backgroundColor: const Color(0xFFD2B48C),
        ),
      );
    }
  }
}

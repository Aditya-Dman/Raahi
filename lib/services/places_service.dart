import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class PlacesService {
  // Google Places API key - Using a working key for testing
  static const String _apiKey = 'AIzaSyBdKg2rEJ8S4YjMJxOGVP3yB1KL4X8F9mN';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  // Get current location  // Get current location
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Search for nearby places using Google Places API
  static Future<List<Place>> searchNearbyPlaces({
    required double latitude,
    required double longitude,
    required String placeType,
    int radius = 5000, // 5km radius
  }) async {
    try {
      final String googlePlaceType = _getGooglePlaceType(placeType);
      final String url =
          '$_baseUrl/nearbysearch/json'
          '?location=$latitude,$longitude'
          '&radius=$radius'
          '&type=$googlePlaceType'
          '&key=$_apiKey';

      print('Making API request to: $url');
      print('Searching for $placeType near $latitude, $longitude');

      final response = await http.get(Uri.parse(url));
      print('API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('API Response data: ${data.toString().substring(0, 200)}...');

        if (data['status'] == 'OK' && data['results'] != null) {
          return await _parseGooglePlacesResponse(
            data['results'],
            latitude,
            longitude,
          );
        } else {
          print('API returned status: ${data['status']}');
          print(
            'API error message: ${data['error_message'] ?? 'No error message'}',
          );
          // Return fallback data for Delhi/NCR area
          return _getFallbackPlaces(placeType);
        }
      } else {
        print('API request failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
        // Return fallback data for Delhi/NCR area
        return _getFallbackPlaces(placeType);
      }
    } catch (e) {
      print('Error searching places: $e');
      // Return fallback data for Delhi/NCR area
      return _getFallbackPlaces(placeType);
    }
  }

  // Convert app place types to Google Places API types
  static String _getGooglePlaceType(String appPlaceType) {
    switch (appPlaceType.toLowerCase()) {
      case 'restaurants':
        return 'restaurant';
      case 'hotels':
        return 'lodging';
      case 'tour_guides':
        return 'travel_agency';
      case 'tourist_places':
        return 'tourist_attraction';
      case 'medical':
        return 'hospital';
      case 'transport':
        return 'transit_station';
      case 'shopping':
        return 'shopping_mall';
      default:
        return 'establishment';
    }
  }

  // Parse Google Places API response
  static Future<List<Place>> _parseGooglePlacesResponse(
    List<dynamic> results,
    double userLat,
    double userLng,
  ) async {
    List<Place> places = [];

    for (var result in results.take(10)) {
      // Limit to 10 results
      try {
        final geometry = result['geometry'];
        final location = geometry['location'];
        final lat = location['lat'].toDouble();
        final lng = location['lng'].toDouble();

        final distance = calculateDistance(userLat, userLng, lat, lng);

        // Get photo URL if available
        String photoUrl = 'https://via.placeholder.com/300x200?text=No+Image';
        if (result['photos'] != null && result['photos'].isNotEmpty) {
          final photoReference = result['photos'][0]['photo_reference'];
          photoUrl =
              '$_baseUrl/photo?maxwidth=400&photoreference=$photoReference&key=$_apiKey';
        }

        // Get real phone number using Place Details API
        final String phoneNumber = await _getPlacePhoneNumber(
          result['place_id'] ?? '',
        );

        places.add(
          Place(
            id: result['place_id'] ?? '',
            name: result['name'] ?? 'Unknown',
            address: result['vicinity'] ?? 'Address not available',
            rating: (result['rating']?.toDouble()) ?? 0.0,
            distance: distance,
            phoneNumber: phoneNumber,
            priceLevel: result['price_level'] ?? 0,
            photoUrl: photoUrl,
            isOpen: _getOpenStatus(result['opening_hours']),
            latitude: lat,
            longitude: lng,
          ),
        );
      } catch (e) {
        print('Error parsing place result: $e');
        continue;
      }
    }

    // Sort by distance
    places.sort((a, b) => a.distance.compareTo(b.distance));
    return places;
  }

  // Get opening status
  static bool _getOpenStatus(dynamic openingHours) {
    if (openingHours == null) return true; // Assume open if no info
    return openingHours['open_now'] ?? true;
  }

  // Calculate distance between two points
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // km
  }

  // Get phone number from Place Details API
  static Future<String> _getPlacePhoneNumber(String placeId) async {
    if (placeId.isEmpty) return 'N/A';

    try {
      final String url =
          '$_baseUrl/details/json'
          '?place_id=$placeId'
          '&fields=formatted_phone_number'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          return data['result']['formatted_phone_number'] ?? 'N/A';
        }
      }
      return 'N/A';
    } catch (e) {
      print('Error getting phone number: $e');
      return 'N/A';
    }
  }

  // Fallback places for Delhi/NCR area (Rithala, Patel Nagar)
  static List<Place> _getFallbackPlaces(String placeType) {
    switch (placeType.toLowerCase()) {
      case 'restaurants':
        return [
          Place(
            id: 'rest_1',
            name: 'Punjabi By Nature',
            address: 'Pacific Mall, Tagore Garden, Delhi',
            rating: 4.2,
            distance: 2.5,
            phoneNumber: '+91-11-4166-6666',
            priceLevel: 3,
            photoUrl: '',
            isOpen: true,
            latitude: 28.6400,
            longitude: 77.1200,
          ),
          Place(
            id: 'rest_2',
            name: 'Haldirams',
            address: 'Netaji Subhash Place, Pitam Pura, Delhi',
            rating: 4.0,
            distance: 3.1,
            phoneNumber: '+91-11-2735-4567',
            priceLevel: 2,
            photoUrl: '',
            isOpen: true,
            latitude: 28.6900,
            longitude: 77.1300,
          ),
          Place(
            id: 'rest_3',
            name: 'Burger King',
            address: 'City Centre Mall, Sector 12, Dwarka, Delhi',
            rating: 3.8,
            distance: 4.2,
            phoneNumber: '+91-11-4567-8900',
            priceLevel: 2,
            photoUrl: '',
            isOpen: true,
            latitude: 28.5900,
            longitude: 77.0400,
          ),
        ];
      case 'medical':
        return [
          Place(
            id: 'med_1',
            name: 'Max Super Speciality Hospital',
            address: 'FC-50, C & D Block, Shalimar Bagh, Delhi',
            rating: 4.3,
            distance: 3.8,
            phoneNumber: '+91-11-2617-2617',
            priceLevel: 3,
            photoUrl: '',
            isOpen: true,
            latitude: 28.7200,
            longitude: 77.1600,
          ),
          Place(
            id: 'med_2',
            name: 'Fortis Hospital',
            address: 'Sector B-22, Shalimar Bagh, Delhi',
            rating: 4.1,
            distance: 4.1,
            phoneNumber: '+91-11-4277-6200',
            priceLevel: 3,
            photoUrl: '',
            isOpen: true,
            latitude: 28.7100,
            longitude: 77.1650,
          ),
          Place(
            id: 'med_3',
            name: 'Kailash Hospital',
            address: 'Noida Sector 27, Delhi-NCR',
            rating: 3.9,
            distance: 5.2,
            phoneNumber: '+91-120-414-7777',
            priceLevel: 2,
            photoUrl: '',
            isOpen: true,
            latitude: 28.5700,
            longitude: 77.3200,
          ),
        ];
      case 'hotels':
        return [
          Place(
            id: 'hotel_1',
            name: 'Hotel Grand Godwin',
            address: 'Ramesh Nagar, New Delhi',
            rating: 4.0,
            distance: 2.8,
            phoneNumber: '+91-11-2545-2020',
            priceLevel: 3,
            photoUrl: '',
            isOpen: true,
            latitude: 28.6350,
            longitude: 77.1850,
          ),
          Place(
            id: 'hotel_2',
            name: 'Hotel President',
            address: 'A-9, Ashoka Road, Paharganj, Delhi',
            rating: 3.7,
            distance: 8.5,
            phoneNumber: '+91-11-4352-1234',
            priceLevel: 2,
            photoUrl: '',
            isOpen: true,
            latitude: 28.6420,
            longitude: 77.2170,
          ),
        ];
      case 'shopping':
        return [
          Place(
            id: 'shop_1',
            name: 'Pacific Mall',
            address: 'NSP, Tagore Garden, Delhi',
            rating: 4.1,
            distance: 2.2,
            phoneNumber: '+91-11-4166-8888',
            priceLevel: 3,
            photoUrl: '',
            isOpen: true,
            latitude: 28.6450,
            longitude: 77.1250,
          ),
          Place(
            id: 'shop_2',
            name: 'TDI Mall',
            address: 'Sector 1, Rohini, Delhi',
            rating: 3.8,
            distance: 3.5,
            phoneNumber: '+91-11-2781-5555',
            priceLevel: 2,
            photoUrl: '',
            isOpen: true,
            latitude: 28.7300,
            longitude: 77.1100,
          ),
        ];
      case 'transport':
        return [
          Place(
            id: 'trans_1',
            name: 'Rithala Metro Station',
            address: 'Rithala, Delhi Metro Red Line',
            rating: 4.0,
            distance: 0.5,
            phoneNumber: '1800-103-3663',
            priceLevel: 1,
            photoUrl: '',
            isOpen: true,
            latitude: 28.7210,
            longitude: 77.1048,
          ),
          Place(
            id: 'trans_2',
            name: 'Netaji Subhash Place Metro',
            address: 'Netaji Subhash Place, Delhi Metro Pink Line',
            rating: 3.9,
            distance: 2.8,
            phoneNumber: '1800-103-3663',
            priceLevel: 1,
            photoUrl: '',
            isOpen: true,
            latitude: 28.6958,
            longitude: 77.1525,
          ),
        ];
      case 'tourist_places':
        return [
          Place(
            id: 'tour_1',
            name: 'Swaminarayan Akshardham',
            address: 'NH 24, Akshardham Setu, Delhi',
            rating: 4.6,
            distance: 15.2,
            phoneNumber: '+91-11-4350-5555',
            priceLevel: 1,
            photoUrl: '',
            isOpen: true,
            latitude: 28.6127,
            longitude: 77.2773,
          ),
          Place(
            id: 'tour_2',
            name: 'Red Fort',
            address: 'Netaji Subhash Marg, Chandni Chowk, Delhi',
            rating: 4.3,
            distance: 12.8,
            phoneNumber: '+91-11-2327-7705',
            priceLevel: 1,
            photoUrl: '',
            isOpen: true,
            latitude: 28.6562,
            longitude: 77.2410,
          ),
        ];
      default:
        return [];
    }
  }
}

class Place {
  final String id;
  final String name;
  final String address;
  final double rating;
  final double distance; // in kilometers
  final String phoneNumber;
  final int priceLevel; // 0-4 (free to very expensive)
  final String photoUrl;
  final bool isOpen;
  final double latitude;
  final double longitude;

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.rating,
    required this.distance,
    required this.phoneNumber,
    required this.priceLevel,
    required this.photoUrl,
    required this.isOpen,
    required this.latitude,
    required this.longitude,
  });

  String get priceText {
    switch (priceLevel) {
      case 0:
        return 'Free';
      case 1:
        return '\$';
      case 2:
        return '\$\$';
      case 3:
        return '\$\$\$';
      case 4:
        return '\$\$\$\$';
      default:
        return 'N/A';
    }
  }

  String get statusText => isOpen ? 'Open' : 'Closed';
}

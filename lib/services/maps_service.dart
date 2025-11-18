import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapsService {
  static final MapsService _instance = MapsService._internal();
  factory MapsService() => _instance;
  MapsService._internal();

  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  String? _cachedApiKey;
  DateTime? _cacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 30);

  /// Get Google Maps API key
  Future<String?> _getApiKey() async {
    // Check cache first
    if (_cachedApiKey != null && 
        _cacheTime != null && 
        DateTime.now().difference(_cacheTime!) < _cacheExpiry) {
      return _cachedApiKey;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('google_maps')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final apiKey = data?['api_key'] as String?;
        
        // Cache the result
        _cachedApiKey = apiKey;
        _cacheTime = DateTime.now();
        
        return apiKey;
      } else {
        print('Google Maps config document not found in Firestore');
        return null;
      }
    } catch (e) {
      print('Error fetching Google Maps API key: $e');
      return null;
    }
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
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

  /// Search for places nearby
  Future<List<Map<String, dynamic>>> searchNearbyPlaces({
    required String query,
    Position? location,
    String? type,
    int radius = 5000,
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey == null) {
      print('No Google Maps API key found');
      return [];
    }

    try {
      Position? currentLocation = location ?? await getCurrentLocation();
      if (currentLocation == null) {
        print('Could not get current location');
        return [];
      }

      // Use Places API Text Search
      final url = Uri.parse(
        '$_baseUrl/place/textsearch/json?query=$query&location=${currentLocation.latitude},${currentLocation.longitude}&radius=$radius&key=$apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null) {
          final results = data['results'] as List;
          return results.map((place) {
            final location = place['geometry']?['location'];
            return {
              'name': place['name'] ?? 'Unknown',
              'address': place['formatted_address'] ?? '',
              'latitude': location?['lat'] ?? 0.0,
              'longitude': location?['lng'] ?? 0.0,
              'place_id': place['place_id'] ?? '',
              'rating': place['rating']?.toDouble() ?? 0.0,
              'types': place['types'] ?? [],
            };
          }).toList();
        }
      } else {
        print('Places API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error searching places: $e');
    }

    return [];
  }

  /// Get directions between two points
  Future<Map<String, dynamic>?> getDirections({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String travelMode = 'driving',
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey == null) {
      print('No Google Maps API key found');
      return null;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/directions/json?origin=$startLat,$startLng&destination=$endLat,$endLng&mode=$travelMode&key=$apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          return {
            'distance': leg['distance']?['text'] ?? '',
            'duration': leg['duration']?['text'] ?? '',
            'polyline': route['overview_polyline']?['points'] ?? '',
            'steps': leg['steps'] ?? [],
            'start_location': {
              'lat': leg['start_location']?['lat'] ?? startLat,
              'lng': leg['start_location']?['lng'] ?? startLng,
            },
            'end_location': {
              'lat': leg['end_location']?['lat'] ?? endLat,
              'lng': leg['end_location']?['lng'] ?? endLng,
            },
          };
        }
      } else {
        print('Directions API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error getting directions: $e');
    }

    return null;
  }

  /// Geocode an address to coordinates
  Future<Position?> geocodeAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
    } catch (e) {
      print('Error geocoding address: $e');
    }
    return null;
  }

  /// Reverse geocode coordinates to address
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.administrativeArea} ${place.postalCode}';
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
    }
    return null;
  }

  /// Get place details by place ID
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    final apiKey = await _getApiKey();
    if (apiKey == null) {
      print('No Google Maps API key found');
      return null;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/place/details/json?place_id=$placeId&fields=name,formatted_address,geometry,rating,types,photos&key=$apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          final place = data['result'];
          final location = place['geometry']?['location'];
          return {
            'name': place['name'] ?? 'Unknown',
            'address': place['formatted_address'] ?? '',
            'latitude': location?['lat'] ?? 0.0,
            'longitude': location?['lng'] ?? 0.0,
            'rating': place['rating']?.toDouble() ?? 0.0,
            'types': place['types'] ?? [],
          };
        }
      }
    } catch (e) {
      print('Error getting place details: $e');
    }

    return null;
  }
}


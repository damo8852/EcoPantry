import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/maps_service.dart';
import '../services/voice_service.dart';
import '../services/command_parser_service.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  final MapsService _mapsService = MapsService();
  final VoiceService _voiceService = VoiceService();
  final CommandParserService _commandParser = CommandParserService();

  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isListening = false;
  bool _isProcessing = false;
  String _statusMessage = 'Tap the microphone to speak';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize voice service
    await _voiceService.initialize();
    
    // Get current location
    await _updateCurrentLocation();
  }

  Future<void> _updateCurrentLocation() async {
    final position = await _mapsService.getCurrentLocation();
    if (position != null && mounted) {
      setState(() {
        _currentPosition = position;
      });
      
      // Move camera to current location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15.0,
        ),
      );
    }
  }

  Future<void> _handleVoiceCommand() async {
    if (_isListening || _isProcessing) return;

    setState(() {
      _isListening = true;
      _statusMessage = 'Listening...';
    });

    await _voiceService.startListening(
      onResult: (text) async {
        setState(() {
          _isListening = false;
          _statusMessage = 'Processing: "$text"';
          _isProcessing = true;
        });

        await _processCommand(text);
      },
      onError: (error) {
        setState(() {
          _isListening = false;
          _statusMessage = 'Error: $error';
          _isProcessing = false;
        });
      },
    );
  }

  Future<void> _processCommand(String command) async {
    try {
      final parsed = await _commandParser.parseCommand(command);
      
      if (parsed == null) {
        setState(() {
          _statusMessage = 'Could not understand command';
          _isProcessing = false;
        });
        await _voiceService.speak('Sorry, I could not understand that command.');
        return;
      }

      final action = parsed['action'] as String;
      final confidence = parsed['confidence'] as double? ?? 0.0;

      if (confidence < 0.5) {
        setState(() {
          _statusMessage = 'Command confidence too low';
          _isProcessing = false;
        });
        await _voiceService.speak('Sorry, I\'m not sure what you meant.');
        return;
      }

      switch (action) {
        case 'navigate':
          await _handleNavigate(parsed);
          break;
        case 'find_nearby':
          await _handleFindNearby(parsed);
          break;
        case 'search':
          await _handleSearch(parsed);
          break;
        case 'what_is':
          await _handleWhatIs(parsed);
          break;
        case 'cancel':
          await _handleCancel();
          break;
        default:
          setState(() {
            _statusMessage = 'Unknown action: $action';
            _isProcessing = false;
          });
      }
    } catch (e) {
      print('Error processing command: $e');
      setState(() {
        _statusMessage = 'Error processing command';
        _isProcessing = false;
      });
      await _voiceService.speak('Sorry, there was an error processing your command.');
    }
  }

  Future<void> _handleNavigate(Map<String, dynamic> parsed) async {
    final destination = parsed['destination'] as String?;
    if (destination == null || _currentPosition == null) {
      setState(() {
        _statusMessage = 'Destination not specified';
        _isProcessing = false;
      });
      await _voiceService.speak('Please specify a destination.');
      return;
    }

    setState(() {
      _statusMessage = 'Finding route to $destination...';
    });
    await _voiceService.speak('Finding route to $destination');

    // Geocode destination
    Position? destPosition = await _mapsService.geocodeAddress(destination);
    if (destPosition == null) {
      // Try searching for the place
      final places = await _mapsService.searchNearbyPlaces(
        query: destination,
        location: _currentPosition,
      );
      
      if (places.isEmpty) {
        setState(() {
          _statusMessage = 'Could not find $destination';
          _isProcessing = false;
        });
        await _voiceService.speak('Sorry, I could not find $destination');
        return;
      }
      
      final place = places.first;
      destPosition = Position(
        latitude: place['latitude'] as double,
        longitude: place['longitude'] as double,
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

    // At this point, destPosition should not be null, but we need to satisfy the type checker
    final finalDestPosition = destPosition!;

    // Get directions
    final directions = await _mapsService.getDirections(
      startLat: _currentPosition!.latitude,
      startLng: _currentPosition!.longitude,
      endLat: finalDestPosition.latitude,
      endLng: finalDestPosition.longitude,
    );

    if (directions != null && mounted) {
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('current'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: const InfoWindow(title: 'Current Location'),
          ),
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(finalDestPosition.latitude, finalDestPosition.longitude),
            infoWindow: InfoWindow(title: destination),
          ),
        };
        
        // Add polyline for route
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: _decodePolyline(directions['polyline'] as String),
            color: Colors.blue,
            width: 5,
          ),
        };
        
        _statusMessage = 'Route found: ${directions['distance']} - ${directions['duration']}';
        _isProcessing = false;
      });

      // Move camera to show route
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          _boundsFromLatLngList([
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            LatLng(finalDestPosition.latitude, finalDestPosition.longitude),
          ]),
          100.0,
        ),
      );

      await _voiceService.speak(
        'Route found. ${directions['distance']} away, estimated time ${directions['duration']}',
      );
    } else {
      setState(() {
        _statusMessage = 'Could not get directions';
        _isProcessing = false;
      });
      await _voiceService.speak('Sorry, I could not get directions to $destination');
    }
  }

  Future<void> _handleFindNearby(Map<String, dynamic> parsed) async {
    final placeType = parsed['place_type'] as String? ?? 'place';
    if (_currentPosition == null) {
      setState(() {
        _statusMessage = 'Location not available';
        _isProcessing = false;
      });
      await _voiceService.speak('I need your location to find nearby places.');
      return;
    }

    setState(() {
      _statusMessage = 'Finding nearby $placeType...';
    });
    await _voiceService.speak('Finding nearby $placeType');

    final places = await _mapsService.searchNearbyPlaces(
      query: placeType,
      location: _currentPosition,
    );

    if (places.isEmpty) {
      setState(() {
        _statusMessage = 'No $placeType found nearby';
        _isProcessing = false;
      });
      await _voiceService.speak('Sorry, I could not find any $placeType nearby');
      return;
    }

    // Show nearest place
    final nearest = places.first;
    final nearestPosition = Position(
      latitude: nearest['latitude'] as double,
      longitude: nearest['longitude'] as double,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    // Get directions to nearest
    final directions = await _mapsService.getDirections(
      startLat: _currentPosition!.latitude,
      startLng: _currentPosition!.longitude,
      endLat: nearestPosition.latitude,
      endLng: nearestPosition.longitude,
    );

    if (mounted) {
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('current'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: const InfoWindow(title: 'Current Location'),
          ),
          Marker(
            markerId: const MarkerId('nearest'),
            position: LatLng(nearestPosition.latitude, nearestPosition.longitude),
            infoWindow: InfoWindow(
              title: nearest['name'] as String,
              snippet: nearest['address'] as String,
            ),
          ),
        };

        if (directions != null) {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: _decodePolyline(directions['polyline'] as String),
              color: Colors.blue,
              width: 5,
            ),
          };
          _statusMessage = 'Found ${nearest['name']}: ${directions['distance']} away';
        } else {
          _statusMessage = 'Found ${nearest['name']}';
        }
        _isProcessing = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(nearestPosition.latitude, nearestPosition.longitude),
          15.0,
        ),
      );

      final distanceText = directions != null 
          ? ', ${directions['distance']} away'
          : '';
      await _voiceService.speak('Found ${nearest['name']}$distanceText');
    }
  }

  Future<void> _handleSearch(Map<String, dynamic> parsed) async {
    final query = parsed['query'] as String?;
    if (query == null) {
      setState(() {
        _statusMessage = 'Search query not specified';
        _isProcessing = false;
      });
      return;
    }

    await _handleFindNearby({'action': 'find_nearby', 'place_type': query, 'confidence': 1.0});
  }

  Future<void> _handleWhatIs(Map<String, dynamic> parsed) async {
    final question = parsed['question'] as String?;
    if (question == null || _currentPosition == null) {
      setState(() {
        _statusMessage = 'Question not specified';
        _isProcessing = false;
      });
      await _voiceService.speak('I need more information to answer that question.');
      return;
    }

    setState(() {
      _statusMessage = 'Searching for information...';
    });

    // Search for places matching the question
    final places = await _mapsService.searchNearbyPlaces(
      query: question,
      location: _currentPosition,
      radius: 2000,
    );

    if (places.isNotEmpty && mounted) {
      final place = places.first;
      final address = place['address'] as String;
      
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('current'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: const InfoWindow(title: 'Current Location'),
          ),
          Marker(
            markerId: const MarkerId('place'),
            position: LatLng(place['latitude'] as double, place['longitude'] as double),
            infoWindow: InfoWindow(
              title: place['name'] as String,
              snippet: address,
            ),
          ),
        };
        _statusMessage = 'Found: ${place['name']}';
        _isProcessing = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(place['latitude'] as double, place['longitude'] as double),
          15.0,
        ),
      );

      await _voiceService.speak('That is ${place['name']}, located at $address');
    } else {
      setState(() {
        _statusMessage = 'Could not find information';
        _isProcessing = false;
      });
      await _voiceService.speak('Sorry, I could not find information about that.');
    }
  }

  Future<void> _handleCancel() async {
    setState(() {
      _markers = {};
      _polylines = {};
      _statusMessage = 'Navigation cancelled';
      _isProcessing = false;
    });

    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          15.0,
        ),
      );
    }

    await _voiceService.speak('Navigation cancelled');
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? west, north, east, south;
    for (LatLng latLng in list) {
      west = west != null ? (west < latLng.longitude ? west : latLng.longitude) : latLng.longitude;
      east = east != null ? (east > latLng.longitude ? east : latLng.longitude) : latLng.longitude;
      south = south != null ? (south < latLng.latitude ? south : latLng.latitude) : latLng.latitude;
      north = north != null ? (north > latLng.latitude ? north : latLng.latitude) : latLng.latitude;
    }
    return LatLngBounds(
      southwest: LatLng(south ?? 0, west ?? 0),
      northeast: LatLng(north ?? 0, east ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(37.7749, -122.4194), // Default to San Francisco
              zoom: 15.0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _updateCurrentLocation();
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Status message
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _statusMessage,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Voice button
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isProcessing ? null : _handleVoiceCommand,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _isListening
                        ? Colors.red
                        : (_isProcessing ? Colors.orange : Colors.blue),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening
                        ? Icons.mic
                        : (_isProcessing ? Icons.hourglass_empty : Icons.mic_none),
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),

          // Location button
          Positioned(
            bottom: 130,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              onPressed: _updateCurrentLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _voiceService.stopListening();
    _voiceService.stopSpeaking();
    _mapController?.dispose();
    super.dispose();
  }
}


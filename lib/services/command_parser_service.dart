import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'llm_service.dart';
import 'maps_service.dart';

class CommandParserService {
  static final CommandParserService _instance = CommandParserService._internal();
  factory CommandParserService() => _instance;
  CommandParserService._internal();

  final LLMService _llmService = LLMService();
  final MapsService _mapsService = MapsService();

  /// Parse voice command and return action
  Future<Map<String, dynamic>?> parseCommand(String command) async {
    if (command.trim().isEmpty) return null;

    // Remove "hey atlas" prefix if present
    String cleanCommand = command.toLowerCase().trim();
    if (cleanCommand.startsWith('hey atlas')) {
      cleanCommand = cleanCommand.substring('hey atlas'.length).trim();
    } else if (cleanCommand.startsWith('atlas')) {
      cleanCommand = cleanCommand.substring('atlas'.length).trim();
    }

    if (cleanCommand.isEmpty) return null;

    try {
      // Get current location for context
      Position? currentLocation = await _mapsService.getCurrentLocation();
      String locationContext = '';
      if (currentLocation != null) {
        locationContext = 'Current location: ${currentLocation.latitude}, ${currentLocation.longitude}';
      }

      // Build prompt for ChatGPT to parse the command
      final prompt = _buildCommandPrompt(cleanCommand, locationContext);

      // Call ChatGPT to parse the command
      final response = await _llmService.callLLM(
        prompt: prompt,
        maxTokens: 300,
        temperature: 0.3,
        useJsonMode: true,
      );

      if (response != null) {
        final parsed = _parseLLMResponse(response);
        if (parsed != null) {
          // Enrich with current location if needed
          if (parsed['action'] == 'navigate' || 
              parsed['action'] == 'search' || 
              parsed['action'] == 'find_nearby') {
            parsed['current_location'] = currentLocation != null
                ? {
                    'latitude': currentLocation.latitude,
                    'longitude': currentLocation.longitude,
                  }
                : null;
          }
          return parsed;
        }
      }
    } catch (e) {
      print('Error parsing command: $e');
    }

    return null;
  }

  String _buildCommandPrompt(String command, String locationContext) {
    return '''You are an AI assistant for a voice-activated Google Maps app called "Atlas". 
Parse the user's voice command and determine what action they want to perform.

Available actions:
1. "navigate" - User wants directions to a destination
2. "search" - User wants to search for a place or location
3. "find_nearby" - User wants to find nearby places (gas stations, restaurants, etc.)
4. "what_is" - User is asking about a location/place they're near or seeing
5. "get_directions" - User wants directions between two places
6. "cancel" - User wants to cancel current navigation

Location context: $locationContext

User command: "$command"

Return a JSON object with this structure:
{
  "action": "navigate|search|find_nearby|what_is|get_directions|cancel",
  "destination": "destination name or address (if applicable)",
  "query": "search query (if applicable)",
  "place_type": "gas_station|restaurant|hospital|etc (if applicable)",
  "question": "what the user is asking about (if applicable)",
  "confidence": 0.0-1.0
}

Examples:
- "redirect me to the nearest gas station" -> {"action": "find_nearby", "place_type": "gas_station", "confidence": 0.95}
- "navigate to 123 Main Street" -> {"action": "navigate", "destination": "123 Main Street", "confidence": 0.95}
- "what's the lake I'm driving next to right now?" -> {"action": "what_is", "question": "lake nearby", "confidence": 0.9}
- "find restaurants near me" -> {"action": "find_nearby", "place_type": "restaurant", "confidence": 0.95}
- "take me to the airport" -> {"action": "navigate", "destination": "airport", "confidence": 0.9}
- "cancel navigation" -> {"action": "cancel", "confidence": 0.95}

Command: "$command"
JSON:''';
  }

  Map<String, dynamic>? _parseLLMResponse(String response) {
    try {
      // Clean the response
      String cleanResponse = response.trim();
      cleanResponse = cleanResponse.replaceAll(RegExp(r'```json\s*|\s*```'), '');

      // Parse JSON
      final data = json.decode(cleanResponse) as Map<String, dynamic>;
      
      // Validate action
      final action = data['action']?.toString().toLowerCase();
      if (action == null) return null;

      // Build result
      final result = <String, dynamic>{
        'action': action,
        'confidence': (data['confidence'] as num?)?.toDouble() ?? 0.8,
      };

      // Add optional fields
      if (data['destination'] != null) {
        result['destination'] = data['destination'].toString();
      }
      if (data['query'] != null) {
        result['query'] = data['query'].toString();
      }
      if (data['place_type'] != null) {
        result['place_type'] = data['place_type'].toString();
      }
      if (data['question'] != null) {
        result['question'] = data['question'].toString();
      }

      return result;
    } catch (e) {
      print('Error parsing LLM response: $e');
      print('Response: $response');
      return null;
    }
  }
}


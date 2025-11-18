import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class LLMService {
  // OpenAI API configuration
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _model = 'gpt-4o-mini'; // Fast, cost-effective, and accurate model

  final ConfigService _configService = ConfigService();

  static final LLMService _instance = LLMService._internal();
  factory LLMService() => _instance;
  LLMService._internal();

  /// Get the OpenAI API key
  Future<String?> _getApiKey() async {
    return await _configService.getOpenAiApiKey();
  }

  /// Public method for general-purpose LLM calls
  /// Used by command parser and other utilities
  Future<String?> callLLM({
    required String prompt,
    int maxTokens = 100,
    double temperature = 0.1,
    bool useJsonMode = false,
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey == null) {
      print('No OpenAI API key found');
      return null;
    }

    try {
      final requestBody = {
        'model': _model,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
      };

      if (useJsonMode) {
        requestBody['response_format'] = {'type': 'json_object'};
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['choices']?[0]?['message']?['content']?.toString().trim();
        return result;
      } else {
        print('OpenAI API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('HTTP request error: $e');
    }

    return null;
  }

  /// Check if OpenAI API is available
  Future<bool> isAvailable() async {
    final apiKey = await _getApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }
}

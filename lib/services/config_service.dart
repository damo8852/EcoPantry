import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  // Cache for the API keys to avoid repeated Firestore reads
  String? _cachedMistralApiKey;
  String? _cachedOpenAiApiKey;
  Map<String, String>? _cachedWalmartCredentials;
  DateTime? _mistralCacheTime;
  DateTime? _openAiCacheTime;
  DateTime? _walmartCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 30); // Cache for 30 minutes

  /// Get the Mistral API key from Firebase
  /// This reads from a Firestore document: /config/mistral
  Future<String?> getMistralApiKey() async {
    // Check cache first
    if (_cachedMistralApiKey != null && 
        _mistralCacheTime != null && 
        DateTime.now().difference(_mistralCacheTime!) < _cacheExpiry) {
      return _cachedMistralApiKey;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('mistral')
          .get();

      if (doc.exists) {
        final data = doc.data();
        final apiKey = data?['api_key'] as String?;
        
        // Cache the result
        _cachedMistralApiKey = apiKey;
        _mistralCacheTime = DateTime.now();
        
        return apiKey;
      } else {
        print('Mistral config document not found in Firestore');
        return null;
      }
    } catch (e) {
      print('Error fetching Mistral API key from Firebase: $e');
      return null;
    }
  }


  /// Get the OpenAI API key from Firebase
  /// This reads from a Firestore document: /config/openai
  Future<String?> getOpenAiApiKey() async {
    // Check cache first
    if (_cachedOpenAiApiKey != null && 
        _openAiCacheTime != null && 
        DateTime.now().difference(_openAiCacheTime!) < _cacheExpiry) {
      return _cachedOpenAiApiKey;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('openai')
          .get();

      if (doc.exists) {
        final data = doc.data();
        final apiKey = data?['key'] as String?;
        
        // Cache the result
        _cachedOpenAiApiKey = apiKey;
        _openAiCacheTime = DateTime.now();
        
        return apiKey;
      } else {
        print('OpenAI config document not found in Firestore');
        return null;
      }
    } catch (e) {
      print('Error fetching OpenAI API key from Firebase: $e');
      return null;
    }
  }

  /// Check if Mistral API key is configured
  Future<bool> hasMistralApiKey() async {
    final key = await getMistralApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Check if OpenAI API key is configured
  Future<bool> hasOpenAiApiKey() async {
    final key = await getOpenAiApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Get Walmart API credentials from Firebase
  /// This reads from a Firestore document: /config/walmart
  /// Returns a map with 'consumerId' and 'privateKey'
  Future<Map<String, String>?> getWalmartCredentials() async {
    // Check cache first
    if (_cachedWalmartCredentials != null && 
        _walmartCacheTime != null && 
        DateTime.now().difference(_walmartCacheTime!) < _cacheExpiry) {
      return _cachedWalmartCredentials;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('walmart')
          .get();

      if (doc.exists) {
        final data = doc.data();
        final consumerId = data?['consumer_id'] as String?;
        final privateKey = data?['private_key'] as String?;
        
        if (consumerId != null && privateKey != null) {
          final credentials = {
            'consumerId': consumerId,
            'privateKey': privateKey,
          };
          
          // Cache the result
          _cachedWalmartCredentials = credentials;
          _walmartCacheTime = DateTime.now();
          
          return credentials;
        } else {
          print('Walmart credentials incomplete in Firestore');
          return null;
        }
      } else {
        print('Walmart config document not found in Firestore');
        return null;
      }
    } catch (e) {
      print('Error fetching Walmart credentials from Firebase: $e');
      return null;
    }
  }

  /// Check if Walmart API is configured
  Future<bool> hasWalmartCredentials() async {
    final credentials = await getWalmartCredentials();
    return credentials != null && 
           credentials['consumerId']?.isNotEmpty == true &&
           credentials['privateKey']?.isNotEmpty == true;
  }

  /// Clear the cached API keys (force refresh on next call)
  void clearCache() {
    _cachedMistralApiKey = null;
    _cachedOpenAiApiKey = null;
    _cachedWalmartCredentials = null;
    _mistralCacheTime = null;
    _openAiCacheTime = null;
    _walmartCacheTime = null;
  }

  /// Loads on-device settings. The OpenAI key itself lives in Firestore at /config/openai.
  Future<void> initializeWithDefaultKey() async {
    final prefs = await SharedPreferences.getInstance();
    _openAiModel = prefs.getString(_openAiModelKey) ?? defaultOpenAiModel;
  }

  // ---------------------------------------------------------------------------
  // OpenAI model (Settings > AI model), used by every AI feature in the app
  // ---------------------------------------------------------------------------

  static const String defaultOpenAiModel = 'gpt-6-luna';
  static const String _openAiModelKey = 'openai_model';
  String _openAiModel = defaultOpenAiModel;

  String get openAiModel => _openAiModel;

  Future<void> setOpenAiModel(String model) async {
    _openAiModel = model.trim().isEmpty ? defaultOpenAiModel : model.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_openAiModelKey, _openAiModel);
  }

  /// Only the older GPT-4 / GPT-3.5 chat models accept `temperature`. Newer families (o-series, GPT-5 and later)
  /// are reasoning models: they reject it and spend part of their token budget thinking.
  bool get _isReasoningModel => !RegExp(r'^gpt-(4|3\.5)').hasMatch(_openAiModel);

  /// Sampling/length parameters for a chat completion, adjusted for the selected model.
  Map<String, dynamic> openAiSampling({required double temperature, required int maxTokens}) => _isReasoningModel
      ? {'max_completion_tokens': maxTokens + 8000}
      : {'temperature': temperature, 'max_completion_tokens': maxTokens};

  /// Chat models available to this API key: GPT models first, then o-series, newest names first. Throws on network/API errors.
  Future<List<String>> listOpenAiModels() async {
    final apiKey = await getOpenAiApiKey();
    if (apiKey == null) throw Exception('OpenAI API key is not configured.');
    final response = await http.get(
      Uri.parse('https://api.openai.com/v1/models'),
      headers: {'Authorization': 'Bearer $apiKey'},
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('OpenAI returned ${response.statusCode}');
    }
    // Keep general chat models; drop audio, image, embedding, moderation and other special-purpose ones.
    const exclude = ['audio', 'realtime', 'tts', 'transcribe', 'image', 'search', 'embedding', 'moderation',
        'dall-e', 'whisper', 'davinci', 'babbage', 'instruct', 'codex', 'computer-use', 'live'];
    final ids = (jsonDecode(response.body)['data'] as List)
        .map((m) => m['id'].toString())
        .where((id) => RegExp(r'^(gpt-|o\d)').hasMatch(id))
        .where((id) => !exclude.any(id.contains))
        // Hide dated snapshots like "o4-mini-2025-04-16"; the undated name points at the latest one.
        .where((id) => !RegExp(r'-\d{4}-\d{2}-\d{2}$').hasMatch(id))
        .toList()
      ..sort((a, b) {
        final ga = a.startsWith('gpt-') ? 0 : 1, gb = b.startsWith('gpt-') ? 0 : 1;
        return ga != gb ? ga - gb : b.compareTo(a);
      });
    return ids;
  }
}

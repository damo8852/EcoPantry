import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  // Cache for the API keys to avoid repeated Firestore reads
  String? _cachedOpenAiApiKey;
  DateTime? _openAiCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 30); // Cache for 30 minutes

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

  /// Check if OpenAI API key is configured
  Future<bool> hasOpenAiApiKey() async {
    final key = await getOpenAiApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Clear the cached API keys (force refresh on next call)
  void clearCache() {
    _cachedOpenAiApiKey = null;
    _openAiCacheTime = null;
  }

  /// Initialize - no longer needed since we read from Firebase
  Future<void> initializeWithDefaultKey() async {
    // This method is kept for compatibility but does nothing
    // The API key should be set directly in Firebase Console
    print('ConfigService: API key should be configured in Firebase Console at /config/openai');
  }
}

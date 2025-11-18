import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  bool _isInitialized = false;

  /// Initialize speech recognition and TTS
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize speech to text
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        onError: (error) {
          print('Speech recognition error: $error');
          _isListening = false;
        },
      );

      if (!available) {
        print('Speech recognition not available');
        return false;
      }

      // Initialize text to speech
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _isInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing voice services: $e');
      return false;
    }
  }

  /// Check if speech recognition is available
  bool get isAvailable => _speech.isAvailable;

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Start listening for voice input
  /// Returns the recognized text via the onResult callback
  Future<void> startListening({
    required Function(String text) onResult,
    Function(String? error)? onError,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call('Speech recognition not available');
        return;
      }
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _isListening = false;
            if (result.recognizedWords.isNotEmpty) {
              onResult(result.recognizedWords);
            }
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        localeId: 'en_US',
      );
    } catch (e) {
      _isListening = false;
      onError?.call(e.toString());
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
    }
  }

  /// Speak text
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    try {
      await _tts.speak(text);
    } catch (e) {
      print('Error speaking text: $e');
    }
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  /// Check if TTS is currently speaking
  Future<bool> isSpeaking() async {
    // FlutterTts doesn't have isSpeaking getter, return false
    // You can implement this with a flag if needed
    return false;
  }

  /// Set TTS language
  Future<void> setLanguage(String language) async {
    await _tts.setLanguage(language);
  }

  /// Set TTS speech rate (0.0 to 1.0)
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
  }
}


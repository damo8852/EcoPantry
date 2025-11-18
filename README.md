# Atlas Maps - Voice-Activated Google Maps AI Assistant

Atlas Maps is a Flutter application that provides a voice-activated interface to Google Maps. Users can interact with maps using natural language voice commands, powered by ChatGPT for intelligent command parsing.

## Features

- 🗺️ **Full Google Maps Integration** - Complete mapping functionality with directions, place search, and navigation
- 🎤 **Voice-Activated Commands** - Speak naturally to control the app (e.g., "Hey Atlas, redirect me to the nearest gas station")
- 🤖 **AI-Powered Command Parsing** - Uses ChatGPT to understand natural language commands
- 🔊 **Text-to-Speech Responses** - Atlas speaks back to confirm actions and provide information
- 📍 **Real-Time Location** - Automatic location tracking and updates
- 🔍 **Smart Place Search** - Find nearby places, get directions, and ask questions about locations

## Voice Commands

You can use natural language commands like:

- **Navigation**: "Hey Atlas, navigate to 123 Main Street" or "Take me to the airport"
- **Find Nearby**: "Hey Atlas, redirect me to the nearest gas station" or "Find restaurants near me"
- **Questions**: "Hey Atlas, what's the lake I'm driving next to right now?"
- **Cancel**: "Hey Atlas, cancel navigation"

## Setup

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Firebase project with Firestore enabled
- Google Maps API key
- OpenAI API key (for ChatGPT integration)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd atlas_maps
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files
   - Ensure Firestore is enabled in your Firebase project

4. Set up API keys in Firestore:
   - Create a `config` collection in Firestore
   - Add documents:
     - `openai` with field `key` (your OpenAI API key)
     - `google_maps` with field `api_key` (your Google Maps API key)

5. Configure Google Maps:
   - For Android: Add your API key to `android/app/src/main/AndroidManifest.xml`
   - For iOS: Add your API key to `ios/Runner/AppDelegate.swift`

### Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<application>
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_API_KEY"/>
</application>
```

### iOS Configuration

Add to `ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps

// In application:didFinishLaunchingWithOptions:
GMSServices.provideAPIKey("YOUR_API_KEY")
```

## Permissions

The app requires the following permissions:

- **Location** - For current location and navigation
- **Microphone** - For voice input
- **Internet** - For API calls

These permissions are automatically requested when needed.

## Tech Stack

- **Flutter** - Cross-platform mobile framework
- **Google Maps Flutter** - Maps integration
- **Firebase** - Backend services (Firestore for config)
- **OpenAI API** - ChatGPT for command parsing
- **Speech to Text** - Voice input recognition
- **Text to Speech** - Voice responses
- **Geolocator** - Location services
- **Geocoding** - Address conversion

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/
│   └── maps_screen.dart     # Main maps interface
├── services/
│   ├── maps_service.dart    # Google Maps API integration
│   ├── voice_service.dart   # Speech recognition & TTS
│   ├── command_parser_service.dart  # AI command parsing
│   ├── llm_service.dart     # ChatGPT integration
│   └── config_service.dart  # Configuration management
└── models/                  # Data models
```

## Usage

1. Launch the app
2. Grant location and microphone permissions when prompted
3. Tap the microphone button to start voice input
4. Speak your command (e.g., "Hey Atlas, find the nearest gas station")
5. Atlas will process your command and respond with voice and visual feedback

## Development

### Running the App

```bash
flutter run
```

### Building for Release

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

## API Keys Setup

### OpenAI API Key

1. Go to [OpenAI Platform](https://platform.openai.com/)
2. Create an API key
3. Add it to Firestore: `/config/openai` document with field `key`

### Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Maps SDK for Android/iOS
3. Enable Places API
4. Enable Directions API
5. Create an API key
6. Add it to Firestore: `/config/google_maps` document with field `api_key`

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.

## Acknowledgments

- Built with Flutter
- Powered by Google Maps
- AI capabilities provided by OpenAI

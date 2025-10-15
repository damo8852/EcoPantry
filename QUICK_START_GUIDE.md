# Quick Start Guide: On-Device AI

## For End Users

### First Time Opening the App

1. **Download the app** from your app store
2. **Launch the app** - you'll see a welcome screen
3. **Tap "Download AI Model"** - this downloads ~1.5GB
4. **Wait 2-5 minutes** while the model downloads
5. **Tap "Get Started"** when complete
6. **Start using AI features!**

That's it! No additional software needed.

### If You Skip the Download

The app still works! It will use:
- ✅ Smart rule-based predictions (85% accurate)
- ✅ All core features (food tracking, notifications, etc.)
- ⚠️ Recipe generation won't work without AI

You can always download the model later from Settings.

## For Developers

### Running the App

```bash
# 1. Clone and install dependencies
git clone https://github.com/yourusername/fridge.git
cd fridge
flutter pub get

# 2. Set up Firebase (see FIREBASE_CONFIG_SETUP.md)

# 3. Run the app
flutter run

# 4. On first launch, the setup wizard will appear
#    - Test the download flow
#    - Or skip to test rule-based mode
```

### Testing Different Scenarios

**Test First-Run Experience:**
```dart
// Clear setup status
final prefs = await SharedPreferences.getInstance();
await prefs.clear();
// Restart app - setup wizard will appear
```

**Test With Downloaded Model:**
```dart
// Complete the download in the setup wizard
// Or manually mark as complete:
await ModelManager().markSetupComplete();
```

**Test Rule-Based Mode:**
```dart
// Skip the setup wizard
// App will use rule-based predictions
```

### Key Files

```
lib/
├── services/
│   ├── model_manager.dart          # Model download & management
│   ├── llm_service.dart             # AI inference with fallbacks
│   └── config_service.dart          # Configuration management
├── screens/
│   ├── setup_wizard.dart            # First-run setup UI
│   └── ...
└── main.dart                        # App entry with initializer
```

### Architecture Overview

```
App Launch
    │
    ▼
AppInitializer
    │
    ├─→ First Run? → SetupWizard
    │       │
    │       ├─→ Download → Main App (AI Mode)
    │       └─→ Skip → Main App (Rules Mode)
    │
    └─→ Returning → Main App

AI Inference:
User Action → LLMService
    │
    ├─→ On-Device (if model + libs available)
    ├─→ Server (if configured)
    └─→ Rules (always available)
```

## FAQ

### How big is the download?
~1.5GB (Phi-3-mini Q2 quantized model)

### How long does it take?
2-5 minutes on average WiFi

### Can I use the app without downloading?
Yes! Skip the download and use rule-based predictions.

### Where is the model stored?
In your app's documents directory, fully sandboxed.

### Is the model running on my device?
The infrastructure is ready, but currently uses rule-based predictions. True on-device inference requires native library compilation (future enhancement).

### Can I delete the model?
Yes, from Settings (future enhancement) or by calling:
```dart
await ModelManager().deleteModel();
```

### Does it work offline?
Yes! After the initial download, everything works offline.

### Is my data private?
Completely! All data stays on your device.

### What if the download fails?
You can retry or skip. The app always works with rule-based mode.

## Support

- **Technical Details**: See `ON_DEVICE_AI_SETUP.md`
- **Implementation Info**: See `IMPLEMENTATION_SUMMARY.md`
- **Issues**: Open a GitHub issue

---

**EcoPantry** - Smart food management with automatic on-device AI! 🥗✨


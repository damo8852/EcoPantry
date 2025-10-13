# Phi-3 Quick Start Guide

Get EcoPantry running with local AI in 5 minutes!

## TL;DR

```bash
# 1. Install Ollama
# Windows: Download from https://ollama.ai/download
# macOS: brew install ollama
# Linux: curl -fsSL https://ollama.ai/install.sh | sh

# 2. Pull Phi-3 model (4-bit quantized, ~2.5GB)
ollama pull phi3:3.8b-mini-4k-instruct-q4_K_M

# 3. Start Ollama (in a new terminal)
ollama serve

# 4. Run the app
flutter run
```

## Step-by-Step

### 1. Install Ollama

**Windows:**
1. Download installer from https://ollama.ai/download
2. Run the installer
3. Ollama will start automatically

**macOS:**
```bash
brew install ollama
```

**Linux:**
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

### 2. Download Phi-3 Model

Open a terminal and run:

```bash
# Recommended: 4-bit quantization (best quality/speed balance)
ollama pull phi3:3.8b-mini-4k-instruct-q4_K_M

# Or for slower hardware: 2-bit quantization (faster, smaller)
ollama pull phi3:3.8b-mini-4k-instruct-q2_K
```

This will download ~2.5GB (Q4) or ~1.5GB (Q2).

### 3. Start the Server

**Option A: Use the provided script**

Windows:
```bash
.\start_phi3_server.bat
```

macOS/Linux:
```bash
./start_phi3_server.sh
```

**Option B: Manual start**

```bash
ollama serve
```

The server will start on `http://localhost:11434`

### 4. Test the Setup

Open a new terminal:

```bash
# Test Ollama is working
curl http://localhost:11434/api/tags

# Should return JSON with available models
```

### 5. Run EcoPantry

```bash
flutter run
```

## Verify It's Working

In the app:
1. Add a food item (e.g., "chicken")
2. Check if AI predicts expiry date (should be ~3 days)
3. Go to Recipes tab
4. Click "Generate Recipes"
5. Should see AI-generated recipes

Console should show:
```
ConfigService: Initialized with Phi-3 local server configuration
  Server URL: http://localhost:11434
  Model: phi3:3.8b-mini-4k-instruct-q4_K_M
  Type: ollama
```

## Troubleshooting

### Issue: "Server not available"

**Check if Ollama is running:**
```bash
curl http://localhost:11434/api/tags
```

**If not responding:**
- Windows: Check if Ollama Desktop is running
- macOS/Linux: Run `ollama serve` in a terminal

### Issue: "Model not found"

**List available models:**
```bash
ollama list
```

**If Phi-3 not listed:**
```bash
ollama pull phi3:3.8b-mini-4k-instruct-q4_K_M
```

### Issue: Slow responses

**Try a smaller quantization:**
```bash
ollama pull phi3:3.8b-mini-4k-instruct-q2_K
```

Then in the app config (future enhancement) or in `lib/services/config_service.dart`:
```dart
static const String defaultModelName = 'phi3:3.8b-mini-4k-instruct-q2_K';
```

### Issue: Out of memory

**Solutions:**
1. Close other applications
2. Use Q2 quantization (requires less RAM)
3. Reduce context length in Ollama

## Alternative: llama.cpp

If you prefer llama.cpp over Ollama:

1. Download llama.cpp from https://github.com/ggerganov/llama.cpp/releases
2. Download Phi-3 GGUF from https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf
3. Run:
   ```bash
   llama-server --model phi-3-mini-4k-instruct-q4.gguf --port 8080
   ```
4. Update app config to use llama.cpp:
   ```dart
   await ConfigService().setServerType('llamacpp');
   ```

## Configuration

### Change Model

```dart
// In lib/services/config_service.dart
static const String defaultModelName = 'phi3:3.8b-mini-4k-instruct-q2_K';
```

### Change Server URL

```dart
// In lib/services/config_service.dart
static const String defaultServerUrl = 'http://192.168.1.100:11434'; // Remote server
```

## Performance Tips

1. **Use Q4 quantization** for best quality
2. **Use Q2 quantization** for fastest speed
3. **Close other apps** to free RAM
4. **Use GPU** if available (NVIDIA CUDA support in llama.cpp)

## Next Steps

- Read [PHI3_SETUP.md](PHI3_SETUP.md) for detailed configuration
- See [README_PHI3_MIGRATION.md](README_PHI3_MIGRATION.md) for technical details
- Check console logs for AI responses and debugging

## Support

- Ollama issues: https://github.com/ollama/ollama/issues
- Phi-3 documentation: https://github.com/microsoft/Phi-3CookBook
- EcoPantry issues: Open a GitHub issue

---

**That's it! You're now running EcoPantry with local, private AI!** 🎉


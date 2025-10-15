# Phi-3 Local AI Setup Guide

This project uses Microsoft's Phi-3 family of models for local AI inference with 2-4 bit quantization for optimal performance.

## Overview

**Why Phi-3?**
- **Small & Fast**: Phi-3-mini (3.8B parameters) runs efficiently on consumer hardware
- **Quantized**: 2-4 bit GGUF models drastically reduce memory usage and increase speed
- **Offline**: No internet required, no API costs, complete privacy
- **Quality**: Despite small size, Phi-3 delivers excellent results for structured tasks

## Prerequisites

- **Operating System**: Windows, macOS, or Linux
- **RAM**: Minimum 4GB (8GB+ recommended)
- **Storage**: ~2GB for quantized model files
- **Python** (optional): For llama.cpp server

## Installation Options

### Option 1: llama.cpp (Recommended)

llama.cpp provides excellent performance with quantized models.

#### Windows Setup

1. **Download llama.cpp server**:
   ```powershell
   # Download pre-built binary from GitHub
   # https://github.com/ggerganov/llama.cpp/releases
   # Look for: llama-b[BUILD]-bin-win-cuda/avx2/avx512-x64.zip
   ```

2. **Extract to project directory**:
   ```powershell
   # Extract to: .\llama-cpp-server\
   ```

3. **Download Phi-3 quantized model**:
   ```powershell
   # Create models directory
   mkdir models
   cd models
   
   # Download from Hugging Face (choose one):
   # Q4_K_M (4-bit, balanced) - RECOMMENDED
   # https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf
   
   # Or use wget/curl:
   # curl -L -o phi-3-mini-4k-instruct-q4.gguf https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf
   ```

4. **Start the server**:
   ```powershell
   .\start_phi3_server.bat
   ```

#### macOS/Linux Setup

1. **Install llama.cpp**:
   ```bash
   # Clone repository
   git clone https://github.com/ggerganov/llama.cpp.git
   cd llama.cpp
   
   # Build
   make
   
   # Or with CUDA support (NVIDIA GPU):
   make LLAMA_CUBLAS=1
   ```

2. **Download Phi-3 model**:
   ```bash
   mkdir -p ../models
   cd ../models
   
   # Download 4-bit quantized model (recommended)
   wget https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf
   ```

3. **Start the server**:
   ```bash
   ./start_phi3_server.sh
   ```

### Option 2: Ollama (Easiest)

Ollama provides the simplest setup experience.

1. **Install Ollama**:
   - Download from: https://ollama.ai/download
   - Run installer

2. **Pull Phi-3 model**:
   ```bash
   # Pull quantized Phi-3 model
   ollama pull phi3:3.8b-mini-4k-instruct-q4_K_M
   
   # Or smaller 2-bit version:
   ollama pull phi3:3.8b-mini-4k-instruct-q2_K
   ```

3. **Start Ollama server**:
   ```bash
   ollama serve
   ```

## Model Quantization Options

Choose based on your hardware:

| Quantization | Size | RAM Usage | Speed | Quality |
|--------------|------|-----------|-------|---------|
| **Q2_K** | ~1.5GB | 2-3GB | Fastest | Good |
| **Q3_K_M** | ~2GB | 3-4GB | Very Fast | Better |
| **Q4_K_M** | ~2.5GB | 4-5GB | Fast | Excellent |
| **Q4_K_S** | ~2.3GB | 3-4GB | Fast | Very Good |

**Recommended**: Q4_K_M for best balance of quality and performance.

## Server Configuration

### Default Settings

The app expects the local server at:
- **URL**: `http://localhost:11434` (Ollama) or `http://localhost:8080` (llama.cpp)
- **Model**: `phi3` or custom model name
- **Context Length**: 4096 tokens

### Custom Configuration

You can configure the server in the app's settings (future enhancement) or modify `lib/services/config_service.dart`:

```dart
// Default values
static const String defaultServerUrl = 'http://localhost:11434';
static const String defaultModelName = 'phi3:3.8b-mini-4k-instruct-q4_K_M';
```

## Helper Scripts

### Windows: `start_phi3_server.bat`

Automatically starts the Phi-3 server with optimal settings.

### macOS/Linux: `start_phi3_server.sh`

Starts the server with proper configuration.

## Testing the Setup

1. **Start the server** (using one of the methods above)

2. **Test the endpoint**:
   ```bash
   # For Ollama:
   curl http://localhost:11434/api/generate -d '{
     "model": "phi3:3.8b-mini-4k-instruct-q4_K_M",
     "prompt": "Say hello",
     "stream": false
   }'
   
   # For llama.cpp:
   curl http://localhost:8080/completion -d '{
     "prompt": "Say hello",
     "n_predict": 50
   }'
   ```

3. **Run the Flutter app**:
   ```bash
   flutter run
   ```

4. **Test AI features**:
   - Scan a food item (tests expiry prediction)
   - Generate recipes (tests recipe generation)
   - Check console logs for AI responses

## Performance Optimization

### CPU Optimization
- Use Q4_K_M quantization for best CPU performance
- Set context length to 2048 for faster inference
- Adjust thread count based on CPU cores

### GPU Acceleration (NVIDIA)
If you have an NVIDIA GPU:

```bash
# llama.cpp with CUDA
./llama-server --model ./models/phi-3-mini-4k-instruct-q4.gguf \
  --port 8080 \
  --n-gpu-layers 32 \
  --ctx-size 4096
```

### Memory Management
- Q2_K: Works on 4GB RAM systems
- Q4_K_M: Recommended for 8GB+ RAM systems
- Reduce context size if running low on memory

## Troubleshooting

### Server Won't Start

**Issue**: Port already in use
```bash
# Find process using port
# Windows:
netstat -ano | findstr :11434
taskkill /PID <pid> /F

# macOS/Linux:
lsof -i :11434
kill -9 <pid>
```

**Issue**: Model file not found
- Verify model is in `./models/` directory
- Check model filename matches configuration
- Re-download model if corrupted

### Slow Performance

- Use a more aggressive quantization (Q2_K or Q3_K_M)
- Reduce context length to 2048
- Close other applications to free RAM
- Consider GPU acceleration if available

### Connection Errors

**Issue**: App can't connect to server
- Verify server is running: `curl http://localhost:11434/api/tags`
- Check firewall settings
- Ensure correct port in configuration
- Try `127.0.0.1` instead of `localhost`

### Poor Response Quality

- Try Q4_K_M quantization for better quality
- Adjust temperature in LLM service (default: 0.1)
- Increase max_tokens if responses are cut off
- Verify model is Phi-3, not a different model

## Model Files

### Recommended Models

1. **Phi-3-mini-4k-instruct-q4.gguf** (Primary)
   - 4-bit quantization
   - ~2.5GB size
   - Best balance of quality and speed
   - Download: https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf

2. **Phi-3-mini-4k-instruct-q2_K.gguf** (Lightweight)
   - 2-bit quantization
   - ~1.5GB size
   - Fastest inference
   - Good for low-end hardware

3. **Phi-3-mini-128k-instruct-q4.gguf** (Long context)
   - 4-bit quantization
   - Supports 128K context
   - Use only if you need long context windows

### Alternative Models (Phi Family)

- **Phi-3-small**: 7B parameters (requires more RAM)
- **Phi-3-medium**: 14B parameters (high-end hardware only)
- **Phi-3.5-mini-instruct**: Improved version of Phi-3-mini

## Migration from Mistral API

### What Changed

- **No API key needed**: All inference is local
- **Offline capable**: Works without internet
- **No costs**: No per-token charges
- **Privacy**: Data never leaves your device
- **Speed**: Faster inference with quantization

### Preserved Functionality

All existing features work identically:
- ✅ Expiry prediction
- ✅ Grocery type classification
- ✅ Recipe generation
- ✅ JSON structured output parsing

## Advanced Configuration

### Custom Model Path

Edit `lib/services/config_service.dart`:

```dart
static const String defaultModelPath = './models/custom-model.gguf';
```

### Server Parameters

For llama.cpp server, adjust performance:

```bash
./llama-server \
  --model ./models/phi-3-mini-4k-instruct-q4.gguf \
  --port 8080 \
  --ctx-size 4096 \
  --threads 8 \
  --batch-size 512 \
  --n-gpu-layers 0
```

For Ollama, create a Modelfile:

```
FROM phi3:3.8b-mini-4k-instruct-q4_K_M

PARAMETER temperature 0.1
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER num_ctx 4096
```

Save as `Modelfile` and run:
```bash
ollama create ecopantry-phi3 -f Modelfile
```

## Next Steps

1. ✅ Start the local Phi-3 server
2. ✅ Verify server is accessible
3. ✅ Run the Flutter app
4. ✅ Test AI features
5. ⚙️ Optimize settings for your hardware

## Support

For issues specific to:
- **llama.cpp**: https://github.com/ggerganov/llama.cpp/issues
- **Ollama**: https://github.com/ollama/ollama/issues
- **Phi-3 models**: https://github.com/microsoft/Phi-3CookBook

## Resources

- **Phi-3 Technical Report**: https://arxiv.org/abs/2404.14219
- **Microsoft Phi-3 Cookbook**: https://github.com/microsoft/Phi-3CookBook
- **GGUF Format**: https://github.com/ggerganov/ggml/blob/master/docs/gguf.md
- **Model Quantization Guide**: https://github.com/ggerganov/llama.cpp/blob/master/examples/quantize/README.md


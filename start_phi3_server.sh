#!/bin/bash
# Start Phi-3 Local Server for EcoPantry
# This script starts a local Phi-3 server using Ollama or llama.cpp

echo "===================================="
echo " EcoPantry - Phi-3 Server Startup"
echo "===================================="
echo ""

# Check if Ollama is installed
if command -v ollama &> /dev/null; then
    echo "[INFO] Ollama detected. Starting Ollama server..."
    echo ""
    echo "Model: phi3:3.8b-mini-4k-instruct-q4_K_M"
    echo "Port: 11434"
    echo ""
    echo "Starting server... Press Ctrl+C to stop"
    echo ""
    ollama serve
    exit 0
fi

# Check if llama.cpp server exists
if [ -f "llama-cpp-server/llama-server" ] || [ -f "llama.cpp/llama-server" ]; then
    echo "[INFO] llama.cpp server detected. Starting server..."
    echo ""
    echo "Model: models/phi-3-mini-4k-instruct-q4.gguf"
    echo "Port: 8080"
    echo ""
    
    if [ ! -f "models/phi-3-mini-4k-instruct-q4.gguf" ]; then
        echo "[ERROR] Model file not found!"
        echo ""
        echo "Please download the Phi-3 model:"
        echo "1. Create 'models' directory: mkdir -p models"
        echo "2. Download from: https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf"
        echo "3. Place file in: models/phi-3-mini-4k-instruct-q4.gguf"
        echo ""
        echo "Quick download:"
        echo "cd models && wget https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf"
        echo ""
        exit 1
    fi
    
    echo "Starting server... Press Ctrl+C to stop"
    echo ""
    
    # Determine llama-server path
    if [ -f "llama-cpp-server/llama-server" ]; then
        SERVER_PATH="llama-cpp-server/llama-server"
    else
        SERVER_PATH="llama.cpp/llama-server"
    fi
    
    # Start server with optimal settings
    $SERVER_PATH \
        --model models/phi-3-mini-4k-instruct-q4.gguf \
        --port 8080 \
        --ctx-size 4096 \
        --threads 8 \
        --batch-size 512 \
        --n-gpu-layers 0
    
    exit 0
fi

# No server found
echo "[ERROR] No Phi-3 server found!"
echo ""
echo "Please install one of the following:"
echo ""
echo "Option 1 - Ollama (Recommended):"
echo "  macOS: brew install ollama"
echo "  Linux: curl -fsSL https://ollama.ai/install.sh | sh"
echo "  Then run: ollama pull phi3:3.8b-mini-4k-instruct-q4_K_M"
echo ""
echo "Option 2 - llama.cpp:"
echo "  1. git clone https://github.com/ggerganov/llama.cpp.git"
echo "  2. cd llama.cpp && make"
echo "  3. Download Phi-3 model to ../models/"
echo "  4. Run this script again"
echo ""
echo "See PHI3_SETUP.md for detailed instructions."
echo ""
exit 1


@echo off
REM Start Phi-3 Local Server for EcoPantry
REM This script starts a local Phi-3 server using Ollama or llama.cpp

echo ====================================
echo  EcoPantry - Phi-3 Server Startup
echo ====================================
echo.

REM Check if Ollama is installed
where ollama >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [INFO] Ollama detected. Starting Ollama server...
    echo.
    echo Model: phi3:3.8b-mini-4k-instruct-q4_K_M
    echo Port: 11434
    echo.
    echo Starting server... Press Ctrl+C to stop
    echo.
    ollama serve
    goto :end
)

REM Check if llama.cpp server exists
if exist "llama-cpp-server\llama-server.exe" (
    echo [INFO] llama.cpp server detected. Starting server...
    echo.
    echo Model: models\phi-3-mini-4k-instruct-q4.gguf
    echo Port: 8080
    echo.
    
    if not exist "models\phi-3-mini-4k-instruct-q4.gguf" (
        echo [ERROR] Model file not found!
        echo.
        echo Please download the Phi-3 model:
        echo 1. Create 'models' directory
        echo 2. Download from: https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf
        echo 3. Place file in: models\phi-3-mini-4k-instruct-q4.gguf
        echo.
        pause
        goto :end
    )
    
    echo Starting server... Press Ctrl+C to stop
    echo.
    cd llama-cpp-server
    llama-server.exe ^
        --model ..\models\phi-3-mini-4k-instruct-q4.gguf ^
        --port 8080 ^
        --ctx-size 4096 ^
        --threads 8 ^
        --batch-size 512
    goto :end
)

REM No server found
echo [ERROR] No Phi-3 server found!
echo.
echo Please install one of the following:
echo.
echo Option 1 - Ollama (Recommended):
echo   1. Download from: https://ollama.ai/download
echo   2. Install and restart this script
echo   3. Run: ollama pull phi3:3.8b-mini-4k-instruct-q4_K_M
echo.
echo Option 2 - llama.cpp:
echo   1. Download from: https://github.com/ggerganov/llama.cpp/releases
echo   2. Extract to: llama-cpp-server\
echo   3. Download Phi-3 model to: models\
echo   4. Restart this script
echo.
echo See PHI3_SETUP.md for detailed instructions.
echo.
pause

:end


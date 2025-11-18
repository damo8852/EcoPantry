@echo off
REM Start the Food LLM API server

echo Starting Food LLM API...

REM Check if virtual environment exists
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Install dependencies if needed
if not exist "venv\.installed" (
    echo Installing dependencies...
    pip install -r requirements.txt
    echo. > venv\.installed
)

REM Set model path (use fine-tuned if available)
if exist "training\food_model" (
    set MODEL_PATH=training\food_model
    echo Using fine-tuned model: %MODEL_PATH%
) else (
    echo Fine-tuned model not found, will use base model
)

REM Start API server
cd inference
python api.py


#!/bin/bash
# Start the Food LLM API server

echo "Starting Food LLM API..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies if needed
if [ ! -f "venv/.installed" ]; then
    echo "Installing dependencies..."
    pip install -r requirements.txt
    touch venv/.installed
fi

# Set model path (use fine-tuned if available)
if [ -d "training/food_model" ]; then
    export MODEL_PATH="training/food_model"
    echo "Using fine-tuned model: $MODEL_PATH"
else
    echo "Fine-tuned model not found, will use base model"
fi

# Start API server
cd inference
python api.py


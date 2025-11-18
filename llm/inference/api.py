"""
FastAPI server for food LLM inference
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import sys
import os

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from models.food_llm import FoodLMFineTuned


# Initialize FastAPI app
app = FastAPI(
    title="Food LLM API",
    description="API for food-specific language model predictions",
    version="0.1.0"
)

# Global model instance (loaded on startup)
model = None
MODEL_PATH = os.environ.get('MODEL_PATH', './food_model')


# Request/Response models
class ExpiryRequest(BaseModel):
    food_item: str
    additional_context: Optional[str] = None


class ExpiryResponse(BaseModel):
    food_item: str
    predicted_days: int
    raw_output: str


class RecipeRequest(BaseModel):
    ingredients: List[str]
    max_tokens: int = 500


class RecipeResponse(BaseModel):
    recipe_text: str
    ingredients_used: List[str]


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    model_path: str


@app.on_event("startup")
async def load_model():
    """Load the model when the API starts"""
    global model
    
    try:
        print(f"Loading model from {MODEL_PATH}...")
        
        # Check if fine-tuned model exists, otherwise use base model
        if os.path.exists(MODEL_PATH):
            model = FoodLMFineTuned('distilgpt2')
            model.load_model(MODEL_PATH)
            print("Fine-tuned model loaded successfully")
        else:
            print(f"Fine-tuned model not found at {MODEL_PATH}")
            print("Loading base model (distilgpt2)...")
            model = FoodLMFineTuned('distilgpt2')
            print("Base model loaded successfully")
            
    except Exception as e:
        print(f"Error loading model: {e}")
        print("API will start but predictions will fail until model is loaded")


@app.get("/", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy" if model is not None else "model_not_loaded",
        model_loaded=model is not None,
        model_path=MODEL_PATH
    )


@app.post("/predict/expiry", response_model=ExpiryResponse)
async def predict_expiry(request: ExpiryRequest):
    """
    Predict expiry days for a food item
    
    Example:
    ```
    curl -X POST "http://localhost:8000/predict/expiry" \
         -H "Content-Type: application/json" \
         -d '{"food_item": "milk"}'
    ```
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # Get prediction from model
        raw_output = model.predict_expiry(request.food_item)
        
        # Parse the output to extract number
        predicted_days = parse_days(raw_output)
        
        return ExpiryResponse(
            food_item=request.food_item,
            predicted_days=predicted_days,
            raw_output=raw_output
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")


@app.post("/predict/recipe", response_model=RecipeResponse)
async def generate_recipe(request: RecipeRequest):
    """
    Generate a recipe from ingredients
    
    Example:
    ```
    curl -X POST "http://localhost:8000/predict/recipe" \
         -H "Content-Type: application/json" \
         -d '{"ingredients": ["chicken", "rice", "vegetables"]}'
    ```
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # Generate recipe
        recipe_text = model.generate_recipe(
            request.ingredients,
            max_tokens=request.max_tokens
        )
        
        return RecipeResponse(
            recipe_text=recipe_text,
            ingredients_used=request.ingredients
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Recipe generation error: {str(e)}")


def parse_days(text: str) -> int:
    """
    Parse days from model output.
    Extracts first number from text.
    """
    import re
    
    # Try to find a number in the text
    match = re.search(r'\b(\d{1,4})\b', text)
    
    if match:
        days = int(match.group(1))
        # Sanity check (1 day to 10 years)
        if 1 <= days <= 3650:
            return days
    
    # Default fallback
    return 7  # Default to 7 days if parsing fails


if __name__ == "__main__":
    import uvicorn
    
    print("Starting Food LLM API server...")
    print(f"Model path: {MODEL_PATH}")
    print("Access API docs at: http://localhost:8000/docs")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )


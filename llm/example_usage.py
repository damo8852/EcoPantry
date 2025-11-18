"""
Example usage of the Food LLM

This script demonstrates how to use the food-specific language model
for expiry prediction and recipe generation.
"""
import sys
import os

# Add current directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from models.food_llm import FoodLMFineTuned


def demo_expiry_prediction(model):
    """Demonstrate expiry prediction"""
    print("\n" + "="*50)
    print("EXPIRY PREDICTION DEMO")
    print("="*50)
    
    test_foods = [
        'milk',
        'chicken breast',
        'strawberries',
        'rice',
        'yogurt',
        'cheddar cheese',
        'ground beef',
        'broccoli',
    ]
    
    print("\nPredicting expiry dates for various foods:\n")
    
    for food in test_foods:
        prediction = model.predict_expiry(food, temperature=0.1)
        print(f"  {food:20s} -> {prediction} days")


def demo_recipe_generation(model):
    """Demonstrate recipe generation"""
    print("\n" + "="*50)
    print("RECIPE GENERATION DEMO")
    print("="*50)
    
    ingredient_sets = [
        ['chicken', 'rice', 'vegetables'],
        ['eggs', 'cheese', 'milk'],
        ['salmon', 'lemon', 'dill'],
        ['pasta', 'tomatoes', 'garlic'],
    ]
    
    print("\nGenerating recipes from ingredients:\n")
    
    for ingredients in ingredient_sets:
        print(f"\nIngredients: {', '.join(ingredients)}")
        print("-" * 50)
        
        recipe = model.generate_recipe(ingredients, max_tokens=300)
        
        # Print recipe (truncate if too long)
        recipe_lines = recipe.split('\n')
        for line in recipe_lines[:15]:  # Show first 15 lines
            print(f"  {line}")
        
        if len(recipe_lines) > 15:
            print("  ...")
        
        print()


def main():
    """Main demo function"""
    print("="*50)
    print("FOOD LLM DEMONSTRATION")
    print("="*50)
    
    print("\nLoading model...")
    print("This may take a moment on first run (downloading model)...\n")
    
    # Check if fine-tuned model exists
    model_path = './training/food_model'
    
    try:
        if os.path.exists(model_path):
            print(f"Loading fine-tuned model from: {model_path}")
            model = FoodLMFineTuned('distilgpt2')
            model.load_model(model_path)
            print("[OK] Fine-tuned model loaded successfully")
        else:
            print("Fine-tuned model not found.")
            print("Using base model (distilgpt2)...")
            print("Note: Results will be better after fine-tuning!")
            model = FoodLMFineTuned('distilgpt2')
            print("[OK] Base model loaded successfully")
    except Exception as e:
        print(f"Error loading model: {e}")
        print("\nPlease ensure you have:")
        print("  1. Installed dependencies: pip install -r requirements.txt")
        print("  2. Internet connection (for first-time model download)")
        return
    
    # Get model info
    print(f"\nModel size: {model._get_model_size():.2f} MB")
    print(f"Device: {model.device}")
    
    # Run demos
    try:
        demo_expiry_prediction(model)
        demo_recipe_generation(model)
    except Exception as e:
        print(f"\nError during demo: {e}")
        import traceback
        traceback.print_exc()
    
    print("\n" + "="*50)
    print("DEMO COMPLETE")
    print("="*50)
    
    print("\nNext steps:")
    print("  1. Prepare training data: python data/prepare_datasets.py")
    print("  2. Train the model: python training/train.py")
    print("  3. Start API server: python inference/api.py")
    print("  4. Integrate with Flutter app")
    print("\nSee README.md for detailed instructions.")


if __name__ == "__main__":
    main()


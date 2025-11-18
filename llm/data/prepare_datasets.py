"""
Prepare training datasets for food-specific LLM
"""
import json
import os
from typing import List, Dict
import random


def create_expiry_dataset() -> List[Dict]:
    """
    Create expiry prediction training examples.
    Based on USDA food storage guidelines.
    """
    
    # Food storage data (food_item, days, category)
    food_storage_data = [
        # Dairy
        ("milk", 7, "dairy"),
        ("yogurt", 14, "dairy"),
        ("cheese (hard)", 180, "dairy"),
        ("cheese (soft)", 7, "dairy"),
        ("butter", 90, "dairy"),
        ("cream", 7, "dairy"),
        ("sour cream", 14, "dairy"),
        
        # Meat & Poultry
        ("chicken (raw)", 2, "poultry"),
        ("chicken (cooked)", 4, "poultry"),
        ("ground beef", 2, "meat"),
        ("steak", 5, "meat"),
        ("pork chops", 5, "meat"),
        ("bacon", 7, "meat"),
        ("ham", 7, "meat"),
        ("turkey", 2, "poultry"),
        
        # Seafood
        ("salmon", 2, "seafood"),
        ("shrimp", 2, "seafood"),
        ("tuna", 2, "seafood"),
        ("crab", 2, "seafood"),
        
        # Vegetables
        ("lettuce", 7, "vegetable"),
        ("carrots", 21, "vegetable"),
        ("broccoli", 7, "vegetable"),
        ("spinach", 7, "vegetable"),
        ("tomatoes", 7, "vegetable"),
        ("cucumbers", 7, "vegetable"),
        ("bell peppers", 14, "vegetable"),
        ("onions", 60, "vegetable"),
        ("potatoes", 60, "vegetable"),
        ("mushrooms", 7, "vegetable"),
        
        # Fruits
        ("apples", 30, "fruit"),
        ("bananas", 7, "fruit"),
        ("strawberries", 5, "fruit"),
        ("blueberries", 10, "fruit"),
        ("grapes", 7, "fruit"),
        ("oranges", 14, "fruit"),
        ("lemons", 30, "fruit"),
        ("avocados", 5, "fruit"),
        ("watermelon", 7, "fruit"),
        
        # Eggs
        ("eggs", 35, "dairy"),
        
        # Condiments (refrigerated)
        ("ketchup", 180, "condiment"),
        ("mayonnaise", 60, "condiment"),
        ("mustard", 365, "condiment"),
        ("soy sauce", 365, "condiment"),
        ("hot sauce", 180, "condiment"),
        
        # Prepared foods
        ("pizza", 4, "prepared"),
        ("leftovers", 4, "prepared"),
        ("soup", 4, "prepared"),
        ("pasta", 5, "prepared"),
        
        # Pantry items (longer shelf life)
        ("rice", 730, "grain"),
        ("pasta (dry)", 730, "grain"),
        ("flour", 365, "grain"),
        ("sugar", 730, "other"),
        ("salt", 3650, "condiment"),
        ("olive oil", 365, "condiment"),
        ("canned beans", 730, "canned"),
        ("canned tomatoes", 730, "canned"),
    ]
    
    examples = []
    for food_item, days, category in food_storage_data:
        examples.append({
            "task": "expiry",
            "food_item": food_item,
            "days": days,
            "category": category,
        })
    
    return examples


def create_recipe_dataset() -> List[Dict]:
    """
    Create recipe generation training examples.
    """
    
    recipes = [
        {
            "name": "Chicken Stir Fry",
            "ingredients": ["chicken", "vegetables", "soy sauce"],
            "detailed_ingredients": [
                "1 lb chicken breast, diced",
                "2 cups mixed vegetables",
                "2 tbsp soy sauce",
                "1 tbsp oil",
                "salt and pepper to taste"
            ],
            "instructions": [
                "Heat oil in a large pan over medium-high heat",
                "Add diced chicken and cook until browned, about 5 minutes",
                "Add vegetables and stir fry for 3-4 minutes",
                "Add soy sauce and season with salt and pepper",
                "Cook for another 2 minutes until everything is well combined"
            ],
            "prep_time": "10min",
            "cook_time": "15min"
        },
        {
            "name": "Simple Pasta",
            "ingredients": ["pasta", "tomatoes", "cheese"],
            "detailed_ingredients": [
                "8 oz pasta",
                "2 cups diced tomatoes",
                "1/2 cup grated cheese",
                "2 cloves garlic, minced",
                "2 tbsp olive oil"
            ],
            "instructions": [
                "Boil pasta according to package directions",
                "In a pan, heat olive oil and sauté garlic until fragrant",
                "Add tomatoes and simmer for 10 minutes",
                "Drain pasta and add to sauce",
                "Top with grated cheese and serve"
            ],
            "prep_time": "5min",
            "cook_time": "20min"
        },
        {
            "name": "Scrambled Eggs",
            "ingredients": ["eggs", "milk"],
            "detailed_ingredients": [
                "4 eggs",
                "2 tbsp milk",
                "1 tbsp butter",
                "salt and pepper to taste"
            ],
            "instructions": [
                "Crack eggs into a bowl and whisk with milk",
                "Heat butter in a non-stick pan over medium heat",
                "Pour in egg mixture",
                "Gently stir with a spatula until eggs are cooked but still soft",
                "Season with salt and pepper and serve immediately"
            ],
            "prep_time": "2min",
            "cook_time": "5min"
        },
        {
            "name": "Grilled Salmon",
            "ingredients": ["salmon", "lemon"],
            "detailed_ingredients": [
                "2 salmon fillets",
                "1 lemon, sliced",
                "2 tbsp olive oil",
                "salt and pepper to taste",
                "fresh dill (optional)"
            ],
            "instructions": [
                "Preheat grill to medium-high heat",
                "Brush salmon with olive oil and season with salt and pepper",
                "Place salmon on grill skin-side down",
                "Grill for 6-8 minutes per side until cooked through",
                "Squeeze lemon over salmon and serve with fresh dill"
            ],
            "prep_time": "5min",
            "cook_time": "15min"
        },
    ]
    
    examples = []
    for recipe in recipes:
        examples.append({
            "task": "recipe",
            **recipe
        })
    
    return examples


def create_classification_dataset() -> List[Dict]:
    """
    Create food classification training examples.
    """
    
    food_categories = {
        "meat": ["beef", "pork", "lamb", "veal", "ground beef", "steak"],
        "poultry": ["chicken", "turkey", "duck", "chicken breast"],
        "seafood": ["salmon", "tuna", "shrimp", "crab", "fish", "cod"],
        "dairy": ["milk", "cheese", "yogurt", "butter", "cream"],
        "vegetable": ["carrots", "broccoli", "spinach", "lettuce", "tomatoes"],
        "fruit": ["apples", "bananas", "oranges", "strawberries", "grapes"],
        "grain": ["rice", "pasta", "bread", "oats", "quinoa"],
        "condiment": ["ketchup", "mustard", "mayonnaise", "soy sauce"],
    }
    
    examples = []
    for category, foods in food_categories.items():
        for food in foods:
            examples.append({
                "task": "classification",
                "food_item": food,
                "category": category,
            })
    
    return examples


def save_dataset(examples: List[Dict], output_file: str):
    """Save dataset to JSONL file"""
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        for example in examples:
            f.write(json.dumps(example) + '\n')
    
    print(f"Saved {len(examples)} examples to {output_file}")


def main():
    """Create all training datasets"""
    
    print("Creating training datasets...")
    
    # Collect all examples
    all_examples = []
    all_examples.extend(create_expiry_dataset())
    all_examples.extend(create_recipe_dataset())
    all_examples.extend(create_classification_dataset())
    
    # Shuffle examples
    random.seed(42)
    random.shuffle(all_examples)
    
    # Split into train/eval (90/10 split)
    split_idx = int(len(all_examples) * 0.9)
    train_examples = all_examples[:split_idx]
    eval_examples = all_examples[split_idx:]
    
    # Save datasets
    script_dir = os.path.dirname(os.path.abspath(__file__))
    train_file = os.path.join(script_dir, 'train.jsonl')
    eval_file = os.path.join(script_dir, 'eval.jsonl')
    
    save_dataset(train_examples, train_file)
    save_dataset(eval_examples, eval_file)
    
    print(f"\nDataset statistics:")
    print(f"Total examples: {len(all_examples)}")
    print(f"Training: {len(train_examples)}")
    print(f"Evaluation: {len(eval_examples)}")
    
    # Print breakdown by task
    task_counts = {}
    for ex in all_examples:
        task = ex['task']
        task_counts[task] = task_counts.get(task, 0) + 1
    
    print(f"\nExamples by task:")
    for task, count in task_counts.items():
        print(f"  {task}: {count}")


if __name__ == "__main__":
    main()


"""
Utility functions for dataset creation and processing
"""
import json
import random
from typing import List, Dict, Tuple


def load_jsonl(file_path: str) -> List[Dict]:
    """Load data from JSONL file"""
    data = []
    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            data.append(json.loads(line))
    return data


def save_jsonl(data: List[Dict], file_path: str):
    """Save data to JSONL file"""
    with open(file_path, 'w', encoding='utf-8') as f:
        for item in data:
            f.write(json.dumps(item) + '\n')


def split_dataset(data: List[Dict], train_ratio: float = 0.9) -> Tuple[List[Dict], List[Dict]]:
    """Split dataset into train and eval sets"""
    random.shuffle(data)
    split_idx = int(len(data) * train_ratio)
    return data[:split_idx], data[split_idx:]


def augment_expiry_data(base_data: List[Dict]) -> List[Dict]:
    """
    Augment expiry dataset with variations.
    Add variations like "2 day old milk", "fresh chicken", etc.
    """
    augmented = []
    
    for item in base_data:
        # Add base item
        augmented.append(item)
        
        # Add variations
        food = item['food_item']
        days = item['days']
        
        # Add "fresh" variation (reduces expiry by 0 days)
        augmented.append({
            **item,
            'food_item': f"fresh {food}",
            'days': days
        })
        
        # Add "opened" variation (reduces expiry)
        if days > 3:
            augmented.append({
                **item,
                'food_item': f"opened {food}",
                'days': max(1, days // 2)
            })
    
    return augmented


def create_food_vocabulary(data: List[Dict], vocab_size: int = 15000) -> List[str]:
    """
    Create a food-specific vocabulary from training data.
    Useful for training tokenizer from scratch.
    """
    from collections import Counter
    
    word_counts = Counter()
    
    for item in data:
        # Extract text from different fields
        if 'food_item' in item:
            words = item['food_item'].lower().split()
            word_counts.update(words)
        
        if 'ingredients' in item:
            for ingredient in item['ingredients']:
                words = ingredient.lower().split()
                word_counts.update(words)
        
        if 'instructions' in item:
            for instruction in item['instructions']:
                words = instruction.lower().split()
                word_counts.update(words)
    
    # Get most common words
    vocab = [word for word, count in word_counts.most_common(vocab_size)]
    
    return vocab


def validate_dataset(data: List[Dict]) -> bool:
    """Validate dataset format"""
    required_fields = {
        'expiry': ['task', 'food_item', 'days'],
        'recipe': ['task', 'name', 'ingredients', 'instructions'],
        'classification': ['task', 'food_item', 'category'],
    }
    
    for item in data:
        task = item.get('task')
        if task not in required_fields:
            print(f"Unknown task type: {task}")
            return False
        
        for field in required_fields[task]:
            if field not in item:
                print(f"Missing field '{field}' in {task} task")
                return False
    
    return True


if __name__ == "__main__":
    # Test utilities
    print("Dataset utilities loaded successfully")


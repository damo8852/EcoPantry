"""
Training script for food-specific language model
"""
import os
import json
import torch
from torch.utils.data import Dataset, DataLoader
from transformers import (
    AutoTokenizer,
    AutoModelForCausalLM,
    Trainer,
    TrainingArguments,
    DataCollatorForLanguageModeling,
)
from datasets import load_dataset, Dataset as HFDataset
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from models.food_llm import FoodLMFineTuned


class FoodDataset(Dataset):
    """Custom dataset for food-related training examples"""
    
    def __init__(self, data_file: str, tokenizer, max_length: int = 512):
        """
        Args:
            data_file: Path to JSONL file with training examples
            tokenizer: HuggingFace tokenizer
            max_length: Maximum sequence length
        """
        self.tokenizer = tokenizer
        self.max_length = max_length
        self.examples = []
        
        # Load data from JSONL file
        with open(data_file, 'r', encoding='utf-8') as f:
            for line in f:
                example = json.loads(line)
                self.examples.append(example)
    
    def __len__(self):
        return len(self.examples)
    
    def __getitem__(self, idx):
        example = self.examples[idx]
        
        # Format depends on task type
        if example['task'] == 'expiry':
            text = self._format_expiry_example(example)
        elif example['task'] == 'recipe':
            text = self._format_recipe_example(example)
        elif example['task'] == 'classification':
            text = self._format_classification_example(example)
        else:
            text = example.get('text', '')
        
        # Tokenize
        encodings = self.tokenizer(
            text,
            truncation=True,
            max_length=self.max_length,
            padding='max_length',
            return_tensors='pt',
        )
        
        return {
            'input_ids': encodings['input_ids'].squeeze(),
            'attention_mask': encodings['attention_mask'].squeeze(),
            'labels': encodings['input_ids'].squeeze(),
        }
    
    def _format_expiry_example(self, example):
        """Format expiry prediction example"""
        return f"""Predict days until expiry: {example['food_item']} -> {example['days']}"""
    
    def _format_recipe_example(self, example):
        """Format recipe generation example"""
        ingredients = ', '.join(example['ingredients'])
        return f"""Recipe using {ingredients}:
Name: {example['name']}
Ingredients: {'; '.join(example['detailed_ingredients'])}
Instructions: {'; '.join(example['instructions'])}"""
    
    def _format_classification_example(self, example):
        """Format food classification example"""
        return f"""Classify food type: {example['food_item']} -> {example['category']}"""


def create_training_config(
    output_dir: str = './output',
    num_epochs: int = 3,
    batch_size: int = 8,
    learning_rate: float = 5e-5,
) -> TrainingArguments:
    """Create training configuration"""
    
    return TrainingArguments(
        output_dir=output_dir,
        num_train_epochs=num_epochs,
        per_device_train_batch_size=batch_size,
        per_device_eval_batch_size=batch_size,
        learning_rate=learning_rate,
        weight_decay=0.01,
        logging_dir=f'{output_dir}/logs',
        logging_steps=100,
        save_steps=500,
        eval_steps=500,
        save_total_limit=3,
        fp16=torch.cuda.is_available(),  # Use mixed precision if GPU available
        gradient_accumulation_steps=2,
        warmup_steps=500,
        report_to=['tensorboard'],
        load_best_model_at_end=True,
    )


def train_model(
    model_name: str = 'distilgpt2',
    train_file: str = '../data/train.jsonl',
    eval_file: str = '../data/eval.jsonl',
    output_dir: str = './food_model',
):
    """
    Main training function
    
    Args:
        model_name: Base model to fine-tune
        train_file: Path to training data
        eval_file: Path to evaluation data
        output_dir: Where to save the fine-tuned model
    """
    
    print(f"Loading model: {model_name}")
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForCausalLM.from_pretrained(model_name)
    
    # Add padding token if needed
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
        model.config.pad_token_id = tokenizer.pad_token_id
    
    print("Loading datasets...")
    train_dataset = FoodDataset(train_file, tokenizer)
    eval_dataset = FoodDataset(eval_file, tokenizer)
    
    print(f"Training examples: {len(train_dataset)}")
    print(f"Evaluation examples: {len(eval_dataset)}")
    
    # Create data collator
    data_collator = DataCollatorForLanguageModeling(
        tokenizer=tokenizer,
        mlm=False,  # We're doing causal LM, not masked LM
    )
    
    # Training configuration
    training_args = create_training_config(output_dir=output_dir)
    
    # Create trainer
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=eval_dataset,
        data_collator=data_collator,
    )
    
    print("Starting training...")
    trainer.train()
    
    print(f"Saving model to {output_dir}")
    trainer.save_model(output_dir)
    tokenizer.save_pretrained(output_dir)
    
    print("Training complete!")
    
    return trainer


def evaluate_model(model_path: str, test_examples: list):
    """
    Evaluate the trained model on test examples
    
    Args:
        model_path: Path to the saved model
        test_examples: List of test cases
    """
    print(f"Loading model from {model_path}")
    
    # Load trained model
    food_lm = FoodLMFineTuned('distilgpt2')
    food_lm.load_model(model_path)
    
    print("\nEvaluating model...")
    
    for example in test_examples:
        food_item = example['food_item']
        expected = example.get('expected_days')
        
        prediction = food_lm.predict_expiry(food_item)
        
        print(f"\nFood: {food_item}")
        print(f"Expected: {expected} days")
        print(f"Predicted: {prediction}")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Train food-specific LLM")
    parser.add_argument('--model', type=str, default='distilgpt2',
                       help='Base model to fine-tune')
    parser.add_argument('--train-file', type=str, default='../data/train.jsonl',
                       help='Training data file')
    parser.add_argument('--eval-file', type=str, default='../data/eval.jsonl',
                       help='Evaluation data file')
    parser.add_argument('--output-dir', type=str, default='./food_model',
                       help='Output directory for trained model')
    parser.add_argument('--epochs', type=int, default=3,
                       help='Number of training epochs')
    parser.add_argument('--batch-size', type=int, default=8,
                       help='Batch size')
    
    args = parser.parse_args()
    
    # Check if data files exist
    if not os.path.exists(args.train_file):
        print(f"Error: Training file not found: {args.train_file}")
        print("Please create training data first using data/prepare_datasets.py")
        sys.exit(1)
    
    # Train model
    train_model(
        model_name=args.model,
        train_file=args.train_file,
        eval_file=args.eval_file,
        output_dir=args.output_dir,
    )


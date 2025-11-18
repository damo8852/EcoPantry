"""
Food-specific Language Model Architecture
"""
import torch
import torch.nn as nn
from typing import List
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    GPT2LMHeadModel,
    GPT2Config,
)


class SmallFoodLM(nn.Module):
    """
    Small transformer model built from scratch for food tasks.
    Based on GPT-2 architecture but smaller.
    """
    
    def __init__(
        self,
        vocab_size: int = 15000,
        max_seq_len: int = 512,
        d_model: int = 512,
        n_layers: int = 4,
        n_heads: int = 8,
        d_ff: int = 2048,
        dropout: float = 0.1,
    ):
        super().__init__()
        
        config = GPT2Config(
            vocab_size=vocab_size,
            n_positions=max_seq_len,
            n_embd=d_model,
            n_layer=n_layers,
            n_head=n_heads,
            n_inner=d_ff,
            resid_pdrop=dropout,
            embd_pdrop=dropout,
            attn_pdrop=dropout,
        )
        
        self.model = GPT2LMHeadModel(config)
        
    def forward(self, input_ids, attention_mask=None, labels=None):
        return self.model(
            input_ids=input_ids,
            attention_mask=attention_mask,
            labels=labels,
        )
    
    def generate(self, input_ids, max_length=50, **kwargs):
        return self.model.generate(
            input_ids=input_ids,
            max_length=max_length,
            **kwargs
        )
    
    def get_model_size(self):
        """Calculate model size in MB"""
        param_size = sum(p.numel() * p.element_size() for p in self.parameters())
        buffer_size = sum(b.numel() * b.element_size() for b in self.buffers())
        size_mb = (param_size + buffer_size) / (1024 ** 2)
        return size_mb


class FoodLMFineTuned:
    """
    Wrapper for fine-tuning existing small models.
    Recommended approach for faster development.
    """
    
    SUPPORTED_MODELS = {
        'distilgpt2': 'distilgpt2',  # ~82M params, ~320MB
        'gpt2': 'gpt2',  # ~124M params, ~500MB
        'tinyllama': 'TinyLlama/TinyLlama-1.1B-Chat-v1.0',  # ~1.1B params, ~2GB
        'phi-2': 'microsoft/phi-2',  # ~2.7B params, ~5GB
    }
    
    def __init__(self, model_name: str = 'distilgpt2', device: str = 'cuda'):
        """
        Initialize with a pre-trained model.
        
        Args:
            model_name: One of the supported model names
            device: 'cuda' or 'cpu'
        """
        self.device = device if torch.cuda.is_available() else 'cpu'
        self.model_name = model_name
        
        model_path = self.SUPPORTED_MODELS.get(model_name, model_name)
        
        print(f"Loading {model_path}...")
        self.tokenizer = AutoTokenizer.from_pretrained(model_path)
        self.model = AutoModelForCausalLM.from_pretrained(
            model_path,
            torch_dtype=torch.float16 if self.device == 'cuda' else torch.float32,
        ).to(self.device)
        
        # Add padding token if not present
        if self.tokenizer.pad_token is None:
            self.tokenizer.pad_token = self.tokenizer.eos_token
        
        print(f"Model loaded on {self.device}")
        print(f"Model size: {self._get_model_size():.2f} MB")
    
    def _get_model_size(self):
        """Calculate model size in MB"""
        param_size = sum(p.numel() * p.element_size() for p in self.model.parameters())
        buffer_size = sum(b.numel() * b.element_size() for b in self.model.buffers())
        return (param_size + buffer_size) / (1024 ** 2)
    
    def predict_expiry(self, food_item: str, temperature: float = 0.1) -> str:
        """
        Predict expiry days for a food item.
        
        Args:
            food_item: Name of the food item
            temperature: Sampling temperature (lower = more deterministic)
            
        Returns:
            Predicted expiry in days as string
        """
        prompt = f"""Predict days until expiry for refrigerated food. Respond with ONLY a number.

Examples:
milk -> 7
chicken -> 3
strawberries -> 4
rice -> 730

{food_item} ->"""
        
        inputs = self.tokenizer(prompt, return_tensors='pt').to(self.device)
        
        with torch.no_grad():
            outputs = self.model.generate(
                **inputs,
                max_new_tokens=10,
                temperature=temperature,
                do_sample=True,
                pad_token_id=self.tokenizer.pad_token_id,
            )
        
        response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
        # Extract just the generated part
        response = response[len(prompt):].strip()
        
        return response
    
    def generate_recipe(self, ingredients: List[str], max_tokens: int = 500) -> str:
        """
        Generate a recipe from ingredients.
        
        Args:
            ingredients: List of available ingredients
            max_tokens: Maximum length of generation
            
        Returns:
            Generated recipe as string
        """
        ingredients_str = ', '.join(ingredients[:4])  # Limit to 4 ingredients
        
        prompt = f"""Create a recipe using: {ingredients_str}

Recipe:
Name:"""
        
        inputs = self.tokenizer(prompt, return_tensors='pt').to(self.device)
        
        with torch.no_grad():
            outputs = self.model.generate(
                **inputs,
                max_new_tokens=max_tokens,
                temperature=0.7,
                do_sample=True,
                pad_token_id=self.tokenizer.pad_token_id,
            )
        
        response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
        
        return response
    
    def save_model(self, path: str):
        """Save fine-tuned model"""
        self.model.save_pretrained(path)
        self.tokenizer.save_pretrained(path)
        print(f"Model saved to {path}")
    
    def load_model(self, path: str):
        """Load fine-tuned model"""
        self.model = AutoModelForCausalLM.from_pretrained(path).to(self.device)
        self.tokenizer = AutoTokenizer.from_pretrained(path)
        print(f"Model loaded from {path}")


if __name__ == "__main__":
    # Quick test
    print("Testing SmallFoodLM (from scratch)...")
    small_model = SmallFoodLM(vocab_size=15000)
    print(f"Model size: {small_model.get_model_size():.2f} MB")
    print(f"Parameters: {sum(p.numel() for p in small_model.parameters()):,}")
    
    print("\n" + "="*50)
    print("\nTesting FoodLMFineTuned (recommended)...")
    print("Note: This will download the model if not cached")
    
    # Uncomment to test (requires internet connection)
    # finetuned = FoodLMFineTuned('distilgpt2')
    # result = finetuned.predict_expiry('milk')
    # print(f"Expiry prediction for milk: {result}")


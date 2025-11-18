# Quick Start Guide

## Setup (5 minutes)

### 1. Install Python Dependencies
```bash
cd llm
pip install -r requirements.txt
```

### 2. Prepare Training Data
```bash
python data/prepare_datasets.py
```

This creates:
- `data/train.jsonl` - Training examples (~90 examples)
- `data/eval.jsonl` - Evaluation examples (~10 examples)

### 3. Test Base Model (Optional)
```python
python -c "
from models.food_llm import FoodLMFineTuned
model = FoodLMFineTuned('distilgpt2')
print(model.predict_expiry('milk'))
"
```

## Training (30 minutes - 2 hours)

### Option A: Quick test (smaller model, fewer epochs)
```bash
cd training
python train.py --model distilgpt2 --epochs 1 --batch-size 4
```

### Option B: Full training (better results)
```bash
cd training
python train.py --model distilgpt2 --epochs 5 --batch-size 8
```

Training will create:
- `training/food_model/` - Fine-tuned model checkpoint
- `training/output/logs/` - TensorBoard logs

Monitor training:
```bash
tensorboard --logdir training/output/logs
```

## Inference API (2 minutes)

### Start the API server
```bash
cd inference
python api.py
```

Or specify custom model path:
```bash
MODEL_PATH=../training/food_model python api.py
```

### Test the API
```bash
# Health check
curl http://localhost:8000/

# Predict expiry
curl -X POST http://localhost:8000/predict/expiry \
  -H "Content-Type: application/json" \
  -d '{"food_item": "milk"}'

# Generate recipe
curl -X POST http://localhost:8000/predict/recipe \
  -H "Content-Type: application/json" \
  -d '{"ingredients": ["chicken", "rice"]}'
```

Interactive API docs: http://localhost:8000/docs

## Integration with Flutter

### Update your Flutter app to call the local API:

```dart
// In lib/services/llm_service.dart

class LLMService {
  static const String _localApiUrl = 'http://localhost:8000';
  
  Future<int?> predictExpiryDays(String itemName) async {
    try {
      final response = await http.post(
        Uri.parse('$_localApiUrl/predict/expiry'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'food_item': itemName}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['predicted_days'];
      }
    } catch (e) {
      print('Local LLM error: $e');
    }
    return null;
  }
}
```

## Next Steps

### Improve the model:
1. **Add more training data** - Collect real user data from your app
2. **Expand recipes** - Add more recipe examples to `data/prepare_datasets.py`
3. **Fine-tune longer** - Train for more epochs
4. **Try different base models** - Experiment with 'gpt2' or 'TinyLlama'

### Deploy to production:
1. **Docker** - Containerize the API
2. **Cloud hosting** - Deploy to Railway, Render, or AWS
3. **Firebase Functions** - Add to your existing functions
4. **Optimize** - Quantize model for faster inference

### Advanced:
1. **Collect user feedback** - Log predictions and corrections
2. **Continuous training** - Retrain with new data regularly
3. **A/B testing** - Compare your model vs OpenAI
4. **Edge deployment** - Convert to TensorFlow Lite for on-device inference

## Troubleshooting

### Out of memory during training?
- Reduce batch size: `--batch-size 2`
- Use smaller model: `--model distilgpt2`
- Enable gradient checkpointing (modify train.py)

### Poor predictions?
- Train for more epochs: `--epochs 10`
- Add more training examples
- Adjust temperature in predictions (lower = more deterministic)

### API not starting?
- Check port 8000 is available
- Verify model path exists
- Check Python dependencies installed

## Cost Comparison

### Current (OpenAI):
- ~$0.15 per 1000 API calls (gpt-4o-mini)
- Requires internet connection
- API key management

### Your LLM:
- Free after training (one-time compute cost)
- Works offline
- Full control and privacy
- Initial training: ~$1-5 on cloud GPU (or free locally)

For 10,000 users making 10 predictions each:
- OpenAI: ~$15/month
- Your model: ~$5-10/month hosting


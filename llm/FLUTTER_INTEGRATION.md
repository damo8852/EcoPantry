# Flutter Integration Guide

## Overview

This guide explains how to integrate your custom Food LLM with your Flutter app.

## Architecture Options

### Option 1: Local API (Development)
Run the Python API locally and connect Flutter app to `localhost:8000`

**Pros:**
- Free
- Fast iteration
- Full control

**Cons:**
- Requires Python server running
- Only works on same machine/network

### Option 2: Cloud Deployment (Production)
Deploy API to cloud service (Railway, Render, Google Cloud Run, etc.)

**Pros:**
- Works from anywhere
- Scalable
- Professional deployment

**Cons:**
- Small hosting cost (~$5-10/month)
- Requires deployment setup

### Option 3: Firebase Functions
Add Python functions to your existing Firebase setup

**Pros:**
- Already integrated with your app
- Serverless (no server management)
- Pay per use

**Cons:**
- Cold start delays
- May have memory/timeout limits for larger models

## Step-by-Step Integration

### 1. Update Flutter Dependencies

No additional dependencies needed! Your app already has `http` package.

### 2. Update LLM Service (lib/services/llm_service.dart)

Add a toggle to use your custom LLM or fallback to OpenAI:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class LLMService {
  // Toggle between custom LLM and OpenAI
  static const bool USE_CUSTOM_LLM = true;
  
  // Your custom LLM API URL
  static const String _customLlmUrl = 'http://localhost:8000';  // Change for production
  
  // OpenAI configuration (fallback)
  static const String _openAiUrl = 'https://api.openai.com/v1';
  static const String _model = 'gpt-4o-mini';

  final ConfigService _configService = ConfigService();

  static final LLMService _instance = LLMService._internal();
  factory LLMService() => _instance;
  LLMService._internal();

  /// Predict expiry days using custom LLM or OpenAI
  Future<int?> predictExpiryDays(String itemName, {String? additionalContext}) async {
    if (USE_CUSTOM_LLM) {
      return await _predictExpiryCustomLLM(itemName);
    } else {
      return await _predictExpiryOpenAI(itemName, additionalContext);
    }
  }

  /// Predict using custom Food LLM
  Future<int?> _predictExpiryCustomLLM(String itemName) async {
    try {
      final response = await http.post(
        Uri.parse('$_customLlmUrl/predict/expiry'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'food_item': itemName}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['predicted_days'];
      } else if (response.statusCode == 503) {
        print('Custom LLM not available, falling back to OpenAI');
        return await _predictExpiryOpenAI(itemName, null);
      } else {
        print('Custom LLM error: ${response.statusCode}');
      }
    } catch (e) {
      print('Custom LLM connection error: $e');
      print('Falling back to OpenAI');
      return await _predictExpiryOpenAI(itemName, null);
    }

    return null;
  }

  /// Original OpenAI prediction (fallback)
  Future<int?> _predictExpiryOpenAI(String itemName, String? additionalContext) async {
    // Your existing OpenAI implementation
    final apiKey = await _configService.getOpenAiApiKey();
    if (apiKey == null) return null;
    
    try {
      final prompt = _buildPrompt(itemName, additionalContext);
      final response = await _callOpenAI(prompt);
      
      if (response != null) {
        return _parseExpiryDays(response);
      }
    } catch (e) {
      print('OpenAI prediction error: $e');
    }
    
    return null;
  }

  // Keep your existing OpenAI helper methods...
  // _buildPrompt, _callOpenAI, _parseExpiryDays, etc.
}
```

### 3. Add Settings Toggle (Optional)

Let users choose between custom LLM and OpenAI in settings:

```dart
// In lib/screens/settings.dart

// Add to your settings state
bool _useCustomLLM = true;

// Add to your settings UI
SwitchListTile(
  title: Text('Use Custom Food LLM'),
  subtitle: Text('Use our specialized food model (faster, free)'),
  value: _useCustomLLM,
  onChanged: (value) {
    setState(() {
      _useCustomLLM = value;
      // Save to SharedPreferences
    });
  },
),
```

### 4. Recipe Generation Integration

Update recipe generation to use custom LLM:

```dart
/// Generate recipes using custom LLM
Future<List<Map<String, dynamic>>> generateRecipesCustomLLM(
  List<String> ingredients,
) async {
  try {
    final response = await http.post(
      Uri.parse('$_customLlmUrl/predict/recipe'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'ingredients': ingredients,
        'max_tokens': 500,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Parse recipe_text and convert to your format
      return _parseRecipeText(data['recipe_text']);
    }
  } catch (e) {
    print('Custom LLM recipe error: $e');
  }

  return [];
}
```

## Testing Integration

### 1. Start Your Custom LLM API

```bash
cd llm
python inference/api.py
```

Verify it's running: http://localhost:8000/docs

### 2. Test from Flutter

Run your Flutter app and try:
- Adding a new food item (tests expiry prediction)
- Generating recipes

Check the console for logs showing which LLM is being used.

### 3. Test Fallback

Stop the Python API server and verify Flutter falls back to OpenAI gracefully.

## Production Deployment

### Option A: Deploy to Railway (Recommended)

1. Create account at https://railway.app
2. Create new project
3. Connect your GitHub repo
4. Set up build:
   ```
   Root directory: /llm
   Build command: pip install -r requirements.txt
   Start command: python inference/api.py
   ```
5. Deploy and get public URL (e.g., `https://your-app.railway.app`)
6. Update Flutter app with production URL

### Option B: Deploy to Google Cloud Run

1. Create `Dockerfile` in `llm/` directory:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV MODEL_PATH=/app/training/food_model
ENV PORT=8080

CMD exec uvicorn inference.api:app --host 0.0.0.0 --port $PORT
```

2. Deploy:
```bash
gcloud run deploy food-llm \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

3. Update Flutter app with Cloud Run URL

### Option C: Firebase Functions (Python)

Add to your `functions/main.py`:

```python
from firebase_functions import https_fn
import sys
sys.path.append('./llm')

from llm.models.food_llm import FoodLMFineTuned

# Global model instance
model = None

@https_fn.on_request()
def predict_expiry(req: https_fn.Request) -> https_fn.Response:
    global model
    
    # Lazy load model
    if model is None:
        model = FoodLMFineTuned('distilgpt2')
        # Load fine-tuned weights if available
    
    food_item = req.get_json().get('food_item')
    prediction = model.predict_expiry(food_item)
    
    return https_fn.Response(
        json.dumps({'predicted_days': int(prediction)}),
        mimetype='application/json'
    )
```

## Environment-Specific URLs

Use different API URLs for different environments:

```dart
class LLMService {
  static String get _customLlmUrl {
    // Check if running in debug/production
    const bool isProduction = bool.fromEnvironment('dart.vm.product');
    
    if (isProduction) {
      return 'https://your-production-api.com';
    } else {
      return 'http://localhost:8000';  // Local development
    }
  }
}
```

## Performance Optimization

### 1. Caching

Cache predictions to reduce API calls:

```dart
final Map<String, int> _expiryCache = {};

Future<int?> predictExpiryDays(String itemName) async {
  // Check cache first
  if (_expiryCache.containsKey(itemName.toLowerCase())) {
    return _expiryCache[itemName.toLowerCase()];
  }
  
  // Get prediction
  final days = await _predictExpiryCustomLLM(itemName);
  
  // Cache result
  if (days != null) {
    _expiryCache[itemName.toLowerCase()] = days;
  }
  
  return days;
}
```

### 2. Batch Predictions

If adding multiple items, batch the predictions:

```dart
Future<List<int?>> predictMultipleExpiry(List<String> items) async {
  // Send all items in one request
  // Implement batch endpoint in your API
}
```

### 3. Background Prediction

Predict expiry in background when app starts:

```dart
void preloadPredictions(List<String> commonFoods) async {
  for (final food in commonFoods) {
    await predictExpiryDays(food);  // Populates cache
  }
}
```

## Monitoring & Analytics

Track which LLM is being used:

```dart
void _logLLMUsage(String llmType, String task, bool success) {
  // Log to Firebase Analytics
  FirebaseAnalytics.instance.logEvent(
    name: 'llm_prediction',
    parameters: {
      'llm_type': llmType,  // 'custom' or 'openai'
      'task': task,          // 'expiry' or 'recipe'
      'success': success,
    },
  );
}
```

## Troubleshooting

### Custom LLM not responding
- Check if Python server is running
- Verify URL is correct
- Check network connectivity
- Look at server logs

### Predictions are poor
- Train the model longer (more epochs)
- Add more training data
- Fine-tune with your app's actual data

### Slow response times
- Use a smaller model (distilgpt2 instead of gpt2)
- Deploy closer to your users (multi-region)
- Implement caching
- Consider quantization (ONNX, TensorFlow Lite)

## Cost Comparison

### Current (OpenAI only):
- 10,000 predictions/month: ~$15
- 1,000 recipe generations: ~$20

### With Custom LLM:
- 10,000 predictions/month: Free (self-hosted) or ~$5 (cloud)
- 1,000 recipe generations: Free (self-hosted) or ~$5 (cloud)
- One-time training cost: ~$1-5

**Savings: ~70-100% cost reduction**


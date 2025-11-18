# Food-Specific Language Model

## Project Goal
Build a small, efficient language model specifically trained on food-related knowledge for:
- Predicting food expiry dates
- Understanding ingredient relationships
- Generating simple recipe suggestions
- Classifying food types and categories

## Architecture Approach

### Option 1: Fine-tune existing small model (Recommended for MVP)
- Start with a small pre-trained model (e.g., DistilGPT-2, TinyLlama, Phi-2)
- Fine-tune on food-specific dataset
- **Pros**: Faster development, better baseline performance
- **Model size**: 500MB - 2GB

### Option 2: Train from scratch (Pure learning experience)
- Build a small transformer (2-6 layers, 512-1024 hidden dim)
- Train on food corpus from scratch
- **Pros**: Full control, smallest possible size
- **Model size**: 50MB - 200MB
- **Cons**: Requires more data and training time

## Dataset Requirements

### Food Knowledge Sources:
1. **Recipe datasets** (AllRecipes, Recipe1M, Food.com)
2. **Food safety databases** (USDA, FDA food storage guidelines)
3. **Nutrition databases** (USDA FoodData Central)
4. **Cooking forums and wikis**
5. **Your own app data** (user-generated recipes, expiry patterns)

### Training Data Format:
- Expiry prediction examples
- Recipe generation examples  
- Food classification examples
- Q&A pairs about food storage

## Project Structure

```
llm/
├── data/              # Training datasets
├── models/            # Model architectures
├── training/          # Training scripts
├── inference/         # API for serving predictions
├── notebooks/         # Jupyter notebooks for experimentation
├── configs/           # Training configurations
└── utils/             # Helper functions
```

## Development Roadmap

### Phase 1: Data Collection (Week 1-2)
- [ ] Scrape/collect food-related text data
- [ ] Create expiry date training dataset
- [ ] Prepare recipe dataset
- [ ] Build data preprocessing pipeline

### Phase 2: Model Development (Week 2-4)
- [ ] Choose base architecture (fine-tune vs from scratch)
- [ ] Implement model architecture
- [ ] Set up training pipeline
- [ ] Create evaluation metrics

### Phase 3: Training (Week 4-6)
- [ ] Train on expiry prediction task
- [ ] Train on recipe generation task
- [ ] Evaluate and iterate
- [ ] Optimize model size

### Phase 4: Deployment (Week 6-8)
- [ ] Build inference API
- [ ] Optimize for mobile/edge deployment
- [ ] Integrate with Flutter app
- [ ] Performance testing

## Quick Start

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Prepare data:
```bash
python data/prepare_datasets.py
```

3. Train model:
```bash
python training/train.py --config configs/base_config.yaml
```

4. Start inference server:
```bash
python inference/api.py
```

## Target Specifications

- **Model Size**: < 200MB (ideally ~100MB)
- **Inference Time**: < 100ms per prediction
- **Context Window**: 512-1024 tokens
- **Vocab Size**: ~15,000 (food-focused vocabulary)

## Integration with Flutter App

The model will replace/augment the current OpenAI API calls in:
- `lib/services/llm_service.dart` (expiry prediction)
- `lib/services/recipes.dart` (recipe generation)
- `lib/services/parser.dart` (ingredient parsing)


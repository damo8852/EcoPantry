# OpenAI GPT-4o-mini Setup Guide

This project uses OpenAI's GPT-4o-mini model for food expiry predictions, grocery classification, and recipe generation.

## Why GPT-4o-mini?

**Benefits over Mistral:**
- **~80% cheaper** than Mistral Small ($0.15/M input tokens vs $0.80/M)
- **Significantly fewer hallucinations** - much more reliable
- **Better structured output support** with native JSON mode
- **Faster and more accurate** for classification tasks
- **Excellent instruction following** - provides consistent results

## Firebase Configuration

The OpenAI API key is stored in Firebase Firestore for security:

**Firestore Path:** `/config/openai`  
**Field Name:** `key`  
**Field Value:** Your OpenAI API key

### Setting up in Firebase Console

1. Go to Firebase Console → Firestore Database
2. Navigate to or create the collection: `config`
3. Create/edit a document with ID: `openai`
4. Add a field:
   - Field name: `key`
   - Field type: `string`
   - Field value: Your OpenAI API key (get it from https://platform.openai.com/api-keys)

## Model Configuration

- **Model**: `gpt-4o-mini`
- **Provider**: OpenAI
- **Base URL**: `https://api.openai.com/v1`
- **Cost**: $0.15/M input tokens, $0.60/M output tokens

## Features

The OpenAI integration provides:

1. **Food Expiry Prediction**: Predicts days until expiry for food items
2. **Grocery Type Classification**: Classifies items into categories (dairy, meat, vegetables, etc.)
3. **Recipe Generation**: Generates recipes based on available ingredients with guaranteed JSON output
4. **Receipt Parsing**: Extracts food items from OCR receipt text with intelligent parsing
5. **Food Name Simplification**: Expands abbreviations and cleans up food names (e.g., "chkn thgh" → "chicken thigh")
6. **Service Availability Check**: Verifies OpenAI service connectivity

## API Usage

The service automatically handles:
- Authentication with OpenAI API
- Request formatting for chat completions
- JSON mode for structured outputs (recipes and classifications)
- Response parsing and error handling
- Timeout management (15s for predictions, 30s for recipes)
- API key caching (30 minutes) to reduce Firestore reads

## Testing

To test the integration:

1. Ensure the API key is set in Firebase (path: `/config/openai`, field: `key`)
2. Run the app and use features that require LLM:
   - Food scanning and expiry prediction
   - Recipe generation
3. Check console logs for any API errors

## Migration from Mistral

The following changes were made:
- Replaced Mistral AI API with OpenAI API
- Changed model from `mistral-medium`/`mistral-small` to `gpt-4o-mini`
- Added JSON mode support for reliable structured outputs
- Updated recipe prompts to use JSON object format (required by OpenAI JSON mode)
- Added OpenAI API key fetching to `ConfigService`
- Updated all API calls and error handling

## Troubleshooting

**Common Issues:**

1. **API Key Invalid**: Verify the key is correct in Firebase Firestore
2. **Network Errors**: Check internet connectivity
3. **Model Unavailable**: Verify you have access to gpt-4o-mini
4. **Rate Limits**: OpenAI has rate limits based on your tier (see https://platform.openai.com/docs/guides/rate-limits)

**Debug Information:**
- Check console logs for detailed error messages
- Use `LLMService().isAvailable()` to test connectivity
- Monitor API response codes and error messages
- Check Firebase Console to verify the API key is correctly stored

## Security Notes

- **API keys are stored in Firebase Firestore** (path: `/config/openai`)
- **Keys are cached for 30 minutes** to reduce Firestore reads
- **Environment variables are not needed** - keys are fetched from Firebase at runtime
- **Firestore security rules should restrict access** to the config collection
- **Never commit API keys** to version control

## Files Modified

- `lib/services/config_service.dart` - Added `getOpenAiApiKey()` method
- `lib/services/llm_service.dart` - Migrated from Mistral to OpenAI (expiry prediction, recipes)
- `lib/services/parser.dart` - Migrated from Mistral to OpenAI (receipt parsing, food name simplification)
- `OPENAI_SETUP.md` - This file (updated from MISTRAL_SETUP.md)

## Cost Comparison

### Mistral Pricing:
- Mistral Small: $0.80/M input, $2.40/M output
- Mistral Medium: $2.70/M input, $8.10/M output

### OpenAI GPT-4o-mini Pricing:
- Input: $0.15/M tokens
- Output: $0.60/M tokens

**Savings**: ~80% cheaper than Mistral Small, ~95% cheaper than Mistral Medium!

## Additional Resources

- [OpenAI API Documentation](https://platform.openai.com/docs)
- [GPT-4o-mini Model Info](https://platform.openai.com/docs/models/gpt-4o-mini)
- [OpenAI Pricing](https://openai.com/api/pricing/)
- [Rate Limits](https://platform.openai.com/docs/guides/rate-limits)


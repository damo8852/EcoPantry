import '../services/llm_service.dart';
import 'dart:convert';

/// AI-powered ingredient parser using LLM for natural language understanding
class AIIngredientParser {
  static final _llmService = LLMService();
  
  /// Cache to avoid repeated API calls for the same ingredients
  static final Map<String, String> _cache = {};

  /// Parse a single ingredient using AI
  /// Returns the core food item name, capitalized
  static Future<String> parseIngredient(String ingredient) async {
    // Check cache first
    final cacheKey = ingredient.toLowerCase().trim();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final result = await _parseWithAI(ingredient);
      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      print('AI parsing failed: $e, falling back to rule-based');
      // Fallback to rule-based parser
      return _fallbackParse(ingredient);
    }
  }

  /// Parse multiple ingredients at once (more efficient)
  static Future<Map<String, String>> parseIngredientsBatch(List<String> ingredients) async {
    final uncachedIngredients = <String>[];
    final results = <String, String>{};

    // Check cache first
    for (final ingredient in ingredients) {
      final cacheKey = ingredient.toLowerCase().trim();
      if (_cache.containsKey(cacheKey)) {
        results[ingredient] = _cache[cacheKey]!;
      } else {
        uncachedIngredients.add(ingredient);
      }
    }

    // If all were cached, return immediately
    if (uncachedIngredients.isEmpty) {
      return results;
    }

    try {
      final batchResults = await _parseBatchWithAI(uncachedIngredients);
      
      // Add to cache and results
      for (final entry in batchResults.entries) {
        final cacheKey = entry.key.toLowerCase().trim();
        _cache[cacheKey] = entry.value;
        results[entry.key] = entry.value;
      }
      
      return results;
    } catch (e) {
      print('Batch AI parsing failed: $e');
      // Fallback for uncached items
      for (final ingredient in uncachedIngredients) {
        results[ingredient] = _fallbackParse(ingredient);
      }
      return results;
    }
  }

  /// Use AI to parse a single ingredient
  static Future<String> _parseWithAI(String ingredient) async {
    final prompt = '''Extract the core food item name from this ingredient description. 
Return ONLY the food item name, properly capitalized, with no quantities or descriptors.

Examples:
"2 white eggs" -> "Eggs"
"1 lb ground beef" -> "Beef"
"3 large carrots" -> "Carrots"
"1 cup of milk" -> "Milk"
"2 tbsp olive oil" -> "Olive oil"
"fresh organic spinach" -> "Spinach"

Ingredient: "$ingredient"
Core food item:''';

    final response = await _llmService.callLLM(
      prompt: prompt,
      maxTokens: 20, // Very short response needed
      temperature: 0.1, // Low temperature for consistency
    );

    if (response == null || response.isEmpty) {
      throw Exception('Empty AI response');
    }

    return response.trim();
  }

  /// Parse multiple ingredients in a single API call
  static Future<Map<String, String>> _parseBatchWithAI(List<String> ingredients) async {
    final ingredientList = ingredients.map((i) => '"$i"').join(', ');
    
    final prompt = '''Extract the core food item from each ingredient. Return a JSON object mapping each ingredient to its core food item name.

Rules:
- Remove quantities (numbers, fractions)
- Remove measurements (cups, tbsp, oz, etc.)
- Remove descriptors (fresh, organic, large, etc.)
- Keep compound nouns (e.g., "bell pepper", "soy sauce")
- Capitalize first letter

Input ingredients: [$ingredientList]

Return format:
{
  "ingredient1": "Core Item",
  "ingredient2": "Core Item"
}''';

    final response = await _llmService.callLLM(
      prompt: prompt,
      maxTokens: 200,
      temperature: 0.1,
      useJsonMode: true,
    );

    if (response == null || response.isEmpty) {
      throw Exception('Empty AI response');
    }

    // Parse JSON response
    final Map<String, dynamic> parsed = json.decode(response);
    return parsed.map((key, value) => MapEntry(key, value.toString()));
  }

  /// Fallback parser using simple rules
  static String _fallbackParse(String ingredient) {
    String cleaned = ingredient.trim().toLowerCase();
    
    // Remove numbers and common measurements
    cleaned = cleaned.replaceAll(RegExp(r'^\d+[\./]?\d*\s*'), '');
    cleaned = cleaned.replaceAll(
      RegExp(r'(cups?|tbsp?|tsp?|oz|lbs?|g|kg|ml|l)\s+(of\s+)?', caseSensitive: false),
      ''
    );
    
    // Remove common adjectives at the start
    final adjectives = ['fresh', 'organic', 'large', 'medium', 'small', 'white', 'ground', 'chopped'];
    for (final adj in adjectives) {
      if (cleaned.startsWith('$adj ')) {
        cleaned = cleaned.substring(adj.length + 1);
      }
    }
    
    cleaned = cleaned.trim();
    return cleaned.isEmpty ? ingredient.trim() : _capitalize(cleaned);
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Clear the cache (useful for testing or memory management)
  static void clearCache() {
    _cache.clear();
  }
}


import '../services/llm_service.dart';
import 'dart:convert';

/// Hybrid ingredient parser combining rule-based and AI approaches
/// Uses fast rule-based parsing for common ingredients, falls back to AI for unusual ones
class HybridIngredientParser {
  static final _llmService = LLMService();
  
  /// Cache for AI-parsed ingredients to minimize API calls
  static final Map<String, String> _aiCache = {};

  /// Common food words that indicate we found a valid ingredient
  static const Set<String> _coreFoodWords = {
    'eggs', 'egg', 'milk', 'cheese', 'butter', 'bread', 'rice', 'pasta', 'noodles',
    'chicken', 'beef', 'pork', 'fish', 'salmon', 'tuna', 'shrimp', 'crab', 'lobster',
    'onion', 'onions', 'garlic', 'tomato', 'tomatoes', 'potato', 'potatoes', 'carrot',
    'carrots', 'broccoli', 'spinach', 'lettuce', 'cabbage', 'apple', 'apples', 'banana',
    'bananas', 'orange', 'oranges', 'lemon', 'lemons', 'lime', 'limes', 'pepper', 'peppers',
    'salt', 'sugar', 'flour', 'oil', 'vinegar', 'soy', 'sauce', 'herbs', 'spices',
    'meat', 'vegetables', 'fruits', 'nuts', 'almonds', 'walnuts', 'peanuts', 'seeds',
    'beans', 'peas', 'corn', 'celery', 'cucumber', 'zucchini', 'squash', 'mushroom',
    'mushrooms', 'avocado', 'avocados', 'berry', 'berries', 'strawberry', 'strawberries',
    'blueberry', 'blueberries', 'raspberry', 'raspberries', 'wine', 'stock', 'broth'
  };

  /// Descriptors that should be removed from ingredient names
  static const Set<String> _descriptors = {
    'white', 'brown', 'black', 'red', 'green', 'blue', 'yellow', 'orange', 'purple',
    'organic', 'fresh', 'frozen', 'canned', 'dried', 'raw', 'cooked', 'boiled',
    'grilled', 'roasted', 'sliced', 'diced', 'chopped', 'minced', 'whole', 'half',
    'large', 'medium', 'small', 'extra', 'boneless', 'skinless', 'lean', 'fat-free',
    'low-fat', 'whole-grain', 'whole-wheat', 'enriched', 'unsalted', 'salted',
    'sweet', 'sour', 'bitter', 'mild', 'sharp', 'aged', 'young', 'ripe', 'unripe',
    'ground', 'shredded', 'grated', 'crushed', 'peeled', 'baby'
  };

  /// Compound nouns that should be kept together
  static const Set<String> _compoundNouns = {
    'bell pepper', 'bell peppers', 'sweet potato', 'sweet potatoes',
    'soy sauce', 'olive oil', 'coconut milk', 'peanut butter', 'almond butter',
    'cream cheese', 'cheddar cheese', 'mozzarella cheese', 'parmesan cheese',
    'ground beef', 'ground pork', 'ground chicken', 'ground turkey',
    'chicken breast', 'chicken breasts', 'chicken thigh', 'chicken thighs',
    'pork chop', 'pork chops', 'green beans', 'black beans', 'kidney beans',
    'cherry tomatoes', 'grape tomatoes', 'roma tomatoes', 'beef broth',
    'chicken broth', 'vegetable broth', 'chicken stock', 'beef stock'
  };

  /// Parse ingredient using hybrid approach
  /// Returns capitalized core food item name
  static Future<String> parseIngredient(String ingredient) async {
    // Step 1: Try rule-based parsing
    final ruleBased = _parseWithRules(ingredient);
    
    // Step 2: Check if we got a valid core food item
    if (_isValidCoreFood(ruleBased)) {
      print('✓ Rule-based: "$ingredient" -> "$ruleBased"');
      return _capitalize(ruleBased);
    }
    
    // Step 3: Fall back to AI for unusual ingredients
    print('⚡ Using AI for unusual ingredient: "$ingredient"');
    final aiResult = await _parseWithAI(ingredient);
    return _capitalize(aiResult);
  }

  /// Parse using rule-based approach
  static String _parseWithRules(String ingredient) {
    String cleaned = ingredient.trim().toLowerCase();
    
    // Remove quantities and measurements
    cleaned = _removeQuantitiesAndMeasurements(cleaned);
    
    // Check for compound nouns first (higher priority)
    for (final compound in _compoundNouns) {
      if (cleaned.contains(compound)) {
        return compound;
      }
    }
    
    // Extract main noun
    cleaned = _extractMainNoun(cleaned);
    
    return cleaned.trim();
  }

  /// Check if the parsed result contains a valid core food word
  static bool _isValidCoreFood(String text) {
    final words = text.toLowerCase().split(' ');
    
    // Check if any word is a core food item
    for (final word in words) {
      if (_coreFoodWords.contains(word)) {
        return true;
      }
    }
    
    // Check if the full phrase is a known compound
    if (_compoundNouns.contains(text.toLowerCase())) {
      return true;
    }
    
    return false;
  }

  /// Remove quantities and measurements
  static String _removeQuantitiesAndMeasurements(String text) {
    String cleaned = text;
    
    // Remove leading numbers (including fractions and decimals)
    cleaned = cleaned.replaceAll(RegExp(r'^\d+[\./\-]?\d*\s*'), '');
    
    // Remove measurement units
    final measurements = [
      r'cups?', r'tbsps?', r'tablespoons?', r'tsps?', r'teaspoons?',
      r'ozs?', r'ounces?', r'lbs?', r'pounds?', r'g', r'grams?',
      r'kgs?', r'kilograms?', r'ml', r'milliliters?', r'l', r'liters?',
      r'cloves?', r'pieces?', r'slices?', r'cans?', r'jars?', r'packages?',
      r'containers?', r'bunches?', r'heads?', r'stalks?', r'strips?'
    ].join('|');
    
    cleaned = cleaned.replaceAll(
      RegExp(r'^\d*[\./\-]?\d*\s*(' + measurements + r')\s+(of\s+)?', caseSensitive: false),
      ''
    );
    
    // Remove "a" or "an" at the beginning
    cleaned = cleaned.replaceAll(RegExp(r'^(a|an)\s+'), '');
    
    return cleaned.trim();
  }

  /// Extract main noun by removing descriptors
  static String _extractMainNoun(String text) {
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return text;
    if (words.length == 1) return words[0];
    
    // Remove descriptors from the beginning
    final filteredWords = <String>[];
    bool foundNoun = false;
    
    for (int i = words.length - 1; i >= 0; i--) {
      final word = words[i];
      
      // Keep words that are not descriptors, or keep everything after we found a core food
      if (!_descriptors.contains(word) || _coreFoodWords.contains(word)) {
        foundNoun = true;
        filteredWords.insert(0, word);
      } else if (foundNoun) {
        // Stop once we hit descriptors after finding the noun
        break;
      }
    }
    
    if (filteredWords.isEmpty) {
      // If everything was filtered, return last 2 words (likely a compound)
      return words.length >= 2 
          ? '${words[words.length - 2]} ${words.last}'
          : words.last;
    }
    
    return filteredWords.join(' ');
  }

  /// Parse with AI (for unusual ingredients)
  static Future<String> _parseWithAI(String ingredient) async {
    // Check cache first
    final cacheKey = ingredient.toLowerCase().trim();
    if (_aiCache.containsKey(cacheKey)) {
      return _aiCache[cacheKey]!;
    }

    try {
      final prompt = '''Extract the core food item from this ingredient. Return ONLY the food name, properly capitalized.

Examples:
"2 white eggs" -> "Eggs"
"1 lb ground beef" -> "Beef"
"fresh organic kale" -> "Kale"
"2 tbsp extra virgin olive oil" -> "Olive oil"

Ingredient: "$ingredient"
Core food item:''';

      final response = await _llmService.callLLM(
        prompt: prompt,
        maxTokens: 20,
        temperature: 0.1,
      );

      if (response != null && response.isNotEmpty) {
        final cleaned = response.trim();
        _aiCache[cacheKey] = cleaned;
        return cleaned;
      }
    } catch (e) {
      print('AI parsing error: $e');
    }

    // Final fallback: return best guess from rule-based
    final fallback = _parseWithRules(ingredient);
    return fallback.isNotEmpty ? fallback : ingredient.trim();
  }

  /// Capitalize first letter of each word in compound nouns, or just first letter
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    
    // For multi-word items (compounds), capitalize each word
    if (text.contains(' ')) {
      return text.split(' ')
          .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
          .join(' ');
    }
    
    // Single word: capitalize first letter only
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Batch parse multiple ingredients (more efficient)
  static Future<Map<String, String>> parseIngredientsBatch(List<String> ingredients) async {
    final results = <String, String>{};
    final needsAI = <String>[];
    
    // First pass: try rule-based for all
    for (final ingredient in ingredients) {
      final ruleBased = _parseWithRules(ingredient);
      
      if (_isValidCoreFood(ruleBased)) {
        results[ingredient] = _capitalize(ruleBased);
      } else {
        needsAI.add(ingredient);
      }
    }
    
    // Second pass: batch AI for unusual ingredients
    if (needsAI.isNotEmpty) {
      print('⚡ Using AI for ${needsAI.length} unusual ingredients');
      
      try {
        final aiResults = await _batchParseWithAI(needsAI);
        results.addAll(aiResults);
      } catch (e) {
        print('Batch AI parsing error: $e');
        // Fallback: use rule-based results for failed items
        for (final ingredient in needsAI) {
          final fallback = _parseWithRules(ingredient);
          results[ingredient] = _capitalize(fallback.isNotEmpty ? fallback : ingredient.trim());
        }
      }
    }
    
    return results;
  }

  /// Batch parse with AI (single API call for multiple ingredients)
  static Future<Map<String, String>> _batchParseWithAI(List<String> ingredients) async {
    final ingredientList = ingredients.map((i) => '"$i"').join(', ');
    
    final prompt = '''Extract core food items from these ingredients. Return JSON mapping each to its core item.

Rules: Remove quantities, measurements, and descriptors. Keep compound nouns. Capitalize properly.

Ingredients: [$ingredientList]

Format:
{
  "ingredient1": "Core Item",
  "ingredient2": "Core Item"
}''';

    final response = await _llmService.callLLM(
      prompt: prompt,
      maxTokens: 300,
      temperature: 0.1,
      useJsonMode: true,
    );

    if (response == null || response.isEmpty) {
      throw Exception('Empty AI response');
    }

    final Map<String, dynamic> parsed = json.decode(response);
    final results = parsed.map((key, value) => MapEntry(key, value.toString()));
    
    // Cache all results
    for (final entry in results.entries) {
      _aiCache[entry.key.toLowerCase().trim()] = entry.value;
    }
    
    return results;
  }

  /// Clear AI cache (useful for testing or memory management)
  static void clearCache() {
    _aiCache.clear();
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cachedItems': _aiCache.length,
      'coreWords': _coreFoodWords.length,
      'compounds': _compoundNouns.length,
    };
  }
}


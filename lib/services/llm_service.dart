import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class LLMService {
  // OpenAI API configuration
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _model = 'gpt-4o-mini'; // Fast, cost-effective, and accurate model

  final ConfigService _configService = ConfigService();

  static final LLMService _instance = LLMService._internal();
  factory LLMService() => _instance;
  LLMService._internal();

  /// Get the OpenAI API key
  Future<String?> _getApiKey() async {
    return await _configService.getOpenAiApiKey();
  }

  /// Predict expiry date in days for a given food item
  /// Returns number of days until expiry, or null if prediction fails
  Future<int?> predictExpiryDays(String itemName, {String? additionalContext}) async {
    try {
      final prompt = _buildPrompt(itemName, additionalContext);
      final response = await _callOpenAI(prompt);

      if (response != null) {
        final days = _parseExpiryDays(response);
        return days;
      }
    } catch (e) {
      print('LLM prediction error: $e');
    }

    return null;
  }

  /// Predict expiry date and grocery type for a given food item
  /// Returns a map with 'days' and 'type' keys, or null if prediction fails
  Future<Map<String, dynamic>?> predictExpiryAndType(String itemName, {String? additionalContext}) async {
    try {
      final prompt = _buildPromptWithType(itemName, additionalContext);
      final response = await _callOpenAI(prompt, useJsonMode: true);

      if (response != null) {
        final result = _parseExpiryAndType(response);
        return result;
      }
    } catch (e) {
      print('LLM prediction error: $e');
    }

    return null;
  }

  String _buildPrompt(String itemName, String? additionalContext) {
    final context = additionalContext != null ? ' Additional context: $additionalContext' : '';

    return '''Predict days until expiry for refrigerated food. Respond with ONLY a number.

Examples:
milk -> 7
chicken -> 3
strawberries -> 4
rice -> 730
salt -> 3650

$itemName$context ->''';
  }

  String _buildPromptWithType(String itemName, String? additionalContext) {
    final context = additionalContext != null ? ' Additional context: $additionalContext' : '';

    return '''Predict expiry days and grocery type. Respond with ONLY JSON.

Types: meat, poultry, seafood, vegetable, fruit, dairy, grain, beverage, snack, condiment, frozen, other

Examples:
milk -> {"days": 7, "type": "dairy"}
chicken -> {"days": 3, "type": "poultry"}
strawberries -> {"days": 4, "type": "fruit"}
rice -> {"days": 730, "type": "grain"}
salt -> {"days": 3650, "type": "condiment"}

$itemName$context ->''';
  }

  Future<String?> _callOpenAI(String prompt, {bool useJsonMode = false}) async {
    final apiKey = await _getApiKey();
    if (apiKey == null) {
      print('No OpenAI API key found');
      return null;
    }

    try {
      final requestBody = {
        'model': _model,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.01, // Low temperature for consistent results
        'max_tokens': 60, // Limit response length for expiry predictions
      };

      // Enable JSON mode if requested (guarantees valid JSON output)
      if (useJsonMode) {
        requestBody['response_format'] = {'type': 'json_object'};
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['choices']?[0]?['message']?['content']?.toString().trim();
        return result;
      } else {
        print('OpenAI API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('HTTP request error: $e');
    }

    return null;
  }

  int? _parseExpiryDays(String response) {
    // Clean the response and extract first number
    final cleanResponse = response.trim().toLowerCase();

    // Look for patterns like "7", "7 days", "7-10", etc.
    final patterns = [
      RegExp(r'^(\d{1,4})$'), // Just a number
      RegExp(r'(\d{1,4})\s*days?'), // "7 days" or "7 day"
      RegExp(r'(\d{1,4})[-–]\d+'), // "7-10" or "7–10"
      RegExp(r'\b(\d{1,4})\b'), // Any number in the text
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleanResponse);
      if (match != null) {
        final days = int.tryParse(match.group(1)!);
        if (days != null && days > 0 && days <= 3650) {
          return days;
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? _parseExpiryAndType(String response) {
    try {
      // Try to parse as JSON first
      final cleanResponse = response.trim();
      final data = json.decode(cleanResponse);
      if (data is Map<String, dynamic>) {
        final days = data['days'];
        final type = data['type'];

        if (days is int && type is String) {
          return {'days': days, 'type': type};
        }
      }
    } catch (e) {
      // If JSON parsing fails, try to extract numbers and guess type
      final days = _parseExpiryDays(response);
      if (days != null) {
        return {'days': days, 'type': 'other'};
      }
    }

    return null;
  }

  /// Check if OpenAI API is available
  Future<bool> isAvailable() async {
    final apiKey = await _getApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }

  /// Get list of available OpenAI models
  Future<List<String>> getAvailableModels() async {
    // Return the model we're configured to use
    return [_model];
  }

  /// Generate recipe suggestions based on available ingredients
  /// Returns a list of recipe objects with name, ingredients, and instructions
  Future<List<Map<String, dynamic>>> generateRecipes(
    List<String> ingredients, {
    int count = 2,
    List<String>? preferredCategories,
    bool prioritizeFilteredItems = false,
    List<String>? prioritizedItems,
    String? recipeMode,
    String? cuisineType,
    String? keyword,
    String? cookingTool,
  }) async {
    if (ingredients.isEmpty) {
      return [];
    }

    try {
      final prompt = _buildRecipePrompt(
        ingredients,
        count,
        preferredCategories,
        prioritizeFilteredItems,
        prioritizedItems,
        recipeMode,
        cuisineType,
        keyword,
        cookingTool,
      );
      final response = await _callOpenAIForRecipes(prompt);

      if (response != null) {
        final recipes = _parseRecipes(response);
        return recipes;
      }
    } catch (e) {
      print('Recipe generation error: $e');
    }

    return [];
  }

  String _buildRecipePrompt(
    List<String> ingredients,
    int count,
    List<String>? preferredCategories,
    bool prioritizeFilteredItems,
    List<String>? prioritizedItems,
    String? recipeMode,
    String? cuisineType,
    String? keyword,
    String? cookingTool,
  ) {
    // Handle empty fridge case
    if (ingredients.isEmpty) {
      return '''Empty fridge. Create $count recipes using pantry staples + minimal shopping (2-4 items max).

Pantry available: salt, pepper, oil, butter, garlic, onions, flour, sugar, vinegar, soy sauce, rice, pasta, canned tomatoes, canned beans

JSON format:
{
  "recipes": [{
    "name": "Recipe Name",
    "ingredients": ["ingredient with quantity"],
    "instructions": ["step by step"],
    "prepTime": "Xmin",
    "cookTime": "Xmin",
    "shoppingList": ["items to buy"]
  }]
}''';
    }

    // Limit to 4 main ingredients for simplicity
    final limitedIngredients = ingredients.take(4).toList();
    final ingredientsList = limitedIngredients.join(', ');

    // Build mode-specific instructions
    String modeInstruction = '';
    if (recipeMode != null && recipeMode.isNotEmpty && recipeMode != 'any') {
      switch (recipeMode) {
        case 'creative':
          modeInstruction = '\n\nSTYLE: Be creative and experimental! Try unique flavor combinations, modern techniques, and unexpected ingredient pairings. Think outside the box!';
          break;
        case 'traditional':
          modeInstruction = '\n\nSTYLE: Stick to traditional, classic recipes. Use time-tested cooking methods and familiar flavor combinations that everyone loves.';
          break;
        case 'fusion':
          modeInstruction = '\n\nSTYLE: Create fusion recipes that blend different culinary traditions. Mix ingredients and techniques from multiple cuisines for exciting new dishes.';
          break;
        case 'comfort':
          modeInstruction = '\n\nSTYLE: Focus on comfort food - hearty, warming, and satisfying dishes that feel like home. Think cozy and nostalgic.';
          break;
        case 'healthy':
          modeInstruction = '\n\nSTYLE: Prioritize healthy cooking methods and nutritious ingredients. Light, balanced, and wholesome recipes.';
          break;
        case 'quick':
          modeInstruction = '\n\nSTYLE: Keep it simple and fast! Recipes should be ready in 30 minutes or less with minimal prep work.';
          break;
      }
    }

    // Build cuisine-specific instructions
    String cuisineInstruction = '';
    if (cuisineType != null && cuisineType.isNotEmpty && cuisineType != 'any') {
      switch (cuisineType) {
        case 'asian':
          cuisineInstruction = '\n\nCUISINE: Asian-inspired recipes. Use Asian flavors like soy sauce, ginger, garlic, sesame oil, rice vinegar, and typical Asian cooking techniques.';
          break;
        case 'american':
          cuisineInstruction = '\n\nCUISINE: American-style recipes. Think burgers, sandwiches, BBQ, classic American comfort food.';
          break;
        case 'latin':
          cuisineInstruction = '\n\nCUISINE: Latin American recipes. Use Latin flavors like cumin, cilantro, lime, chili peppers, and typical Latin cooking styles.';
          break;
        case 'mediterranean':
          cuisineInstruction = '\n\nCUISINE: Mediterranean recipes. Use olive oil, tomatoes, herbs like basil and oregano, garlic, and Mediterranean cooking techniques.';
          break;
        case 'italian':
          cuisineInstruction = '\n\nCUISINE: Italian recipes. Focus on pasta, tomato sauces, Italian herbs, olive oil, and classic Italian cooking methods.';
          break;
        case 'french':
          cuisineInstruction = '\n\nCUISINE: French-inspired recipes. Use butter, cream, wine, herbs de Provence, and classic French techniques.';
          break;
        case 'indian':
          cuisineInstruction = '\n\nCUISINE: Indian recipes. Use spices like cumin, coriander, turmeric, garam masala, and traditional Indian cooking methods.';
          break;
        case 'mexican':
          cuisineInstruction = '\n\nCUISINE: Mexican recipes. Use ingredients like peppers, cilantro, lime, tortillas, and classic Mexican preparations.';
          break;
      }
    }

    // Focus on best tasting combinations with detailed instructions
    String categoryInstruction = '';
    if (preferredCategories != null && preferredCategories.isNotEmpty) {
      categoryInstruction = '\n\nIMPORTANT: Focus on recipes that primarily use ingredients from these categories: ${preferredCategories.join(', ')}.';
    }
    
    String priorityInstruction = '';
    if (prioritizeFilteredItems && preferredCategories != null && preferredCategories.isNotEmpty) {
      priorityInstruction = '\n\nPRIORITY: The user has filtered their fridge to show only ${preferredCategories.join(', ')} items. Prioritize recipes that use these filtered ingredients as the main components.';
    }
    
    String prioritizedItemsInstruction = '';
    if (prioritizedItems != null && prioritizedItems.isNotEmpty) {
      prioritizedItemsInstruction = '\n\nHIGH PRIORITY: The user has specifically marked these items as priority: ${prioritizedItems.join(', ')}. Make sure to include these items as main ingredients in your recipe suggestions.';
    }
    
    String keywordInstruction = '';
    if (keyword != null && keyword.trim().isNotEmpty) {
      keywordInstruction = '\n\nUSER REQUEST: The user wants to make "$keyword" or something similar. Try to create recipes that match this request using the available ingredients. Be creative if exact ingredients aren\'t available.';
    }
    
    String cookingToolInstruction = '';
    if (cookingTool != null && cookingTool.isNotEmpty && cookingTool != 'any') {
      switch (cookingTool) {
        case 'pan':
          cookingToolInstruction = '\n\nCOOKING TOOL: Recipes must be prepared using a pan or skillet. Focus on stir-fries, sautés, pan-fried dishes, and one-pan meals.';
          break;
        case 'rice_cooker':
          cookingToolInstruction = '\n\nCOOKING TOOL: Recipes must be prepared using a rice cooker. Focus on rice dishes, steamed meals, and one-pot rice cooker recipes.';
          break;
        case 'air_fryer':
          cookingToolInstruction = '\n\nCOOKING TOOL: Recipes must be prepared using an air fryer. Focus on crispy, roasted, or fried-style dishes that work well in an air fryer.';
          break;
        case 'slow_cooker':
          cookingToolInstruction = '\n\nCOOKING TOOL: Recipes must be prepared using a slow cooker. Focus on stews, braises, and dishes that benefit from long, slow cooking.';
          break;
        case 'instant_pot':
          cookingToolInstruction = '\n\nCOOKING TOOL: Recipes must be prepared using an Instant Pot or pressure cooker. Focus on quick-cooking pressure cooker recipes.';
          break;
        case 'oven':
          cookingToolInstruction = '\n\nCOOKING TOOL: Recipes must be prepared using an oven. Focus on baked, roasted, or broiled dishes.';
          break;
        case 'pot':
          cookingToolInstruction = '\n\nCOOKING TOOL: Recipes must be prepared using a pot. Focus on boiled, simmered, or soup-based dishes.';
          break;
      }
    }
    
    return '''Create $count recipes using: $ingredientsList$keywordInstruction$modeInstruction$cuisineInstruction$cookingToolInstruction$categoryInstruction$priorityInstruction$prioritizedItemsInstruction

Pantry staples available: salt, pepper, oil, butter, garlic, onions, flour, sugar, vinegar, soy sauce

JSON format:
{
  "recipes": [{
    "name": "Recipe Name",
    "ingredients": ["ingredient with quantity"],
    "instructions": ["step by step"],
    "prepTime": "Xmin",
    "cookTime": "Xmin",
    "shoppingList": ["items to buy"]
  }]
}

Rules:
- Use fridge items + pantry staples
- Focus on taste, not using everything
- 4-6 instruction steps
- Minimal shopping (1-3 items max)
- Simple, delicious recipes''';
  }

  Future<String?> _callOpenAIForRecipes(String prompt) async {
    final apiKey = await _getApiKey();
    if (apiKey == null) {
      print('No OpenAI API key found');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.2, // Lower for more predictable output
          'max_tokens': 1000, // Increased for complete JSON generation
          'response_format': {'type': 'json_object'}, // JSON mode for reliable output
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['choices']?[0]?['message']?['content']?.toString().trim();
        print('LLM Response received (${result?.length ?? 0} chars)');
        return result;
      } else {
        print('OpenAI API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('HTTP request error: $e');
    }

    return null;
  }

  List<Map<String, dynamic>> _parseRecipes(String response) {
    try {
      print('Raw recipe response: $response');
      
      // Clean the response first
      var cleanResponse = response.trim();
      
      // Remove any markdown code blocks
      cleanResponse = cleanResponse.replaceAll(RegExp(r'```json\s*|\s*```'), '');
      
      // Try to parse as JSON object first (new format with "recipes" key)
      try {
        final decoded = json.decode(cleanResponse);
        
        if (decoded is Map<String, dynamic> && decoded.containsKey('recipes')) {
          final recipesList = decoded['recipes'];
          if (recipesList is List) {
            return recipesList.map((recipe) {
              if (recipe is Map<String, dynamic>) {
                return {
                  'name': recipe['name']?.toString() ?? 'Unnamed Recipe',
                  'ingredients': (recipe['ingredients'] as List?)?.map((e) => e.toString()).toList() ?? [],
                  'instructions': (recipe['instructions'] as List?)?.map((e) => e.toString()).toList() ?? [],
                  'prepTime': recipe['prepTime']?.toString() ?? 'Unknown',
                  'cookTime': recipe['cookTime']?.toString() ?? 'Unknown',
                  'shoppingList': (recipe['shoppingList'] as List?)?.map((e) => e.toString()).toList() ?? [],
                };
              }
              return <String, dynamic>{};
            }).where((r) => r.isNotEmpty).toList();
          }
        }
        
        // Fallback: try parsing as array (old format)
        if (decoded is List) {
          return decoded.map((recipe) {
            if (recipe is Map<String, dynamic>) {
              return {
                'name': recipe['name']?.toString() ?? 'Unnamed Recipe',
                'ingredients': (recipe['ingredients'] as List?)?.map((e) => e.toString()).toList() ?? [],
                'instructions': (recipe['instructions'] as List?)?.map((e) => e.toString()).toList() ?? [],
                'prepTime': recipe['prepTime']?.toString() ?? 'Unknown',
                'cookTime': recipe['cookTime']?.toString() ?? 'Unknown',
                'shoppingList': (recipe['shoppingList'] as List?)?.map((e) => e.toString()).toList() ?? [],
              };
            }
            return <String, dynamic>{};
          }).where((r) => r.isNotEmpty).toList();
        }
      } catch (e) {
        print('JSON decode failed, trying regex fallback: $e');
      }
      
      // Legacy fallback: try to find JSON array with regex
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(cleanResponse);
      if (jsonMatch != null) {
        var jsonStr = jsonMatch.group(0)!;
        
        // Try to fix incomplete JSON by adding missing closing brackets
        if (!jsonStr.endsWith(']')) {
          final openBrackets = jsonStr.split('[').length - 1;
          final closeBrackets = jsonStr.split(']').length - 1;
          final missingCloses = openBrackets - closeBrackets;
          
          for (int i = 0; i < missingCloses; i++) {
            jsonStr += ']';
          }
        }
        
        print('Cleaned JSON string: $jsonStr');
        final decoded = json.decode(jsonStr);

        if (decoded is List) {
          return decoded.map((recipe) {
            if (recipe is Map<String, dynamic>) {
              return {
                'name': recipe['name']?.toString() ?? 'Unnamed Recipe',
                'ingredients': (recipe['ingredients'] as List?)?.map((e) => e.toString()).toList() ?? [],
                'instructions': (recipe['instructions'] as List?)?.map((e) => e.toString()).toList() ?? [],
                'prepTime': recipe['prepTime']?.toString() ?? 'Unknown',
                'cookTime': recipe['cookTime']?.toString() ?? 'Unknown',
                'shoppingList': (recipe['shoppingList'] as List?)?.map((e) => e.toString()).toList() ?? [],
              };
            }
            return <String, dynamic>{};
          }).where((r) => r.isNotEmpty).toList();
        }
      }
    } catch (e) {
      print('Error parsing recipes JSON: $e');
      print('Response that failed to parse: $response');
    }

    // Fallback: return empty list if parsing fails
    return [];
  }
}

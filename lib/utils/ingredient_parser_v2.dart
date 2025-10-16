/// Advanced ingredient parser using linguistic patterns and heuristics
class IngredientParserV2 {
  /// Parse ingredient using linguistic patterns instead of fixed sets
  static String parseIngredient(String ingredient) {
    String cleaned = ingredient.trim();
    if (cleaned.isEmpty) return '';

    // Step 1: Remove quantities and measurements
    cleaned = _removeQuantitiesAndMeasurements(cleaned);
    
    // Step 2: Extract the noun phrase (the actual food item)
    cleaned = _extractMainNoun(cleaned);
    
    // Step 3: Clean up and capitalize
    return _capitalize(cleaned.trim());
  }

  /// Remove quantities and measurements using comprehensive patterns
  static String _removeQuantitiesAndMeasurements(String text) {
    String cleaned = text.toLowerCase();
    
    // Remove leading numbers with or without units
    // e.g., "2", "1/2", "2.5", "2-3"
    cleaned = cleaned.replaceAll(RegExp(r'^\d+[\./\-]?\d*\s*'), '');
    
    // Remove measurement units with optional "of"
    // e.g., "cup of", "tbsp", "pounds"
    final measurements = [
      r'cups?', r'tbsps?', r'tablespoons?', r'tsps?', r'teaspoons?',
      r'ozs?', r'ounces?', r'lbs?', r'pounds?', r'g', r'grams?', 
      r'kgs?', r'kilograms?', r'ml', r'milliliters?', r'l', r'liters?',
      r'cloves?', r'pieces?', r'slices?', r'strips?', r'cans?', r'jars?',
      r'packages?', r'containers?', r'bunches?', r'heads?', r'stalks?'
    ].join('|');
    
    cleaned = cleaned.replaceAll(
      RegExp(r'^\d*[\./\-]?\d*\s*(' + measurements + r')\s+(of\s+)?', caseSensitive: false),
      ''
    );
    
    // Remove trailing measurements
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+\d+\s*(' + measurements + r')$', caseSensitive: false),
      ''
    );
    
    return cleaned.trim();
  }

  /// Extract the main noun (food item) from the phrase
  /// Uses linguistic heuristics to identify the core ingredient
  static String _extractMainNoun(String text) {
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return text;
    
    // Single word - return as is
    if (words.length == 1) return words[0];
    
    // Remove common adjectives and determiners
    final filteredWords = words.where((word) => 
      !_isCommonAdjective(word) && 
      !_isDeterminer(word) &&
      !_isPreposition(word)
    ).toList();
    
    if (filteredWords.isEmpty) return words.last;
    
    // If we have multiple words left, the noun is typically:
    // 1. The last word (English grammar: adjectives precede nouns)
    // 2. Or a compound noun (last 2 words)
    
    if (filteredWords.length == 1) {
      return filteredWords[0];
    }
    
    // Check if last two words form a compound noun
    if (filteredWords.length >= 2) {
      final lastTwo = '${filteredWords[filteredWords.length - 2]} ${filteredWords.last}';
      if (_isCompoundFood(lastTwo)) {
        return lastTwo;
      }
    }
    
    // Default: return the last word (the head noun)
    return filteredWords.last;
  }

  /// Check if a word is a common adjective/descriptor
  static bool _isCommonAdjective(String word) {
    final adjectives = {
      // Colors
      'white', 'brown', 'black', 'red', 'green', 'blue', 'yellow', 'orange', 'purple', 'pink',
      
      // Sizes
      'large', 'medium', 'small', 'big', 'little', 'extra', 'jumbo', 'mini',
      
      // Quality/Freshness
      'fresh', 'frozen', 'canned', 'dried', 'raw', 'cooked', 'organic', 'ripe', 'unripe',
      
      // Preparation
      'chopped', 'diced', 'sliced', 'minced', 'ground', 'shredded', 'grated', 'crushed',
      'half', 'quartered', 'peeled', 'boneless', 'skinless',
      
      // Taste/Quality
      'sweet', 'sour', 'bitter', 'spicy', 'mild', 'hot', 'cold', 'warm',
      
      // Fat content
      'lean', 'fat-free', 'low-fat', 'whole', 'skim', 'reduced-fat',
      
      // Other
      'unsalted', 'salted', 'aged', 'young', 'roasted', 'grilled', 'boiled'
    };
    
    return adjectives.contains(word.toLowerCase());
  }

  /// Check if word is a determiner (a, an, the, some, etc.)
  static bool _isDeterminer(String word) {
    return {'a', 'an', 'the', 'some', 'any'}.contains(word.toLowerCase());
  }

  /// Check if word is a preposition
  static bool _isPreposition(String word) {
    return {'of', 'from', 'with', 'without', 'in', 'on', 'at'}.contains(word.toLowerCase());
  }

  /// Check if a phrase is a known compound food noun
  static bool _isCompoundFood(String phrase) {
    final compounds = {
      'bell pepper', 'bell peppers', 'sweet potato', 'sweet potatoes',
      'soy sauce', 'olive oil', 'coconut milk', 'peanut butter',
      'cream cheese', 'cheddar cheese', 'ground beef', 'ground pork',
      'chicken breast', 'chicken breasts', 'pork chop', 'pork chops',
      'green beans', 'black beans', 'kidney beans', 'lima beans',
      'cherry tomatoes', 'grape tomatoes', 'roma tomatoes',
      'iceberg lettuce', 'romaine lettuce', 'butterhead lettuce'
    };
    
    return compounds.contains(phrase.toLowerCase());
  }

  /// Capitalize first letter
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}


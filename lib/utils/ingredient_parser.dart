/// Utility class for parsing and cleaning ingredient names for shopping lists
class IngredientParser {
  /// Common food words that should be extracted as the main ingredient
  static const Set<String> _coreFoodWords = {
    'eggs', 'egg', 'milk', 'cheese', 'butter', 'bread', 'rice', 'pasta', 'noodles',
    'chicken', 'beef', 'pork', 'fish', 'salmon', 'tuna', 'shrimp', 'crab', 'lobster',
    'onion', 'onions', 'garlic', 'tomato', 'tomatoes', 'potato', 'potatoes', 'carrot',
    'carrots', 'broccoli', 'spinach', 'lettuce', 'cabbage', 'apple', 'apples', 'banana',
    'bananas', 'orange', 'oranges', 'lemon', 'lemons', 'lime', 'limes', 'pepper',
    'salt', 'sugar', 'flour', 'oil', 'vinegar', 'soy', 'sauce', 'herbs', 'spices',
    'meat', 'vegetables', 'fruits', 'nuts', 'almonds', 'walnuts', 'peanuts', 'seeds'
  };

  /// Adjectives and descriptors that commonly precede food items
  static const Set<String> _descriptors = {
    'white', 'brown', 'black', 'red', 'green', 'blue', 'yellow', 'orange', 'purple',
    'organic', 'fresh', 'dried', 'frozen', 'canned', 'raw', 'cooked', 'boiled',
    'grilled', 'roasted', 'sliced', 'diced', 'chopped', 'minced', 'whole', 'half',
    'large', 'medium', 'small', 'extra', 'boneless', 'skinless', 'lean', 'fat-free',
    'low-fat', 'whole-grain', 'whole-wheat', 'enriched', 'unsalted', 'salted',
    'sweet', 'sour', 'bitter', 'mild', 'sharp', 'aged', 'young', 'ripe', 'unripe',
    'ground'
  };

  /// Parse and clean an ingredient string to extract the core food item
  /// 
  /// Examples:
  /// "2 white eggs" -> "Eggs"
  /// "3 large carrots" -> "Carrots" 
  /// "1 cup of milk" -> "Milk"
  /// "2 lbs ground beef" -> "Beef"
  static String parseIngredient(String ingredient) {
    String cleaned = ingredient.trim().toLowerCase();

    // First remove quantities and measurements (existing logic)
    cleaned = _removeQuantitiesAndMeasurements(cleaned);
    
    // Remove common descriptors and extract the core food item
    cleaned = _extractCoreFoodItem(cleaned);
    
    // Capitalize the first letter
    if (cleaned.trim().isEmpty) {
      cleaned = ingredient.trim();
    } else {
      cleaned = cleaned.trim();
    }
    
    return _capitalize(cleaned);
  }
  
  /// Capitalize the first letter of a string
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Remove quantities and measurements from ingredient string
  static String _removeQuantitiesAndMeasurements(String ingredient) {
    // Remove common quantity patterns from the beginning
    String cleaned = ingredient.replaceAll(
      RegExp(r'^\d+\s*(cups?|tbsp?|tsp?|oz|lb|lbs?|g|kg|ml|l|cloves?|pieces?|slices?|medium|large|small)\s+', caseSensitive: false),
      ''
    );
    
    // Remove remaining quantity patterns like "2 cups of" or "1 lb of"
    cleaned = cleaned.replaceAll(
      RegExp(r'\d+\s*(cups?|tbsp?|tsp?|oz|lb|lbs?|g|kg|ml|l|cloves?|pieces?|slices?)\s+of\s+', caseSensitive: false),
      ''
    );
    
    // Remove standalone measurements at the end (but keep ingredient name)
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+\d+\s*(cups?|tbsp?|tsp?|oz|lb|lbs?|g|kg|ml|l|cloves?|pieces?|slices?)$', caseSensitive: false),
      ''
    );
    
    // Remove fractional amounts like "1/2 cup" or "1/4 tsp"
    cleaned = cleaned.replaceAll(
      RegExp(r'^\d+\/\d+\s*(cups?|tbsp?|tsp?|oz|lb|lbs?|g|kg|ml|l|cloves?|pieces?|slices?)\s+', caseSensitive: false),
      ''
    );

    // Remove any remaining numbers at the beginning
    cleaned = cleaned.replaceAll(RegExp(r'^\d+\s+'), '');
    
    return cleaned.trim();
  }

  /// Extract the core food item by removing descriptors and finding the main food word
  static String _extractCoreFoodItem(String ingredient) {
    final words = ingredient.split(' ').where((word) => word.isNotEmpty).toList();
    
    // If no words, return empty
    if (words.isEmpty) return '';
    
    // Look for core food words in the ingredient
    for (int i = words.length - 1; i >= 0; i--) {
      final word = words[i];
      if (_coreFoodWords.contains(word)) {
        return word;
      }
    }
    
    // If no core food word found, try removing descriptors from the end
    String result = ingredient;
    for (final descriptor in _descriptors) {
      // Remove descriptor if it's at the beginning
      if (result.startsWith('$descriptor ')) {
        result = result.substring(descriptor.length + 1);
      }
      // Remove descriptor if it's at the end  
      else if (result.endsWith(' $descriptor')) {
        result = result.substring(0, result.length - descriptor.length - 1);
      }
    }
    
    // Also try removing common suffixes like "pieces", "slices", etc.
    result = result.replaceAll(RegExp(r'\s+(pieces?|slices?|chunks?|bits?|strips?)\s*$'), '');
    
    // If we have multiple words left and the last word looks like a core food item
    final remainingWords = result.split(' ').where((word) => word.isNotEmpty).toList();
    if (remainingWords.isNotEmpty && remainingWords.length > 1) {
      final lastWord = remainingWords.last;
      if (_coreFoodWords.contains(lastWord)) {
        return lastWord;
      }
    }
    
    return result.trim();
  }
}

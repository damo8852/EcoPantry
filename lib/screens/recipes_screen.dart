import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';
import '../services/theme_service.dart';
import '../utils/hybrid_ingredient_parser.dart';

class RecipesScreen extends StatefulWidget {
  final List<Recipe> recipes;
  final List<String> usedIngredients;

  const RecipesScreen({
    super.key,
    required this.recipes,
    required this.usedIngredients,
  });

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  bool _showIngredientsDetails = false;
  late final ThemeService _themeService;

  User get user => _auth.currentUser!;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService();
    _themeService.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _saveRecipe(Recipe recipe) async {
    try {
      // Check if recipe is already saved
      final existingQuery = await _db
          .collection('users')
          .doc(user.uid)
          .collection('saved_recipes')
          .where('name', isEqualTo: recipe.name)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe already saved!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Save recipe to Firestore
      final recipeData = recipe.toMap();
      recipeData['savedAt'] = FieldValue.serverTimestamp();

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('saved_recipes')
          .add(recipeData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${recipe.name}"'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                // Navigate to saved recipes screen
                Navigator.pushNamed(context, '/saved_recipes');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save recipe: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _addToShoppingList(String ingredient) async {
    try {
      // Check if user is authenticated
      if (!mounted) {
        return;
      }
      
      // Get current user safely
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to add items to your shopping list'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Use the hybrid ingredient parser (rule-based + AI fallback)
      final cleanIngredient = await HybridIngredientParser.parseIngredient(ingredient);

      // Final validation - ensure we have a valid ingredient name
      if (cleanIngredient.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not add item to shopping list: Invalid ingredient name'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      print('Adding to shopping list - Original: "$ingredient" -> Cleaned: "$cleanIngredient"');

      // Check if item already exists in shopping list
      final existingQuery = await _db
          .collection('users')
          .doc(currentUser.uid)
          .collection('shopping_list')
          .where('name', isEqualTo: cleanIngredient)
          .where('isCompleted', isEqualTo: false)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$cleanIngredient" is already in your shopping list'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      await _db.collection('users').doc(currentUser.uid).collection('shopping_list').add({
        'name': cleanIngredient,
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "$cleanIngredient" to shopping list'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to shopping list: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.isDarkMode ? ThemeService.darkBackground : ThemeService.lightBackground,
      appBar: AppBar(
        title: Text(
          'Recipe Suggestions',
          style: TextStyle(
            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
          ),
        ),
        backgroundColor: _themeService.isDarkMode ? ThemeService.darkBackground : ThemeService.lightBackground,
        elevation: 0,
        iconTheme: IconThemeData(
          color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
        ),
      ),
      body: widget.recipes.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                _buildIngredientsHeader(context),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.recipes.length,
                    itemBuilder: (context, index) {
                      return _buildRecipeCard(context, widget.recipes[index]);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildIngredientsHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode ? ThemeService.darkCardBackground : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: _themeService.isDarkMode ? Border.all(color: ThemeService.darkBorder) : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _showIngredientsDetails = !_showIngredientsDetails;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.kitchen_rounded,
                    color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.usedIngredients.isEmpty 
                          ? 'No ingredients from fridge - using pantry staples'
                          : 'Using ${widget.usedIngredients.length} ingredients from your fridge',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Icon(
                    _showIngredientsDetails ? Icons.expand_less : Icons.expand_more,
                    color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
          ),
          if (_showIngredientsDetails)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.usedIngredients.isEmpty 
                  ? Text(
                      'These recipes use common pantry staples like salt, pepper, oil, garlic, onions, rice, pasta, and canned goods. You may need to buy a few fresh ingredients as listed in each recipe.',
                      style: TextStyle(
                        color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.usedIngredients.map((ingredient) {
                        return Chip(
                          label: Text(
                            ingredient,
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: _themeService.isDarkMode ? ThemeService.darkBorder : Theme.of(context).colorScheme.surface,
                          labelStyle: TextStyle(
                            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : Theme.of(context).colorScheme.onSurface,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(BuildContext context, Recipe recipe) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _themeService.isDarkMode 
                ? [ThemeService.darkCardBackground, ThemeService.darkCardBackground.withOpacity(0.8)]
                : [Colors.white, const Color(0xFFFFF8F3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE67E22).withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE67E22).withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _showRecipeDetails(context, recipe),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with subtle background
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _themeService.isDarkMode 
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFE67E22).withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE67E22).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.restaurant_menu,
                        color: _themeService.isDarkMode ? const Color(0xFFE67E22) : const Color(0xFFD35400),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        recipe.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE67E22).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.bookmark_border_rounded),
                        color: _themeService.isDarkMode ? const Color(0xFFE67E22) : const Color(0xFFD35400),
                        onPressed: () => _saveRecipe(recipe),
                        tooltip: 'Save Recipe',
                        iconSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats row with modern badges
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE67E22).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 18,
                                  color: Color(0xFFE67E22),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    recipe.cookTime != 'Unknown' 
                                        ? '${recipe.prepTime} + ${recipe.cookTime}'
                                        : recipe.prepTime,
                                    style: TextStyle(
                                      color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : const Color(0xFFE67E22),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.kitchen,
                                  size: 18,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${recipe.ingredients.length} items',
                                    style: TextStyle(
                                      color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : Colors.green,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (recipe.shoppingList.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.shopping_cart,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      '+${recipe.shoppingList.length}',
                                      style: TextStyle(
                                        color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : Colors.blue,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Filter ingredients based on what's available
                    ...() {
                      // Get ingredients from fridge (match against usedIngredients)
                      final fridgeIngredients = recipe.ingredients.where((ingredient) {
                        final ingredientLower = ingredient.toLowerCase();
                        return widget.usedIngredients.any((used) => 
                          ingredientLower.contains(used.toLowerCase()) || 
                          used.toLowerCase().contains(ingredientLower.split(' ').last)
                        );
                      }).toList();

                      // Get ingredients that need to be bought (not in fridge, not basic pantry staples)
                      final basicPantryStaples = ['salt', 'pepper', 'oil', 'butter', 'water', 'sugar', 'flour'];
                      final toBuyIngredients = recipe.ingredients.where((ingredient) {
                        final ingredientLower = ingredient.toLowerCase();
                        // Skip if it's a basic pantry staple
                        if (basicPantryStaples.any((staple) => ingredientLower.contains(staple))) {
                          return false;
                        }
                        // Include if NOT in fridge
                        return !widget.usedIngredients.any((used) => 
                          ingredientLower.contains(used.toLowerCase()) || 
                          used.toLowerCase().contains(ingredientLower.split(' ').last)
                        );
                      }).toList();

                      return [
                        // From Your Fridge section
                        if (fridgeIngredients.isNotEmpty) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'From Your Fridge',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${fridgeIngredients.length}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...fridgeIngredients.take(3).map((ingredient) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        ingredient,
                                        style: TextStyle(
                                          color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          if (fridgeIngredients.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 12),
                              child: Text(
                                '+ ${fridgeIngredients.length - 3} more from fridge',
                                style: TextStyle(
                                  color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Colors.green,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],

                        // Need to Buy section
                        if (toBuyIngredients.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.shopping_cart,
                                  size: 18,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Need to Buy',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${toBuyIngredients.length}',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...toBuyIngredients.take(3).map((ingredient) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.add_shopping_cart, size: 16, color: Colors.orange),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        ingredient,
                                        style: TextStyle(
                                          color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.add_shopping_cart,
                                        size: 16,
                                        color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Colors.grey[600],
                                      ),
                                      onPressed: () => _addToShoppingList(ingredient),
                                      tooltip: 'Add to shopping list',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          if (toBuyIngredients.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '+ ${toBuyIngredients.length - 3} more to buy',
                                style: TextStyle(
                                  color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Colors.orange,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ];
                    }(),
                    
                    // Shopping list section
                    if (recipe.shoppingList.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.shopping_cart,
                              size: 18,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Need to Buy',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...recipe.shoppingList.take(2).map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      if (recipe.shoppingList.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+ ${recipe.shoppingList.length - 2} more items',
                            style: TextStyle(
                              color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Colors.blue,
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                    
                    const SizedBox(height: 16),
                    // Modern CTA button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _showRecipeDetails(context, recipe),
                        icon: const Icon(Icons.menu_book_rounded, size: 20),
                        label: const Text('View Full Recipe'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE67E22),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecipeDetails(BuildContext context, Recipe recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      recipe.name,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.prepTime} prep',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (recipe.cookTime != 'Unknown') ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${recipe.cookTime} cook',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ],
                    ),
              const SizedBox(height: 24),
              Text(
                'Available in your fridge',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 12),
              ...recipe.ingredients.map((ingredient) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ingredient,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.add_shopping_cart,
                            size: 20,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          onPressed: () => _addToShoppingList(ingredient),
                          tooltip: 'Add to shopping list',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  )),
              if (recipe.shoppingList.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Need to buy',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                ),
                const SizedBox(height: 12),
                ...recipe.shoppingList.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
                    const SizedBox(height: 24),
                    Text(
                      'Directions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...recipe.instructions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final instruction = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                instruction,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      height: 1.5,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No recipes generated',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : null,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adding more items to your fridge or check your Mistral API connection.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

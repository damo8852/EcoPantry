import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';
import '../services/theme_service.dart';
import '../utils/hybrid_ingredient_parser.dart';

class SavedRecipesScreen extends StatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  late final ThemeService _themeService;

  User get user => _auth.currentUser!;

  // Filter states
  String _sourceFilter = 'all'; // all, user-created, ai-generated
  String _cookingToolFilter = 'all';
  String _styleFilter = 'all';
  String _cuisineFilter = 'all';

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

  bool _matchesFilters(Map<String, dynamic> recipe) {
    // Source filter
    if (_sourceFilter != 'all') {
      final isUserCreated = recipe['isUserCreated'] == true;
      if (_sourceFilter == 'user-created' && !isUserCreated) return false;
      if (_sourceFilter == 'ai-generated' && isUserCreated) return false;
    }

    // Cooking tool filter
    if (_cookingToolFilter != 'all') {
      final recipeTool = recipe['cookingTool'];
      if (recipeTool != _cookingToolFilter) return false;
    }

    // Style filter
    if (_styleFilter != 'all') {
      final recipeStyle = recipe['recipeStyle'];
      if (recipeStyle != _styleFilter) return false;
    }

    // Cuisine filter
    if (_cuisineFilter != 'all') {
      final recipeCuisine = recipe['cuisineType'];
      if (recipeCuisine != _cuisineFilter) return false;
    }

    return true;
  }

  void _showFiltersDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: _themeService.isDarkMode ? ThemeService.darkCardBackground : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE67E22).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.filter_list, color: Color(0xFFE67E22), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Filter Recipes',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Filters content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterSection(
                          'Source',
                          _sourceFilter,
                          ['all', 'user-created', 'ai-generated'],
                          ['All', 'My Creations', 'AI Generated'],
                          (value) => setDialogState(() => _sourceFilter = value),
                        ),
                        const SizedBox(height: 20),
                        _buildFilterSection(
                          'Cooking Tool',
                          _cookingToolFilter,
                          ['all', 'pan', 'rice_cooker', 'air_fryer', 'slow_cooker', 'instant_pot', 'oven', 'pot'],
                          ['All', '🍳 Pan', '🍚 Rice Cooker', '🔥 Air Fryer', '🥘 Slow Cooker', '⚡ Instant Pot', '🔥 Oven', '🍲 Pot'],
                          (value) => setDialogState(() => _cookingToolFilter = value),
                        ),
                        const SizedBox(height: 20),
                        _buildFilterSection(
                          'Recipe Style',
                          _styleFilter,
                          ['all', 'creative', 'traditional', 'healthy', 'quick', 'comfort'],
                          ['All', '🎨 Creative', '👨‍🍳 Traditional', '🥗 Healthy', '⚡ Quick', '🏡 Comfort'],
                          (value) => setDialogState(() => _styleFilter = value),
                        ),
                        const SizedBox(height: 20),
                        _buildFilterSection(
                          'Cuisine',
                          _cuisineFilter,
                          ['all', 'asian', 'american', 'italian', 'mexican', 'indian', 'mediterranean'],
                          ['All', '🥢 Asian', '🍔 American', '🍝 Italian', '🌶️ Mexican', '🍛 Indian', '🫒 Mediterranean'],
                          (value) => setDialogState(() => _cuisineFilter = value),
                        ),
                      ],
                    ),
                  ),
                ),

              // Action buttons
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + (Platform.isAndroid ? MediaQuery.of(context).viewPadding.bottom : 0),
                ),
                decoration: BoxDecoration(
                  color: _themeService.isDarkMode ? ThemeService.darkBackground : Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setDialogState(() {
                            _sourceFilter = 'all';
                            _cookingToolFilter = 'all';
                            _styleFilter = 'all';
                            _cuisineFilter = 'all';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Clear All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {}); // Apply filters
                          Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE67E22),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Apply Filters'),
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

  Widget _buildFilterSection(
    String title,
    String currentValue,
    List<String> values,
    List<String> labels,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(values.length, (index) {
            final value = values[index];
            final label = labels[index];
            final isSelected = currentValue == value;
            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) onChanged(value);
              },
              selectedColor: const Color(0xFFE67E22).withOpacity(0.15),
              checkmarkColor: const Color(0xFFE67E22),
              backgroundColor: _themeService.isDarkMode ? ThemeService.darkBackground : Colors.grey[100],
              labelStyle: TextStyle(
                color: isSelected 
                    ? const Color(0xFFE67E22)
                    : (_themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFE67E22) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            );
          }),
        ),
      ],
    );
  }

  Future<void> _deleteRecipe(String recipeId, String recipeName, Map<String, dynamic> recipeData) async {
    final isUserCreated = recipeData['isUserCreated'] == true;
    final authorId = recipeData['authorId'];
    final communityRecipeId = recipeData['communityRecipeId'];
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text(
          isUserCreated && authorId == user.uid
              ? 'Are you sure you want to delete "$recipeName"? This will remove it from the community for everyone.'
              : 'Are you sure you want to delete "$recipeName" from your saved recipes?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete from user's saved recipes
        await _db
            .collection('users')
            .doc(user.uid)
            .collection('saved_recipes')
            .doc(recipeId)
            .delete();

        // If user created this recipe, also delete from community
        if (isUserCreated && authorId == user.uid && communityRecipeId != null) {
          await _db
              .collection('community_recipes')
              .doc(communityRecipeId)
              .delete();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "$recipeName"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete recipe: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.isDarkMode ? ThemeService.darkBackground : ThemeService.lightBackground,
      appBar: AppBar(
        title: Text(
          'My Recipes',
          style: TextStyle(
            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
          ),
        ),
        backgroundColor: _themeService.isDarkMode ? ThemeService.darkBackground : ThemeService.lightBackground,
        elevation: 0,
        iconTheme: IconThemeData(
          color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFiltersDialog,
                tooltip: 'Filter Recipes',
              ),
              if (_sourceFilter != 'all' || _cookingToolFilter != 'all' || _styleFilter != 'all' || _cuisineFilter != 'all')
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE67E22),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db
            .collection('users')
            .doc(user.uid)
            .collection('saved_recipes')
            .orderBy('savedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(
                  color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data?.docs ?? [];
          
          // Apply filters
          final docs = allDocs.where((doc) {
            final data = doc.data();
            return _matchesFilters(data);
          }).toList();

          if (allDocs.isEmpty) {
            return _buildEmptyState();
          }
          
          if (docs.isEmpty) {
            return _buildNoResultsState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final recipe = Recipe.fromMap(data);
              final savedAt = (data['savedAt'] as Timestamp?)?.toDate();

              return _buildRecipeCard(recipe, doc.id, savedAt, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 64,
              color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No Saved Recipes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : null,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save recipes from the recipe suggestions to keep them handy!',
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

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No Recipes Match Filters',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : null,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filter settings',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showFiltersDialog,
              icon: const Icon(Icons.filter_list),
              label: const Text('Change Filters'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE67E22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe, String recipeId, DateTime? savedAt, Map<String, dynamic> data) {
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
          onTap: () => _showRecipeDetails(recipe),
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
                        Icons.bookmark,
                        color: _themeService.isDarkMode ? const Color(0xFFE67E22) : const Color(0xFFD35400),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                            ),
                          ),
                          if (savedAt != null)
                            Text(
                              'Saved ${_formatDate(savedAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : const Color(0xFF7F8C8D),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: const Color(0xFFE74C3C),
                        onPressed: () => _deleteRecipe(recipeId, recipe.name, data),
                        tooltip: 'Delete',
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
                                  Icons.restaurant_menu,
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Ingredients preview
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
                          'Ingredients',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...recipe.ingredients.take(3).map((ingredient) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
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
                              const SizedBox(width: 8),
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
                    if (recipe.ingredients.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+ ${recipe.ingredients.length - 3} more ingredients',
                          style: TextStyle(
                            color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Colors.green,
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    // Modern CTA button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _showRecipeDetails(recipe),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'just now';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  void _showRecipeDetails(Recipe recipe) {
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
            color: _themeService.isDarkMode ? ThemeService.darkCardBackground : Theme.of(context).colorScheme.surface,
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
                            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : null,
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
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : null,
                              ),
                        ),
                        if (recipe.cookTime != 'Unknown') ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${recipe.cookTime} cook',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : null,
                                ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Ingredients',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : Theme.of(context).colorScheme.primary,
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
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : null,
                                      ),
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
                        'Shopping List',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : Theme.of(context).colorScheme.tertiary,
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
                                          color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : Theme.of(context).colorScheme.secondary,
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
                            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : null,
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
                                      color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : null,
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
}


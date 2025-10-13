import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_service.dart';
import '../services/llm_service.dart';
import '../models/recipe.dart';
import 'create_recipe_screen.dart';
import 'saved_recipes_screen.dart';
import 'community_recipes_screen.dart';
import 'recipes_screen.dart';

class RecipesHubScreen extends StatefulWidget {
  const RecipesHubScreen({super.key});

  @override
  State<RecipesHubScreen> createState() => _RecipesHubScreenState();
}

class _RecipesHubScreenState extends State<RecipesHubScreen> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
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

  Future<void> _generateAIRecipes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show recipe preferences dialog
    String recipeMode = 'any';
    String cuisineType = 'any';
    String recipeKeyword = '';
    String cookingTool = 'any';
    final keywordController = TextEditingController();
    
    final options = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
            decoration: BoxDecoration(
              color: _themeService.isDarkMode ? ThemeService.darkCardBackground : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _themeService.isDarkMode 
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFF3498DB).withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3498DB).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF3498DB),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Recipe Generator',
                              style: TextStyle(
                                color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Customize your recipe suggestions',
                              style: TextStyle(
                                color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : const Color(0xFF7F8C8D),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDialogSection('Recipe Style', recipeMode, [
                          {'label': 'Any Style', 'value': 'any'},
                          {'label': '🎨 Creative', 'value': 'creative'},
                          {'label': '👨‍🍳 Traditional', 'value': 'traditional'},
                          {'label': '🌍 Fusion', 'value': 'fusion'},
                          {'label': '🏡 Comfort', 'value': 'comfort'},
                          {'label': '🥗 Healthy', 'value': 'healthy'},
                          {'label': '⚡ Quick', 'value': 'quick'},
                        ], (value) => setDialogState(() => recipeMode = value)),
                        
                        const SizedBox(height: 20),
                        
                        _buildDialogSection('Cuisine Type', cuisineType, [
                          {'label': 'Any Cuisine', 'value': 'any'},
                          {'label': '🥢 Asian', 'value': 'asian'},
                          {'label': '🍔 American', 'value': 'american'},
                          {'label': '🌮 Latin', 'value': 'latin'},
                          {'label': '🫒 Mediterranean', 'value': 'mediterranean'},
                          {'label': '🍝 Italian', 'value': 'italian'},
                          {'label': '🥖 French', 'value': 'french'},
                          {'label': '🍛 Indian', 'value': 'indian'},
                          {'label': '🌶️ Mexican', 'value': 'mexican'},
                        ], (value) => setDialogState(() => cuisineType = value)),
                        
                        const SizedBox(height: 20),
                        
                        _buildDialogSection('Cooking Tool', cookingTool, [
                          {'label': 'Any Tool', 'value': 'any'},
                          {'label': '🍳 Pan/Skillet', 'value': 'pan'},
                          {'label': '🍚 Rice Cooker', 'value': 'rice_cooker'},
                          {'label': '🔥 Air Fryer', 'value': 'air_fryer'},
                          {'label': '🥘 Slow Cooker', 'value': 'slow_cooker'},
                          {'label': '⚡ Instant Pot', 'value': 'instant_pot'},
                          {'label': '🔥 Oven', 'value': 'oven'},
                          {'label': '🍲 Pot', 'value': 'pot'},
                        ], (value) => setDialogState(() => cookingTool = value)),
                        
                        const SizedBox(height: 24),
                        
                        Text(
                          'Recipe Keywords (Optional)',
                          style: TextStyle(
                            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: keywordController,
                          decoration: InputDecoration(
                            hintText: 'e.g., butter chicken, pasta carbonara',
                            hintStyle: TextStyle(
                              color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF3498DB), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            filled: true,
                            fillColor: _themeService.isDarkMode ? ThemeService.darkBackground : Colors.grey[50],
                          ),
                          style: TextStyle(
                            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              recipeKeyword = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Action buttons
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _themeService.isDarkMode ? ThemeService.darkBackground : Colors.grey[50],
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop({
                            'recipeMode': recipeMode,
                            'cuisineType': cuisineType,
                            'keyword': recipeKeyword,
                            'cookingTool': cookingTool,
                          }),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Generate Recipes'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3498DB),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      ),
    );

    if (options == null) return;
    
    final selectedMode = options['recipeMode'] as String;
    final selectedCuisine = options['cuisineType'] as String;
    final keyword = options['keyword'] as String?;
    final selectedCookingTool = options['cookingTool'] as String?;

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.isDarkMode ? ThemeService.darkCardBackground : Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF3498DB)),
            const SizedBox(height: 16),
            Text(
              'Generating recipes...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take 10-20 seconds',
              style: TextStyle(
                fontSize: 14,
                color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // Get user's ingredients
      final db = FirebaseFirestore.instance;
      final snapshot = await db
          .collection('users')
          .doc(user.uid)
          .collection('items')
          .get();

      final ingredients = snapshot.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      // Generate recipes
      final recipeData = await LLMService().generateRecipes(
        ingredients,
        count: 3,
        recipeMode: selectedMode != 'any' ? selectedMode : null,
        cuisineType: selectedCuisine != 'any' ? selectedCuisine : null,
        keyword: keyword != null && keyword.trim().isNotEmpty ? keyword : null,
        cookingTool: selectedCookingTool != null && selectedCookingTool != 'any' ? selectedCookingTool : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (recipeData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate recipes. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Convert to Recipe objects
      final recipes = recipeData.map((data) => Recipe.fromMap(data)).toList();

      // Navigate to RecipesScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipesScreen(
            recipes: recipes,
            usedIngredients: ingredients,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Widget _buildDialogSection(
    String title,
    String currentValue,
    List<Map<String, String>> options,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: options.map((option) {
            final label = option['label']!;
            final value = option['value']!;
            return _buildChoiceChip(label, value, currentValue, onChanged);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChoiceChip(String label, String value, String groupValue, Function(String) onSelected) {
    final isSelected = value == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) onSelected(value);
      },
      selectedColor: const Color(0xFF3498DB).withOpacity(0.15),
      checkmarkColor: const Color(0xFF3498DB),
      backgroundColor: _themeService.isDarkMode ? ThemeService.darkBackground : Colors.grey[100],
      labelStyle: TextStyle(
        color: isSelected 
            ? const Color(0xFF3498DB)
            : (_themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? const Color(0xFF3498DB) : Colors.transparent,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.isDarkMode 
          ? ThemeService.darkBackground 
          : ThemeService.lightBackground,
      appBar: AppBar(
        title: Text(
          'Recipes',
          style: TextStyle(
            color: _themeService.isDarkMode 
                ? ThemeService.darkTextPrimary 
                : ThemeService.lightTextPrimary,
          ),
        ),
        backgroundColor: _themeService.isDarkMode 
            ? ThemeService.darkBackground 
            : ThemeService.lightBackground,
        elevation: 0,
        iconTheme: IconThemeData(
          color: _themeService.isDarkMode 
              ? ThemeService.darkTextPrimary 
              : ThemeService.lightTextPrimary,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'What would you like to do?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextPrimary 
                    : const Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create, save, or discover amazing recipes',
              style: TextStyle(
                fontSize: 16,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextSecondary 
                    : const Color(0xFF7F8C8D),
              ),
            ),
            const SizedBox(height: 32),

            // Generate AI Recipes Card
            _buildOptionCard(
              context,
              icon: Icons.auto_awesome,
              iconColor: const Color(0xFF3498DB),
              title: 'Generate AI Recipes',
              description: 'Get personalized recipe suggestions based on your ingredients',
              onTap: _generateAIRecipes,
            ),

            const SizedBox(height: 16),

            // Create Recipe Card
            _buildOptionCard(
              context,
              icon: Icons.add_circle_rounded,
              iconColor: const Color(0xFF27AE60),
              title: 'Create Recipe',
              description: 'Share your own culinary creations with the community',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateRecipeScreen()),
                );
              },
            ),

            const SizedBox(height: 16),

            // My Recipes Card
            _buildOptionCard(
              context,
              icon: Icons.bookmark_rounded,
              iconColor: const Color(0xFFE67E22),
              title: 'My Recipes',
              description: 'View your saved recipes and creations',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavedRecipesScreen()),
                );
              },
            ),

            const SizedBox(height: 16),

            // Community Recipes Card
            _buildOptionCard(
              context,
              icon: Icons.people_rounded,
              iconColor: const Color(0xFF9B59B6),
              title: 'Community Recipes',
              description: 'Discover and share recipes with others',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CommunityRecipesScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _themeService.isDarkMode 
                  ? [
                      ThemeService.darkCardBackground, 
                      ThemeService.darkCardBackground.withOpacity(0.8)
                    ]
                  : [Colors.white, iconColor.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: iconColor.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextPrimary 
                            : const Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextSecondary 
                            : const Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 20,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextSecondary 
                    : const Color(0xFFBDC3C7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


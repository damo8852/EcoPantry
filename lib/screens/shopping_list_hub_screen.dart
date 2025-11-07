import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_service.dart';
import '../services/llm_service.dart';
import '../services/subscription_service.dart';
import '../models/recipe.dart';
import '../widgets/upgrade_dialog.dart';
import 'my_shopping_list_screen.dart';
import 'recipes_screen.dart';
import 'paywall_screen.dart';

class ShoppingListHubScreen extends StatefulWidget {
  const ShoppingListHubScreen({super.key});

  @override
  State<ShoppingListHubScreen> createState() => _ShoppingListHubScreenState();
}

class _ShoppingListHubScreenState extends State<ShoppingListHubScreen> {
  final ThemeService _themeService = ThemeService();
  bool _isCheckingAccess = true;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _checkShoppingListAccess();
  }

  Future<void> _checkShoppingListAccess() async {
    final hasAccess = await SubscriptionService.instance.canAccessShoppingList();
    if (mounted) {
      setState(() {
        _hasAccess = hasAccess;
        _isCheckingAccess = false;
      });
    }
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

  Future<void> _handleUpgrade() async {
    // Navigate to paywall screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaywallScreen(),
      ),
    );
  }

  Future<void> _generateAIRecipesFromShopping() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if user can generate recipes
    final canGenerate = await SubscriptionService.instance.canGenerateRecipes();
    if (!canGenerate) {
      final remaining = await SubscriptionService.instance.getRemainingRecipesToday();
      if (mounted) {
        final shouldUpgrade = await showRecipeLimitUpgradeDialog(context, remaining);
        if (shouldUpgrade) {
          // Navigate to settings or show upgrade options
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Premium upgrade coming soon! Contact support for early access.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      return;
    }

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
                              'Generate recipes from your shopping list',
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
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    24 + (Platform.isAndroid ? MediaQuery.of(context).viewPadding.bottom : 0),
                  ),
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
      final db = FirebaseFirestore.instance;

      // Get user's shopping list items
      final shoppingSnapshot = await db
          .collection('users')
          .doc(user.uid)
          .collection('shopping_list')
          .where('isCompleted', isEqualTo: false)
          .get();

      final shoppingListItems = shoppingSnapshot.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      // Get user's fridge items (items collection)
      final fridgeSnapshot = await db
          .collection('users')
          .doc(user.uid)
          .collection('items')
          .get();

      final fridgeItems = fridgeSnapshot.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      print('🛒 Shopping list: ${shoppingListItems.length} items');
      print('🧊 Fridge items: ${fridgeItems.length} items');

      // Get user's diet preferences
      List<String> dietPreferences = [];
      try {
        final userDoc = await db.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final preferences = userData['dietPreferences'] as List<dynamic>?;
          if (preferences != null) {
            dietPreferences = preferences.cast<String>();
          }
        }
      } catch (e) {
        print('Error loading diet preferences: $e');
      }

      // Generate recipes from shopping list items with fridge context
      final recipeData = await LLMService().generateRecipesFromShoppingList(
        shoppingListItems,
        fridgeItems: fridgeItems,
        count: 3,
        recipeMode: selectedMode != 'any' ? selectedMode : null,
        cuisineType: selectedCuisine != 'any' ? selectedCuisine : null,
        keyword: keyword != null && keyword.trim().isNotEmpty ? keyword : null,
        cookingTool: selectedCookingTool != null && selectedCookingTool != 'any' ? selectedCookingTool : null,
        dietPreferences: dietPreferences.isNotEmpty ? dietPreferences : null,
      );

      // Increment recipe generation count for free users
      await SubscriptionService.instance.incrementRecipeCount();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (recipeData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate recipes. Please try again or add items to your shopping list.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Convert to Recipe objects
      final recipes = recipeData.map((data) => Recipe.fromMap(data)).toList();

      // Navigate to RecipesScreen with fridge items as "used" ingredients
      // (these are what the user already has - will show in "From Your Fridge")
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipesScreen(
            recipes: recipes,
            usedIngredients: fridgeItems,
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
    // Show loading state while checking access
    if (_isCheckingAccess) {
      return Scaffold(
        backgroundColor: _themeService.isDarkMode
            ? ThemeService.darkBackground
            : ThemeService.lightBackground,
        appBar: AppBar(
          title: Text(
            'Shopping List',
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show upgrade screen if no access
    if (!_hasAccess) {
      return Scaffold(
        backgroundColor: _themeService.isDarkMode
            ? ThemeService.darkBackground
            : ThemeService.lightBackground,
        appBar: AppBar(
          title: Text(
            'Shopping List',
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
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Premium Feature',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode
                        ? ThemeService.darkTextPrimary
                        : const Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Shopping lists are available with Premium.\nUpgrade now to unlock this feature!',
                  style: TextStyle(
                    fontSize: 16,
                    color: _themeService.isDarkMode
                        ? ThemeService.darkTextSecondary
                        : const Color(0xFF7F8C8D),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Premium Benefits List
                _buildBenefitItem(
                  '✨ Unlimited Recipe Generation',
                  'Generate as many recipes as you want',
                ),
                const SizedBox(height: 16),
                _buildBenefitItem(
                  '🛒 Shopping List Access',
                  'Full access to shopping list features',
                ),
                const SizedBox(height: 16),
                _buildBenefitItem(
                  '👥 Community Recipes',
                  'Access and share recipes with the community',
                ),
                const SizedBox(height: 16),
                _buildBenefitItem(
                  '📸 Unlimited Receipt Scanning',
                  'Scan as many receipts as you want',
                ),
                const SizedBox(height: 16),
                _buildBenefitItem(
                  '🎯 Priority Support',
                  'Get help faster when you need it',
                ),
                const SizedBox(height: 16),
                _buildBenefitItem(
                  '🚀 Future Features',
                  'First access to new premium features',
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _handleUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF2C3E50),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.workspace_premium, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

    // Show shopping list hub for premium users
    return Scaffold(
      backgroundColor: _themeService.isDarkMode
          ? ThemeService.darkBackground
          : ThemeService.lightBackground,
      appBar: AppBar(
        title: Text(
          'Shopping List',
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
              'Manage your shopping list and discover new recipes',
              style: TextStyle(
                fontSize: 16,
                color: _themeService.isDarkMode
                    ? ThemeService.darkTextSecondary
                    : const Color(0xFF7F8C8D),
              ),
            ),
            const SizedBox(height: 32),

            // My Shopping List Card
            _buildOptionCard(
              context,
              icon: Icons.shopping_cart_rounded,
              iconColor: const Color(0xFF3498DB),
              title: 'My Shopping List',
              description: 'View and manage your shopping items',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyShoppingListScreen()),
                );
              },
            ),

            const SizedBox(height: 16),

            // Generate AI Recipes Card
            _buildOptionCard(
              context,
              icon: Icons.auto_awesome,
              iconColor: const Color(0xFF27AE60),
              title: "Don't know what to make?",
              description: 'Generate recipe suggestions from your shopping list',
              onTap: _generateAIRecipesFromShopping,
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

  Widget _buildBenefitItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.check_circle,
            color: Color(0xFFFFD700),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _themeService.isDarkMode
                      ? ThemeService.darkTextPrimary
                      : const Color(0xFF2C3E50),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: _themeService.isDarkMode
                      ? ThemeService.darkTextSecondary
                      : const Color(0xFF7F8C8D),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_service.dart';

class CreateRecipeScreen extends StatefulWidget {
  const CreateRecipeScreen({super.key});

  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final ThemeService _themeService = ThemeService();
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController();

  final List<TextEditingController> _ingredientControllers = [TextEditingController()];
  final List<TextEditingController> _instructionControllers = [TextEditingController()];

  String _selectedCookingTool = 'any';
  String _selectedRecipeStyle = 'any';
  String _selectedCuisineType = 'any';
  bool _isAnonymous = false;
  bool _isSubmitting = false;

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
    _nameController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    for (var controller in _ingredientControllers) {
      controller.dispose();
    }
    for (var controller in _instructionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addIngredientField() {
    setState(() {
      _ingredientControllers.add(TextEditingController());
    });
  }

  void _removeIngredientField(int index) {
    if (_ingredientControllers.length > 1) {
      setState(() {
        _ingredientControllers[index].dispose();
        _ingredientControllers.removeAt(index);
      });
    }
  }

  void _addInstructionField() {
    setState(() {
      _instructionControllers.add(TextEditingController());
    });
  }

  void _removeInstructionField(int index) {
    if (_instructionControllers.length > 1) {
      setState(() {
        _instructionControllers[index].dispose();
        _instructionControllers.removeAt(index);
      });
    }
  }

  Future<void> _submitRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = _auth.currentUser!;
      
      // Collect ingredients and instructions
      final ingredients = _ingredientControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      
      final instructions = _instructionControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      // Create recipe document
      final recipeData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'ingredients': ingredients,
        'instructions': instructions,
        'prepTime': _prepTimeController.text.trim(),
        'cookTime': _cookTimeController.text.trim(),
        'servings': _servingsController.text.trim(),
        'cookingTool': _selectedCookingTool != 'any' ? _selectedCookingTool : null,
        'recipeStyle': _selectedRecipeStyle != 'any' ? _selectedRecipeStyle : null,
        'cuisineType': _selectedCuisineType != 'any' ? _selectedCuisineType : null,
        'authorId': user.uid,
        'authorName': _isAnonymous ? 'Anonymous' : (user.displayName ?? 'User'),
        'isAnonymous': _isAnonymous,
        'isUserCreated': true,
        'createdAt': FieldValue.serverTimestamp(),
        'ratings': [],
        'averageRating': 0.0,
        'totalRatings': 0,
        'comments': [],
        'saves': 0,
      };

      // Save to community recipes and get the document ID
      final communityRecipeDoc = await _db.collection('community_recipes').add(recipeData);
      final communityRecipeId = communityRecipeDoc.id;

      // Also save to user's personal recipes with the community recipe ID
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('saved_recipes')
          .add({
        ...recipeData,
        'communityRecipeId': communityRecipeId,
        'savedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe created successfully!'),
            backgroundColor: Color(0xFF27AE60),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create recipe: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    return Scaffold(
      backgroundColor: _themeService.isDarkMode 
          ? ThemeService.darkBackground 
          : ThemeService.lightBackground,
      appBar: AppBar(
        title: Text(
          'Create Recipe',
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Recipe Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Recipe Name *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: _themeService.isDarkMode 
                    ? ThemeService.darkBackground 
                    : Colors.grey[50],
              ),
              style: TextStyle(
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextPrimary 
                    : ThemeService.lightTextPrimary,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a recipe name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: _themeService.isDarkMode 
                    ? ThemeService.darkBackground 
                    : Colors.grey[50],
              ),
              style: TextStyle(
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextPrimary 
                    : ThemeService.lightTextPrimary,
              ),
            ),

            const SizedBox(height: 24),

            // Time and Servings Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    decoration: InputDecoration(
                      labelText: 'Prep Time',
                      hintText: 'e.g., 15min',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: _themeService.isDarkMode 
                          ? ThemeService.darkBackground 
                          : Colors.grey[50],
                    ),
                    style: TextStyle(
                      color: _themeService.isDarkMode 
                          ? ThemeService.darkTextPrimary 
                          : ThemeService.lightTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cookTimeController,
                    decoration: InputDecoration(
                      labelText: 'Cook Time',
                      hintText: 'e.g., 30min',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: _themeService.isDarkMode 
                          ? ThemeService.darkBackground 
                          : Colors.grey[50],
                    ),
                    style: TextStyle(
                      color: _themeService.isDarkMode 
                          ? ThemeService.darkTextPrimary 
                          : ThemeService.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _servingsController,
              decoration: InputDecoration(
                labelText: 'Servings',
                hintText: 'e.g., 4',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: _themeService.isDarkMode 
                    ? ThemeService.darkBackground 
                    : Colors.grey[50],
              ),
              style: TextStyle(
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextPrimary 
                    : ThemeService.lightTextPrimary,
              ),
            ),

            const SizedBox(height: 24),

            // Cooking Tool Selection
            Text(
              'Cooking Tool',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextPrimary 
                    : ThemeService.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip('Any', 'any', _selectedCookingTool, (value) => setState(() => _selectedCookingTool = value)),
                _buildChoiceChip('🍳 Pan', 'pan', _selectedCookingTool, (value) => setState(() => _selectedCookingTool = value)),
                _buildChoiceChip('🍚 Rice Cooker', 'rice_cooker', _selectedCookingTool, (value) => setState(() => _selectedCookingTool = value)),
                _buildChoiceChip('🔥 Air Fryer', 'air_fryer', _selectedCookingTool, (value) => setState(() => _selectedCookingTool = value)),
                _buildChoiceChip('🥘 Slow Cooker', 'slow_cooker', _selectedCookingTool, (value) => setState(() => _selectedCookingTool = value)),
                _buildChoiceChip('⚡ Instant Pot', 'instant_pot', _selectedCookingTool, (value) => setState(() => _selectedCookingTool = value)),
                _buildChoiceChip('🔥 Oven', 'oven', _selectedCookingTool, (value) => setState(() => _selectedCookingTool = value)),
                _buildChoiceChip('🍲 Pot', 'pot', _selectedCookingTool, (value) => setState(() => _selectedCookingTool = value)),
              ],
            ),

            const SizedBox(height: 24),

            // Recipe Style
            Text(
              'Recipe Style',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextPrimary 
                    : ThemeService.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip('Any', 'any', _selectedRecipeStyle, (value) => setState(() => _selectedRecipeStyle = value)),
                _buildChoiceChip('🎨 Creative', 'creative', _selectedRecipeStyle, (value) => setState(() => _selectedRecipeStyle = value)),
                _buildChoiceChip('👨‍🍳 Traditional', 'traditional', _selectedRecipeStyle, (value) => setState(() => _selectedRecipeStyle = value)),
                _buildChoiceChip('🥗 Healthy', 'healthy', _selectedRecipeStyle, (value) => setState(() => _selectedRecipeStyle = value)),
                _buildChoiceChip('⚡ Quick', 'quick', _selectedRecipeStyle, (value) => setState(() => _selectedRecipeStyle = value)),
                _buildChoiceChip('🏡 Comfort', 'comfort', _selectedRecipeStyle, (value) => setState(() => _selectedRecipeStyle = value)),
              ],
            ),

            const SizedBox(height: 24),

            // Cuisine Type
            Text(
              'Cuisine Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextPrimary 
                    : ThemeService.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip('Any', 'any', _selectedCuisineType, (value) => setState(() => _selectedCuisineType = value)),
                _buildChoiceChip('🥢 Asian', 'asian', _selectedCuisineType, (value) => setState(() => _selectedCuisineType = value)),
                _buildChoiceChip('🍔 American', 'american', _selectedCuisineType, (value) => setState(() => _selectedCuisineType = value)),
                _buildChoiceChip('🍝 Italian', 'italian', _selectedCuisineType, (value) => setState(() => _selectedCuisineType = value)),
                _buildChoiceChip('🌶️ Mexican', 'mexican', _selectedCuisineType, (value) => setState(() => _selectedCuisineType = value)),
                _buildChoiceChip('🍛 Indian', 'indian', _selectedCuisineType, (value) => setState(() => _selectedCuisineType = value)),
                _buildChoiceChip('🫒 Mediterranean', 'mediterranean', _selectedCuisineType, (value) => setState(() => _selectedCuisineType = value)),
              ],
            ),

            const SizedBox(height: 24),

            // Ingredients
            Text(
              'Ingredients *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextPrimary 
                    : ThemeService.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._ingredientControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: 'Ingredient ${index + 1}',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: _themeService.isDarkMode 
                              ? ThemeService.darkBackground 
                              : Colors.grey[50],
                        ),
                        style: TextStyle(
                          color: _themeService.isDarkMode 
                              ? ThemeService.darkTextPrimary 
                              : ThemeService.lightTextPrimary,
                        ),
                        validator: index == 0 
                            ? (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter at least one ingredient';
                                }
                                return null;
                              }
                            : null,
                      ),
                    ),
                    if (_ingredientControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeIngredientField(index),
                      ),
                  ],
                ),
              );
            }).toList(),
            TextButton.icon(
              onPressed: _addIngredientField,
              icon: const Icon(Icons.add),
              label: const Text('Add Ingredient'),
            ),

            const SizedBox(height: 24),

            // Instructions
            Text(
              'Instructions *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextPrimary 
                    : ThemeService.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._instructionControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Step ${index + 1}',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: _themeService.isDarkMode 
                              ? ThemeService.darkBackground 
                              : Colors.grey[50],
                        ),
                        style: TextStyle(
                          color: _themeService.isDarkMode 
                              ? ThemeService.darkTextPrimary 
                              : ThemeService.lightTextPrimary,
                        ),
                        validator: index == 0 
                            ? (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter at least one instruction';
                                }
                                return null;
                              }
                            : null,
                      ),
                    ),
                    if (_instructionControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeInstructionField(index),
                      ),
                  ],
                ),
              );
            }).toList(),
            TextButton.icon(
              onPressed: _addInstructionField,
              icon: const Icon(Icons.add),
              label: const Text('Add Step'),
            ),

            const SizedBox(height: 24),

            // Anonymous Toggle
            if (user != null && !user.isAnonymous)
              SwitchListTile(
                title: Text(
                  'Post Anonymously',
                  style: TextStyle(
                    color: _themeService.isDarkMode 
                        ? ThemeService.darkTextPrimary 
                        : ThemeService.lightTextPrimary,
                  ),
                ),
                subtitle: Text(
                  'Share this recipe without revealing your identity',
                  style: TextStyle(
                    color: _themeService.isDarkMode 
                        ? ThemeService.darkTextSecondary 
                        : ThemeService.lightTextSecondary,
                  ),
                ),
                value: _isAnonymous,
                onChanged: (value) => setState(() => _isAnonymous = value),
                activeColor: const Color(0xFF27AE60),
              ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitRecipe,
                icon: _isSubmitting 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_rounded),
                label: Text(_isSubmitting ? 'Creating...' : 'Create Recipe'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
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
      selectedColor: const Color(0xFF27AE60).withOpacity(0.15),
      checkmarkColor: const Color(0xFF27AE60),
      backgroundColor: _themeService.isDarkMode ? ThemeService.darkBackground : Colors.grey[100],
      labelStyle: TextStyle(
        color: isSelected 
            ? const Color(0xFF27AE60)
            : (_themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? const Color(0xFF27AE60) : Colors.transparent,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}


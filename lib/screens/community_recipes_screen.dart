import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_service.dart';

class CommunityRecipesScreen extends StatefulWidget {
  const CommunityRecipesScreen({super.key});

  @override
  State<CommunityRecipesScreen> createState() => _CommunityRecipesScreenState();
}

class _CommunityRecipesScreenState extends State<CommunityRecipesScreen> {
  final ThemeService _themeService = ThemeService();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  
  String _sortBy = 'recent'; // recent, popular, top_rated
  String _cookingToolFilter = 'all';
  String _styleFilter = 'all';
  String _cuisineFilter = 'all';

  User? get user => _auth.currentUser;

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

  bool _matchesFilters(Map<String, dynamic> recipe) {
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

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
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
                        color: const Color(0xFF9B59B6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.filter_list, color: Color(0xFF9B59B6), size: 24),
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
                          'Sort By',
                          _sortBy,
                          ['recent', 'popular', 'top_rated'],
                          ['🕐 Recent', '🔖 Most Saved', '⭐ Top Rated'],
                          (value) => setSheetState(() => _sortBy = value),
                        ),
                        const SizedBox(height: 20),
                        _buildFilterSection(
                          'Cooking Tool',
                          _cookingToolFilter,
                          ['all', 'pan', 'rice_cooker', 'air_fryer', 'slow_cooker', 'instant_pot', 'oven', 'pot'],
                          ['All', '🍳 Pan', '🍚 Rice Cooker', '🔥 Air Fryer', '🥘 Slow Cooker', '⚡ Instant Pot', '🔥 Oven', '🍲 Pot'],
                          (value) => setSheetState(() => _cookingToolFilter = value),
                        ),
                  const SizedBox(height: 20),
                  _buildFilterSection(
                    'Recipe Style',
                    _styleFilter,
                    ['all', 'creative', 'traditional', 'healthy', 'quick', 'comfort'],
                    ['All', '🎨 Creative', '👨‍🍳 Traditional', '🥗 Healthy', '⚡ Quick', '🏡 Comfort'],
                    (value) => setSheetState(() => _styleFilter = value),
                  ),
                      const SizedBox(height: 20),
                      _buildFilterSection(
                        'Cuisine',
                        _cuisineFilter,
                        ['all', 'asian', 'american', 'italian', 'mexican', 'indian', 'mediterranean'],
                        ['All', '🥢 Asian', '🍔 American', '🍝 Italian', '🌶️ Mexican', '🍛 Indian', '🫒 Mediterranean'],
                        (value) => setSheetState(() => _cuisineFilter = value),
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _themeService.isDarkMode ? ThemeService.darkBackground : Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setSheetState(() {
                            _sortBy = 'recent';
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
                          backgroundColor: const Color(0xFF9B59B6),
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
              selectedColor: const Color(0xFF9B59B6).withOpacity(0.15),
              checkmarkColor: const Color(0xFF9B59B6),
              backgroundColor: _themeService.isDarkMode ? ThemeService.darkBackground : Colors.grey[100],
              labelStyle: TextStyle(
                color: isSelected 
                    ? const Color(0xFF9B59B6)
                    : (_themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF9B59B6) : Colors.transparent,
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

  Query<Map<String, dynamic>> _getQuery() {
    var query = _db.collection('community_recipes');
    
    switch (_sortBy) {
      case 'recent':
        return query.orderBy('createdAt', descending: true).limit(50);
      case 'popular':
        return query.orderBy('saves', descending: true).limit(50);
      case 'top_rated':
        return query.orderBy('averageRating', descending: true).limit(50);
      default:
        return query.orderBy('createdAt', descending: true).limit(50);
    }
  }

  Future<void> _rateRecipe(String recipeId, Map<String, dynamic> recipeData, double rating) async {
    if (user == null || user!.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guest users cannot rate recipes')),
      );
      return;
    }

    try {
      final recipeRef = _db.collection('community_recipes').doc(recipeId);
      final ratingsCollection = recipeRef.collection('ratings');
      
      // Check if user already rated
      final existingRating = await ratingsCollection.doc(user!.uid).get();
      
      if (existingRating.exists) {
        // Update existing rating
        await ratingsCollection.doc(user!.uid).update({
          'rating': rating,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Add new rating
        await ratingsCollection.doc(user!.uid).set({
          'userId': user!.uid,
          'rating': rating,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Recalculate average rating
      final allRatings = await ratingsCollection.get();
      double totalRating = 0;
      for (var doc in allRatings.docs) {
        totalRating += (doc.data()['rating'] as num).toDouble();
      }
      final averageRating = allRatings.docs.isNotEmpty ? totalRating / allRatings.docs.length : 0.0;

      // Update recipe with new average
      await recipeRef.update({
        'averageRating': averageRating,
        'totalRatings': allRatings.docs.length,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleSaveRecipe(String recipeId, Map<String, dynamic> recipeData) async {
    if (user == null) return;

    try {
      // Check if already saved
      final existing = await _db
          .collection('users')
          .doc(user!.uid)
          .collection('saved_recipes')
          .where('communityRecipeId', isEqualTo: recipeId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Unsave the recipe
        final savedRecipeId = existing.docs.first.id;
        await _db
            .collection('users')
            .doc(user!.uid)
            .collection('saved_recipes')
            .doc(savedRecipeId)
            .delete();

        // Decrement saves count
        await _db.collection('community_recipes').doc(recipeId).update({
          'saves': FieldValue.increment(-1),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe unsaved'),
              backgroundColor: Color(0xFF7F8C8D),
            ),
          );
        }
      } else {
        // Save to user's collection
        await _db
            .collection('users')
            .doc(user!.uid)
            .collection('saved_recipes')
            .add({
          ...recipeData,
          'communityRecipeId': recipeId,
          'savedAt': FieldValue.serverTimestamp(),
        });

        // Increment saves count
        await _db.collection('community_recipes').doc(recipeId).update({
          'saves': FieldValue.increment(1),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe saved!'),
              backgroundColor: Color(0xFF27AE60),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<bool> _isRecipeSaved(String recipeId) async {
    if (user == null) return false;
    
    final existing = await _db
        .collection('users')
        .doc(user!.uid)
        .collection('saved_recipes')
        .where('communityRecipeId', isEqualTo: recipeId)
        .limit(1)
        .get();

    return existing.docs.isNotEmpty;
  }

  void _showCommentsDialog(String recipeId, String recipeName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: _themeService.isDarkMode 
                ? ThemeService.darkCardBackground 
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _CommentsWidget(
            recipeId: recipeId,
            recipeName: recipeName,
            scrollController: scrollController,
          ),
        ),
      ),
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
          'Community Recipes',
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
        actions: [
          // Filter button with indicator
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFiltersBottomSheet,
                tooltip: 'Filter Recipes',
              ),
              if (_cookingToolFilter != 'all' || _styleFilter != 'all' || _cuisineFilter != 'all' || _sortBy != 'recent')
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF9B59B6),
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
        stream: _getQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(
                  color: _themeService.isDarkMode 
                      ? ThemeService.darkTextPrimary 
                      : ThemeService.lightTextPrimary,
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
              return _buildCommunityRecipeCard(doc.id, data);
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
              Icons.people_outline,
              size: 64,
              color: _themeService.isDarkMode 
                  ? ThemeService.darkTextSecondary 
                  : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Community Recipes Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextPrimary 
                    : ThemeService.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share a recipe!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextSecondary 
                    : ThemeService.lightTextSecondary,
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
              color: _themeService.isDarkMode 
                  ? ThemeService.darkTextSecondary 
                  : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Recipes Match Filters',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextPrimary 
                    : ThemeService.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filter settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextSecondary 
                    : ThemeService.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showFiltersBottomSheet,
              icon: const Icon(Icons.filter_list),
              label: const Text('Change Filters'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9B59B6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityRecipeCard(String recipeId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Untitled Recipe';
    final authorName = data['authorName'] ?? 'Unknown';
    final isAnonymous = data['isAnonymous'] == true;
    final isUserCreated = data['isUserCreated'] == true;
    final averageRating = (data['averageRating'] ?? 0.0) as num;
    final totalRatings = data['totalRatings'] ?? 0;
    final saves = data['saves'] ?? 0;
    final description = data['description'] ?? '';
    final ingredients = (data['ingredients'] as List?)?.cast<String>() ?? [];
    final instructions = (data['instructions'] as List?)?.cast<String>() ?? [];
    final prepTime = data['prepTime'] ?? 'Unknown';
    final cookTime = data['cookTime'] ?? 'Unknown';
    final cookingTool = data['cookingTool'];
    final recipeStyle = data['recipeStyle'];

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
                : [Colors.white, const Color(0xFFF8F9FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF9B59B6).withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9B59B6).withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with author info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _themeService.isDarkMode 
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFF9B59B6).withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF9B59B6).withOpacity(0.2),
                    child: Icon(
                      isAnonymous ? Icons.person_off : Icons.person,
                      color: const Color(0xFF9B59B6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _themeService.isDarkMode 
                                ? ThemeService.darkTextPrimary 
                                : const Color(0xFF2C3E50),
                          ),
                        ),
                        if (isUserCreated)
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 12,
                                color: _themeService.isDarkMode 
                                    ? ThemeService.darkTextSecondary 
                                    : const Color(0xFF7F8C8D),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'User Created',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _themeService.isDarkMode 
                                      ? ThemeService.darkTextSecondary 
                                      : const Color(0xFF7F8C8D),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  FutureBuilder<bool>(
                    future: _isRecipeSaved(recipeId),
                    builder: (context, snapshot) {
                      final isSaved = snapshot.data ?? false;
                      return IconButton(
                        icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                        color: const Color(0xFF9B59B6),
                        onPressed: () => _toggleSaveRecipe(recipeId, data),
                        tooltip: isSaved ? 'Unsave Recipe' : 'Save Recipe',
                        iconSize: 24,
                      );
                    },
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipe Name
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _themeService.isDarkMode 
                          ? ThemeService.darkTextPrimary 
                          : const Color(0xFF2C3E50),
                    ),
                  ),
                  
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextSecondary 
                            : const Color(0xFF7F8C8D),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Stats Row
                  Row(
                    children: [
                      // Rating
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              totalRatings > 0 
                                  ? '${averageRating.toStringAsFixed(1)} ($totalRatings)'
                                  : 'No ratings',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _themeService.isDarkMode 
                                    ? ThemeService.darkTextPrimary 
                                    : Colors.amber[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Saves
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bookmark, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              '$saves saves',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _themeService.isDarkMode 
                                    ? ThemeService.darkTextPrimary 
                                    : Colors.green[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Time
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              cookTime != 'Unknown' ? '$prepTime + $cookTime' : prepTime,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _themeService.isDarkMode 
                                    ? ThemeService.darkTextPrimary 
                                    : Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (cookingTool != null && cookingTool != 'any')
                        _buildTag(_getCookingToolLabel(cookingTool), Colors.orange),
                      if (recipeStyle != null && recipeStyle != 'any')
                        _buildTag(_getStyleLabel(recipeStyle), Colors.purple),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Quick preview
                  Text(
                    '${ingredients.length} ingredients • ${instructions.length} steps',
                    style: TextStyle(
                      fontSize: 13,
                      color: _themeService.isDarkMode 
                          ? ThemeService.darkTextSecondary 
                          : const Color(0xFF7F8C8D),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRatingDialog(recipeId, data),
                          icon: const Icon(Icons.star_outline, size: 18),
                          label: const Text('Rate'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showCommentsDialog(recipeId, name),
                          icon: const Icon(Icons.comment_outlined, size: 18),
                          label: const Text('Comments'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _showFullRecipe(data),
                          icon: const Icon(Icons.menu_book, size: 18),
                          label: const Text('View'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF9B59B6),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _getCookingToolLabel(String tool) {
    switch (tool) {
      case 'pan': return '🍳 Pan';
      case 'rice_cooker': return '🍚 Rice Cooker';
      case 'air_fryer': return '🔥 Air Fryer';
      case 'slow_cooker': return '🥘 Slow Cooker';
      case 'instant_pot': return '⚡ Instant Pot';
      case 'oven': return '🔥 Oven';
      case 'pot': return '🍲 Pot';
      default: return tool;
    }
  }

  String _getStyleLabel(String style) {
    switch (style) {
      case 'creative': return '🎨 Creative';
      case 'traditional': return '👨‍🍳 Traditional';
      case 'healthy': return '🥗 Healthy';
      case 'quick': return '⚡ Quick';
      case 'comfort': return '🏡 Comfort';
      default: return style;
    }
  }

  void _showRatingDialog(String recipeId, Map<String, dynamic> data) {
    double selectedRating = 0;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _themeService.isDarkMode 
              ? ThemeService.darkCardBackground 
              : Colors.white,
          title: Text(
            'Rate this Recipe',
            style: TextStyle(
              color: _themeService.isDarkMode 
                  ? ThemeService.darkTextPrimary 
                  : ThemeService.lightTextPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tap a star to rate',
                style: TextStyle(
                  color: _themeService.isDarkMode 
                      ? ThemeService.darkTextSecondary 
                      : ThemeService.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    iconSize: 40,
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        selectedRating = (index + 1).toDouble();
                      });
                    },
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedRating > 0 
                  ? () {
                      Navigator.pop(context);
                      _rateRecipe(recipeId, data, selectedRating);
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9B59B6),
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullRecipe(Map<String, dynamic> data) {
    final name = data['name'] ?? 'Untitled Recipe';
    final ingredients = (data['ingredients'] as List?)?.cast<String>() ?? [];
    final instructions = (data['instructions'] as List?)?.cast<String>() ?? [];
    final prepTime = data['prepTime'] ?? 'Unknown';
    final cookTime = data['cookTime'] ?? 'Unknown';
    final servings = data['servings'] ?? '';

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
            color: _themeService.isDarkMode 
                ? ThemeService.darkCardBackground 
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode 
                      ? ThemeService.darkTextPrimary 
                      : const Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 18, color: Color(0xFFE67E22)),
                  const SizedBox(width: 6),
                  Text(
                    '$prepTime prep',
                    style: TextStyle(
                      color: _themeService.isDarkMode 
                          ? ThemeService.darkTextSecondary 
                          : const Color(0xFF7F8C8D),
                    ),
                  ),
                  if (cookTime != 'Unknown') ...[
                    const Text(' • '),
                    Text(
                      '$cookTime cook',
                      style: TextStyle(
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextSecondary 
                            : const Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                  if (servings.isNotEmpty) ...[
                    const Text(' • '),
                    Text(
                      '$servings servings',
                      style: TextStyle(
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextSecondary 
                            : const Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Ingredients',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode 
                      ? ThemeService.darkTextPrimary 
                      : const Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 12),
              ...ingredients.map((ingredient) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 7),
                          decoration: const BoxDecoration(
                            color: Color(0xFF9B59B6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ingredient,
                            style: TextStyle(
                              fontSize: 15,
                              color: _themeService.isDarkMode 
                                  ? ThemeService.darkTextSecondary 
                                  : const Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 24),
              Text(
                'Instructions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _themeService.isDarkMode 
                      ? ThemeService.darkTextPrimary 
                      : const Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 12),
              ...instructions.asMap().entries.map((entry) {
                final index = entry.key;
                final instruction = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFF9B59B6),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          instruction,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: _themeService.isDarkMode 
                                ? ThemeService.darkTextSecondary 
                                : const Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// Comments Widget
class _CommentsWidget extends StatefulWidget {
  final String recipeId;
  final String recipeName;
  final ScrollController scrollController;

  const _CommentsWidget({
    required this.recipeId,
    required this.recipeName,
    required this.scrollController,
  });

  @override
  State<_CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<_CommentsWidget> {
  final _commentController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _themeService = ThemeService();

  User? get user => _auth.currentUser;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (user == null || user!.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guest users cannot comment')),
      );
      return;
    }

    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    try {
      await _db
          .collection('community_recipes')
          .doc(widget.recipeId)
          .collection('comments')
          .add({
        'userId': user!.uid,
        'userName': user!.displayName ?? 'User',
        'comment': commentText,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
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
              Expanded(
                child: Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode 
                        ? ThemeService.darkTextPrimary 
                        : const Color(0xFF2C3E50),
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

        // Comments list
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _db
                .collection('community_recipes')
                .doc(widget.recipeId)
                .collection('comments')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final comments = snapshot.data?.docs ?? [];

              if (comments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: _themeService.isDarkMode 
                              ? ThemeService.darkTextSecondary 
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _themeService.isDarkMode 
                                ? ThemeService.darkTextPrimary 
                                : ThemeService.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(
                            color: _themeService.isDarkMode 
                                ? ThemeService.darkTextSecondary 
                                : ThemeService.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index].data();
                  final userName = comment['userName'] ?? 'User';
                  final commentText = comment['comment'] ?? '';
                  final timestamp = comment['createdAt'] as Timestamp?;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF9B59B6).withOpacity(0.2),
                          child: const Icon(Icons.person, size: 18, color: Color(0xFF9B59B6)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    userName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: _themeService.isDarkMode 
                                          ? ThemeService.darkTextPrimary 
                                          : const Color(0xFF2C3E50),
                                    ),
                                  ),
                                  if (timestamp != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTimestamp(timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _themeService.isDarkMode 
                                            ? ThemeService.darkTextSecondary 
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                commentText,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _themeService.isDarkMode 
                                      ? ThemeService.darkTextSecondary 
                                      : const Color(0xFF2C3E50),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        const Divider(height: 1),

        // Comment input
        Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: _themeService.isDarkMode 
                ? ThemeService.darkBackground 
                : Colors.grey[50],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF9B59B6).withOpacity(0.2),
                child: const Icon(Icons.person, size: 18, color: Color(0xFF9B59B6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(
                      color: _themeService.isDarkMode 
                          ? ThemeService.darkTextSecondary 
                          : ThemeService.lightTextSecondary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: _themeService.isDarkMode 
                        ? ThemeService.darkCardBackground 
                        : Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  style: TextStyle(
                    color: _themeService.isDarkMode 
                        ? ThemeService.darkTextPrimary 
                        : ThemeService.lightTextPrimary,
                  ),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF9B59B6)),
                onPressed: _postComment,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}
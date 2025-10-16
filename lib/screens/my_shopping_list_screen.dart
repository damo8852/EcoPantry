import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_service.dart';

class MyShoppingListScreen extends StatefulWidget {
  const MyShoppingListScreen({super.key});

  @override
  State<MyShoppingListScreen> createState() => _MyShoppingListScreenState();
}

class _MyShoppingListScreenState extends State<MyShoppingListScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _textController = TextEditingController();
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
    _textController.dispose();
    super.dispose();
  }

  Future<void> _addItem(String name) async {
    if (name.trim().isEmpty) return;

    try {
      await _db.collection('users').doc(user.uid).collection('shopping_list').add({
        'name': name.trim(),
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _textController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "$name.trim()" to shopping list'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleItem(String docId, bool isCompleted) async {
    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('shopping_list')
          .doc(docId)
          .update({'isCompleted': !isCompleted});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update item: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteItem(String docId) async {
    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('shopping_list')
          .doc(docId)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete item: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _editItem(String docId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Item name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(context).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.of(context).pop(newName);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result != currentName) {
      try {
        await _db
            .collection('users')
            .doc(user.uid)
            .collection('shopping_list')
            .doc(docId)
            .update({'name': result});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Updated item to "$result"'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update item: ${e.toString()}'),
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
      backgroundColor: _themeService.isDarkMode 
          ? ThemeService.darkBackground 
          : ThemeService.lightBackground,
      appBar: AppBar(
        title: Text(
          'My Shopping List',
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
      body: Column(
        children: [
          // Add item section
          Container(
            padding: const EdgeInsets.all(16),
            color: _themeService.isDarkMode 
                ? ThemeService.darkCardBackground 
                : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Add item to shopping list...',
                      hintStyle: TextStyle(
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextSecondary 
                            : ThemeService.lightTextSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _themeService.isDarkMode 
                              ? ThemeService.darkBorder 
                              : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _themeService.isDarkMode 
                              ? ThemeService.darkBorder 
                              : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF3498DB),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    onSubmitted: _addItem,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => _addItem(_textController.text),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          
          // Shopping list items
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('users')
                  .doc(user.uid)
                  .collection('shopping_list')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

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

                final items = snapshot.data?.docs ?? [];
                
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: _themeService.isDarkMode 
                              ? ThemeService.darkTextSecondary 
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your shopping list is empty',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _themeService.isDarkMode 
                                ? ThemeService.darkTextPrimary 
                                : ThemeService.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add items above to get started',
                          style: TextStyle(
                            color: _themeService.isDarkMode 
                                ? ThemeService.darkTextSecondary 
                                : ThemeService.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final doc = items[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name']?.toString() ?? '';
                    final isCompleted = data['isCompleted'] as bool? ?? false;
                    final docId = doc.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: _themeService.isDarkMode 
                          ? ThemeService.darkCardBackground 
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _themeService.isDarkMode 
                              ? ThemeService.darkBorder 
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: isCompleted,
                          onChanged: (value) => _toggleItem(docId, isCompleted),
                          activeColor: const Color(0xFF3498DB),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: isCompleted
                                ? (_themeService.isDarkMode 
                                    ? ThemeService.darkTextSecondary 
                                    : Colors.grey[600])
                                : (_themeService.isDarkMode 
                                    ? ThemeService.darkTextPrimary 
                                    : ThemeService.lightTextPrimary),
                            decoration: isCompleted 
                                ? TextDecoration.lineThrough 
                                : null,
                            fontSize: 16,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                color: _themeService.isDarkMode 
                                    ? ThemeService.darkTextSecondary 
                                    : Colors.grey[600],
                              ),
                              onPressed: () => _editItem(docId, name),
                              tooltip: 'Edit item',
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: _themeService.isDarkMode 
                                    ? ThemeService.darkTextSecondary 
                                    : Colors.grey[600],
                              ),
                              onPressed: () => _deleteItem(docId),
                              tooltip: 'Delete item',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

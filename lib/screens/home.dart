import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../services/auth.dart';
import '../services/notifications.dart';
import '../services/theme_service.dart';
import '../services/config_service.dart';
import '../widgets/item_tile.dart';
import '../models/grocery_type.dart';
import 'scan.dart';
import 'recipes_hub_screen.dart';
import 'collections_screen.dart';
import 'auth_gate.dart';
import 'grocery_stores_screen.dart';
import 'shopping_list_hub_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User get user => _auth.currentUser!;
  Set<GroceryType> _selectedFilters = {};
  late final ThemeService _themeService;
  bool _isSelectionMode = false;
  bool _isMultiSelectMode = false;
  Set<String> _selectedItems = {};
  bool _isFabMenuOpen = false;

  // Sorting options
  String _sortOption = 'expiry_asc';

  // Must contain filter
  String _mustContainText = '';

  // Search filter
  String _searchText = '';
  bool _showFrozenItems = false;
  bool _hideFrozenItems = true; // Default: hide frozen items

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



  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _isMultiSelectMode = _isSelectionMode;
      _selectedItems.clear();
    });
  }

  void _enterMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = true;
      _isSelectionMode = true;
      _selectedItems.clear();
    });
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _isSelectionMode = false;
      _selectedItems.clear();
    });
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
    });
  }

  /// Extract a numeric unit price from various stored representations.
  /// Returns `null` when price cannot be parsed.
  double? _extractPrice(dynamic price) {
    if (price == null) return null;
    // If numeric already, return as double
    if (price is num) return price.toDouble();

    // If the price was stored as a map/object (e.g. {'amount': 1.23, 'currency':'USD'})
    if (price is Map) {
      if (price['amount'] is num) return (price['amount'] as num).toDouble();
      if (price['amount'] is String) {
        final parsed = double.tryParse((price['amount'] as String).replaceAll(',', ''));
        if (parsed != null) return parsed;
      }
    }

    // If string, try to extract a number (handles $1.23, 1,23, 1.23 USD, etc.)
    if (price is String) {
      var s = price.trim();
      if (s.isEmpty) return null;

      // Remove common currency symbols and letters, keep digits, dot and comma and minus
      // Then prefer dot as decimal separator.
      // Examples: "$1.23" -> "1.23"  "1,234.56" -> "1234.56"  "1,23" -> "1.23"
      // First, find the first numeric token in the string
      final match = RegExp(r'-?\d+[\d,\.]*').firstMatch(s);
      if (match == null) return null;
      var token = match.group(0)!;
      // If contains both comma and dot, assume comma is thousands separator -> remove commas
      if (token.contains(',') && token.contains('.')) token = token.replaceAll(',', '');
      // If contains only commas (e.g. "1,23"), replace comma with dot for decimal
      else if (token.contains(',') && !token.contains('.')) token = token.replaceAll(',', '.');
      // Remove any remaining non-digit/dot/minus
      token = token.replaceAll(RegExp(r'[^0-9\.-]'), '');

      return double.tryParse(token);
    }

    // Could not parse
    return null;
  }

  void _deleteSelectedItems() async {
    if (_selectedItems.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Items'),
        content: Text('Are you sure you want to delete ${_selectedItems.length} item(s)?'),
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

    if (confirmed != true) return;

    // Store deleted items data for undo
    final deletedItems = <String, Map<String, dynamic>>{};
    for (final itemId in _selectedItems) {
      final docRef = _db.collection('users').doc(user.uid).collection('items').doc(itemId);
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        deletedItems[itemId] = docSnapshot.data() as Map<String, dynamic>;
      }
    }

    // Delete items
    final batch = _db.batch();
    for (final itemId in _selectedItems) {
      final docRef = _db.collection('users').doc(user.uid).collection('items').doc(itemId);
      batch.delete(docRef);
    }

    try {
      await batch.commit();
      final deletedCount = _selectedItems.length;
      setState(() {
        _selectedItems.clear();
        _isSelectionMode = false;
        _isMultiSelectMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $deletedCount items'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                // Restore deleted items
                final restoreBatch = _db.batch();
                for (final entry in deletedItems.entries) {
                  final docRef = _db.collection('users').doc(user.uid).collection('items').doc(entry.key);
                  restoreBatch.set(docRef, entry.value);
                }
                await restoreBatch.commit();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restored $deletedCount items')),
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete items: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }


  void _finishSelectedItems() async {
    if (_selectedItems.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish Selected Items'),
        content: Text('Are you sure you want to mark ${_selectedItems.length} item(s) as finished? These items will be moved to your finished items history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF27AE60),
            ),
            child: const Text('Finish'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Store finished items data and IDs for undo
    final finishedItemsData = <String, Map<String, dynamic>>{};
    final finishedItemsIds = <String, String>{}; // maps original item ID to finished_items doc ID

    final batch = _db.batch();
    final user = _auth.currentUser!;

    for (final itemId in _selectedItems) {
      final docRef = _db.collection('users').doc(user.uid).collection('items').doc(itemId);

      // Get the item data first
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        finishedItemsData[itemId] = data;

        // Move to finished_items collection
        final finishedItemsRef = _db
            .collection('users')
            .doc(user.uid)
            .collection('finished_items')
            .doc();

        finishedItemsIds[itemId] = finishedItemsRef.id;

  // Compute saved amount if price exists
  final unitPriceNum = _extractPrice(data['price']);
        final qtyNum = data['quantity'] is num ? (data['quantity'] as num).toDouble() : 1.0;
        final savedAmount = (unitPriceNum != null) ? (unitPriceNum * qtyNum) : 0.0;

        final finishedDocData = {
          'name': data['name'],
          'quantity': data['quantity'],
          'groceryType': data['groceryType'],
          'finishedAt': FieldValue.serverTimestamp(),
          'originalExpiryDate': data['expiryDate'],
          'savedAmount': savedAmount,
        };
        if (unitPriceNum != null) finishedDocData['price'] = unitPriceNum;
        if (data['currency'] != null) finishedDocData['currency'] = data['currency'];

        // Keep savedAmount in the local map for undo and later aggregation
        finishedItemsData[itemId] = {...data, 'savedAmount': savedAmount};

        batch.set(finishedItemsRef, finishedDocData);

        // Delete from main collection
        batch.delete(docRef);
      }
    }

    try {
      await batch.commit();

      // Aggregate total saved amount across the finished items we just created
      double totalSaved = 0.0;
      String currencySymbol = '';
      for (final v in finishedItemsData.values) {
        final saved = (v['savedAmount'] is num) ? (v['savedAmount'] as num).toDouble() : 0.0;
        totalSaved += saved;
        if (currencySymbol.isEmpty && v['currency'] != null) {
          currencySymbol = v['currency'].toString();
        }
      }

      // Update user's aggregate saved amount (atomic increment)
      if (totalSaved > 0) {
        await _db.collection('users').doc(user.uid).set({
          'moneySaved': FieldValue.increment(totalSaved),
        }, SetOptions(merge: true));
      }

      final finishedCount = _selectedItems.length;
      setState(() {
        _selectedItems.clear();
        _isSelectionMode = false;
        _isMultiSelectMode = false;
      });
      if (mounted) {
        final savedLabel = totalSaved > 0 ? ' — Saved ${currencySymbol.isNotEmpty ? currencySymbol : '\$'}${totalSaved.toStringAsFixed(2)}' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Finished $finishedCount items$savedLabel'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                // Restore items to main collection and remove from finished_items
                final undoBatch = _db.batch();
                for (final entry in finishedItemsData.entries) {
                  final itemId = entry.key;
                  final data = entry.value;

                  // Restore to main collection
                  final docRef = _db.collection('users').doc(user.uid).collection('items').doc(itemId);
                  undoBatch.set(docRef, data);

                  // Remove from finished_items
                  final finishedDocId = finishedItemsIds[itemId];
                  if (finishedDocId != null) {
                    final finishedDocRef = _db
                        .collection('users')
                        .doc(user.uid)
                        .collection('finished_items')
                        .doc(finishedDocId);
                    undoBatch.delete(finishedDocRef);
                  }
                }
                await undoBatch.commit();

                // Decrement the user's aggregate saved amount if we previously incremented
                if (totalSaved > 0) {
                  await _db.collection('users').doc(user.uid).set({
                    'moneySaved': FieldValue.increment(-totalSaved),
                  }, SetOptions(merge: true));
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restored $finishedCount items')),
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to finish items: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _freezeSelectedItems() async {
    if (_selectedItems.isEmpty) return;

    final batch = _db.batch();
    final user = _auth.currentUser!;

    for (final itemId in _selectedItems) {
      final docRef = _db.collection('users').doc(user.uid).collection('items').doc(itemId);
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        // Store the original expiry date when freezing
        batch.update(docRef, {
          'isFrozen': true,
          'frozenAt': FieldValue.serverTimestamp(),
          'originalExpiryDate': data['expiryDate'], // Store original expiry date
        });
      }
    }

    try {
      await batch.commit();
      final frozenCount = _selectedItems.length;
      setState(() {
        _selectedItems.clear();
        _isSelectionMode = false;
        _isMultiSelectMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Froze $frozenCount items'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to freeze items: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _unfreezeSelectedItems() async {
    if (_selectedItems.isEmpty) return;

    final batch = _db.batch();
    final user = _auth.currentUser!;

    for (final itemId in _selectedItems) {
      final docRef = _db.collection('users').doc(user.uid).collection('items').doc(itemId);
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        // Restore original expiry date when unfreezing, or keep current if no original stored
        final updates = <String, dynamic>{
          'isFrozen': false,
          'unfrozenAt': FieldValue.serverTimestamp(),
        };

        // If there's an original expiry date stored, restore it
        if (data['originalExpiryDate'] != null) {
          updates['expiryDate'] = data['originalExpiryDate'];
          updates['originalExpiryDate'] = FieldValue.delete(); // Remove the stored original date
        }

        batch.update(docRef, updates);
      }
    }

    try {
      await batch.commit();
      final unfrozenCount = _selectedItems.length;
      setState(() {
        _selectedItems.clear();
        _isSelectionMode = false;
        _isMultiSelectMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unfroze $unfrozenCount items'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unfreeze items: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _selectAllVisibleItems() {
    // This will be called from the app bar, but we need access to the current docs
    // We'll use a different approach - store the current docs in a variable
    if (_currentSortedDocs != null) {
      setState(() {
        if (_selectedItems.length == _currentSortedDocs!.length) {
          _selectedItems.clear();
        } else {
          _selectedItems = _currentSortedDocs!.map((doc) => doc.id).toSet();
        }
      });
    }
  }

  int _getCurrentItemsCount() {
    return _currentSortedDocs?.length ?? 0;
  }

  bool _hasFrozenSelectedItems() {
    if (_selectedItems.isEmpty || _currentSortedDocs == null) return false;

    for (final doc in _currentSortedDocs!) {
      if (_selectedItems.contains(doc.id)) {
        final data = doc.data();
        if (data['isFrozen'] == true) {
          return true;
        }
      }
    }
    return false;
  }

  void _freezeItem(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) async {
    try {
      // Store the original expiry date when freezing
      await ref.update({
        'isFrozen': true,
        'frozenAt': FieldValue.serverTimestamp(),
        'originalExpiryDate': data['expiryDate'], // Store original expiry date
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Froze "${(data['name'] ?? 'Unknown').toString()}"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to freeze item: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _unfreezeItem(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) async {
    try {
      // Restore original expiry date when unfreezing, or keep current if no original stored
      final updates = <String, dynamic>{
        'isFrozen': false,
        'unfrozenAt': FieldValue.serverTimestamp(),
      };

      // If there's an original expiry date stored, restore it
      if (data['originalExpiryDate'] != null) {
        updates['expiryDate'] = data['originalExpiryDate'];
        updates['originalExpiryDate'] = FieldValue.delete(); // Remove the stored original date
      }

      await ref.update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unfroze "${(data['name'] ?? 'Unknown').toString()}"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unfreeze item: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // Store current sorted docs for select all functionality
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _currentSortedDocs;

  String _getSortDisplayName(String sortOption) {
    switch (sortOption) {
      case 'expiry_asc':
        return 'Expiry (Earliest First)';
      case 'expiry_desc':
        return 'Expiry (Latest First)';
      case 'name_asc':
        return 'Name (A-Z)';
      case 'name_desc':
        return 'Name (Z-A)';
      case 'quantity_asc':
        return 'Quantity (Low to High)';
      case 'quantity_desc':
        return 'Quantity (High to Low)';
      case 'type_asc':
        return 'Category (A-Z)';
      case 'type_desc':
        return 'Category (Z-A)';
      default:
        return 'Default';
    }
  }

  String _getFilterDisplayText() {
    final parts = <String>[];

    // Frozen items status
    if (_showFrozenItems) {
      parts.add('Only Frozen');
    } else if (_hideFrozenItems) {
      parts.add('Hide Frozen');
    } else {
      parts.add('Show All');
    }

    // Category filters
    if (_selectedFilters.isNotEmpty) {
      parts.add('${_selectedFilters.length} Categories');
    }

    // Text search
    if (_mustContainText.isNotEmpty) {
      parts.add('contains "$_mustContainText"');
    }

    parts.add(_getSortDisplayName(_sortOption));
    return parts.join(' • ');
  }

  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;

    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void _showCompactFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: _themeService.isDarkMode ? ThemeService.darkCardBackground : ThemeService.lightCardBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _themeService.isDarkMode ? ThemeService.darkBorder : ThemeService.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFF4A90E2),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Filters',
                      style: TextStyle(
                        color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Must contain text field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MUST CONTAIN',
                          style: TextStyle(
                            color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 1,
                      color: _themeService.isDarkMode ? ThemeService.darkBorder : ThemeService.lightBorder,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Enter text to filter items...',
                        hintStyle: TextStyle(
                          color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                        ),
                        suffixIcon: _mustContainText.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                                ),
                                onPressed: () {
                                  setState(() => _mustContainText = '');
                                  setDialogState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _themeService.isDarkMode ? ThemeService.darkBorder : ThemeService.lightBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _themeService.isDarkMode ? ThemeService.darkBorder : ThemeService.lightBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                        filled: true,
                        fillColor: _themeService.isDarkMode ? ThemeService.darkCardBackground : ThemeService.lightCardBackground,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      style: TextStyle(
                        color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
                      ),
                      onChanged: (value) {
                        setState(() => _mustContainText = value);
                        setDialogState(() {});
                      },
                      controller: TextEditingController(text: _mustContainText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Multi-column filters (scrollable)
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Categories Column
                        _buildFilterColumn(
                          'CATEGORIES',
                          Icons.category_rounded,
                          GroceryType.allTypes.map((type) => _FilterOption(
                            label: type.displayName,
                            icon: _getGroceryIcon(type),
                            color: _getGroceryColor(type),
                            isSelected: _selectedFilters.contains(type),
                            onTap: () {
                              setState(() {
                                if (_selectedFilters.contains(type)) {
                                  _selectedFilters.remove(type);
                                } else {
                                  _selectedFilters.add(type);
                                }
                              });
                              setDialogState(() {});
                            },
                          )).toList(),
                        ),
                        const SizedBox(height: 20),
                        // Frozen Items Filter
                        _buildFilterColumn(
                          'FROZEN ITEMS',
                          Icons.ac_unit_rounded,
                          [
                            _FilterOption(
                              label: 'Hide Frozen',
                              icon: Icons.visibility_off_rounded,
                              color: const Color(0xFF00BCD4),
                              isSelected: _hideFrozenItems && !_showFrozenItems,
                              onTap: () {
                                setState(() {
                                  _hideFrozenItems = true;
                                  _showFrozenItems = false;
                                });
                                setDialogState(() {});
                              },
                            ),
                            _FilterOption(
                              label: 'Show All Items',
                              icon: Icons.visibility_rounded,
                              color: const Color(0xFF00BCD4),
                              isSelected: !_hideFrozenItems && !_showFrozenItems,
                              onTap: () {
                                setState(() {
                                  _hideFrozenItems = false;
                                  _showFrozenItems = false;
                                });
                                setDialogState(() {});
                              },
                            ),
                            _FilterOption(
                              label: 'Only Frozen',
                              icon: Icons.ac_unit_rounded,
                              color: const Color(0xFF00BCD4),
                              isSelected: _showFrozenItems,
                              onTap: () {
                                setState(() {
                                  _showFrozenItems = true;
                                  _hideFrozenItems = false;
                                });
                                setDialogState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Sort Column
                        _buildFilterColumn(
                        'SORT BY',
                        Icons.sort_rounded,
                        [
                          _FilterOption(
                            label: 'Expiry (Earliest First)',
                            icon: Icons.schedule_rounded,
                            color: const Color(0xFF27AE60),
                            isSelected: _sortOption == 'expiry_asc',
                            onTap: () {
                              setState(() => _sortOption = 'expiry_asc');
                              setDialogState(() {});
                            },
                          ),
                          _FilterOption(
                            label: 'Expiry (Latest First)',
                            icon: Icons.schedule_rounded,
                            color: const Color(0xFF27AE60),
                            isSelected: _sortOption == 'expiry_desc',
                            onTap: () {
                              setState(() => _sortOption = 'expiry_desc');
                              setDialogState(() {});
                            },
                          ),
                          _FilterOption(
                            label: 'Name (A-Z)',
                            icon: Icons.sort_by_alpha_rounded,
                            color: const Color(0xFF27AE60),
                            isSelected: _sortOption == 'name_asc',
                            onTap: () {
                              setState(() => _sortOption = 'name_asc');
                              setDialogState(() {});
                            },
                          ),
                          _FilterOption(
                            label: 'Name (Z-A)',
                            icon: Icons.sort_by_alpha_rounded,
                            color: const Color(0xFF27AE60),
                            isSelected: _sortOption == 'name_desc',
                            onTap: () {
                              setState(() => _sortOption = 'name_desc');
                              setDialogState(() {});
                            },
                          ),
                          _FilterOption(
                            label: 'Quantity (Low to High)',
                            icon: Icons.inventory_2_rounded,
                            color: const Color(0xFF27AE60),
                            isSelected: _sortOption == 'quantity_asc',
                            onTap: () {
                              setState(() => _sortOption = 'quantity_asc');
                              setDialogState(() {});
                            },
                          ),
                          _FilterOption(
                            label: 'Quantity (High to Low)',
                            icon: Icons.inventory_2_rounded,
                            color: const Color(0xFF27AE60),
                            isSelected: _sortOption == 'quantity_desc',
                            onTap: () {
                              setState(() => _sortOption = 'quantity_desc');
                              setDialogState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20), // Bottom padding for scrollable content
                    ],
                  ),
                ),
              ),
            ),
            ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterColumn(String title, IconData titleIcon, List<_FilterOption> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              titleIcon,
              color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 1,
          color: _themeService.isDarkMode ? ThemeService.darkBorder : ThemeService.lightBorder,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) => _buildFilterChip(option)).toList(),
        ),
      ],
    );
  }

  Widget _buildFilterChip(_FilterOption option) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: option.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: option.isSelected
                ? option.color.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: option.isSelected
                  ? option.color
                  : (_themeService.isDarkMode ? ThemeService.darkBorder : ThemeService.lightBorder),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                color: option.color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                option.label,
                style: TextStyle(
                  color: option.isSelected
                      ? option.color
                      : (_themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary),
                  fontSize: 12,
                  fontWeight: option.isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
  ) {
    return List.from(items)..sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      switch (_sortOption) {
        case 'expiry_asc':
          final expiryA = (dataA['expiryDate'] as Timestamp?)?.toDate();
          final expiryB = (dataB['expiryDate'] as Timestamp?)?.toDate();
          if (expiryA == null && expiryB == null) return 0;
          if (expiryA == null) return 1;
          if (expiryB == null) return -1;
          return expiryA.compareTo(expiryB);

        case 'expiry_desc':
          final expiryA = (dataA['expiryDate'] as Timestamp?)?.toDate();
          final expiryB = (dataB['expiryDate'] as Timestamp?)?.toDate();
          if (expiryA == null && expiryB == null) return 0;
          if (expiryA == null) return -1;
          if (expiryB == null) return 1;
          return expiryB.compareTo(expiryA);

        case 'name_asc':
          return (dataA['name'] ?? '').toString().toLowerCase()
              .compareTo((dataB['name'] ?? '').toString().toLowerCase());

        case 'name_desc':
          return (dataB['name'] ?? '').toString().toLowerCase()
              .compareTo((dataA['name'] ?? '').toString().toLowerCase());

        case 'quantity_asc':
          final qtyA = (dataA['quantity'] ?? 0) as num;
          final qtyB = (dataB['quantity'] ?? 0) as num;
          return qtyA.compareTo(qtyB);

        case 'quantity_desc':
          final qtyA = (dataA['quantity'] ?? 0) as num;
          final qtyB = (dataB['quantity'] ?? 0) as num;
          return qtyB.compareTo(qtyA);

        case 'type_asc':
          return (dataA['groceryType'] ?? 'other').toString()
              .compareTo((dataB['groceryType'] ?? 'other').toString());

        case 'type_desc':
          return (dataB['groceryType'] ?? 'other').toString()
              .compareTo((dataA['groceryType'] ?? 'other').toString());

        default:
          return 0;
      }
    });
  }

  IconData _getGroceryIcon(GroceryType type) {
    switch (type) {
      case GroceryType.meat:
        return Icons.restaurant_rounded;
      case GroceryType.poultry:
        return Icons.egg_rounded;
      case GroceryType.seafood:
        return Icons.set_meal_rounded;
      case GroceryType.vegetable:
        return Icons.eco_rounded;
      case GroceryType.fruit:
        return Icons.apple_rounded;
      case GroceryType.dairy:
        return Icons.local_drink_rounded;
      case GroceryType.grain:
        return Icons.grain_rounded;
      case GroceryType.beverage:
        return Icons.local_cafe_rounded;
      case GroceryType.snack:
        return Icons.cookie_rounded;
      case GroceryType.condiment:
        return Icons.local_fire_department_rounded;
      case GroceryType.frozen:
        return Icons.ac_unit_rounded;
      case GroceryType.other:
        return Icons.inventory_rounded;
    }
  }

  Color _getGroceryColor(GroceryType type) {
    switch (type) {
      case GroceryType.meat:
        return const Color(0xFFE74C3C);
      case GroceryType.poultry:
        return const Color(0xFFF39C12);
      case GroceryType.seafood:
        return const Color(0xFF3498DB);
      case GroceryType.vegetable:
        return const Color(0xFF27AE60);
      case GroceryType.fruit:
        return const Color(0xFFE91E63);
      case GroceryType.dairy:
        return const Color(0xFF9B59B6);
      case GroceryType.grain:
        return const Color(0xFF8E44AD);
      case GroceryType.beverage:
        return const Color(0xFF1ABC9C);
      case GroceryType.snack:
        return const Color(0xFFF1C40F);
      case GroceryType.condiment:
        return const Color(0xFFFF5722);
      case GroceryType.frozen:
        return const Color(0xFF00BCD4);
      case GroceryType.other:
        return const Color(0xFF95A5A6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.isDarkMode ? ThemeService.darkBackground : ThemeService.lightBackground,
      appBar: AppBar(
        title: (_isSelectionMode || _isMultiSelectMode)
          ? Row(
              children: [
                Text(
                  '${_selectedItems.length} selected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const SizedBox(width: 12),
                Text(
                  'My Pantry',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
                  ),
                ),
              ],
            ),
        backgroundColor: _themeService.isDarkMode ? ThemeService.darkBackground : ThemeService.lightBackground,
        elevation: 0,
        leading: (_isSelectionMode || _isMultiSelectMode) ? IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
          ),
          onPressed: _exitMultiSelectMode,
          tooltip: 'Exit selection',
        ) : Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu,
              color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        actions: (_isSelectionMode || _isMultiSelectMode) ? [
          // Use a single overflow menu button for all actions
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
            ),
            tooltip: 'Actions',
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'select_all',
                child: Row(
                  children: [
                    Icon(
                      Icons.select_all_rounded,
                      color: _themeService.isDarkMode ? const Color(0xFF7BB3F0) : const Color(0xFF4A90E2),
                    ),
                    const SizedBox(width: 12),
                    Text(_selectedItems.length == _getCurrentItemsCount() ? 'Deselect All' : 'Select All'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'finish',
                enabled: _selectedItems.isNotEmpty,
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: _selectedItems.isEmpty
                          ? (_themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary)
                          : (_themeService.isDarkMode ? const Color(0xFF81C784) : const Color(0xFF27AE60)),
                    ),
                    const SizedBox(width: 12),
                    Text('Finish Selected'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'prioritize',
                enabled: _selectedItems.isNotEmpty,
                child: Row(
                  children: [
                    Icon(
                      Icons.priority_high_rounded,
                      color: _selectedItems.isEmpty
                          ? (_themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary)
                          : (_themeService.isDarkMode ? const Color(0xFFE57373) : const Color(0xFFE74C3C)),
                    ),
                    const SizedBox(width: 12),
                    Text('Prioritize Selected'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'freeze',
                enabled: _selectedItems.isNotEmpty,
                child: Row(
                  children: [
                    Icon(
                      Icons.ac_unit_rounded,
                      color: _selectedItems.isEmpty
                          ? (_themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary)
                          : (_themeService.isDarkMode ? const Color(0xFF7BB3F0) : const Color(0xFF00BCD4)),
                    ),
                    const SizedBox(width: 12),
                    Text('Freeze Selected'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'unfreeze',
                enabled: _selectedItems.isNotEmpty && _hasFrozenSelectedItems(),
                child: Row(
                  children: [
                    Icon(
                      Icons.whatshot_rounded,
                      color: (_selectedItems.isEmpty || !_hasFrozenSelectedItems())
                          ? (_themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary)
                          : (_themeService.isDarkMode ? const Color(0xFF7BB3F0) : const Color(0xFF00BCD4)),
                    ),
                    const SizedBox(width: 12),
                    Text('Unfreeze Selected'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                enabled: _selectedItems.isNotEmpty,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_rounded,
                      color: _selectedItems.isEmpty
                          ? (_themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary)
                          : (_themeService.isDarkMode ? const Color(0xFFE57373) : const Color(0xFFE74C3C)),
                    ),
                    const SizedBox(width: 12),
                    Text('Delete Selected'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'select_all':
                  _selectAllVisibleItems();
                  break;
                case 'finish':
                  _finishSelectedItems();
                  break;
                case 'prioritize':
                  _prioritizeSelectedItems();
                  break;
                case 'freeze':
                  _freezeSelectedItems();
                  break;
                case 'unfreeze':
                  _unfreezeSelectedItems();
                  break;
                case 'delete':
                  _deleteSelectedItems();
                  break;
              }
            },
          ),
        ] : [
          IconButton(
            icon: const Icon(Icons.checklist),
            onPressed: _enterMultiSelectMode,
            tooltip: 'Select items',
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: _themeService.isDarkMode
            ? ThemeService.darkBackground
            : ThemeService.lightBackground,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Custom header - simplified without background
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    // Logo/Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF27AE60),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // App name and tagline
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EcoPantry',
                            style: TextStyle(
                              color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Reduce waste, save the planet',
                            style: TextStyle(
                              color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // APP header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: Text(
                  'APP',
                  style: TextStyle(
                    color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              // Recipes
              _buildDrawerItem(
                icon: Icons.restaurant_menu_rounded,
                title: 'Recipes',
                subtitle: 'Create, save & discover recipes',
                iconColor: const Color(0xFFE67E22),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipesHubScreen()));
                },
              ),

              // Shopping List
              _buildDrawerItem(
                icon: Icons.shopping_cart_rounded,
                title: 'Shopping List',
                subtitle: 'Manage your shopping list & find recipes',
                iconColor: const Color(0xFF3498DB),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListHubScreen()));
                },
              ),

              // Collections
              _buildDrawerItem(
                icon: Icons.collections_rounded,
                title: 'Collections',
                subtitle: 'View finished, frozen, or priority items',
                iconColor: const Color(0xFF9B59B6),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionsScreen()));
                },
              ),

              // Settings
              _buildDrawerItem(
                icon: Icons.settings_rounded,
                title: 'Settings',
                subtitle: 'App preferences & configuration',
                iconColor: const Color(0xFF4A90E2),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                },
              ),

              const SizedBox(height: 8),

              // Account header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ACCOUNT',
                    style: TextStyle(
                      color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              // User info
              _buildDrawerItem(
                icon: Icons.person_rounded,
                title: user.isAnonymous ? 'Guest User' : (user.displayName ?? 'User'),
                subtitle: user.email ?? 'Not signed in',
                iconColor: const Color(0xFF9B59B6),
                onTap: null,
              ),

              // Logout
              _buildDrawerItem(
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                iconColor: const Color(0xFFE74C3C),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
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
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await AuthService.instance.signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const AuthGate()),
                        (route) => false,
                      );
                    }
                  }
                },
              ),

              // Impact header and Carbon card
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'IMPACT',
                    style: TextStyle(
                      color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildCarbonSavingsCard(),
              ),

              // Footer message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: _themeService.isDarkMode ? ThemeService.darkBorder : ThemeService.lightBorder,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.eco_rounded,
                      size: 16,
                      color: Color(0xFF27AE60),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Making a difference, one meal at a time',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: TextStyle(
                          color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
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
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: Platform.isAndroid
              ? MediaQuery.of(context).viewPadding.bottom > 0
                  ? 8.0  // Add extra padding if there's a navigation bar
                  : 0.0
              : 0.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Scan Receipt button
            AnimatedScale(
              scale: _isFabMenuOpen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: _isFabMenuOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9B59B6), Color(0xFF8E44AD)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9B59B6).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Scan Receipt',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9B59B6), Color(0xFF8E44AD)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9B59B6).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: FloatingActionButton(
                          onPressed: () {
                            setState(() => _isFabMenuOpen = false);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ScanPage()),
                            );
                          },
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          heroTag: "scan_fab",
                          child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Kroger Integration button
            AnimatedScale(
              scale: _isFabMenuOpen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: _isFabMenuOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF27AE60), Color(0xFF229954)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF27AE60).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Grocery Stores',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF27AE60), Color(0xFF229954)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF27AE60).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: FloatingActionButton(
                          onPressed: () {
                            setState(() => _isFabMenuOpen = false);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const GroceryStoresScreen()),
                            );
                          },
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          heroTag: "grocery_stores_fab",
                          child: const Icon(Icons.store_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Manual Input button
            AnimatedScale(
              scale: _isFabMenuOpen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: _isFabMenuOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3498DB).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Manual Input',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3498DB).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: FloatingActionButton(
                          onPressed: () {
                            setState(() => _isFabMenuOpen = false);
                            _addItemDialog();
                          },
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          heroTag: "manual_fab",
                          child: const Icon(Icons.edit_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Main Add button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: _isFabMenuOpen
                      ? [const Color(0xFFE74C3C), const Color(0xFFC0392B)]
                      : [const Color(0xFF4A90E2), const Color(0xFF357ABD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isFabMenuOpen ? const Color(0xFFE74C3C) : const Color(0xFF4A90E2)).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () {
                  setState(() => _isFabMenuOpen = !_isFabMenuOpen);
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                heroTag: "add_fab",
                icon: AnimatedRotation(
                  turns: _isFabMenuOpen ? 0.125 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isFabMenuOpen ? Icons.close_rounded : Icons.add_rounded,
                    color: Colors.white,
                  ),
                ),
                label: Text(
                  _isFabMenuOpen ? 'Close' : 'Add Items',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection('users')
                  .doc(user.uid)
                  .collection('items')
                  .orderBy('expiryDate')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;

                // Filter items by frozen status, grocery type, must contain text, and search
                final filteredDocs = docs.where((doc) {
                  final data = doc.data();

                  // Filter frozen items based on filter settings
                  final isFrozen = data['isFrozen'] == true;
                  if (_showFrozenItems) {
                    // Show only frozen items
                    if (!isFrozen) return false;
                  } else if (_hideFrozenItems) {
                    // Hide frozen items
                    if (isFrozen) return false;
                  }
                  // If neither flag is set, show all items (including frozen)

                  // Check grocery type filter
                  if (_selectedFilters.isNotEmpty) {
                    final groceryType = GroceryType.fromString(data['groceryType'] ?? 'other');
                    if (!_selectedFilters.contains(groceryType)) {
                      return false;
                    }
                  }

                  // Check search text (prioritize over mustContainText)
                  final searchQuery = _searchText.isNotEmpty ? _searchText : _mustContainText;
                  if (searchQuery.isNotEmpty) {
                    final itemName = (data['name'] ?? '').toString().toLowerCase();
                    if (!itemName.contains(searchQuery.toLowerCase())) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                // Sort the filtered items
                final sortedDocs = _sortItems(filteredDocs);

                // Store current sorted docs for select all functionality
                _currentSortedDocs = sortedDocs;

                return CustomScrollView(
                  slivers: [
                    // Welcome section
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: _themeService.isDarkMode
                            ? const LinearGradient(
                                colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (_themeService.isDarkMode ? const Color(0xFF2C3E50) : const Color(0xFF667eea)).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hi, ${user.isAnonymous ? 'Guest' : (user.displayName ?? 'you')}! 👋',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manage your fridge items',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Search Bar
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        decoration: BoxDecoration(
                          color: _themeService.isDarkMode ? ThemeService.darkCardBackground : ThemeService.lightCardBackground,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(_themeService.isDarkMode ? 0.2 : 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          onChanged: (value) => setState(() => _searchText = value),
                          style: TextStyle(
                            color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search items...',
                            hintStyle: TextStyle(
                              color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                            ),
                            suffixIcon: _searchText.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                                  ),
                                  onPressed: () => setState(() => _searchText = ''),
                                )
                              : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),

                    // Filter Button
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _themeService.isDarkMode ? ThemeService.darkCardBackground : ThemeService.lightCardBackground,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(_themeService.isDarkMode ? 0.2 : 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showCompactFilters(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.tune_rounded,
                                      color: Color(0xFF4A90E2),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _getFilterDisplayText(),
                                        style: TextStyle(
                                          color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Items list or empty state
                    if (docs.isEmpty)
                      SliverFillRemaining(
                        child: _EmptyState(isDarkMode: _themeService.isDarkMode),
                      )
                    else if (filteredDocs.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No items found for this filter',
                            style: TextStyle(
                              color: _themeService.isDarkMode ? const Color(0xFF9E9E9E) : const Color(0xFF7F8C8D),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(top: 1),
                        sliver: SliverList.separated(
                        itemCount: sortedDocs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final ref = sortedDocs[i].reference;
                          final data = sortedDocs[i].data();
                          final groceryType = GroceryType.fromString(data['groceryType'] ?? 'other');
                          final itemId = sortedDocs[i].id;
                          final isSelected = _selectedItems.contains(itemId);

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: _themeService.isDarkMode ? ThemeService.darkCardBackground : ThemeService.lightCardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: _isSelectionMode && isSelected
                                ? Border.all(color: const Color(0xFF27AE60), width: 2)
                                : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(_themeService.isDarkMode ? 0.2 : 0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _isSelectionMode
                              ? ListTile(
                                  leading: Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => _toggleItemSelection(itemId),
                                    activeColor: const Color(0xFF27AE60),
                                  ),
                                  title: Text(
                                    (data['name'] ?? 'Unknown').toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _themeService.isDarkMode ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                                    ),
                                  ),
                                  subtitle: Text(
                                     'Qty: ${data['quantity'] ?? 1} • ${groceryType.displayName}',
                                    style: TextStyle(
                                      color: _themeService.isDarkMode ? ThemeService.darkTextSecondary : const Color(0xFF7F8C8D),
                                    ),
                                  ),
                                  onTap: () => _toggleItemSelection(itemId),
                                )
                              : ItemTile(
                                  name: (data['name'] ?? 'Unknown').toString(),
                                  expiry: (data['expiryDate'] as Timestamp?)?.toDate(),
                                  quantity: (data['quantity'] ?? 1),
                                  groceryType: groceryType,
                                  isDarkMode: _themeService.isDarkMode,
                                  isSelectionMode: _isSelectionMode,
                                  isSelected: _selectedItems.contains(itemId),
                                  isFrozen: data['isFrozen'] == true,
                                  isCompactView: _themeService.isCompactView,
                                  usagePercentage: (data['usagePercentage'] ?? 100.0).toDouble(),
                                  onEdit: () => _editItemDialog(ref, data),
                                  onUsedHalf: () async {
                                    final currentPercentage = (data['usagePercentage'] ?? 100.0).toDouble();
                                    final newPercentage = (currentPercentage / 2).clamp(0.0, 100.0);
                                    await ref.update({
                                      'usagePercentage': newPercentage,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                  },
                                  onFinish: () async {
                                    // Store item data for undo
                                    final docSnapshot = await ref.get();
                                    if (!docSnapshot.exists) return;

                                    final data = docSnapshot.data() as Map<String, dynamic>;
                                    final itemName = (data['name'] ?? 'Unknown').toString();
                                    final user = _auth.currentUser!;
                                    final itemId = ref.id;

                                    // Move to finished_items collection
                                    final finishedItemsRef = _db
                                        .collection('users')
                                        .doc(user.uid)
                                        .collection('finished_items')
                                        .doc();

                                    // Compute saved amount if price exists
                                    final unitPriceNum = _extractPrice(data['price']);
                                    final qtyNum = data['quantity'] is num ? (data['quantity'] as num).toDouble() : 1.0;
                                    final savedAmount = (unitPriceNum != null) ? (unitPriceNum * qtyNum) : 0.0;

                                    final finishedDoc = {
                                      'name': data['name'],
                                      'quantity': data['quantity'],
                                      'groceryType': data['groceryType'],
                                      'finishedAt': FieldValue.serverTimestamp(),
                                      'originalExpiryDate': data['expiryDate'],
                                      'savedAmount': savedAmount,
                                    };
                                    if (unitPriceNum != null) finishedDoc['price'] = unitPriceNum;
                                    if (data['currency'] != null) finishedDoc['currency'] = data['currency'];

                                    await finishedItemsRef.set(finishedDoc);

                                    // Delete from main collection
                                    await ref.delete();

                                    // Increment user's aggregate saved amount
                                    if (savedAmount > 0) {
                                      await _db.collection('users').doc(user.uid).set({
                                        'moneySaved': FieldValue.increment(savedAmount),
                                      }, SetOptions(merge: true));
                                    }

                                    // Show undo snackbar
                                    if (mounted) {
                                      final savedLabel = savedAmount > 0 ? ' — Saved ${data['currency'] ?? '\$'}${savedAmount.toStringAsFixed(2)}' : '';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Finished "' + itemName + '"' + savedLabel),
                                          duration: const Duration(seconds: 3),
                                          action: SnackBarAction(
                                            label: 'Undo',
                                            onPressed: () async {
                                              // Restore to main collection
                                              final docRef = _db.collection('users').doc(user.uid).collection('items').doc(itemId);
                                              await docRef.set(data);

                                              // Remove from finished_items
                                              await finishedItemsRef.delete();


                                              // Decrement user's aggregate saved amount if we incremented
                                              if (savedAmount > 0) {
                                                await _db.collection('users').doc(user.uid).set({
                                                  'moneySaved': FieldValue.increment(-savedAmount),
                                                }, SetOptions(merge: true));
                                              }

                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Restored "$itemName"')),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  onRemove: () async {
                                    // Store item data for undo
                                    final docSnapshot = await ref.get();
                                    if (!docSnapshot.exists) return;

                                    final data = docSnapshot.data() as Map<String, dynamic>;
                                    final itemName = (data['name'] ?? 'Unknown').toString();
                                    final itemId = ref.id;

                                    // Delete the item
                                    await ref.delete();

                                    // Show undo snackbar
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Deleted "$itemName"'),
                                          duration: const Duration(seconds: 3),
                                          action: SnackBarAction(
                                            label: 'Undo',
                                            onPressed: () async {
                                              // Restore the item
                                              final docRef = _db.collection('users').doc(user.uid).collection('items').doc(itemId);
                                              await docRef.set(data);

                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Restored "$itemName"')),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  onSelectMultiple: () {
                                    if (!_isSelectionMode) {
                                      _toggleSelectionMode();
                                      _toggleItemSelection(itemId);
                                    }
                                  },
                                  onPrioritize: () => _prioritizeItem(ref, data),
                                  onUnprioritize: () => _unprioritizeItem(ref, data),
                                  onFreeze: () => _freezeItem(ref, data),
                                  onUnfreeze: () => _unfreezeItem(ref, data),
                                  isPrioritized: data['isPrioritized'] == true,
                                  onSelectionChanged: (selected) {
                                    if (selected) {
                                      _selectedItems.add(itemId);
                                    } else {
                                      _selectedItems.remove(itemId);
                                    }
                                    setState(() {});
                                  },
                                ),
                          );
                        },
                      ),
                      ),

                    // Bottom padding for FAB
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 120),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _addItemDialog() async {
    final nameCtrl = TextEditingController();
    bool isProcessing = false;

    Future<void> parseAndSave(StateSetter setLocal) async {
      final input = nameCtrl.text.trim();
      if (input.isEmpty) return;

      // Use LLM to parse the input text into individual items
      final prompt = '''Parse food items from text. Return ONLY JSON.

Examples:
"apples, bananas, milk" → {"items": [{"name": "apples", "quantity": 1, "type": "fruit", "days": 7}, {"name": "bananas", "quantity": 1, "type": "fruit", "days": 5}, {"name": "milk", "quantity": 1, "type": "dairy", "days": 7}]}
"2 chicken, bread" → {"items": [{"name": "chicken", "quantity": 2, "type": "poultry", "days": 3}, {"name": "bread", "quantity": 1, "type": "grain", "days": 7}]}

Types: meat, poultry, seafood, vegetable, fruit, dairy, grain, beverage, snack, condiment, frozen, other

Input: $input''';

      try {
        final configService = ConfigService();
        final apiKey = await configService.getOpenAiApiKey();
        if (apiKey == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OpenAI API key not configured')),
            );
          }
          return;
        }

        final response = await http.post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: json.encode({
            'model': 'gpt-4o-mini',
            'messages': [{'role': 'user', 'content': prompt}],
            'temperature': 0.1,
            'max_tokens': 1000,
            'response_format': {'type': 'json_object'},
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final result = data['choices']?[0]?['message']?['content']?.toString().trim();

          if (result != null) {
            final parsed = json.decode(result);
            final items = parsed['items'] as List?;

            if (items != null && items.isNotEmpty) {
              // Check for existing items
              final existingItems = await _db
                  .collection('users')
                  .doc(user.uid)
                  .collection('items')
                  .get();

              final existingNames = existingItems.docs
                  .map((doc) => (doc.data()['name'] ?? '').toString().toLowerCase())
                  .toSet();

              final batch = _db.batch();
              int addedCount = 0;
              final skippedItems = <String>[];

              for (final item in items) {
                final rawName = item['name']?.toString().trim() ?? '';
                if (rawName.isEmpty) continue;

                // Capitalize the name (title case)
                final name = _capitalizeWords(rawName);

                // Skip duplicates
                if (existingNames.contains(name.toLowerCase())) {
                  skippedItems.add(name);
                  continue;
                }

                final quantity = item['quantity'] as int? ?? 1;
                final days = item['days'] as int? ?? 5;
                final type = item['type']?.toString() ?? 'other';
                final expiry = DateTime.now().add(Duration(days: days));

                final ref = _db.collection('users').doc(user.uid).collection('items').doc();
                batch.set(ref, {
                  'name': name,
                  'quantity': quantity,
                  'expiryDate': Timestamp.fromDate(expiry),
                  'groceryType': type,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'source': 'manual',
                });

                // Try to schedule notification (non-blocking - don't fail if permissions aren't granted)
                try {
                  await NotificationsService.instance.scheduleExpiryReminder(
                    id: ref.id.hashCode,
                    title: 'Use soon: $name',
                    body: 'Expires tomorrow',
                    when: expiry.subtract(const Duration(days: 1)),
                  );
                } catch (e) {
                  print('Failed to schedule notification for $name: $e');
                  // Continue anyway - item should still be added even if notification fails
                }

                addedCount++;
              }

              await batch.commit();

              if (mounted) {
                String message = 'Added $addedCount item(s)';
                if (skippedItems.isNotEmpty) {
                  message += '\nSkipped duplicates: ${skippedItems.join(', ')}';
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: skippedItems.isNotEmpty ? Colors.orange : const Color(0xFF27AE60),
                  ),
                );
              }
            }
          }
        }
      } catch (e) {
        print('Error parsing items: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding items: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('Add Items'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item names',
                    hintText: 'e.g., apples, milk, 2 chicken',
                    helperText: 'Enter one or more items separated by commas',
                  ),
                  maxLines: 3,
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                Text(
                  'AI will automatically categorize items and predict expiry dates',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isProcessing ? null : () async {
                  try {
                    setLocal(() => isProcessing = true);
                    await parseAndSave(setLocal);
                  } finally {
                    setLocal(() => isProcessing = false);
                  }
                  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
                },
                child: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add'),
              ),
            ],
          );
        });
      },
    );
  }


  Future<void> _editItemDialog(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final nameCtrl = TextEditingController(text: (data['name'] ?? '').toString());
    DateTime expiry =
        (data['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 5));
    GroceryType selectedType = GroceryType.fromString(data['groceryType'] ?? 'other');
    double usagePercentage = (data['usagePercentage'] ?? 100.0).toDouble();

    Future<void> save() async {
      await ref.update({
        'name': nameCtrl.text.trim(),
        'expiryDate': Timestamp.fromDate(expiry),
        'groceryType': selectedType.name,
        'usagePercentage': usagePercentage,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('Edit Item'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                DropdownButtonFormField<GroceryType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Grocery Type'),
                  items: GroceryType.allTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) setLocal(() => selectedType = value);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: expiry.year < 9000 ? expiry : DateTime.now().add(const Duration(days: 5)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100), // Extended to 2100
                          );
                          if (picked != null) setLocal(() => expiry = picked);
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          expiry.year >= 9000
                              ? 'Never Expires'
                              : 'Expires ${expiry.toLocal().toString().split(' ').first}'
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => setLocal(() => expiry = DateTime(9999)),
                      child: const Text('Never'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Usage: ${usagePercentage.round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Slider(
                  value: usagePercentage,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${usagePercentage.round()}%',
                  onChanged: (value) => setLocal(() => usagePercentage = value),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context, rootNavigator: true).pop(), child: const Text('Cancel')),
              FilledButton(onPressed: () async {
                try {
                  await save();
                } catch (e) {
                  // Handle any errors during save, but still close the dialog
                  print('Error updating item: $e');
                }
                if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
              }, child: const Text('Save')),
            ],
          );
        });
      },
    );
  }


  Future<void> _prioritizeItem(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) async {
    final itemName = (data['name'] ?? 'Unknown').toString();

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prioritize Item'),
        content: Text('Prioritize "$itemName" for recipe suggestions? This will help generate recipes that use this item as a main ingredient.'),
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
            child: const Text('Prioritize'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Add priority flag to the item
    await ref.update({
      'isPrioritized': true,
      'prioritizedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$itemName" has been prioritized for recipe suggestions'),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    }
  }

  Future<void> _prioritizeSelectedItems() async {
    if (_selectedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prioritize Items'),
        content: Text('Mark ${_selectedItems.length} selected items as priority for recipe suggestions?'),
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
            child: const Text('Prioritize'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final batch = _db.batch();
      int successCount = 0;

      for (final itemId in _selectedItems) {
        try {
          final ref = _db.collection('users').doc(user.uid).collection('items').doc(itemId);
          batch.update(ref, {
            'isPrioritized': true,
            'prioritizedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          successCount++;
        } catch (e) {
          print('Error prioritizing item $itemId: $e');
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount items marked as priority'),
            backgroundColor: const Color(0xFFE74C3C),
          ),
        );
        _exitMultiSelectMode();
      }
    }
  }

  Future<void> _unprioritizeItem(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) async {
    final itemName = (data['name'] ?? 'Unknown').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Priority'),
        content: Text('Remove priority from "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.update({
        'isPrioritized': false,
        'prioritizedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Priority removed from "$itemName"'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  double _getCarbonFootprint(String groceryType) {
    // Carbon footprint in kg CO2 per kg of food (approximate values)
    switch (groceryType) {
      case 'meat':
        return 27.0; // Beef has highest carbon footprint
      case 'poultry':
        return 6.9; // Chicken
      case 'seafood':
        return 13.6; // Fish
      case 'dairy':
        return 3.2; // Dairy products
      case 'vegetable':
        return 2.0; // Vegetables
      case 'fruit':
        return 1.0; // Fruits
      case 'grain':
        return 1.4; // Grains
      case 'frozen':
        return 3.0; // Frozen foods (higher due to energy)
      default:
        return 2.5; // Average
    }
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _themeService.isDarkMode
                            ? ThemeService.darkTextPrimary
                            : ThemeService.lightTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _themeService.isDarkMode
                            ? ThemeService.darkTextSecondary
                            : ThemeService.lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: _themeService.isDarkMode
                      ? ThemeService.darkTextSecondary
                      : ThemeService.lightTextSecondary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCarbonValue(double carbonKg) {
    // Convert kg to lbs if user preference is set to lbs (1 kg = 2.20462 lbs)
    if (_themeService.useLbs) {
      final carbonLbs = carbonKg * 2.20462;
      return '${carbonLbs.toStringAsFixed(1)} lbs CO2';
    } else {
      return '${carbonKg.toStringAsFixed(1)} kg CO2';
    }
  }

  Widget _buildCarbonSavingsCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('users')
          .doc(user.uid)
          .collection('finished_items')
          .snapshots(),
      builder: (context, snapshot) {
        double carbonSaved = 0.0;
        int itemsFinished = 0;
        double moneySaved = 0.0;
        String currencySymbol = '\$';

        if (snapshot.hasData) {
          itemsFinished = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            final data = doc.data();
            final quantity = (data['quantity'] ?? 1) as num;
            final groceryType = data['groceryType'] ?? 'other';

            double carbonPerKg = _getCarbonFootprint(groceryType);
            carbonSaved += quantity * carbonPerKg * 0.5; // Assume average 0.5kg per item

            // Aggregate money saved: prefer explicit savedAmount, otherwise compute from price * qty
            double thisSaved = 0.0;
            if (data['savedAmount'] is num) {
              thisSaved = (data['savedAmount'] as num).toDouble();
            } else if (data['price'] != null) {
              final unit = _extractPrice(data['price']);
              final qty = (data['quantity'] is num) ? (data['quantity'] as num).toDouble() : 1.0;
              if (unit != null) thisSaved = unit * qty;
            }
            moneySaved += thisSaved;

            // Try to capture a currency symbol if present in the finished item
            if ((data['currency'] != null) && (currencySymbol == '\$')) {
              try {
                final c = data['currency'].toString();
                if (c.isNotEmpty) currencySymbol = c;
              } catch (_) {}
            }
          }
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF27AE60).withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Carbon Impact Saved',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatCarbonValue(carbonSaved),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'emissions avoided',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$itemsFinished',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'items finished',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Money saved row (below the main numbers) - show amount on the left, slightly larger
              const SizedBox(height: 12),
              if (moneySaved > 0.0) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left-aligned money saved amount (larger)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '💰 ',
                              style: TextStyle(fontSize: 18),
                            ),
                            Text(
                              '${currencySymbol}${moneySaved.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'money saved',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),

                    // Keep the rest of the card content aligned as before
                    const Spacer(),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }



}

class _EmptyState extends StatefulWidget {
  const _EmptyState({required this.isDarkMode});

  final bool isDarkMode;

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  double _carbonSaved = 0.0;
  int _itemsFinished = 0;
  bool _isLoading = true;
  late final ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService();
    _calculateCarbonSavings();
  }

  Future<void> _calculateCarbonSavings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Query for finished items (items that were consumed/used)
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('finished_items')
          .get();

      double totalCarbon = 0.0;
      int itemCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final qtyNum = (data['quantity'] is num) ? (data['quantity'] as num).toDouble() : 1.0;
        final groceryType = (data['groceryType'] ?? 'other').toString();

        double carbonPerKg;
        switch (groceryType) {
          case 'meat':
            carbonPerKg = 27.0;
            break;
          case 'poultry':
            carbonPerKg = 6.9;
            break;
          case 'seafood':
            carbonPerKg = 13.6;
            break;
          case 'dairy':
            carbonPerKg = 3.2;
            break;
          case 'vegetable':
            carbonPerKg = 2.0;
            break;
          case 'fruit':
            carbonPerKg = 1.0;
            break;
          case 'grain':
            carbonPerKg = 1.4;
            break;
          case 'frozen':
            carbonPerKg = 3.0;
            break;
          default:
            carbonPerKg = 2.5;
        }

        // Compute estimated carbon saved per item (assume avg 0.5kg per item)
        totalCarbon += qtyNum * carbonPerKg * 0.5;
        itemCount++;
      }

      if (mounted) {
        setState(() {
          _carbonSaved = totalCarbon;
          _itemsFinished = itemCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatCarbonValue(double carbonKg) {
    // Convert kg to lbs if user preference is set to lbs (1 kg = 2.20462 lbs)
    if (_themeService.useLbs) {
      final carbonLbs = carbonKg * 2.20462;
      return '${carbonLbs.toStringAsFixed(1)} lbs CO2';
    } else {
      return '${carbonKg.toStringAsFixed(1)} kg CO2';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty fridge icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? Colors.grey[800]
                    : const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.kitchen,
                size: 64,
                color: widget.isDarkMode
                    ? ThemeService.darkTextSecondary
                    : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your fridge is empty',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode
                    ? ThemeService.darkTextPrimary
                    : ThemeService.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start adding items to reduce food waste',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: widget.isDarkMode
                    ? ThemeService.darkTextSecondary
                    : ThemeService.lightTextSecondary,
              ),
            ),
            if (_itemsFinished > 0) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF27AE60), Color(0xFF229954)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.eco,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Impact So Far',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatCarbonValue(_carbonSaved),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'saved from $_itemsFinished items',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterOption {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  _FilterOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });
}


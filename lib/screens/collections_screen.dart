import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_service.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  final ThemeService _themeService = ThemeService();
  final _db = FirebaseFirestore.instance;

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

  Future<void> _showFinishedItemsHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final finishedItems = await _db
          .collection('users')
          .doc(user.uid)
          .collection('finished_items')
          .orderBy('finishedAt', descending: true)
          .get();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: _themeService.isDarkMode 
            ? ThemeService.darkCard 
            : ThemeService.lightCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF27AE60),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Finished Items History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextPrimary 
                            : ThemeService.lightTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${finishedItems.docs.length}',
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
              const Divider(),
              Expanded(
                child: finishedItems.docs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 80,
                              color: _themeService.isDarkMode 
                                  ? ThemeService.darkTextSecondary 
                                  : ThemeService.lightTextSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No finished items yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: _themeService.isDarkMode 
                                    ? ThemeService.darkTextSecondary 
                                    : ThemeService.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: finishedItems.docs.length,
                        itemBuilder: (context, index) {
                          final item = finishedItems.docs[index];
                          final data = item.data();
                          final name = data['name'] ?? 'Unknown';
                          final finishedAt = data['finishedAt'] as Timestamp?;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: _themeService.isDarkMode 
                                ? ThemeService.darkCardBackground 
                                : Colors.white,
                            child: ListTile(
                              leading: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF27AE60),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  color: _themeService.isDarkMode 
                                      ? ThemeService.darkTextPrimary 
                                      : ThemeService.lightTextPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: finishedAt != null
                                  ? Text(
                                      'Finished on ${_formatDate(finishedAt.toDate())}',
                                      style: TextStyle(
                                        color: _themeService.isDarkMode 
                                            ? ThemeService.darkTextSecondary 
                                            : ThemeService.lightTextSecondary,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _showFrozenItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final frozenItems = await _db
          .collection('users')
          .doc(user.uid)
          .collection('items')
          .where('isFrozen', isEqualTo: true)
          .get();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: _themeService.isDarkMode 
            ? ThemeService.darkCard 
            : ThemeService.lightCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.ac_unit_rounded,
                      color: Color(0xFF00BCD4),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Frozen Items',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextPrimary 
                            : ThemeService.lightTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${frozenItems.docs.length}',
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
              const Divider(),
              Expanded(
                child: frozenItems.docs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.ac_unit_rounded,
                              size: 80,
                              color: _themeService.isDarkMode 
                                  ? ThemeService.darkTextSecondary 
                                  : ThemeService.lightTextSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No frozen items',
                              style: TextStyle(
                                fontSize: 18,
                                color: _themeService.isDarkMode 
                                    ? ThemeService.darkTextSecondary 
                                    : ThemeService.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: frozenItems.docs.length,
                        itemBuilder: (context, index) {
                          final item = frozenItems.docs[index];
                          final data = item.data();
                          final name = data['name'] ?? 'Unknown';
                          final expiry = data['expiry'] as Timestamp?;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: _themeService.isDarkMode 
                                ? ThemeService.darkCardBackground 
                                : Colors.white,
                            child: ListTile(
                              leading: const Icon(
                                Icons.ac_unit_rounded,
                                color: Color(0xFF00BCD4),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  color: _themeService.isDarkMode 
                                      ? ThemeService.darkTextPrimary 
                                      : ThemeService.lightTextPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: expiry != null
                                  ? Text(
                                      'Expires on ${_formatDate(expiry.toDate())}',
                                      style: TextStyle(
                                        color: _themeService.isDarkMode 
                                            ? ThemeService.darkTextSecondary 
                                            : ThemeService.lightTextSecondary,
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE74C3C)),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Frozen Item'),
                                          content: Text('Delete "$name" from frozen items?'),
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
                                        await item.reference.delete();
                                        if (context.mounted) {
                                          Navigator.of(context).pop(); // Close the modal
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Deleted "$name"')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _showPrioritizedItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final prioritizedItems = await _db
          .collection('users')
          .doc(user.uid)
          .collection('items')
          .where('isPrioritized', isEqualTo: true)
          .get();

      if (!mounted) return;

      final sortedItems = prioritizedItems.docs.toList()
        ..sort((a, b) {
          final aTime = a.data()['prioritizedAt'] as Timestamp?;
          final bTime = b.data()['prioritizedAt'] as Timestamp?;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          return bTime.compareTo(aTime);
        });

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: _themeService.isDarkMode 
            ? ThemeService.darkCard 
            : ThemeService.lightCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.priority_high_rounded,
                      color: Color(0xFFE74C3C),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Prioritized Items',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextPrimary 
                            : ThemeService.lightTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${sortedItems.length}',
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
              const Divider(),
              Expanded(
                child: sortedItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.priority_high_rounded,
                              size: 80,
                              color: _themeService.isDarkMode 
                                  ? ThemeService.darkTextSecondary 
                                  : ThemeService.lightTextSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No prioritized items',
                              style: TextStyle(
                                fontSize: 18,
                                color: _themeService.isDarkMode 
                                    ? ThemeService.darkTextSecondary 
                                    : ThemeService.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: sortedItems.length,
                        itemBuilder: (context, index) {
                          final item = sortedItems[index];
                          final data = item.data();
                          final name = data['name'] ?? 'Unknown';
                          final expiry = data['expiry'] as Timestamp?;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: _themeService.isDarkMode 
                                ? ThemeService.darkCardBackground 
                                : Colors.white,
                            child: ListTile(
                              leading: const Icon(
                                Icons.priority_high_rounded,
                                color: Color(0xFFE74C3C),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  color: _themeService.isDarkMode 
                                      ? ThemeService.darkTextPrimary 
                                      : ThemeService.lightTextPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: expiry != null
                                  ? Text(
                                      'Expires on ${_formatDate(expiry.toDate())}',
                                      style: TextStyle(
                                        color: _themeService.isDarkMode 
                                            ? ThemeService.darkTextSecondary 
                                            : ThemeService.lightTextSecondary,
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE74C3C)),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Priority Item'),
                                          content: Text('Delete "$name" from your fridge?'),
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
                                        await item.reference.delete();
                                        if (context.mounted) {
                                          Navigator.of(context).pop(); // Close the modal
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Deleted "$name"')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays == -1) return 'Yesterday';
    
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.isDarkMode 
          ? ThemeService.darkBackground 
          : ThemeService.lightBackground,
      appBar: AppBar(
        title: Text(
          'Collections',
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
              'Organize Your Items',
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
              'View finished, frozen, or priority items',
              style: TextStyle(
                fontSize: 16,
                color: _themeService.isDarkMode 
                    ? ThemeService.darkTextSecondary 
                    : const Color(0xFF7F8C8D),
              ),
            ),
            const SizedBox(height: 32),

            // Finished Items Card
            _buildOptionCard(
              context,
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF27AE60),
              title: 'Finished Items',
              description: 'View your consumption history',
              onTap: _showFinishedItemsHistory,
            ),

            const SizedBox(height: 16),

            // Frozen Items Card
            _buildOptionCard(
              context,
              icon: Icons.ac_unit_rounded,
              iconColor: const Color(0xFF00BCD4),
              title: 'Frozen Items',
              description: 'View your frozen foods',
              onTap: _showFrozenItems,
            ),

            const SizedBox(height: 16),

            // Priority Items Card
            _buildOptionCard(
              context,
              icon: Icons.priority_high_rounded,
              iconColor: const Color(0xFFE74C3C),
              title: 'Priority Items',
              description: 'Items marked for recipes',
              onTap: _showPrioritizedItems,
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


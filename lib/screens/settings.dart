import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_service.dart';
import '../services/auth.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ThemeService _themeService = ThemeService();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  
  bool _isDarkMode = false;
  bool _isCompactView = false;
  bool _useLbs = true;
  
  // Diet preferences
  Set<String> _selectedDietPreferences = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDietPreferences();
  }

  void _loadSettings() {
    setState(() {
      _isDarkMode = _themeService.isDarkMode;
      _isCompactView = _themeService.isCompactView;
      _useLbs = _themeService.useLbs;
    });
  }

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
    });
    _themeService.toggleTheme();
  }

  void _toggleCompactView(bool value) {
    setState(() {
      _isCompactView = value;
    });
    _themeService.toggleCompactView();
  }

  void _toggleCarbonUnit(bool value) {
    setState(() {
      _useLbs = value;
    });
    _themeService.toggleCarbonUnit();
  }

  Future<void> _loadDietPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final preferences = data['dietPreferences'] as List<dynamic>? ?? [];
        setState(() {
          _selectedDietPreferences = preferences.cast<String>().toSet();
        });
      }
    } catch (e) {
      print('Error loading diet preferences: $e');
    }
  }

  Future<void> _saveDietPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.collection('users').doc(user.uid).set({
        'dietPreferences': _selectedDietPreferences.toList(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save diet preferences: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _toggleDietPreference(String preference) {
    setState(() {
      if (_selectedDietPreferences.contains(preference)) {
        _selectedDietPreferences.remove(preference);
      } else {
        _selectedDietPreferences.add(preference);
      }
    });
    _saveDietPreferences();
  }

  List<Map<String, String>> _getDietPreferenceOptions() {
    return [
      {'label': '🌱 Vegan', 'value': 'vegan'},
      {'label': '🥛 Vegetarian', 'value': 'vegetarian'},
      {'label': '🥩 Pescatarian', 'value': 'pescatarian'},
      {'label': '🌾 Gluten-Free', 'value': 'gluten_free'},
      {'label': '🥛 Dairy-Free', 'value': 'dairy_free'},
      {'label': '🥜 Nut-Free', 'value': 'nut_free'},
      {'label': '🦐 Shellfish-Free', 'value': 'shellfish_free'},
      {'label': '🥚 Egg-Free', 'value': 'egg_free'},
      {'label': '🍯 Sugar-Free', 'value': 'sugar_free'},
      {'label': '🧂 Low-Sodium', 'value': 'low_sodium'},
      {'label': '🫒 Keto', 'value': 'keto'},
      {'label': '🥬 Paleo', 'value': 'paleo'},
      {'label': '🌶️ Spicy Food', 'value': 'spicy'},
      {'label': '🍃 Organic', 'value': 'organic'},
      {'label': '⚡ Quick Meals', 'value': 'quick_meals'},
    ];
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.instance.signOut();
      if (mounted) {
        // Pop back to auth gate which will handle navigation
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: _themeService.isDarkMode 
            ? ThemeService.darkBackground 
            : ThemeService.lightBackground,
        foregroundColor: _themeService.isDarkMode 
            ? ThemeService.darkTextPrimary 
            : ThemeService.lightTextPrimary,
      ),
      backgroundColor: _themeService.isDarkMode 
          ? ThemeService.darkBackground 
          : ThemeService.lightBackground,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          Card(
            color: _themeService.isDarkMode 
                ? ThemeService.darkCard 
                : ThemeService.lightCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _themeService.isDarkMode 
                          ? ThemeService.darkTextPrimary 
                          : ThemeService.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Dark Mode Toggle
                  SwitchListTile(
                    title: Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontSize: 15,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextPrimary 
                            : ThemeService.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Switch between light and dark themes',
                      style: TextStyle(
                        fontSize: 12,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextSecondary 
                            : ThemeService.lightTextSecondary,
                      ),
                    ),
                    value: _isDarkMode,
                    onChanged: _toggleDarkMode,
                    activeColor: ThemeService.primaryColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    dense: true,
                  ),
                  
                  const Divider(),
                  
                  // Compact View Toggle
                  SwitchListTile(
                    title: Text(
                      'Compact View',
                      style: TextStyle(
                        fontSize: 15,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextPrimary 
                            : ThemeService.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Use compact layout for item tiles',
                      style: TextStyle(
                        fontSize: 12,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextSecondary 
                            : ThemeService.lightTextSecondary,
                      ),
                    ),
                    value: _isCompactView,
                    onChanged: _toggleCompactView,
                    activeColor: ThemeService.primaryColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Units Section
          Card(
            color: _themeService.isDarkMode 
                ? ThemeService.darkCard 
                : ThemeService.lightCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Units',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _themeService.isDarkMode 
                          ? ThemeService.darkTextPrimary 
                          : ThemeService.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Carbon Unit Toggle
                  SwitchListTile(
                    title: Text(
                      'Use Pounds (lbs)',
                      style: TextStyle(
                        fontSize: 15,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextPrimary 
                            : ThemeService.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _useLbs 
                          ? 'Carbon savings shown in lbs CO₂' 
                          : 'Carbon savings shown in kg CO₂',
                      style: TextStyle(
                        fontSize: 12,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextSecondary 
                            : ThemeService.lightTextSecondary,
                      ),
                    ),
                    value: _useLbs,
                    onChanged: _toggleCarbonUnit,
                    activeColor: ThemeService.primaryColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Diet Preferences Section
          Card(
            color: _themeService.isDarkMode 
                ? ThemeService.darkCard 
                : ThemeService.lightCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diet Preferences',
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
                    'Select your dietary preferences to get better recipe recommendations',
                    style: TextStyle(
                      fontSize: 12,
                      color: _themeService.isDarkMode 
                          ? ThemeService.darkTextSecondary 
                          : ThemeService.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _getDietPreferenceOptions().map((option) {
                      final value = option['value']!;
                      final label = option['label']!;
                      final isSelected = _selectedDietPreferences.contains(value);
                      return FilterChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) => _toggleDietPreference(value),
                        selectedColor: ThemeService.primaryColor.withOpacity(0.2),
                        checkmarkColor: ThemeService.primaryColor,
                        backgroundColor: _themeService.isDarkMode 
                            ? ThemeService.darkBackground 
                            : Colors.grey[100],
                        labelStyle: TextStyle(
                          color: isSelected 
                              ? ThemeService.primaryColor
                              : (_themeService.isDarkMode ? ThemeService.darkTextPrimary : Colors.black87),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Account Section
          Card(
            color: _themeService.isDarkMode 
                ? ThemeService.darkCard 
                : ThemeService.lightCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _themeService.isDarkMode 
                          ? ThemeService.darkTextPrimary 
                          : ThemeService.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Sign out of your account',
                      style: TextStyle(
                        fontSize: 12,
                        color: _themeService.isDarkMode 
                            ? ThemeService.darkTextSecondary 
                            : ThemeService.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // About Section
          Card(
            color: _themeService.isDarkMode 
                ? ThemeService.darkCard 
                : ThemeService.lightCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _themeService.isDarkMode 
                          ? ThemeService.darkTextPrimary 
                          : ThemeService.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // App Version (not a button, just display)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _themeService.isDarkMode 
                          ? Colors.grey.shade800 
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: ThemeService.primaryColor,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'App Version',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _themeService.isDarkMode 
                                    ? ThemeService.darkTextPrimary 
                                    : ThemeService.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '1.0.0',
                              style: TextStyle(
                                fontSize: 14,
                                color: _themeService.isDarkMode 
                                    ? ThemeService.darkTextSecondary 
                                    : ThemeService.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement privacy policy
                      },
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Privacy Policy'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: _themeService.isDarkMode 
                              ? ThemeService.darkTextSecondary 
                              : ThemeService.lightTextSecondary,
                        ),
                        foregroundColor: _themeService.isDarkMode 
                            ? ThemeService.darkTextPrimary 
                            : ThemeService.lightTextPrimary,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement help
                      },
                      icon: const Icon(Icons.help_outline),
                      label: const Text('Help & Support'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: _themeService.isDarkMode 
                              ? ThemeService.darkTextSecondary 
                              : ThemeService.lightTextSecondary,
                        ),
                        foregroundColor: _themeService.isDarkMode 
                            ? ThemeService.darkTextPrimary 
                            : ThemeService.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

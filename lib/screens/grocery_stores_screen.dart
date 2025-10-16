import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/walmart_service.dart';
import '../services/config_service.dart';

class GroceryStoresScreen extends StatefulWidget {
  const GroceryStoresScreen({super.key});

  @override
  State<GroceryStoresScreen> createState() => _GroceryStoresScreenState();
}

class _GroceryStoresScreenState extends State<GroceryStoresScreen> {
  final _themeService = ThemeService();
  final _walmartService = WalmartService();
  final _configService = ConfigService();
  
  bool _walmartConnected = false;
  bool _checkingWalmart = true;

  @override
  void initState() {
    super.initState();
    _checkWalmartConnection();
  }

  Future<void> _checkWalmartConnection() async {
    final connected = await _configService.hasWalmartCredentials();
    setState(() {
      _walmartConnected = connected;
      _checkingWalmart = false;
    });
  }

  Future<void> _testWalmartConnection() async {
    final isDark = _themeService.isDarkMode;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? ThemeService.darkCardBackground : Colors.white,
        title: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(
              'Testing Connection...',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
          ],
        ),
        content: Text(
          'Searching for milk products...',
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ),
    );

    try {
      // Test with a simple product search
      final products = await _walmartService.searchProducts('milk', maxResults: 3);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? ThemeService.darkCardBackground : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF27AE60)),
              const SizedBox(width: 12),
              Text(
                'Connection Successful!',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${products.length} products. Your Walmart API is working correctly!',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              if (products.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Sample products:',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.grey[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...products.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${p.name}',
                    style: TextStyle(
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                )),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? ThemeService.darkCardBackground : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                'Connection Failed',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
            ],
          ),
          content: Text(
            'Error: $e\n\nPlease check your Walmart API credentials in Firebase.',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeService.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? ThemeService.darkBackground : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Grocery Stores'),
        backgroundColor: isDark ? ThemeService.darkCardBackground : Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? ThemeService.darkCardBackground : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27AE60).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.store_rounded,
                        color: Color(0xFF27AE60),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grocery Store Integration',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.grey[900],
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connect your grocery accounts to auto-sync purchases',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // Store Cards - All Coming Soon
          _buildComingSoonCard(
            isDark: isDark,
            storeName: 'Kroger',
            storeDescription: 'Connect your Kroger account to automatically sync purchases',
            icon: Icons.store_mall_directory_rounded,
            color: const Color(0xFF0057B8),
          ),

          const SizedBox(height: 16),

          // Walmart - Functional Integration
          _buildWalmartCard(isDark: isDark),

          const SizedBox(height: 16),

          _buildComingSoonCard(
            isDark: isDark,
            storeName: 'Target',
            storeDescription: 'Auto-sync your Target shopping trips',
            icon: Icons.adjust_rounded,
            color: const Color(0xFFCC0000),
          ),

          const SizedBox(height: 16),

          _buildComingSoonCard(
            isDark: isDark,
            storeName: 'Whole Foods',
            storeDescription: 'Connect your Whole Foods Market account',
            icon: Icons.eco_rounded,
            color: const Color(0xFF00674F),
          ),

          const SizedBox(height: 24),

          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF27AE60).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF27AE60).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF27AE60),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Grocery store integrations are coming soon! When available, you\'ll be able to connect your accounts to automatically sync purchases.',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF27AE60) : const Color(0xFF059669),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalmartCard({required bool isDark}) {
    if (_checkingWalmart) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? ThemeService.darkCardBackground : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? ThemeService.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: _walmartConnected 
          ? Border.all(color: const Color(0xFF27AE60).withOpacity(0.3), width: 2)
          : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0071CE).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.store_rounded,
                    color: Color(0xFF0071CE),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Walmart',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.grey[900],
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_walmartConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27AE60).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: Color(0xFF27AE60)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Connected',
                                    style: TextStyle(
                                      color: Color(0xFF27AE60),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Setup Required',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _walmartConnected
                            ? 'API configured and ready to use'
                            : 'Configure Walmart API in Firebase to enable',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _walmartConnected ? _testWalmartConnection : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _walmartConnected 
                      ? const Color(0xFF0071CE)
                      : (isDark ? Colors.grey[700] : Colors.grey[300]),
                  foregroundColor: _walmartConnected 
                      ? Colors.white
                      : (isDark ? Colors.grey[500] : Colors.grey[600]),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _walmartConnected ? 'Test Connection' : 'Configure in Firebase',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (_walmartConnected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF27AE60).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF27AE60),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Use the test button to verify your Walmart API connection',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF27AE60) : const Color(0xFF059669),
                          fontSize: 12,
                        ),
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

  Widget _buildComingSoonCard({
    required bool isDark,
    required String storeName,
    required String storeDescription,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? ThemeService.darkCardBackground.withOpacity(0.5) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color.withOpacity(0.5),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            storeName,
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[700] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Coming Soon',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        storeDescription,
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null, // Disabled
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                  foregroundColor: isDark ? Colors.grey[500] : Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Coming Soon',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
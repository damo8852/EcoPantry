import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../screens/paywall_screen.dart';

/// Reusable widget to show upgrade to premium prompt
class UpgradeToPremiumDialog extends StatelessWidget {
  final String title;
  final String message;
  final String feature;

  const UpgradeToPremiumDialog({
    super.key,
    required this.title,
    required this.message,
    required this.feature,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final isDark = themeService.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: isDark ? ThemeService.darkCardBackground : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium Badge Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Premium Feature',
                          style: TextStyle(
                            color: Colors.white70,
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isDark ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Premium Features List
                  _buildFeatureItem(
                    '✨ Unlimited Recipe Generation',
                    'Generate as many recipes as you want',
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    '🛒 Shopping List Access',
                    'Full access to shopping list features',
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    '👥 Community Recipes',
                    'Access and share recipes with the community',
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    '📸 Unlimited Receipt Scanning',
                    'Scan as many receipts as you want',
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    '🎯 Priority Support',
                    'Get help faster when you need it',
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    '🚀 Future Features',
                    'First access to new premium features',
                    isDark,
                  ),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(false); // Close dialog
                        // Navigate to paywall
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PaywallScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: const Color(0xFF2C3E50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.workspace_premium, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Upgrade to Premium',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false); // Return false to cancel
                    },
                    child: Text(
                      'Maybe Later',
                      style: TextStyle(
                        color: isDark ? ThemeService.darkTextSecondary : const Color(0xFF7F8C8D),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.check_circle,
            color: Color(0xFFFFD700),
            size: 16,
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
                  color: isDark ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: isDark ? ThemeService.darkTextSecondary : const Color(0xFF7F8C8D),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Helper method to show the dialog
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String feature,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => UpgradeToPremiumDialog(
        title: title,
        message: message,
        feature: feature,
      ),
    );
  }
}

/// Show upgrade dialog for shopping list feature
Future<bool> showShoppingListUpgradeDialog(BuildContext context) async {
  final result = await UpgradeToPremiumDialog.show(
    context,
    title: 'Shopping List',
    message: 'Shopping lists are a premium feature. Upgrade to Premium to create and manage shopping lists, discover recipes from your list, and get price comparisons.',
    feature: 'shopping_list',
  );
  return result ?? false;
}

/// Show upgrade dialog for recipe limit
Future<bool> showRecipeLimitUpgradeDialog(BuildContext context, int remaining) async {
  final message = remaining == 0
      ? 'You\'ve reached your daily limit of 3 recipe generations. Upgrade to Premium for unlimited recipe generation!'
      : 'You have $remaining recipe generation${remaining == 1 ? '' : 's'} remaining today. Upgrade to Premium for unlimited recipes!';

  final result = await UpgradeToPremiumDialog.show(
    context,
    title: 'Recipe Limit Reached',
    message: message,
    feature: 'unlimited_recipes',
  );
  return result ?? false;
}

/// Show upgrade dialog for community recipes feature
Future<bool> showCommunityRecipesUpgradeDialog(BuildContext context) async {
  final result = await UpgradeToPremiumDialog.show(
    context,
    title: 'Community Recipes',
    message: 'Community recipes are a premium feature. Upgrade to Premium to access thousands of recipes shared by the EcoPantry community, and share your own creations!',
    feature: 'community_recipes',
  );
  return result ?? false;
}

/// Show upgrade dialog for receipt scanning limit
Future<bool> showReceiptScanLimitUpgradeDialog(BuildContext context, int remaining) async {
  final message = remaining == 0
      ? 'You\'ve used your daily receipt scan. Upgrade to Premium for unlimited receipt scanning!'
      : 'You have $remaining receipt scan remaining today. Upgrade to Premium for unlimited scanning!';

  final result = await UpgradeToPremiumDialog.show(
    context,
    title: 'Receipt Scan Limit',
    message: message,
    feature: 'unlimited_scanning',
  );
  return result ?? false;
}

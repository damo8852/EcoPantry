import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// Premium paywall screen showing subscription options
/// This is a placeholder that will be replaced with RevenueCat integration
class PaywallScreen extends StatefulWidget {
  final bool showCloseButton;

  const PaywallScreen({
    super.key,
    this.showCloseButton = true,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final ThemeService _themeService = ThemeService();
  int _selectedPlanIndex = 1; // 0 = monthly, 1 = yearly (default to best value)
  bool _isLoading = false;

  // Pricing (will come from RevenueCat offerings in real implementation)
  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'premium_monthly',
      'title': 'Monthly',
      'price': '\$9.99',
      'period': 'per month',
      'savings': null,
      'description': 'Billed monthly',
    },
    {
      'id': 'premium_yearly',
      'title': 'Yearly',
      'price': '\$99.99',
      'period': 'per year',
      'savings': 'Save 17%',
      'description': 'Billed annually',
      'badge': 'BEST VALUE',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = _themeService.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? ThemeService.darkBackground : Colors.white,
      appBar: widget.showCloseButton
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDark ? ThemeService.darkTextPrimary : Colors.black87,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Premium Badge
                    Container(
                      padding: const EdgeInsets.all(20),
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
                        size: 80,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Upgrade to Premium',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDark ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Unlock unlimited recipes and exclusive features',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? ThemeService.darkTextSecondary : const Color(0xFF7F8C8D),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Features List
                    _buildFeature(
                      '✨ Unlimited Recipe Generation',
                      'Create as many recipes as you want, whenever you want',
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildFeature(
                      '🛒 Full Shopping List Access',
                      'Create, manage, and share shopping lists with ease',
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildFeature(
                      '📸 Unlimited Receipt Scanning',
                      'Scan and add items from receipts without daily limits',
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildFeature(
                      '👥 Community Recipes Access',
                      'Browse and share recipes with the community',
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildFeature(
                      '🎯 Advanced Filters',
                      'Customize recipes with cuisine types, cooking tools, and more',
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildFeature(
                      '💾 Unlimited Saves',
                      'Save all your favorite recipes without limits',
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildFeature(
                      '🚀 Priority Support',
                      'Get help faster when you need it',
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildFeature(
                      '🆕 Early Access',
                      'Be the first to try new premium features',
                      isDark,
                    ),

                    const SizedBox(height: 32),

                    // Plan Selection
                    Text(
                      'Choose Your Plan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Plans
                    ..._plans.asMap().entries.map((entry) {
                      final index = entry.key;
                      final plan = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPlanCard(plan, index == _selectedPlanIndex, isDark, () {
                          setState(() => _selectedPlanIndex = index);
                        }),
                      );
                    }).toList(),

                    const SizedBox(height: 24),

                    // Terms
                    Text(
                      'Cancel anytime. No commitments.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? ThemeService.darkTextSecondary : const Color(0xFF95A5A6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? ThemeService.darkCard : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: const Color(0xFF2C3E50),
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.workspace_premium, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  'Start Premium - ${_plans[_selectedPlanIndex]['price']}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _handleRestore,
                    child: Text(
                      'Restore Purchases',
                      style: TextStyle(
                        color: isDark ? ThemeService.darkTextSecondary : const Color(0xFF7F8C8D),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By subscribing, you agree to our Terms of Service',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? ThemeService.darkTextSecondary : const Color(0xFF95A5A6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(String title, String description, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.check_circle,
            color: Color(0xFFFFD700),
            size: 24,
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? ThemeService.darkTextSecondary : const Color(0xFF7F8C8D),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, bool isSelected, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFD700).withOpacity(0.1)
              : (isDark ? ThemeService.darkCard : Colors.grey[100]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Radio button
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFFFD700) : Colors.grey,
                  width: 2,
                ),
                color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),

            // Plan details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan['title'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                        ),
                      ),
                      if (plan['badge'] != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            plan['badge'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan['description'],
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? ThemeService.darkTextSecondary : const Color(0xFF7F8C8D),
                    ),
                  ),
                  if (plan['savings'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      plan['savings'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF27AE60),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan['price'],
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? ThemeService.darkTextPrimary : const Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  plan['period'],
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? ThemeService.darkTextSecondary : const Color(0xFF7F8C8D),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    setState(() => _isLoading = true);

    try {
      // TODO: Replace with actual RevenueCat purchase flow
      // final paymentService = PaymentService.instance;
      // final offerings = await paymentService.getOfferings();
      // final package = offerings?.current?.availablePackages[_selectedPlanIndex];
      // if (package != null) {
      //   final success = await paymentService.purchasePackage(package);
      //   if (success && mounted) {
      //     Navigator.pop(context, true);
      //   }
      // }

      // Temporary: Show coming soon message
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment processing coming soon! '
              'Use the debug button in Settings to test premium features.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    // TODO: Implement restore purchases with RevenueCat
    // final paymentService = PaymentService.instance;
    // final success = await paymentService.restorePurchases();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore purchases coming soon with payment integration!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

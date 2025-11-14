// import 'package:purchases_flutter/purchases_flutter.dart';
// import 'package:flutter/foundation.dart';
// import 'subscription_service.dart';

// /// RevenueCat payment service for handling in-app purchases
// /// This service manages subscription purchases through iOS App Store and Google Play Store
// class PaymentService {
//   PaymentService._();
//   static final instance = PaymentService._();

//   bool _isConfigured = false;

//   /// Initialize RevenueCat SDK
//   /// Call this in main.dart before runApp()
//   Future<void> initialize() async {
//     if (_isConfigured) return;

//     try {
//       // TODO: Replace with your actual RevenueCat API keys
//       // Get these from https://app.revenuecat.com/
//       const String iosApiKey = 'YOUR_IOS_API_KEY_HERE';
//       const String androidApiKey = 'YOUR_ANDROID_API_KEY_HERE';

//       // Configure SDK based on platform
//       PurchasesConfiguration configuration;
//       if (defaultTargetPlatform == TargetPlatform.iOS) {
//         configuration = PurchasesConfiguration(iosApiKey);
//       } else if (defaultTargetPlatform == TargetPlatform.android) {
//         configuration = PurchasesConfiguration(androidApiKey);
//       } else {
//         print('RevenueCat not supported on this platform');
//         return;
//       }

//       // Enable debug logging in debug mode
//       if (kDebugMode) {
//         configuration = configuration.copyWith(
//           // This will log all RevenueCat activity
//           debugLogsEnabled: true,
//         );
//       }

//       await Purchases.configure(configuration);
//       _isConfigured = true;

//       // Set up listener for purchase updates
//       Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);

//       print('✅ RevenueCat initialized successfully');
//     } catch (e) {
//       print('❌ Failed to initialize RevenueCat: $e');
//     }
//   }

//   /// Handle customer info updates (purchases, cancellations, etc.)
//   void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
//     _updateSubscriptionFromCustomerInfo(customerInfo);
//   }

//   /// Get available subscription offerings
//   Future<Offerings?> getOfferings() async {
//     if (!_isConfigured) {
//       print('RevenueCat not configured');
//       return null;
//     }

//     try {
//       final offerings = await Purchases.getOfferings();
//       return offerings;
//     } catch (e) {
//       print('Error getting offerings: $e');
//       return null;
//     }
//   }

//   /// Purchase a subscription package
//   Future<bool> purchasePackage(Package package) async {
//     if (!_isConfigured) {
//       print('RevenueCat not configured');
//       return false;
//     }

//     try {
//       final customerInfo = await Purchases.purchasePackage(package);
//       await _updateSubscriptionFromCustomerInfo(customerInfo);
//       return _isPremium(customerInfo);
//     } on PlatformException catch (e) {
//       final errorCode = PurchasesErrorHelper.getErrorCode(e);

//       if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
//         print('User cancelled purchase');
//       } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
//         print('Purchase not allowed');
//       } else {
//         print('Purchase error: ${e.message}');
//       }

//       return false;
//     } catch (e) {
//       print('Unexpected purchase error: $e');
//       return false;
//     }
//   }

//   /// Restore previous purchases
//   /// Useful when user reinstalls app or switches devices
//   Future<bool> restorePurchases() async {
//     if (!_isConfigured) {
//       print('RevenueCat not configured');
//       return false;
//     }

//     try {
//       final customerInfo = await Purchases.restorePurchases();
//       await _updateSubscriptionFromCustomerInfo(customerInfo);
//       return _isPremium(customerInfo);
//     } catch (e) {
//       print('Error restoring purchases: $e');
//       return false;
//     }
//   }

//   /// Check current subscription status
//   Future<bool> checkSubscriptionStatus() async {
//     if (!_isConfigured) {
//       return false;
//     }

//     try {
//       final customerInfo = await Purchases.getCustomerInfo();
//       return _isPremium(customerInfo);
//     } catch (e) {
//       print('Error checking subscription: $e');
//       return false;
//     }
//   }

//   /// Check if user has premium access
//   bool _isPremium(CustomerInfo customerInfo) {
//     // Check for active premium entitlement
//     // "premium" is the entitlement identifier you configure in RevenueCat dashboard
//     final entitlements = customerInfo.entitlements.all['premium'];
//     return entitlements?.isActive ?? false;
//   }

//   /// Update local subscription status based on RevenueCat customer info
//   Future<void> _updateSubscriptionFromCustomerInfo(CustomerInfo customerInfo) async {
//     final isPremium = _isPremium(customerInfo);

//     // Get expiration date if available
//     final entitlement = customerInfo.entitlements.all['premium'];
//     final expirationDate = entitlement?.expirationDate;

//     if (isPremium) {
//       // Upgrade to premium
//       await SubscriptionService.instance.upgradeToPremium(
//         expiresAt: expirationDate,
//       );
//       print('✅ Premium subscription active${expirationDate != null ? " until $expirationDate" : ""}');
//     } else {
//       // Downgrade to free
//       await SubscriptionService.instance.downgradeToFree();
//       print('ℹ️ Free subscription active');
//     }
//   }

//   /// Get current customer info
//   Future<CustomerInfo?> getCustomerInfo() async {
//     if (!_isConfigured) {
//       return null;
//     }

//     try {
//       return await Purchases.getCustomerInfo();
//     } catch (e) {
//       print('Error getting customer info: $e');
//       return null;
//     }
//   }

//   /// Login user with custom user ID
//   /// This links purchases across devices
//   Future<void> loginUser(String userId) async {
//     if (!_isConfigured) {
//       return;
//     }

//     try {
//       await Purchases.logIn(userId);
//       print('✅ Logged in user: $userId');
//     } catch (e) {
//       print('Error logging in user: $e');
//     }
//   }

//   /// Logout current user
//   Future<void> logoutUser() async {
//     if (!_isConfigured) {
//       return;
//     }

//     try {
//       await Purchases.logOut();
//       print('✅ Logged out user');
//     } catch (e) {
//       print('Error logging out user: $e');
//     }
//   }

//   /// Check if user is eligible for intro pricing
//   /// (Useful for offering free trials to new subscribers)
//   Future<bool> isEligibleForIntroOffer(Package package) async {
//     if (!_isConfigured) {
//       return false;
//     }

//     try {
//       final eligibility = await Purchases.checkTrialOrIntroductoryPriceEligibility(
//         [package.storeProduct.identifier],
//       );

//       final status = eligibility[package.storeProduct.identifier];
//       return status?.status == IntroEligibilityStatus.eligible;
//     } catch (e) {
//       print('Error checking intro eligibility: $e');
//       return false;
//     }
//   }

//   /// Get subscription management URL
//   /// Opens App Store or Play Store subscription management
//   Future<void> openSubscriptionManagement() async {
//     if (!_isConfigured) {
//       return;
//     }

//     try {
//       await Purchases.showManageSubscriptions();
//     } catch (e) {
//       print('Error opening subscription management: $e');
//     }
//   }

//   /// Sync purchases with backend
//   /// Call this periodically or after app opens
//   Future<void> syncPurchases() async {
//     if (!_isConfigured) {
//       return;
//     }

//     try {
//       final customerInfo = await Purchases.getCustomerInfo();
//       await _updateSubscriptionFromCustomerInfo(customerInfo);
//     } catch (e) {
//       print('Error syncing purchases: $e');
//     }
//   }
// }

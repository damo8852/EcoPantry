import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_subscription.dart';

/// Service for managing user subscriptions and access control
class SubscriptionService {
  SubscriptionService._();
  static final instance = SubscriptionService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Get current user's subscription
  Future<UserSubscription?> getUserSubscription() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        // Create default subscription for new user
        await initializeUserSubscription(user.uid);
        return UserSubscription.defaultFree();
      }

      final data = doc.data();
      if (data == null) return UserSubscription.defaultFree();

      // Check if subscription field exists
      if (data['subscription'] == null) {
        // Initialize subscription for existing user
        await initializeUserSubscription(user.uid);
        return UserSubscription.defaultFree();
      }

      return UserSubscription.fromFirestore(data['subscription'] as Map<String, dynamic>);
    } catch (e) {
      print('Error getting user subscription: $e');
      return null;
    }
  }

  /// Stream user subscription for real-time updates
  Stream<UserSubscription?> getUserSubscriptionStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _db.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return UserSubscription.defaultFree();
      }

      final data = doc.data()!;
      if (data['subscription'] == null) {
        return UserSubscription.defaultFree();
      }

      return UserSubscription.fromFirestore(data['subscription'] as Map<String, dynamic>);
    });
  }

  /// Initialize subscription for a new user
  Future<void> initializeUserSubscription(String uid) async {
    try {
      final subscription = UserSubscription.defaultFree();
      await _db.collection('users').doc(uid).set({
        'subscription': subscription.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error initializing user subscription: $e');
    }
  }

  /// Update user subscription
  Future<void> updateSubscription(UserSubscription subscription) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.collection('users').doc(user.uid).update({
        'subscription': subscription.toFirestore(),
      });
    } catch (e) {
      print('Error updating subscription: $e');
    }
  }

  /// Increment recipe generation count
  /// Returns true if the recipe can be generated, false if limit reached
  Future<bool> incrementRecipeCount() async {
    final subscription = await getUserSubscription();
    if (subscription == null) return false;

    // Premium users have unlimited access
    if (subscription.isPremium) return true;

    // Check if can generate recipe
    if (!subscription.canGenerateRecipe()) {
      return false;
    }

    // Check if it's a new day (reset counter)
    final now = DateTime.now();
    final lastGenerated = subscription.lastRecipeGeneratedAt;
    final isNewDay = now.year != lastGenerated.year ||
        now.month != lastGenerated.month ||
        now.day != lastGenerated.day;

    final updatedSubscription = subscription.copyWith(
      recipesGeneratedToday: isNewDay ? 1 : subscription.recipesGeneratedToday + 1,
      lastRecipeGeneratedAt: now,
    );

    await updateSubscription(updatedSubscription);
    return true;
  }

  /// Check if user can access shopping list feature
  Future<bool> canAccessShoppingList() async {
    final subscription = await getUserSubscription();
    if (subscription == null) return false;
    return subscription.hasShoppingListAccess;
  }

  /// Check if user can generate recipes
  Future<bool> canGenerateRecipes() async {
    final subscription = await getUserSubscription();
    if (subscription == null) return false;
    return subscription.canGenerateRecipe();
  }

  /// Get remaining recipes for today
  Future<int> getRemainingRecipesToday() async {
    final subscription = await getUserSubscription();
    if (subscription == null) return 0;
    return subscription.remainingRecipesToday;
  }

  /// Check if user can access community recipes
  Future<bool> canAccessCommunityRecipes() async {
    final subscription = await getUserSubscription();
    if (subscription == null) return false;
    return subscription.hasCommunityRecipesAccess;
  }

  /// Check if user can scan receipt
  Future<bool> canScanReceipt() async {
    final subscription = await getUserSubscription();
    if (subscription == null) return false;
    return subscription.canScanReceipt();
  }

  /// Increment receipt scan count
  /// Returns true if the scan can be performed, false if limit reached
  Future<bool> incrementReceiptScanCount() async {
    final subscription = await getUserSubscription();
    if (subscription == null) return false;

    // Premium users have unlimited access
    if (subscription.isPremium) return true;

    // Check if can scan receipt
    if (!subscription.canScanReceipt()) {
      return false;
    }

    // Check if it's a new day (reset counter)
    final now = DateTime.now();
    final lastScanned = subscription.lastReceiptScannedAt;
    final isNewDay = now.year != lastScanned.year ||
        now.month != lastScanned.month ||
        now.day != lastScanned.day;

    final updatedSubscription = subscription.copyWith(
      receiptsScannedToday: isNewDay ? 1 : subscription.receiptsScannedToday + 1,
      lastReceiptScannedAt: now,
    );

    await updateSubscription(updatedSubscription);
    return true;
  }

  /// Get remaining receipt scans for today
  Future<int> getRemainingReceiptScansToday() async {
    final subscription = await getUserSubscription();
    if (subscription == null) return 0;
    return subscription.remainingReceiptScansToday;
  }

  /// Upgrade user to premium
  Future<void> upgradeToPremium({DateTime? expiresAt}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final subscription = await getUserSubscription() ?? UserSubscription.defaultFree();

      final updatedSubscription = subscription.copyWith(
        tier: SubscriptionTier.premium,
        premiumExpiresAt: expiresAt,
      );

      await updateSubscription(updatedSubscription);
    } catch (e) {
      print('Error upgrading to premium: $e');
    }
  }

  /// Downgrade user to free tier
  Future<void> downgradeToFree() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final subscription = await getUserSubscription() ?? UserSubscription.defaultFree();

      final updatedSubscription = subscription.copyWith(
        tier: SubscriptionTier.free,
        premiumExpiresAt: null,
      );

      await updateSubscription(updatedSubscription);
    } catch (e) {
      print('Error downgrading to free: $e');
    }
  }

  /// Check if premium subscription is expired and update if needed
  Future<void> checkAndUpdateExpiredPremium() async {
    final subscription = await getUserSubscription();
    if (subscription == null) return;

    if (subscription.tier == SubscriptionTier.premium &&
        subscription.premiumExpiresAt != null &&
        DateTime.now().isAfter(subscription.premiumExpiresAt!)) {
      // Premium expired, downgrade to free
      await downgradeToFree();
    }
  }

  /// Get subscription display information
  Future<Map<String, dynamic>> getSubscriptionInfo() async {
    final subscription = await getUserSubscription();
    if (subscription == null) {
      return {
        'tier': 'Free',
        'isPremium': false,
        'recipesRemaining': 3,
        'hasShoppingList': false,
      };
    }

    return {
      'tier': subscription.isPremium ? 'Premium' : 'Free',
      'isPremium': subscription.isPremium,
      'recipesRemaining': subscription.remainingRecipesToday,
      'hasShoppingList': subscription.hasShoppingListAccess,
      'expiresAt': subscription.premiumExpiresAt,
    };
  }
}

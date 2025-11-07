import 'package:cloud_firestore/cloud_firestore.dart';

/// Subscription tier types
enum SubscriptionTier {
  free,
  premium;

  String toFirestore() => name;

  static SubscriptionTier fromFirestore(String value) {
    return SubscriptionTier.values.firstWhere(
      (tier) => tier.name == value,
      orElse: () => SubscriptionTier.free,
    );
  }
}

/// User subscription model
class UserSubscription {
  final SubscriptionTier tier;
  final DateTime? premiumExpiresAt;
  final int recipesGeneratedToday;
  final DateTime lastRecipeGeneratedAt;
  final int receiptsScannedToday;
  final DateTime lastReceiptScannedAt;

  const UserSubscription({
    required this.tier,
    this.premiumExpiresAt,
    this.recipesGeneratedToday = 0,
    required this.lastRecipeGeneratedAt,
    this.receiptsScannedToday = 0,
    required this.lastReceiptScannedAt,
  });

  /// Default free tier subscription for new users
  factory UserSubscription.defaultFree() {
    return UserSubscription(
      tier: SubscriptionTier.free,
      premiumExpiresAt: null,
      recipesGeneratedToday: 0,
      lastRecipeGeneratedAt: DateTime.now(),
      receiptsScannedToday: 0,
      lastReceiptScannedAt: DateTime.now(),
    );
  }

  /// Check if user has premium access
  bool get isPremium {
    if (tier != SubscriptionTier.premium) return false;
    if (premiumExpiresAt == null) return true; // Lifetime premium
    return DateTime.now().isBefore(premiumExpiresAt!);
  }

  /// Check if user is on free tier
  bool get isFree => !isPremium;

  /// Check if user can generate recipes today
  /// Free users: 3 recipes per day
  /// Premium users: unlimited
  bool canGenerateRecipe() {
    if (isPremium) return true;

    // Check if it's a new day (reset counter)
    final now = DateTime.now();
    final lastGenerated = lastRecipeGeneratedAt;
    final isNewDay = now.year != lastGenerated.year ||
        now.month != lastGenerated.month ||
        now.day != lastGenerated.day;

    if (isNewDay) return true; // Counter will be reset

    // Check if under daily limit
    return recipesGeneratedToday < 3;
  }

  /// Get remaining recipes for today (free users only)
  int get remainingRecipesToday {
    if (isPremium) return -1; // Unlimited

    final now = DateTime.now();
    final lastGenerated = lastRecipeGeneratedAt;
    final isNewDay = now.year != lastGenerated.year ||
        now.month != lastGenerated.month ||
        now.day != lastGenerated.day;

    if (isNewDay) return 3;
    return (3 - recipesGeneratedToday).clamp(0, 3);
  }

  /// Check if user has access to shopping list feature
  /// Shopping list is premium-only
  bool get hasShoppingListAccess => isPremium;

  /// Check if user has access to community recipes
  /// Community recipes are premium-only
  bool get hasCommunityRecipesAccess => isPremium;

  /// Check if user can scan receipt today
  /// Free users: 1 receipt per day
  /// Premium users: unlimited
  bool canScanReceipt() {
    if (isPremium) return true;

    // Check if it's a new day (reset counter)
    final now = DateTime.now();
    final lastScanned = lastReceiptScannedAt;
    final isNewDay = now.year != lastScanned.year ||
        now.month != lastScanned.month ||
        now.day != lastScanned.day;

    if (isNewDay) return true; // Counter will be reset

    // Check if under daily limit (1 per day for free)
    return receiptsScannedToday < 1;
  }

  /// Get remaining receipt scans for today (free users only)
  int get remainingReceiptScansToday {
    if (isPremium) return -1; // Unlimited

    final now = DateTime.now();
    final lastScanned = lastReceiptScannedAt;
    final isNewDay = now.year != lastScanned.year ||
        now.month != lastScanned.month ||
        now.day != lastScanned.day;

    if (isNewDay) return 1;
    return (1 - receiptsScannedToday).clamp(0, 1);
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'tier': tier.toFirestore(),
      'premiumExpiresAt': premiumExpiresAt,
      'recipesGeneratedToday': recipesGeneratedToday,
      'lastRecipeGeneratedAt': Timestamp.fromDate(lastRecipeGeneratedAt),
      'receiptsScannedToday': receiptsScannedToday,
      'lastReceiptScannedAt': Timestamp.fromDate(lastReceiptScannedAt),
    };
  }

  /// Create from Firestore document
  factory UserSubscription.fromFirestore(Map<String, dynamic> data) {
    return UserSubscription(
      tier: SubscriptionTier.fromFirestore(data['tier'] ?? 'free'),
      premiumExpiresAt: data['premiumExpiresAt'] != null
          ? (data['premiumExpiresAt'] as Timestamp).toDate()
          : null,
      recipesGeneratedToday: data['recipesGeneratedToday'] ?? 0,
      lastRecipeGeneratedAt: data['lastRecipeGeneratedAt'] != null
          ? (data['lastRecipeGeneratedAt'] as Timestamp).toDate()
          : DateTime.now(),
      receiptsScannedToday: data['receiptsScannedToday'] ?? 0,
      lastReceiptScannedAt: data['lastReceiptScannedAt'] != null
          ? (data['lastReceiptScannedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Copy with updated fields
  UserSubscription copyWith({
    SubscriptionTier? tier,
    DateTime? premiumExpiresAt,
    int? recipesGeneratedToday,
    DateTime? lastRecipeGeneratedAt,
    int? receiptsScannedToday,
    DateTime? lastReceiptScannedAt,
  }) {
    return UserSubscription(
      tier: tier ?? this.tier,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      recipesGeneratedToday: recipesGeneratedToday ?? this.recipesGeneratedToday,
      lastRecipeGeneratedAt: lastRecipeGeneratedAt ?? this.lastRecipeGeneratedAt,
      receiptsScannedToday: receiptsScannedToday ?? this.receiptsScannedToday,
      lastReceiptScannedAt: lastReceiptScannedAt ?? this.lastReceiptScannedAt,
    );
  }

  @override
  String toString() {
    return 'UserSubscription(tier: $tier, isPremium: $isPremium, recipesRemaining: $remainingRecipesToday)';
  }
}

# Payment Integration Guide for EcoPantry Subscriptions

## Overview
This guide covers implementing payment processing for Premium subscriptions in the EcoPantry app.

---

## Recommended Payment Providers

### 1. **RevenueCat** (Recommended for Flutter/Mobile)
**Best for:** Mobile apps with subscriptions

**Pros:**
- ✅ Handles both iOS App Store and Google Play Store
- ✅ Built-in subscription management
- ✅ Cross-platform purchases
- ✅ Excellent Flutter SDK
- ✅ Webhooks for server-side validation
- ✅ Free tier available (< $10k MRR)
- ✅ Handles subscription lifecycle (renewals, cancellations, etc.)

**Cons:**
- ⚠️ 1% fee on top of store fees for paid tier
- ⚠️ Requires app store setup

**Monthly Cost:**
- Free: Up to $10,000 monthly revenue
- Growth: 1% of revenue after $10k

### 2. **Stripe**
**Best for:** Web and custom payment flows

**Pros:**
- ✅ Most popular payment processor
- ✅ Excellent documentation
- ✅ Supports credit cards, digital wallets
- ✅ Powerful subscription management
- ✅ Lower fees than app stores (2.9% + $0.30)
- ✅ Works on all platforms

**Cons:**
- ⚠️ More complex mobile implementation
- ⚠️ Against Apple App Store guidelines for in-app purchases
- ⚠️ Better suited for web or non-app-store distribution

**Monthly Cost:**
- 2.9% + $0.30 per transaction
- No monthly fee

### 3. **Firebase Extensions + Stripe**
**Best for:** Firebase-integrated apps

**Pros:**
- ✅ Easy Firebase integration
- ✅ Cloud Functions handle backend
- ✅ Stripe's payment processing
- ✅ Good for existing Firebase apps

**Cons:**
- ⚠️ Requires Firebase Blaze plan
- ⚠️ Same App Store guideline issues as Stripe

### 4. **In-App Purchases (IAP)** - Native Store Payments
**Best for:** Apps distributed through app stores

**Pros:**
- ✅ Apple/Google handle all payments
- ✅ Required for App Store distribution
- ✅ Users trust store payments
- ✅ No PCI compliance needed

**Cons:**
- ⚠️ 15-30% store commission
- ⚠️ Separate iOS and Android implementations
- ⚠️ Complex subscription management

---

## Recommended Approach: RevenueCat

For a mobile-first app like EcoPantry, **RevenueCat** is the best choice because:
1. It works with both iOS and Android app stores
2. Handles complex subscription logic
3. Easy Flutter integration
4. Free for small apps
5. Complies with App Store guidelines

---

## Implementation Steps

### Phase 1: Setup RevenueCat Account

1. **Create Account**
   - Go to https://www.revenuecat.com/
   - Sign up for free account
   - Create a new project for "EcoPantry"

2. **Configure App Stores**
   - Add iOS app (Bundle ID from Xcode)
   - Add Android app (Package name from build.gradle)
   - Connect to App Store Connect & Google Play Console

3. **Create Products**
   - Product ID: `premium_monthly` - $9.99/month
   - Product ID: `premium_yearly` - $99.99/year (save 17%)
   - Configure in both App Store Connect and Google Play Console

4. **Get API Keys**
   - Copy public SDK key (different for iOS/Android)
   - Copy secret API key (for server)

### Phase 2: Setup App Store Products

#### Apple App Store Connect
1. Go to https://appstoreconnect.apple.com/
2. Navigate to your app → Features → In-App Purchases
3. Create Auto-Renewable Subscription Group: "EcoPantry Premium"
4. Add subscriptions:
   - `premium_monthly`: $9.99/month
   - `premium_yearly`: $99.99/year
5. Fill in localizations and metadata
6. Submit for review

#### Google Play Console
1. Go to https://play.google.com/console/
2. Navigate to your app → Monetize → Subscriptions
3. Create subscription products:
   - `premium_monthly`: $9.99/month
   - `premium_yearly`: $99.99/year
4. Set up base plans and offers
5. Activate subscriptions

### Phase 3: Add Flutter Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  purchases_flutter: ^6.0.0  # RevenueCat SDK
  purchases_ui_flutter: ^6.0.0  # Optional: Pre-built paywall UI
```

### Phase 4: Implement RevenueCat Integration

See implementation files below.

### Phase 5: Setup Webhooks

1. In RevenueCat dashboard, configure webhook URL:
   - URL: `https://your-cloud-function-url/revenuecat-webhook`
   - Events: All subscription events

2. Implement Cloud Function to handle events:
   - `INITIAL_PURCHASE` - Upgrade to premium
   - `RENEWAL` - Extend premium
   - `CANCELLATION` - Schedule downgrade
   - `EXPIRATION` - Downgrade to free

### Phase 6: Testing

1. **Sandbox Testing**
   - iOS: Add sandbox tester in App Store Connect
   - Android: Use test license testers in Play Console

2. **Test Scenarios**
   - Purchase subscription
   - Restore purchases (different device)
   - Cancel subscription
   - Resubscribe
   - Refund

---

## Alternative: Web-Only Stripe Integration

If you're distributing outside app stores (web app, enterprise), you can use Stripe:

### Stripe Setup Steps

1. **Create Stripe Account**
   - https://stripe.com/
   - Complete business verification

2. **Create Products**
   - Premium Monthly: $9.99/month
   - Premium Yearly: $99.99/year

3. **Add Flutter Package**
   ```yaml
   dependencies:
     flutter_stripe: ^10.0.0
   ```

4. **Implement Stripe Payment Flow**
   - See stripe_implementation.dart below

---

## Pricing Recommendations

### Suggested Pricing Tiers

**Monthly:** $9.99/month
- Good for testing
- Low commitment
- Higher LTV with annual push

**Yearly:** $99.99/year (17% discount)
- Better for business
- Higher upfront revenue
- Lower churn

**Alternative Tiered Approach:**
- Basic (Free): 3 recipes/day, no shopping list
- Plus ($4.99/month): 10 recipes/day, shopping list
- Premium ($9.99/month): Unlimited everything, priority support

---

## Security Best Practices

1. **Never Store Payment Info**
   - Let RevenueCat/Stripe handle it
   - Never store credit card details

2. **Server-Side Verification**
   - Always verify purchases on backend
   - Don't trust client-side purchase status

3. **Use Webhooks**
   - Handle subscription changes server-side
   - Update Firestore via Cloud Functions

4. **Test Thoroughly**
   - Test refunds
   - Test subscription cancellations
   - Test grace periods

---

## Legal Requirements

⚠️ **Important:** Consult with a lawyer for:

1. **Terms of Service**
   - Subscription terms
   - Cancellation policy
   - Refund policy

2. **Privacy Policy**
   - Payment data handling
   - Third-party processors (RevenueCat/Stripe)

3. **Regional Compliance**
   - EU: GDPR, PSD2
   - US: State sales tax
   - Others: Local regulations

---

## Next Steps

1. Choose payment provider (RevenueCat recommended)
2. Set up developer accounts (Apple, Google)
3. Create subscription products
4. Implement payment flow (see implementation files)
5. Set up webhooks for server-side validation
6. Test thoroughly in sandbox
7. Submit for app store review
8. Launch! 🚀

---

## Cost Breakdown Example

**Monthly Revenue: $1,000**
- RevenueCat: $0 (free tier)
- Apple Store: $300 (30% commission)
- Google Play: $300 (30% commission)
- Net: $400 (40%)

**After $10k MRR:**
- RevenueCat: 1% of revenue
- Store fees: 15-30% (drops to 15% after year 1 on Apple)

---

## Support Resources

**RevenueCat:**
- Docs: https://www.revenuecat.com/docs
- Flutter: https://www.revenuecat.com/docs/flutter
- Discord: https://discord.gg/revenuecat

**Stripe:**
- Docs: https://stripe.com/docs
- Flutter: https://pub.dev/packages/flutter_stripe

**In-App Purchases:**
- Apple: https://developer.apple.com/in-app-purchase/
- Google: https://developer.android.com/google/play/billing

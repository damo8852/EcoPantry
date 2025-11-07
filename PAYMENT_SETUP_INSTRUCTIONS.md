# Step-by-Step Payment Integration Instructions

## Quick Start Guide: Adding Payments to EcoPantry

This guide will walk you through implementing RevenueCat for in-app subscriptions.

---

## Prerequisites

Before you begin, you'll need:

- ✅ Apple Developer Account ($99/year) - https://developer.apple.com/
- ✅ Google Play Developer Account ($25 one-time) - https://play.google.com/console/
- ✅ RevenueCat free account - https://www.revenuecat.com/
- ✅ Your app published or in TestFlight/Internal Testing

---

## Step 1: Add RevenueCat Package

1. Open `pubspec.yaml`

2. Add the RevenueCat dependency:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ... your existing dependencies ...

  # Add these:
  purchases_flutter: ^6.0.0
  purchases_ui_flutter: ^6.0.0  # Optional: Pre-built paywall
```

3. Run in terminal:
```bash
cd /home/daniel/Desktop/CSC25/fridge/fridge
flutter pub get
```

---

## Step 2: Setup Apple App Store Connect

### 2.1 Create App in App Store Connect

1. Go to https://appstoreconnect.apple.com/
2. Click **My Apps** → **+** button → **New App**
3. Fill in app information:
   - **Platform**: iOS
   - **Name**: EcoPantry
   - **Primary Language**: English
   - **Bundle ID**: Select your bundle ID (e.g., com.ecopantry.app)
   - **SKU**: ecopantry-ios (unique identifier)

### 2.2 Create Subscription Group

1. In your app, go to **Features** → **In-App Purchases**
2. Click **+** → **Auto-Renewable Subscription**
3. Create a **Subscription Group**: "EcoPantry Premium"
4. Click **Create**

### 2.3 Create Monthly Subscription

1. Click **+** in the subscription group
2. Fill in details:
   - **Reference Name**: Premium Monthly
   - **Product ID**: `premium_monthly` (must match RevenueCat)
   - Click **Create**
3. Add Subscription Pricing:
   - Click **+ Add Subscription Pricing**
   - **Price**: $9.99 USD
   - Select all territories or specific ones
4. Add Localizations:
   - **Subscription Display Name**: Premium Monthly
   - **Description**: Unlimited recipes and shopping lists
5. Save

### 2.4 Create Yearly Subscription

1. Repeat for yearly:
   - **Reference Name**: Premium Yearly
   - **Product ID**: `premium_yearly`
   - **Price**: $99.99 USD (you can also add intro pricing here)
   - **Display Name**: Premium Yearly
   - **Description**: Save 17% with annual billing

### 2.5 Submit for Review

1. Fill in **Review Information**
2. Add **App Store Promotional Image** (optional)
3. Click **Submit for Review**

⚠️ **Note**: Subscriptions must be approved before you can test them (even in sandbox)

---

## Step 3: Setup Google Play Console

### 3.1 Create App

1. Go to https://play.google.com/console/
2. **Create app** if not already created
3. Fill in app details

### 3.2 Setup Subscription Base Plans

1. Navigate to **Monetize** → **Subscriptions**
2. Click **Create subscription**

### 3.3 Create Monthly Subscription

1. **Product ID**: `premium_monthly` (must match exactly)
2. **Name**: Premium Monthly
3. **Description**: Unlimited recipes and shopping lists
4. Click **Create**

5. Add Base Plan:
   - **Base plan ID**: monthly
   - **Billing period**: 1 month
   - **Price**: $9.99 USD
   - Set prices for all countries
   - **Auto-renewing**: Yes
   - **Grace period**: 3 days (optional)
6. **Save** and **Activate**

### 3.4 Create Yearly Subscription

1. Repeat for yearly:
   - **Product ID**: `premium_yearly`
   - **Base plan ID**: yearly
   - **Billing period**: 12 months
   - **Price**: $99.99 USD
2. **Save** and **Activate**

---

## Step 4: Setup RevenueCat

### 4.1 Create Account

1. Go to https://app.revenuecat.com/signup
2. Sign up with email
3. Create project: **EcoPantry**

### 4.2 Add iOS App

1. In RevenueCat dashboard, click **+ New** → **Project**
2. Click **Apps** → **+ New**
3. Select **iOS**
4. Fill in:
   - **App name**: EcoPantry iOS
   - **Bundle ID**: Your iOS bundle ID
   - **App Store Connect App-Specific Shared Secret**:
     - Get this from App Store Connect → Your App → General → App Information
     - Click **Manage** next to Shared Secret
     - Generate if needed
     - Copy and paste into RevenueCat
5. Click **Save**

### 4.3 Add Android App

1. Click **Apps** → **+ New**
2. Select **Android**
3. Fill in:
   - **App name**: EcoPantry Android
   - **Package name**: Your Android package name
   - **Service Account Credentials**:
     - Go to Google Play Console → Settings → API access
     - Create credentials → Service account
     - Download JSON file
     - Upload to RevenueCat
4. Click **Save**

### 4.4 Create Products

1. In RevenueCat, go to **Products**
2. Click **+ New**
3. Create **premium_monthly**:
   - **Identifier**: premium_monthly
   - **Type**: Subscription
   - **Store Product IDs**:
     - iOS: premium_monthly
     - Android: premium_monthly
4. Create **premium_yearly** the same way

### 4.5 Create Entitlement

1. Go to **Entitlements** → **+ New**
2. Create entitlement:
   - **Identifier**: `premium`
   - **Description**: Premium access
3. Attach products:
   - Add premium_monthly
   - Add premium_yearly
4. Save

### 4.6 Create Offering

1. Go to **Offerings** → **+ New**
2. Create offering:
   - **Identifier**: `default`
   - **Description**: Default offering
3. Add packages:
   - **Package 1**:
     - **Identifier**: `$rc_monthly`
     - **Product**: premium_monthly
   - **Package 2**:
     - **Identifier**: `$rc_annual`
     - **Product**: premium_yearly
4. Set as **Current offering**
5. Save

### 4.7 Get API Keys

1. Go to **API Keys** in project settings
2. Copy **Public app-specific SDK key for iOS**
3. Copy **Public app-specific SDK key for Android**
4. Copy **Secret API Key** (for webhooks)

---

## Step 5: Update Flutter Code

### 5.1 Add API Keys

1. Open `lib/services/payment_service.dart`

2. Replace the API keys:

```dart
// Around line 18-19, replace:
const String iosApiKey = 'YOUR_IOS_API_KEY_HERE';
const String androidApiKey = 'YOUR_ANDROID_API_KEY_HERE';

// With your actual keys from RevenueCat:
const String iosApiKey = 'appl_xxxxxxxxxxxxxx';
const String androidApiKey = 'goog_xxxxxxxxxxxxxx';
```

### 5.2 Initialize in main.dart

1. Open `lib/main.dart`

2. Add import at top:
```dart
import 'services/payment_service.dart';
```

3. In the `main()` function, after Firebase initialization, add:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ADD THIS: Initialize RevenueCat
  await PaymentService.instance.initialize();

  // ... rest of initialization ...
  runApp(const EcoPantryApp());
}
```

### 5.3 Update Paywall Screen (Optional)

If you want to load real prices from RevenueCat, update `lib/screens/paywall_screen.dart`:

1. In `_PaywallScreenState`, add:
```dart
  List<Package>? _packages;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final offerings = await PaymentService.instance.getOfferings();
    if (offerings?.current != null) {
      setState(() {
        _packages = offerings!.current!.availablePackages;
      });
    }
  }
```

2. Update `_handleSubscribe()` to use real purchase:
```dart
  Future<void> _handleSubscribe() async {
    setState(() => _isLoading = true);

    try {
      final package = _packages?[_selectedPlanIndex];
      if (package != null) {
        final success = await PaymentService.instance.purchasePackage(package);
        if (success && mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome to Premium!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
```

---

## Step 6: Setup Webhooks (Backend Validation)

### 6.1 Create Cloud Function

1. In your `functions/` directory, create `revenuecat_webhook.py`:

```python
from firebase_functions import https_fn
from firebase_admin import firestore
import hmac
import hashlib

db = firestore.client()

@https_fn.on_request()
def revenuecat_webhook(req: https_fn.Request) -> https_fn.Response:
    """Handle RevenueCat webhook events"""

    # Verify webhook signature
    signature = req.headers.get('X-RevenueCat-Signature')
    # TODO: Verify signature with your RevenueCat webhook secret

    event = req.get_json()
    event_type = event.get('type')
    user_id = event.get('app_user_id')

    # Handle different event types
    if event_type == 'INITIAL_PURCHASE':
        # User purchased premium
        _update_subscription(user_id, True, event)

    elif event_type == 'RENEWAL':
        # Subscription renewed
        _update_subscription(user_id, True, event)

    elif event_type == 'CANCELLATION':
        # User cancelled (but may still have access until expiry)
        pass

    elif event_type == 'EXPIRATION':
        # Subscription expired
        _update_subscription(user_id, False, event)

    return https_fn.Response("OK")

def _update_subscription(user_id: str, is_premium: bool, event: dict):
    """Update user subscription in Firestore"""
    user_ref = db.collection('users').document(user_id)

    subscription_data = {
        'tier': 'premium' if is_premium else 'free',
        'premiumExpiresAt': event.get('expiration_at_ms'),
        # Don't reset recipe count - let client handle that
    }

    user_ref.update({'subscription': subscription_data})
```

2. Deploy:
```bash
firebase deploy --only functions
```

### 6.2 Configure Webhook in RevenueCat

1. In RevenueCat dashboard, go to **Integrations** → **Webhooks**
2. Click **+ Add Webhook**
3. Enter your Cloud Function URL:
   - `https://your-region-your-project.cloudfunctions.net/revenuecat_webhook`
4. Select events to send:
   - ✅ Initial Purchase
   - ✅ Renewal
   - ✅ Cancellation
   - ✅ Expiration
   - ✅ Billing Issue
5. Copy the **Webhook secret** for signature verification
6. Save

---

## Step 7: Testing

### 7.1 iOS Sandbox Testing

1. On your iPhone, go to **Settings** → **App Store** → **Sandbox Account**
2. Sign in with test account from App Store Connect
3. Run app in debug mode
4. Try to purchase subscription
5. You'll see iTunes confirmation (sandbox)
6. Approve purchase
7. Check that premium features unlock

### 7.2 Android Testing

1. Add your Google account as a license tester in Play Console
2. Run app in debug mode
3. Try to purchase
4. You'll see Google Play confirmation (test)
5. Approve purchase
6. Check premium features

### 7.3 Test Scenarios

Test these flows:
- ✅ Purchase monthly subscription
- ✅ Purchase yearly subscription
- ✅ Cancel subscription
- ✅ Restore purchases on new device
- ✅ Let subscription expire
- ✅ Resubscribe after cancellation

---

## Step 8: Production Release

### 8.1 Final Checks

- [ ] Tested in sandbox thoroughly
- [ ] Webhooks configured and tested
- [ ] Terms of Service updated
- [ ] Privacy Policy updated with payment info
- [ ] Refund policy documented
- [ ] Customer support email set up

### 8.2 App Store Submission

1. Update app with payment code
2. Submit to App Store review
3. In review notes, mention:
   - Test account credentials
   - How to trigger subscription flow
   - That subscriptions are properly configured

### 8.3 Play Store Submission

1. Upload APK/AAB with payment code
2. Submit for review
3. Play Store review is usually faster

### 8.4 Go Live!

1. Once approved, flip app to production
2. Monitor RevenueCat dashboard for purchases
3. Watch Firestore for subscription updates
4. Monitor error logs for issues

---

## Troubleshooting

### "Product IDs don't match"
- Ensure product IDs are exactly the same in:
  - App Store Connect
  - Google Play Console
  - RevenueCat dashboard
  - Your code

### "Purchases not updating in app"
- Check webhook logs in Firebase
- Verify webhook URL is correct
- Check RevenueCat event history
- Ensure user ID matches Firebase auth UID

### "Can't test subscriptions"
- Ensure subscriptions are approved in stores
- Use correct sandbox/test accounts
- Clear app data and reinstall
- Check RevenueCat debug logs

### "Store prices don't show"
- Ensure offerings are set as "Current"
- Check network connection
- Verify API keys are correct
- Check RevenueCat debug logs

---

## Support

**RevenueCat:**
- Docs: https://www.revenuecat.com/docs/getting-started
- Community: https://community.revenuecat.com/
- Support: support@revenuecat.com

**Apple:**
- Developer Forums: https://developer.apple.com/forums/
- Support: https://developer.apple.com/support/

**Google:**
- Support: https://support.google.com/googleplay/android-developer/

---

## Cost Summary

**Development:**
- Apple Developer: $99/year
- Google Play: $25 one-time
- RevenueCat: Free (< $10k MRR)
- Total: ~$124 first year, $99/year after

**Per Transaction:**
- Apple: 30% (15% after year 1)
- Google: 30% (15% after year 1)
- RevenueCat: 1% (after $10k MRR)

**Example: $1000 in monthly revenue**
- RevenueCat: $0 (free tier)
- Store fees: $300
- Your net: $700 (70%)

---

## Next Steps

1. ✅ Read this guide thoroughly
2. ✅ Create developer accounts if needed
3. ✅ Setup RevenueCat account
4. ✅ Configure products in stores
5. ✅ Add API keys to code
6. ✅ Test in sandbox
7. ✅ Setup webhooks
8. ✅ Submit for review
9. ✅ Launch!

Good luck with your payment integration! 🚀

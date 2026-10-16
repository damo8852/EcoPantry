# Premium plan (archived)

The free/premium tier system was removed from the app while it isn't headed to production.
Everything is still in git under the tag **`premium-plan-archive`** (commit `75392c1`, "money tracking").

## What it was

| File | Purpose |
| --- | --- |
| `lib/models/user_subscription.dart` | Tier, daily counters, feature limits |
| `lib/services/subscription_service.dart` | Reads/writes `users/{uid}.subscription`, enforces limits |
| `lib/services/payment_service.dart` | Payment processing stub |
| `lib/screens/paywall_screen.dart` | Upgrade / pricing screen |
| `lib/widgets/upgrade_dialog.dart` | "Limit reached" and "Premium only" dialogs |

Free-tier limits: daily recipe generations, daily receipt scans, and no access to Community Recipes
or the Shopping List hub.

## Where it was wired in

- `lib/services/auth.dart`: `initializeUserSubscription(uid)` after every sign-up / Google sign-in
- `lib/screens/scan.dart`: `canScanReceipt()` check before scanning, `incrementReceiptScanCount()` after saving
- `lib/screens/recipes_hub_screen.dart`: `canGenerateRecipes()` check, `incrementRecipeCount()` after generating
- `lib/screens/shopping_list_hub_screen.dart`: `canAccessShoppingList()` gate with locked screen, plus the recipe limit
- `lib/screens/community_recipes_screen.dart`: `canAccessCommunityRecipes()` gate with locked screen
- `lib/screens/settings.dart`: "Free Plan / Premium Plan" card with dev upgrade/downgrade/reset buttons

`firestore.rules` still validates the `subscription` field on `users/{uid}`; that rule is harmless
without the feature and is needed again if it comes back.

## Restoring it

```bash
# bring back the five premium files
git checkout premium-plan-archive -- \
  lib/models/user_subscription.dart \
  lib/services/subscription_service.dart \
  lib/services/payment_service.dart \
  lib/screens/paywall_screen.dart \
  lib/widgets/upgrade_dialog.dart

# see exactly how each screen was gated, to re-apply by hand
git diff premium-plan-archive -- lib/services/auth.dart lib/screens/scan.dart \
  lib/screens/recipes_hub_screen.dart lib/screens/shopping_list_hub_screen.dart \
  lib/screens/community_recipes_screen.dart lib/screens/settings.dart
```

The tag is local until pushed: `git push origin premium-plan-archive`.

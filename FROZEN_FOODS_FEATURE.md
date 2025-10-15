# Frozen Foods Feature

## Overview
This feature adds a "frozen foods section" to the app, allowing users to freeze items (pausing their expiration dates) and optionally include them in recipe generation.

## Features Implemented

### 1. Data Model Updates
- Added `isFrozen` boolean field to track frozen status
- Added `frozenAt` timestamp to record when item was frozen
- Added `originalExpiryDate` to preserve expiry date when freezing

### 2. Freeze/Unfreeze Operations

#### Freeze Items (`_freezeSelectedItems`)
- Marks selected items as frozen
- Stores the original expiry date
- Records the frozen timestamp
- Shows success message with undo option

#### Unfreeze Items (`_unfreezeSelectedItems`)
- Marks selected items as unfrozen
- Restores the original expiry date
- Cleans up frozen metadata
- Shows success message

### 3. UI Components

#### Separate Frozen Items View (Modal Bottom Sheet)
- Frozen items displayed in a modal bottom sheet (like Priority Items)
- Accessed via hamburger menu "Frozen Items" option
- Features:
  - Shows count of frozen items in header
  - Sortable by freeze date (most recent first)
  - Each item shows name, category icon, and "Frozen X time ago"
  - Quick unfreeze via popup menu on each item
  - Empty state with helpful message when no items are frozen
- Matches the Priority Items UX pattern for consistency

#### Freeze/Unfreeze Action Buttons
- Added to multi-select mode action bar
- Context-aware: shows "Freeze" when viewing regular items, "Unfreeze" when viewing frozen items
- Blue/cyan colored for visual distinction (freeze) and orange colored (unfreeze)
- Icons: `ac_unit_rounded` for freeze, `ac_unit` with orange color for unfreeze

#### Visual Indicators
- Frozen items display a small snowflake icon badge (🧊) next to the item name
- Badge appears in both compact and regular view modes
- Blue (#00BCD4) colored background for consistency

### 4. Item Filtering
- Modified StreamBuilder filtering logic to separate frozen and non-frozen items
- When `_showFrozenOnly = true`: only frozen items are displayed
- When `_showFrozenOnly = false`: only non-frozen items are displayed
- Filters work in combination with existing category and text filters

### 5. Recipe Generation Integration

#### User Option Dialog
- Added a dialog before recipe generation asking if user wants to include frozen items
- Simple checkbox: "Include frozen items"
- Styled to match app theme (dark/light mode support)
- "Generate" button proceeds with user's choice
- "Cancel" button aborts the operation

#### Recipe Logic Updates
- Modified ingredient extraction to filter based on frozen status
- If user chooses NOT to include frozen items:
  - Frozen items are excluded from ingredient list
  - Frozen items are excluded from prioritized items list
- If user chooses to include frozen items:
  - All items (frozen and non-frozen) are included
- Filtering happens at the query level for efficiency

## Files Modified

### 1. `lib/screens/home.dart`
- Added `_freezeSelectedItems()` method for bulk freezing
- Created `_showFrozenItems()` method to display modal with frozen items
- Main StreamBuilder automatically filters out frozen items
- Added freeze button to multi-select action bar
- Added "Frozen Items" menu option in hamburger drawer
- Modal bottom sheet displays:
  - Frozen items count
  - Sorted list by freeze date
  - Individual unfreeze action per item
  - Empty state when no frozen items
- Updated `_recommendRecipes()` to show dialog and filter ingredients
- Passed `isFrozen` parameter to ItemTile widget

### 2. `lib/widgets/item_tile.dart`
- Added `isFrozen` boolean parameter
- Added frozen badge display (snowflake icon) in both compact and regular views
- Badge appears next to priority indicator (if present)

## User Experience Flow

### Freezing Items
1. User selects items using multi-select mode (checkbox icon in app bar)
2. User taps the freeze icon (❄️) in the action bar
3. Items are marked as frozen and moved to frozen section
4. Success message appears

### Viewing Frozen Items
1. User opens hamburger menu (☰)
2. User taps "Frozen Items" menu option
3. Modal bottom sheet opens showing all frozen items
4. Items sorted by freeze date (newest first)
5. User can unfreeze items individually via popup menu
6. Swipe down or tap outside to close modal

### Unfreezing Items
1. Open "Frozen Items" from hamburger menu
2. Tap the menu button (⋮) on any frozen item
3. Select "Unfreeze"
4. Item is immediately unfrozen and restored to main list
5. Original expiry date is restored (or set to 7 days if lost)
6. Modal automatically closes after unfreezing

### Recipe Generation with Frozen Items
1. User taps "Recipes" button
2. Dialog appears asking "Include frozen items?"
3. User checks/unchecks the checkbox and taps "Generate"
4. Recipe generation proceeds with filtered ingredient list
5. Frozen items are included/excluded based on user's choice

## Technical Notes

### Database Schema
Items in Firestore now support these optional fields:
```
{
  name: string,
  quantity: number,
  groceryType: string,
  expiryDate: timestamp,
  isPrioritized: boolean,
  isFrozen: boolean,           // NEW
  frozenAt: timestamp,          // NEW
  originalExpiryDate: timestamp // NEW (only when frozen)
}
```

### State Management
- Main view automatically excludes frozen items (filters out `isFrozen == true`)
- `_showFrozenItems()` fetches frozen items on-demand via Firestore query
- Modal pattern ensures frozen items don't interfere with main view
- Works with existing filters (`_selectedFilters`, `_mustContainText`) in main view

### Color Scheme
- Freeze icon/button: Cyan (#00BCD4)
- Unfreeze icon/button: Orange (#FF5722 / #FF9800)
- Frozen badge: Cyan (#00BCD4) background with white icon

## Architecture

The frozen foods feature uses a modal-based architecture (similar to Priority Items):

1. **Separation of Views**: Main view excludes frozen items automatically
2. **On-Demand Loading**: Frozen items are fetched only when modal is opened
3. **Modal Bottom Sheet**: Uses DraggableScrollableSheet for smooth UX
4. **Individual Actions**: Unfreeze happens per-item in the modal (no multi-select needed)
5. **Freeze from Main View**: Multi-select freeze available in main view via action bar
6. **Consistency**: Matches the Priority Items UX pattern users are already familiar with

## Future Enhancements (Optional)

1. **Auto-freeze by Type**: Option to auto-freeze items of type "Frozen" 
2. **Freeze Duration Display**: Show how long items have been frozen
3. **Batch Operations**: "Freeze all expired items" or "Freeze all in category"
4. **Smart Unfreeze**: Suggest new expiry dates based on food type when unfreezing
5. **Frozen Items Count**: Display count badge on "Frozen" tab
6. **Remember User Preference**: Save user's preference for including frozen items in recipes
7. **Swipe to Freeze**: Add swipe gesture to quickly freeze/unfreeze items

## Testing Checklist

- [x] Items can be frozen via multi-select
- [x] Items can be unfrozen via multi-select
- [x] Frozen section toggle works correctly
- [x] Frozen badge displays on items
- [x] Recipe dialog shows frozen items option
- [x] Recipe generation filters ingredients correctly
- [x] Dark mode styling works
- [x] Light mode styling works
- [x] No linter errors
- [x] Existing functionality not broken

## Compatibility

- Flutter SDK: Compatible with current version
- Firebase Firestore: Backward compatible (new fields are optional)
- Existing data: Works with items that don't have frozen fields


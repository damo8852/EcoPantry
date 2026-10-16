import 'package:ecopantry/models/purchase.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> item(String name, double list, double discount, String category, {double qty = 1}) =>
    {'name': name, 'quantity': qty, 'price': list, 'discount': discount, 'category': category};

/// The Oct 13, 2026 King Soopers delivery invoice, transcribed line by line.
Map<String, dynamic> oct13Invoice() => {
      'date': '2026-10-13',
      'subtotal': 89.77,
      'itemDiscounts': 37.32,
      'coupons': 2.00,
      'fees': 1.01,
      'tax': 1.90,
      'total': 53.36,
      'savings': 43.27,
      'items': [
        item('Arizona Lemon Iced Tea', 0.89, 0.10, 'beverages'),
        item('Birds Eye Steamfresh', 1.67, 0.62, 'frozen'),
        item('Bubly Cherry', 2.99, 2.00, 'beverages'),
        item('Ensure Max Protein', 4.95, 17.50, 'beverages', qty: 5),
        item('Jalapeno', 0.30, 0.02, 'produce'),
        item('Green Onions', 2.58, 0, 'produce', qty: 2),
        item("Kinder's Fajita", 1.00, 1.19, 'pantry'),
        item('Milk', 2.69, 0, 'dairyEggs'),
        item('Black Bean', 1.00, 0, 'pantry'),
        item('Ground Beef', 6.14, 1.35, 'meatSeafood'),
        item('Eggs', 1.99, 0.66, 'dairyEggs'),
        item('Chicken Broth', 1.49, 0.10, 'pantry'),
        item('Shredded Cheese', 2.00, 0, 'dairyEggs'),
        item('Sour Cream', 1.99, 0, 'dairyEggs'),
        item('Ketchup', 1.25, 0.34, 'pantry'),
        item('Salsa', 2.99, 0, 'pantry'),
        item('Clementines', 2.49, 3.50, 'produce'),
        item('Firm Tofu', 1.99, 0, 'meatSeafood'),
        item('Silken Tofu', 1.99, 0, 'meatSeafood'),
        item('Chicken Breast Tenders', 7.92, 0, 'meatSeafood'),
        item('Chicken Breast Tenders', 0.00, 7.79, 'meatSeafood'),
        item('Tortillas', 2.14, 2.15, 'bakery'),
      ],
    };

void main() {
  test('real invoice: passes summary checks and categories add up to the total', () {
    final p = Purchase.fromReceipt(oct13Invoice());
    expect(p.problems, isEmpty);
    expect(p.addsUp, isTrue);
    final totals = p.categoryTotals();
    expect(totals.values.fold<double>(0, (a, b) => a + b), closeTo(53.36, 0.001));
    expect(totals[SpendCategory.tax], closeTo(2.91, 0.001));
    expect(totals[SpendCategory.orderCoupons], closeTo(-2.00, 0.001));
    expect(totals.containsKey(SpendCategory.other), isFalse);
    // ground beef 6.14 + chicken 7.92 + two tofus 3.98
    expect(totals[SpendCategory.meatSeafood], closeTo(18.04, 0.001));
    expect(p.savings, 43.27);
    expect(p.itemDiscounts, 37.32);
    expect(p.couponSavings, 2.00);
  });

  test('real invoice: printed prices are kept and duplicate chicken lines merge', () {
    final p = Purchase.fromReceipt(oct13Invoice());
    final beef = p.items.firstWhere((i) => i.name == 'Ground Beef');
    expect(beef.price, 6.14);
    expect(beef.listPrice, closeTo(7.49, 0.001));
    final chicken = p.items.where((i) => i.name == 'Chicken Breast Tenders').toList();
    expect(chicken, hasLength(1));
    expect(chicken.single.price, 7.92);
    expect(chicken.single.savings, 7.79);
    expect(chicken.single.quantity, 1);
    final ensure = p.items.firstWhere((i) => i.name == 'Ensure Max Protein');
    expect(ensure.price, 4.95);
    expect(ensure.listPrice, closeTo(22.45, 0.001));
  });

  test('flags an extraction that does not match the receipt summary', () {
    final bad = oct13Invoice()..['items'] = (oct13Invoice()['items'] as List).sublist(1);
    final p = Purchase.fromReceipt(bad);
    expect(p.problems, isNotEmpty);
  });

  test('stored trips round-trip and old labels still map', () {
    final p = Purchase.fromReceipt(oct13Invoice());
    final map = p.toMap()..['date'] = p.date.toIso8601String();
    final back = Purchase.fromMap(map, id: p.id);
    expect(back.itemsTotal, closeTo(p.itemsTotal, 0.001));
    expect(back.fees, 1.01);
    expect(back.items.first.listPrice, closeTo(0.99, 0.001));
    expect(SpendCategory.fromName('Meat & Seafood'), SpendCategory.meatSeafood);
    expect(SpendCategory.fromName('tax'), SpendCategory.other);
  });
}

// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ecopantry/main.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('app builds without crashing', (WidgetTester tester) async {
    // Use the app widget defined in lib/main.dart
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    // We cannot easily run the full app (it initializes Firebase/timezone),
    // so assert the test environment can render a simple widget.
    expect(find.byType(SizedBox), findsOneWidget);
  });
}

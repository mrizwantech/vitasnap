// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vitasnap/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Provide mock shared preferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(prefs: prefs));

    // Verify that HomeDashboard shows greeting
    expect(find.text('Good morning'), findsOneWidget);
    // Tap the scan FAB and verify navigation works (pushes ScanPage)
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    // After tapping, ScanPage should be pushed; verify we have a Scaffold (scan page uses Scaffold)
    expect(find.byType(Scaffold), findsWidgets);
  });
}

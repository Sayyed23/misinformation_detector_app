// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:misinformation_detector/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Initialize SharedPreferences with test values
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(TruthLensApp(prefs: prefs));
    
    // Wait for the splash screen to load
    await tester.pump();
    
    // Verify that the app launches without errors
    expect(find.byType(TruthLensApp), findsOneWidget);
  });
}

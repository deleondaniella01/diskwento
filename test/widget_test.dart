// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the widgets are displayed.
//
// For example:
//
// testWidgets('Counter increments smoke test', (WidgetTester tester) async {
//   // Build our app and trigger a frame.
//   await tester.pumpWidget(const MyApp());
//
//   // Verify that our counter starts at 0.
//   expect(find.text('0'), findsOneWidget);
//   expect(find.text('1'), findsNothing);
//
//   // Tap the '+' icon and trigger a frame.
//   await tester.tap(find.byIcon(Icons.add));
//   await tester.pump();
//
//   // Verify that our counter has incremented.
//   expect(find.text('0'), findsNothing);
//   expect(find.text('1'), findsOneWidget);
// });

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_analytics/firebase_analytics.dart'; // Import if not already
import 'package:mockito/mockito.dart'; // Add this for mocking

import 'package:myapp/main.dart'; // Adjust import path if necessary

// Mock classes for FirebaseAnalytics and FirebaseAnalyticsObserver
// If you have a separate file for mocks, you can import it.
// Otherwise, define them here.

// You'll need to add mockito to your pubspec.yaml dev_dependencies:
// dev_dependencies:
//   flutter_test:
//     sdk: flutter
//   mockito: ^5.x.x # Use the latest stable version

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}
class MockFirebaseAnalyticsObserver extends Mock implements FirebaseAnalyticsObserver {}


void main() {
  testWidgets('App displays title', (WidgetTester tester) async {
    // Create mock instances
    final mockAnalytics = MockFirebaseAnalytics();
    final mockObserver = MockFirebaseAnalyticsObserver();

    // Build our app with the mock instances and trigger a frame.
    await tester.pumpWidget(MyApp(
      analytics: mockAnalytics,
      observer: mockObserver,
    ));

    // Verify that the app title is displayed.
    // Replace 'Dibs Home' with the actual text your app displays as its title.
    expect(find.text('Dibs'), findsOneWidget); // Changed to 'Dibs' as seen in main.dart app bar
    expect(find.text('Your exclusive claim to best deals'), findsOneWidget);

    // You can add more specific tests here based on your UI.
    // For example, finding a specific icon or text.
    expect(find.byIcon(Icons.local_offer), findsOneWidget);
  });

  // Add more tests as needed for other functionalities.
}
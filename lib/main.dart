import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diskwento',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.greenAccent),
        useMaterial3: true, // Recommended for modern Flutter apps
      ),
      navigatorObservers: <NavigatorObserver>[observer],
      home: MyHomePage(
        title: 'Diskwento',
        analytics: analytics,
        observer: observer,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.analytics,
    required this.observer,
  });

  final String title;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void setMessage(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _sendAnalyticsEvent() async {
    await widget.analytics.logEvent(
      name: 'test_event',
      parameters: <String, Object>{
        'string': 'string',
        'int': 42,
        'long': 12345678910,
        'double': 42.0,
        'bool': true.toString(),
      },
    );
    setMessage('logEvent succeeded');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Image.asset('assets/logo.png', height: 45),
        centerTitle: false, // Align logo to start
      ),
      body: SingleChildScrollView(
        // <--- THIS IS THE KEY FIX!
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            // 1. Search Bar at the top
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  suffixIcon: const Icon(Icons.search),
                ),
              ),
            ),

            // 2. The "Browse Categories" Text and Buttons section
            Container(
              padding: const EdgeInsets.all(16.0),
              color: const Color.fromARGB(54, 186, 186, 186),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // The "Browse Categories" Text
                  Text(
                    'Browse Categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(232, 47, 47, 47),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Use a Row or more specific layout for buttons
                  // Expanded inside a Wrap is problematic.
                  // For responsive buttons, consider using LayoutBuilder or MediaQuery
                  // For now, let's just make sure they don't overflow horizontally.
                  Wrap(
                    spacing: 8.0, // horizontal space between buttons
                    runSpacing: 4.0, // vertical space when wrapping
                    children: <Widget>[
                      ElevatedButton.icon(
                        // Changed to ElevatedButton.icon for direct icon+text
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 91, 216, 156), // Background color
                          foregroundColor: const Color.fromARGB(255, 255, 255, 255), // Text and icon color
                        ),
                        onPressed: () {
                          // Button 1 action
                        },
                        icon: const Icon(Icons.local_offer),
                        label: const Text('All deals'),
                      ),

                      ElevatedButton.icon(
                        onPressed: () {
                          // Button 1 action
                        },
                        icon: const Icon(Icons.checkroom), // Fashion icon
                        label: const Text('Fashion'),
                      ),

                      ElevatedButton.icon(
                        onPressed: () {
                          // Button 2 action
                        },
                        icon: const Icon(
                          Icons.restaurant,
                        ), // Food & Dining icon
                        label: const Text('Food'),
                      ),
                      // Add more buttons as needed
                    ],
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16.0),
              color: const Color.fromARGB(54, 255, 255, 255),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row( // Use Row for horizontal layout
                    children: <Widget>[
                      Expanded( // Each card takes equal horizontal space
                        child: Card(
                          elevation: 4.0,
                          margin: const EdgeInsets.symmetric(horizontal: 4.0), // Smaller horizontal margin
                          child: Container(
                            // Remove fixed width: 150
                            padding: const EdgeInsets.all(8.0), // Reduced padding for tighter fit
                            child: Column(
                              mainAxisSize: MainAxisSize.min, // Keep column as small as possible vertically
                              children: [
                                Image.asset(
                                  'assets/logo.png',
                                  height: 80, // Reduced height for image
                                  fit: BoxFit.contain, // Use contain to ensure image fits without cropping
                                ),
                                const SizedBox(height: 4.0), // Spacing between image and text
                                const Text(
                                  'Deal 1',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), // Smaller text
                                  textAlign: TextAlign.center,
                                ),
                                const Text(
                                  'Description',
                                  style: TextStyle(fontSize: 11), // Smaller text
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4.0), // Spacing between text and button
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Smaller button padding
                                    textStyle: const TextStyle(fontSize: 12), // Smaller button text
                                  ),
                                  child: const Text('View deal'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Card(
                          elevation: 4.0,
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/logo.png',
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 4.0),
                                const Text(
                                  'Deal 2',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                                const Text(
                                  'Description',
                                  style: TextStyle(fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4.0),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  child: const Text('View deal'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Card(
                          elevation: 4.0,
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/logo.png',
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 4.0),
                                const Text(
                                  'Deal 3',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                                const Text(
                                  'Description',
                                  style: TextStyle(fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4.0),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  child: const Text('View deal'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _sendAnalyticsEvent,
        tooltip: 'log analytics event',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat, // Common and good default
    );
  }
}

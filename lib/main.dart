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
                              Colors.greenAccent, // Background color
                          foregroundColor: const Color.fromARGB(
                            255,
                            23,
                            96,
                            74,
                          ), // Text and icon color
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
                  // The "Hot Deals" Text
                  Text(
                    'Hot Deals',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(232, 47, 47, 47),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        // First floating card
                        Card(
                          elevation: 4.0,
                          margin: const EdgeInsets.only(
                            right: 8.0,
                          ), // Added right margin for spacing
                          child: Container(
                            width: 150,
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/logo.png',
                                  height: 100,
                                  width: 150,
                                  fit: BoxFit.cover,
                                ),
                                const SizedBox(
                                  height: 8.0,
                                ), // Spacing between image and text
                                const Text(
                                  'Deal 1',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  'Description',
                                ), // More descriptive
                              ],
                            ),
                          ),
                        ),

                        // Second floating card
                        Card(
                          elevation: 4.0,
                          margin: const EdgeInsets.only(
                            right: 8.0,
                          ), // Added right margin
                          child: Container(
                            width: 150,
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/logo.png',
                                  height: 100,
                                  width: 150,
                                  fit: BoxFit.cover,
                                ),
                                const SizedBox(
                                  height: 8.0,
                                ), // Spacing between image and text
                                const Text(
                                  'Deal 2',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const Text('Description'),
                              ],
                            ),
                          ),
                        ),
                        // You can add more cards here
                        Card(
                          elevation: 4.0,
                          margin: const EdgeInsets.only(right: 8.0),
                          child: Container(
                            width: 150,
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/logo.png',
                                  height: 100,
                                  width: 150,
                                  fit: BoxFit.cover,
                                ),
                                const SizedBox(height: 8.0),
                                const Text(
                                  'Deal 3',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const Text('Description'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80,), 

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

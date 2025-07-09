import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'firebase_options.dart'; // Make sure this file exists and is correct

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diskwento',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF67B08B),
        ), // More similar green from image
        useMaterial3: true,
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
  // Current index for the BottomNavigationBar
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // You can navigate to different pages here based on index
    // For now, we'll just show a toast.
    switch (index) {
      case 0:
        setMessage('Deals tab selected');
        break;
      case 1:
        setMessage('Saved tab selected');
        break;
      case 2:
        setMessage('Profile tab selected');
        break;
      case 3:
        setMessage('Settings tab selected');
        break;
    }
  }

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
        // The background color from the image seems to be a specific blue/purple
        backgroundColor: const Color.fromARGB(
          255,
          93,
          181,
          239,
        ), // Changed AppBar color
        elevation: 0, // Remove shadow
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png', // Assuming this is your Diskwento logo
              height: 45,
            ),

            const SizedBox(width: 8),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications, color: Colors.white),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: const Text(
                      '1', // Notification count
                      style: TextStyle(color: Colors.white, fontSize: 8),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              setMessage('Notifications tapped');
            },
          ),
          const SizedBox(width: 8), // Some padding on the right
        ],
      ),
      body: Container(
        // Wrap body in a Container for the light purple background
        color: const Color(
          0xFFE8F0FE,
        ), // Light blueish background color from image
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 1. Search Bar at the top
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search deals, merchants, or categories',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none, // No border line
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 20,
                    ), // Adjust padding
                  ),
                ),
              ),

              // 2. Category Buttons (from your previous code, adapted)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SingleChildScrollView(
                  // Make category buttons scrollable horizontally
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    // Use Row here, not Wrap
                    spacing: 8.0, // horizontal space between buttons
                    // runSpacing: 4.0, // runSpacing is for Wrap
                    children: <Widget>[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF2FB264,
                          ), // Green from image
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              20,
                            ), // Rounded corners
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 0, // No shadow
                        ),
                        onPressed: () {
                          setMessage('All deals tapped');
                        },
                        icon: const Icon(Icons.local_offer, size: 18),
                        label: const Text(
                          'All Deals',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.grey[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: Colors.grey[300]!,
                            ), // Light grey border
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setMessage('Food & Dining tapped');
                        },
                        icon: const Icon(Icons.restaurant, size: 18),
                        label: const Text(
                          'Food & Dining',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.grey[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setMessage('Electronics tapped');
                        },
                        icon: const Icon(
                          Icons.devices_other,
                          size: 18,
                        ), // Example icon
                        label: const Text(
                          'Electronics',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      // Add more buttons as needed
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16), // Space before deal cards start
              // Deal Cards (now using a Column of custom DealCard widgets)
              DealCard(
                bankInitial: 'BPI',
                bankColor: Colors.red[800]!, // Example color
                dealTitle: "McDonald's Flash Deal",
                categoryIcon: Icons.restaurant,
                categoryText: 'Food & Dining',
                description:
                    "Get 25% discount on all McDonald's orders using BPI Credit Cards. Valid for dine-in and delivery.",
                validUntil: 'Dec 31, 2024',
                tagText: '25% OFF',
                tagColor: const Color(0xFFBFE0C5), // Light green
                tagTextColor: const Color(0xFF2FB264), // Darker green
                isNew: true,
              ),
              DealCard(
                bankInitial: 'BDO',
                bankColor: Colors.blue[800]!, // Example color
                dealTitle: "Lazada Mega Sale",
                categoryIcon: Icons.devices_other, // Electronics icon
                categoryText: 'Electronics',
                description:
                    "Up to 50% off on electronics and gadgets with BDO Debit Cards. Free shipping on orders over ₱1,500.",
                validUntil: 'Jan 15, 2025',
                tagText: 'UP TO 50%',
                tagColor: const Color(0xFFFEE8EB), // Light red
                tagTextColor: const Color(0xFFE56060), // Darker red
                isNew: false,
              ),
              DealCard(
                bankInitial: 'UB',
                bankColor: Colors.orange[800]!, // Example color
                dealTitle: "Grab Cashback Promo",
                categoryIcon: Icons.local_taxi, // Transportation icon
                categoryText: 'Transportation',
                description:
                    "Get 15% cashback on Grab rides with UnionBank Cards. Maximum cashback of P200 per user.",
                validUntil: 'Nov 30, 2024',
                tagText: '15% BACK',
                tagColor: const Color(0xFFCCE4FF), // Light blue
                tagTextColor: const Color(0xFF4285F4), // Darker blue
                isNew: false,
              ),

              // Add more DealCard widgets as needed
              const SizedBox(height: 80), // Space for FAB and bottom nav bar
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _sendAnalyticsEvent,
        tooltip: 'log analytics event',
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary, // Using theme color
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.local_offer),
            label: 'Deals',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF7E57C2), // Selected icon color
        unselectedItemColor: Colors.grey, // Unselected icon color
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Essential for more than 3 items
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// NEW CUSTOM WIDGET: DealCard
// -----------------------------------------------------------------------------
class DealCard extends StatelessWidget {
  final String bankInitial;
  final Color bankColor;
  final String dealTitle;
  final IconData categoryIcon;
  final String categoryText;
  final String description;
  final String validUntil;
  final String tagText;
  final Color tagColor;
  final Color tagTextColor;
  final bool isNew;

  const DealCard({
    super.key,
    required this.bankInitial,
    required this.bankColor,
    required this.dealTitle,
    required this.categoryIcon,
    required this.categoryText,
    required this.description,
    required this.validUntil,
    required this.tagText,
    required this.tagColor,
    required this.tagTextColor,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bank Initial Circle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: bankColor,
                        borderRadius: BorderRadius.circular(
                          8.0,
                        ), // Slightly rounded square
                        // Use circle if you prefer
                        // shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        bankInitial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dealTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                categoryIcon,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                categoryText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                  maxLines: 3, // Limit description to 3 lines
                  overflow:
                      TextOverflow.ellipsis, // Add ellipsis if it overflows
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Valid until: $validUntil',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Action for "View Details"
                        // For example: Navigator.push(context, MaterialPageRoute(builder: (context) => DealDetailsPage()));
                        Fluttertoast.showToast(
                          msg: "Viewing details for $dealTitle",
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF4CAF50,
                        ), // Green button color
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 0, // No shadow
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: const Text('View Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tag overlay (e.g., "25% OFF" or "NEW")
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12.0),
                  bottomLeft: Radius.circular(12.0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize
                    .min, // To make the row only as wide as its children
                children: [
                  if (isNew) // Conditionally show "NEW" tag
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          color: const Color(0xFF2FB264), // Green color for NEW
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    tagText,
                    style: TextStyle(
                      color: tagTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

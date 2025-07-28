// main.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';

import 'firebase_options.dart';
import 'screens/nearby_deals_screen.dart'; // Import the new NearbyDealsScreen
import 'screens/new_deals_screen.dart'; // Import the new NewDealsScreen
import 'screens/expiring_deals_screen.dart'; // Import the new ExpiringDealsScreen

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  runApp(MyApp(analytics: analytics, observer: observer));
}

class MyApp extends StatelessWidget {
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const MyApp({super.key, required this.analytics, required this.observer});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dibs',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B69E4)),
        useMaterial3: true,
      ),
      navigatorObservers: [observer],
      home: MyHomePage(title: 'Dibs', analytics: analytics, observer: observer),
    );
  }
}

// Helper function to convert hex string to Color object
Color colorFromHex(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll("#", "");
  if (hexColor.length == 6) {
    hexColor = "FF$hexColor";
  }
  return Color(int.parse(hexColor, radix: 16));
}

// Helper function to map merchant_id (or a specific icon field) to IconData
IconData getMerchantIcon(String merchantId) {
  switch (merchantId.toLowerCase()) {
    case 'jollibee':
      return Icons.fastfood;
    case 'mcdonalds':
      return Icons.local_dining;
    case 'grab':
      return Icons.local_taxi;
    case 'shopee':
      return Icons.shopping_bag;
    case 'lazada':
      return Icons.devices_other;
    case 'starbucks':
      return Icons.local_cafe;
    case 'bdo':
      return Icons.account_balance;
    default:
      return Icons.store;
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

class Deal {
  final String id;
  final String title;
  final String description;
  final String bank;
  final List<String> eligibleCards;
  final String categories;
  final String discountDetails;
  final DateTime validUntil;
  final String merchantId;
  final String merchantName;
  final String? merchantBranchName;
  final String? merchantAddress;
  final GeoPoint? merchantGeopoint;
  final String? geohash;

  final IconData merchantIcon;
  final String rightTagText;
  final Color rightTagColor;

  final double? price;
  final String? distance;
  final String? availability;

  Deal({
    required this.id,
    required this.title,
    required this.description,
    required this.bank,
    required this.eligibleCards,
    required this.categories,
    required this.discountDetails,
    required this.validUntil,
    required this.merchantId,
    required this.merchantName,
    this.merchantBranchName,
    this.merchantAddress,
    this.merchantGeopoint,
    this.geohash,
    required this.merchantIcon,
    required this.rightTagText,
    required this.rightTagColor,
    this.price,
    this.distance,
    this.availability,
  });

  factory Deal.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    DateTime parsedValidUntil;
    if (data['valid_until'] is Timestamp) {
      parsedValidUntil = (data['valid_until'] as Timestamp).toDate();
    } else if (data['valid_until'] is String) {
      parsedValidUntil = DateTime.parse(data['valid_until']);
    } else {
      parsedValidUntil = DateTime.now().add(const Duration(days: 30));
    }

    IconData icon = getMerchantIcon(data['merchant_id'] ?? '');
    Color tagColor = colorFromHex(data['tag_color_hex'] ?? '#BFE0C5');

    GeoPoint? parsedGeopoint;
    if (data['merchant_geopoint'] is GeoPoint) {
      parsedGeopoint = data['merchant_geopoint'] as GeoPoint;
    } else if (data['merchant_geopoint'] is Map) {
      final geoMap = data['merchant_geopoint'] as Map<String, dynamic>;

      double? latitude;
      if (geoMap['latitude'] is num) {
        latitude = (geoMap['latitude'] as num).toDouble();
      } else if (geoMap['latitude'] is String) {
        latitude = double.tryParse(geoMap['latitude']);
      }

      double? longitude;
      if (geoMap['longitude'] is num) {
        longitude = (geoMap['longitude'] as num).toDouble();
      } else if (geoMap['longitude'] is String) {
        longitude = double.tryParse(geoMap['longitude']);
      }

      if (latitude != null && longitude != null) {
        parsedGeopoint = GeoPoint(latitude, longitude);
      }
    }

    double? parsedPrice;
    if (data['price'] is num) {
      parsedPrice = (data['price'] as num).toDouble();
    } else if (data['price'] is String) {
      String priceString = data['price'].toString().replaceAll('₱', '').trim();
      parsedPrice = double.tryParse(priceString);
    }

    return Deal(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      description: data['description'] ?? 'No description available.',
      bank: data['bank'] ?? 'N/A',
      eligibleCards: List<String>.from(data['eligible_cards'] ?? []),
      categories: data['categories'] ?? 'General',
      discountDetails: data['discount_details'] ?? 'No Discount',
      validUntil: parsedValidUntil,
      merchantId: data['merchant_id'] ?? 'unknown',
      merchantName: data['merchant_name'] ?? 'Unknown Merchant',
      merchantBranchName: data['merchant_branch_name'],
      merchantAddress: data['merchant_address'],
      merchantGeopoint: parsedGeopoint,
      geohash: data['geohash'],
      merchantIcon: icon,
      rightTagText: data['discount_details'] ?? '',
      rightTagColor: tagColor,
      price: parsedPrice,
      distance: data['distance'],
      availability: data['availability'],
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  String _selectedCategory = 'All Categories';
  LocationData? _currentLocation;
  String _locationStatus = 'Checking location...';

  final Location _location = Location();

  @override
  void initState() {
    super.initState();
    _checkLocationAndGet();
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

  void _selectCategoryFilter(String category) {
    setState(() {
      _selectedCategory = category;
    });
    setMessage('$category deals selected');
  }

  Future<void> _checkLocationAndGet() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;
    LocationData locationData;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationStatus = 'Location services disabled.';
        });
        setMessage('Location services are disabled.');
        return;
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        if (!mounted) return;
        setState(() {
          _locationStatus = 'Location permission denied.';
        });
        setMessage('Location permission denied.');
        return;
      }
    }

    try {
      locationData = await _location.getLocation();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = locationData;
        _locationStatus = 'Location retrieved!';
      });
      setMessage(
        'Location fetched: Lat ${_currentLocation!.latitude}, Lon ${_currentLocation!.longitude}',
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              NearbyDealsScreen(userLocation: _currentLocation!),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationStatus = 'Error getting location: ${e.toString()}';
      });
      setMessage('Error getting location: ${e.toString()}');
    }
  }

  final CollectionReference _dealsCollection = FirebaseFirestore.instance
      .collection('deals');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F9),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: Container(
          color: const Color(0xFFF1F4F9),
          padding: const EdgeInsets.only(
            top: 30.0,
            left: 16.0,
            right: 16.0,
            bottom: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7FA),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.local_offer,
                        color: Color(0xFF5B69E4),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Dibs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF323B60),
                        ),
                      ),
                      Text(
                        'Your exclusive claim to best deals',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7FA),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: const Center(
                      child: Text(
                        'JD',
                        style: TextStyle(
                          color: Color(0xFF5B69E4),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Good morning, John! 👋',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF323B60),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Deals for YOU',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF323B60),
                        ),
                      ),
                      Text(
                        'Personalized recommendations',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (_currentLocation != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NearbyDealsScreen(
                                        userLocation: _currentLocation!,
                                      ),
                                    ),
                                  );
                                } else {
                                  _checkLocationAndGet();
                                  setMessage(
                                    'Getting location for nearby deals...',
                                  );
                                }
                              },
                              child: _buildRecommendationCardContent(
                                color: const Color(0xFF5B69E4),
                                icon: Icons.location_on,
                                dealsCount: 8,
                                title: 'Nearby',
                                subtitle: _currentLocation != null
                                    ? 'Lat: ${_currentLocation!.latitude!.toStringAsFixed(2)}, Lon: ${_currentLocation!.longitude!.toStringAsFixed(2)}'
                                    : _locationStatus,
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NewDealsScreen(),
                                  ),
                                );
                                setMessage('New Deals tapped');
                              },
                              child: _buildRecommendationCardContent(
                                color: const Color(0xFF4CAF50),
                                icon: Icons.bolt,
                                dealsCount: 12,
                                title: 'New Deals',
                                subtitle: 'Fresh offers\nLast 7 days',
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ExpiringDealsScreen(),
                                  ),
                                );
                                setMessage('Expiring tapped');
                              },
                              child: _buildRecommendationCardContent(
                                color: const Color(0xFFE56060),
                                icon: Icons.access_time,
                                dealsCount: 5,
                                title: 'Expiring',
                                subtitle: 'Ending today\nDon\'t miss!',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'All Deals',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF323B60),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _buildCategoryFilterButton(
                      'All Categories',
                      _selectedCategory == 'All Categories',
                      Colors.blue,
                      () => _selectCategoryFilter('All Categories'),
                    ),
                    _buildCategoryFilterButton(
                      'Food & Dining',
                      _selectedCategory == 'Food & Dining',
                      Colors.orange,
                      () => _selectCategoryFilter('Food & Dining'),
                    ),
                    _buildCategoryFilterButton(
                      'Travel',
                      _selectedCategory == 'Travel',
                      Colors.deepOrange,
                      () => _selectCategoryFilter('Travel'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _selectedCategory == 'All Categories'
                  ? _dealsCollection.snapshots()
                  : _dealsCollection
                        .where('categories', isEqualTo: _selectedCategory)
                        .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No deals found for this category.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                List<Deal> deals = snapshot.data!.docs.map((doc) {
                  return Deal.fromFirestore(doc);
                }).toList();

                return Column(
                  children: deals.map((deal) {
                    return NewDealCard(
                      merchantIcon: deal.merchantIcon,
                      merchantName: deal.merchantName,
                      categoryText: deal.categories,
                      description: deal.description,
                      validUntil: DateFormat('MMM dd').format(deal.validUntil),
                      rightTagText: deal.discountDetails,
                      rightTagColor: deal.rightTagColor,
                      price: deal.price,
                      distance: deal.distance,
                      availability: deal.availability,
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendAnalyticsEvent,
        tooltip: 'Add new deal',
        backgroundColor: const Color(0xFF5B69E4),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildRecommendationCardContent({
    required Color color,
    required IconData icon,
    required int dealsCount,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              Text(
                '$dealsCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterButton(
    String category,
    bool isSelected,
    Color accentColor,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.only(right: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(20.0),
          border: isSelected
              ? Border.all(
                  color: accentColor.withAlpha((255 * 0.8).round()),
                  width: 1.0,
                )
              : Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            if (category == 'All Categories')
              const Icon(Icons.filter_list, size: 18, color: Colors.white),
            if (category == 'All Categories') const SizedBox(width: 4),
            Text(
              category,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewDealCard extends StatelessWidget {
  final IconData merchantIcon;
  final String merchantName;
  final String categoryText;
  final String description;
  final String validUntil;
  final String rightTagText;
  final Color rightTagColor;
  final double? price;
  final String? distance;
  final String? availability;

  const NewDealCard({
    super.key,
    required this.merchantIcon,
    required this.merchantName,
    required this.categoryText,
    required this.description,
    required this.validUntil,
    required this.rightTagText,
    required this.rightTagColor,
    this.price,
    this.distance,
    this.availability,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Center(
                    child: Icon(
                      merchantIcon,
                      size: 32,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            merchantName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF323B60),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: rightTagColor,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              rightTagText,
                              style: const TextStyle(
                                color: Color(0xFF2FB264),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (distance != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  distance!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              categoryText,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      price != null
                          ? '₱${price!.toStringAsFixed(2)}'
                          : (availability != null
                                ? availability!
                                : rightTagText),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF323B60),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Valid until: $validUntil',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    Fluttertoast.showToast(
                      msg: "Viewing details for $merchantName deal",
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B69E4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('View Deal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

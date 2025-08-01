// main.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart'; // Import geoflutterfire_plus
import 'package:geolocator/geolocator.dart';

import 'firebase_options.dart';
import 'screens/nearby_deals_screen.dart';
import 'screens/new_deals_screen.dart';
import 'screens/expiring_deals_screen.dart';
import 'package:rxdart/rxdart.dart';
import 'package:geocoding/geocoding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  runApp(MyApp(analytics: analytics, observer: observer));
}

//test
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
    case 'fastfood':
      return Icons.fastfood;
    case 'dining':
      return Icons.local_dining;
    case 'shop':
      return Icons.shopping_bag;
    case 'travel':
      return Icons.airplanemode_active;
    case 'banking':
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
    Color tagColor = colorFromHex(data['tag_color_hex'] ?? '#1c1c1c');

    GeoPoint? parsedGeopoint;
    final dynamic rawGeopoint = data['merchant_geopoint'];

    if (rawGeopoint is GeoPoint) {
      parsedGeopoint = rawGeopoint;
    } else if (rawGeopoint is Map<String, dynamic>) {
      final double? latitude = (rawGeopoint['latitude'] is num)
          ? (rawGeopoint['latitude'] as num).toDouble()
          : null;
      final double? longitude = (rawGeopoint['longitude'] is num)
          ? (rawGeopoint['longitude'] as num).toDouble()
          : null;
      if (latitude != null && longitude != null) {
        parsedGeopoint = GeoPoint(latitude, longitude);
      }
    } else if (rawGeopoint is String) {
      // Attempt to parse the string format "[lat° N, lon° E]"
      final RegExp regex = RegExp(r'\[(-?\d+\.?\d*)° N, (-?\d+\.?\d*)° E\]');
      final Match? match = regex.firstMatch(rawGeopoint);
      if (match != null && match.groupCount == 2) {
        final double? latitude = double.tryParse(match.group(1)!);
        final double? longitude = double.tryParse(match.group(2)!);
        if (latitude != null && longitude != null) {
          parsedGeopoint = GeoPoint(latitude, longitude);
        } else {
          debugPrint(
            'Failed to parse latitude/longitude from string: $rawGeopoint',
          );
        }
      } else {
        debugPrint('String geopoint format not recognized: $rawGeopoint');
      }
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
      rightTagText: data['bank'] ?? '',
      rightTagColor: tagColor,
      distance: data['distance'],
      availability: data['availability'],
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  String _selectedCategory = 'All Categories';
  loc.LocationData? _currentLocation;
  String _locationStatus = 'Checking location...';
  String _locationAddress = 'Fetching address...';

  final loc.Location _location = loc.Location();

  // Explicitly type _dealsCollection for GeoCollectionReference
  final CollectionReference<Map<String, dynamic>> _dealsCollection =
      FirebaseFirestore.instance
          .collection('deals')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, options) => snapshot.data()!,
            toFirestore: (value, options) => value,
          );

  // Initialize GeoCollectionReference
  late final GeoCollectionReference<Map<String, dynamic>> _geoDealsCollection;

  // Stream for nearby deals count
  Stream<int> _nearbyDealsCountStream = Stream.value(0);

  // Stream for this month deals count
  Stream<int> _thisMonthDealsCountStream = Stream.value(0);

  // Stream for this expiring deals count
  Stream<int> _thisWeekExpiringDealsCountStream = Stream.value(0);

  @override
  void initState() {
    super.initState();
    // Initialize _geoDealsCollection with the correctly typed _dealsCollection
    _geoDealsCollection = GeoCollectionReference(_dealsCollection);
    _checkLocationAndGet();
    _thisMonthDealsCountStream = _getThisMonthDealsCountStream();
    _thisWeekExpiringDealsCountStream = _getThisWeekExpiringDealsCountStream();
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
    loc.PermissionStatus permissionGranted;
    loc.LocationData locationData;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationStatus = 'Location services disabled.';
          _locationAddress =
              'Location services disabled.'; // Update address status as well
        });
        setMessage('Location services are disabled.');
        return;
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        if (!mounted) return;
        setState(() {
          _locationStatus = 'Location permission denied.';
          _locationAddress =
              'Location permission denied.'; // Update address status as well
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
        debugPrint('user location:$_currentLocation');
        // Update the nearby deals stream when location is available
        _nearbyDealsCountStream = _getNearbyDealsCountStream(_currentLocation!);
      });

      // Perform reverse geocoding
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          _currentLocation!.latitude!,
          _currentLocation!.longitude!,
        );

        if (placemarks.isNotEmpty) {
          final Placemark first = placemarks.first;
          setState(() {
            _locationAddress = '${first.locality}, ${first.administrativeArea}';
          });
          setMessage(
            'Location fetched: $_locationAddress',
          ); // Show address in toast
        } else {
          setState(() {
            _locationAddress = 'Address not found';
          });
          setMessage(
            'Location fetched, but address not found.',
          ); // Indicate address not found
        }
      } catch (e) {
        setState(() {
          _locationAddress = 'Error fetching address: ${e.toString()}';
        });
        setMessage(
          'Location fetched, but error fetching address: ${e.toString()}',
        ); // Show error in toast
        debugPrint('Error fetching address: $e');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationStatus = 'Error getting location: ${e.toString()}';
        _locationAddress =
            'Error getting location: ${e.toString()}'; // Update address status with error
      });
      setMessage(
        'Error getting location: ${e.toString()}',
      ); // Show error in toast
    }
  }

  Stream<int> _getNearbyDealsCountStream(loc.LocationData userLocation) {
    if (userLocation.latitude == null || userLocation.longitude == null) {
      debugPrint(
        '_getNearbyDealsCountStream: User location is null or invalid, returning 0 nearby deals.',
      );
      return Stream.value(0);
    }

    final GeoFirePoint center = GeoFirePoint(
      GeoPoint(userLocation.latitude!, userLocation.longitude!),
    );

    debugPrint(
      '_getNearbyDealsCountStream: User Location GeoPoint: Lat: ${userLocation.latitude}, Lon: ${userLocation.longitude}',
    ); // Print user location

    debugPrint(
      '_getNearbyDealsCountStream: GeoFirePoint Center: Lat: ${center.geopoint.latitude}, Lon: ${center.geopoint.longitude}',
    ); // Print the center point used for the query

    const double radiusValue = 50; // Keep this at 50 for now
    const String geoPointFieldName = 'merchant_geopoint';

    debugPrint(
      '_getNearbyDealsCountStream: Querying with radius $radiusValue km and field "$geoPointFieldName"',
    ); // Print query parameters
    return _geoDealsCollection
        .subscribeWithin(
          center: center,
          radiusInKm: radiusValue,
          field: geoPointFieldName,
          strictMode: false,
          geopointFrom: (data) {
            final dynamic rawGeopoint = data[geoPointFieldName];
            final String docId = data['id'] ?? 'unknown';
            debugPrint(
              'geopointFrom: Received raw data for doc ID $docId: $rawGeopoint',
            );
            GeoPoint? extractedGeopoint;
            if (rawGeopoint is GeoPoint) {
              extractedGeopoint = rawGeopoint;
            } else if (rawGeopoint is Map<String, dynamic>) {
              final double? latitude = (rawGeopoint['latitude'] is num)
                  ? (rawGeopoint['latitude'] as num).toDouble()
                  : null;
              final double? longitude = (rawGeopoint['longitude'] is num)
                  ? (rawGeopoint['longitude'] as num).toDouble()
                  : null;
              if (latitude != null && longitude != null) {
                extractedGeopoint = GeoPoint(latitude, longitude);
              } else {
                debugPrint(
                  'geopointFrom: Failed to parse lat/lon from map for doc ID: $docId. Invalid numbers or keys.',
                );
              }
            } else if (rawGeopoint is String) {
              // Parse the string format "[lat° N, lon° E]"
              final RegExp regex = RegExp(
                r'\[(-?\d+\.?\d*)° N, (-?\d+\.?\d*)° E\]',
              );
              final Match? match = regex.firstMatch(rawGeopoint);
              if (match != null && match.groupCount == 2) {
                final double? latitude = double.tryParse(match.group(1)!);
                final double? longitude = double.tryParse(match.group(2)!);
                if (latitude != null && longitude != null) {
                  extractedGeopoint = GeoPoint(latitude, longitude);
                } else {
                  debugPrint(
                    'geopointFrom: Failed to parse lat/lon from string: "$rawGeopoint" for doc ID: $docId. Invalid numbers.',
                  );
                }
              } else {
                debugPrint(
                  'geopointFrom: String format not recognized: "$rawGeopoint" for doc ID: $docId. Regex failed.',
                );
              }
            }
            // Check if the extracted GeoPoint is (0,0) and return null if it is.
            if (extractedGeopoint != null &&
                extractedGeopoint.latitude == 0 &&
                extractedGeopoint.longitude == 0) {
              debugPrint(
                'geopointFrom: Found GeoPoint(0, 0) for doc ID: $docId. Treating as invalid.',
              );
              return GeoPoint(0, 0); // Treat (0,0) as invalid
            }
            // Return the extracted geopoint or null if none was valid
            if (extractedGeopoint != null) {
              debugPrint(
                'geopointFrom: Successfully extracted GeoPoint: ${extractedGeopoint.latitude}, ${extractedGeopoint.longitude} for doc ID: $docId',
              );
              return extractedGeopoint;
            } else {
              debugPrint(
                'geopointFrom: No valid GeoPoint extracted from: "$rawGeopoint" for doc ID: $docId. Returning null.',
              );
              return GeoPoint(0, 0);
            }
          },
        )
        .map((snapshotList) {
          debugPrint(
            'Fetched ${snapshotList.length} raw documents within bounding box (before client-side distance filter).',
          );
          int actualCount = 0;
          for (var doc in snapshotList) {
            final GeoPoint? dealGeoPoint = _extractGeoPointFromDoc(
              doc.data(),
              geoPointFieldName,
            );
            if (dealGeoPoint != null &&
                (dealGeoPoint.latitude != 0 || dealGeoPoint.longitude != 0)) {
              // Only process if not the dummy (0,0) point
              final double distance = Geolocator.distanceBetween(
                dealGeoPoint.latitude,
                dealGeoPoint.longitude,
                center.geopoint.latitude,
                center.geopoint.longitude,
              );
              debugPrint(
                'Deal ID: ${doc.id}, Distance: ${distance.toStringAsFixed(2)} m, Title: ${doc.data()?['title']}',
              ); // Distance is in meters
              if (distance <= radiusValue) {
                actualCount++;
              }
            } else {
              debugPrint(
                'Could not extract valid GeoPoint for document ID: ${doc.id} or it was (0,0). Skipping.',
              );
            }
          }
          debugPrint(
            'Final count of nearby deals after client-side filter: $actualCount',
          );
          return actualCount;
        })
        .onErrorReturn(0);
  }

  // Helper function to extract GeoPoint for debugging purposes (used in the .map block)
  GeoPoint? _extractGeoPointFromDoc(
    Map<String, dynamic>? data,
    String fieldName,
  ) {
    if (data == null || !data.containsKey(fieldName)) {
      debugPrint(
        '_extractGeoPointFromDoc: Data is null or does not contain field "$fieldName".',
      );
      return null;
    }
    final dynamic rawGeopoint = data[fieldName];
    final String docId =
        data['id'] ?? 'unknown'; // Get document ID for better logging
    debugPrint(
      '_extractGeoPointFromDoc: Processing rawGeopoint: "$rawGeopoint" for doc ID: $docId',
    );

    if (rawGeopoint is GeoPoint) {
      if (rawGeopoint.latitude == 0 && rawGeopoint.longitude == 0) {
        debugPrint(
          '_extractGeoPointFromDoc: Found GeoPoint(0, 0) for doc ID: $docId. Treating as invalid.',
        );
        return null; // Treat (0,0) as invalid
      }
      debugPrint(
        '_extractGeoPointFromDoc: Found native GeoPoint: ${rawGeopoint.latitude}, ${rawGeopoint.longitude} for doc ID: $docId',
      );
      return rawGeopoint;
    } else if (rawGeopoint is Map<String, dynamic>) {
      final double? latitude = (rawGeopoint['latitude'] is num)
          ? (rawGeopoint['latitude'] as num).toDouble()
          : null;
      final double? longitude = (rawGeopoint['longitude'] is num)
          ? (rawGeopoint['longitude'] as num).toDouble()
          : null;
      if (latitude != null && longitude != null) {
        if (latitude == 0 && longitude == 0) {
          debugPrint(
            '_extractGeoPointFromDoc: Found map GeoPoint(0, 0) for doc ID: $docId. Treating as invalid.',
          );
          return null; // Treat (0,0) as invalid
        }
        debugPrint(
          '_extractGeoPointFromDoc: Found map GeoPoint: $latitude, $longitude for doc ID: $docId',
        );
        return GeoPoint(latitude, longitude);
      } else {
        debugPrint(
          '_extractGeoPointFromDoc: Failed to parse lat/lon from map for doc ID: $docId. Invalid numbers.',
        );
      }
    } else if (rawGeopoint is String) {
      // Parse the string format "[lat° N, lon° E]"
      final RegExp regex = RegExp(r'\[(-?\d+\.?\d*)° N, (-?\d+\.?\d*)° E\]');
      final Match? match = regex.firstMatch(rawGeopoint);
      if (match != null && match.groupCount == 2) {
        final double? latitude = double.tryParse(match.group(1)!);
        final double? longitude = double.tryParse(match.group(2)!);
        if (latitude != null && longitude != null) {
          if (latitude == 0 && longitude == 0) {
            debugPrint(
              '_extractGeoPointFromDoc: Parsed string GeoPoint(0, 0) for doc ID: $docId. Treating as invalid.',
            );
            return null; // Treat (0,0) as invalid
          }
          debugPrint(
            '_extractGeoPointFromDoc: Parsed string GeoPoint: $latitude, $longitude for doc ID: $docId',
          );
          return GeoPoint(latitude, longitude);
        } else {
          debugPrint(
            '_extractGeoPointFromDoc: Failed to parse lat/lon from string: "$rawGeopoint" for doc ID: $docId. Invalid numbers.',
          );
        }
      } else {
        debugPrint(
          '_extractGeoPointFromDoc: String format not recognized: "$rawGeopoint" for doc ID: $docId. Regex failed.',
        );
      }
    }
    debugPrint(
      '_extractGeoPointFromDoc: No valid GeoPoint extracted from: "$rawGeopoint" for doc ID: $docId. Returning null.',
    );
    return null; // Return null for any other invalid or missing cases
  }

  // Method to get active deals count for the current month
  Stream<int> _getThisMonthDealsCountStream() {
    final now = DateTime.now();
    // Start of the current month (e.g., July 1, 2025, 00:00:00)
    final startOfMonth = DateTime(now.year, now.month, 1);
    // End of the current month (last millisecond of the last day)
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    return _dealsCollection
        .where(
          'valid_until',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
        .where(
          'valid_until',
          isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .onErrorReturn(0);
  }

  Stream<int> _getThisWeekExpiringDealsCountStream() {
    final now = DateTime.now();

    // Calculate the start of the current week (Monday at 00:00:00)
    // Dart's weekday: Monday is 1, Sunday is 7.
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    // Calculate the end of the current week (Sunday at 23:59:59.999)
    final endOfWeek =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day).add(
          const Duration(
            days: 6,
            hours: 23,
            minutes: 59,
            seconds: 59,
            milliseconds: 999,
          ),
        );

    return _dealsCollection
        .where(
          'valid_until',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek),
        )
        .where(
          'valid_until',
          isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .onErrorReturn(0); // Returns 0 if there's an error
  }

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
                    child: Center(
                      // Changed from const Center to Center
                      child: Image.asset('assets/dibs.png'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Your exclusive claim to best deals',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              Builder(
                builder: (BuildContext builderContext) {
                  // Use a different name for the context
                  return InkWell(
                    onTap: () {
                      // Use the builderContext here
                      Scaffold.of(builderContext).openEndDrawer();
                    },
                    child: Stack(
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
                              '3', // Your notification count
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      endDrawer: Drawer(
        // This defines the content that slides in from the right
        child: ListView(
          padding: EdgeInsets.zero, // Important to remove default padding
          children: <Widget>[
            // You can customize the header of your drawer
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF5B69E4), // Match your app's primary color
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      'JD',
                      style: TextStyle(
                        color: Color(0xFF5B69E4),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'John Doe', // Placeholder: Replace with actual user name
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'john.doe@example.com', // Placeholder: Replace with actual user email
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            // Example ListTiles for navigation
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
              },
            ),
            const Divider(), // A visual separator
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
              },
            ),
          ],
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
                              child: StreamBuilder<int>(
                                stream: _nearbyDealsCountStream,
                                builder: (context, snapshot) {
                                  int nearbyCount = snapshot.data ?? 0;
                                  return _buildRecommendationCardContent(
                                    color: const Color(0xFF5B69E4),
                                    icon: Icons.location_on,
                                    dealsCount: nearbyCount,
                                    title: 'Nearby',
                                    subtitle: _currentLocation != null
                                        ? _locationAddress
                                        : _locationStatus,
                                  );
                                },
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

                                setMessage('This Month Deals tapped');
                              },
                              child: StreamBuilder<int>(
                                stream: _thisMonthDealsCountStream,
                                builder: (context, snapshot) {
                                  int thisMonthCount = snapshot.data ?? 0;
                                  return _buildRecommendationCardContent(
                                    color: Colors
                                        .purple, // You can choose your preferred color
                                    icon: Icons
                                        .calendar_month, // You can choose your preferred icon
                                    dealsCount: thisMonthCount,
                                    title:
                                        '${DateFormat('MMMM').format(DateTime.now())} Deals',
                                    subtitle: 'Exclusive deals this month',
                                  );
                                },
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
                                // Example of using Fluttertoast instead of a hypothetical 'setMessage'
                                Fluttertoast.showToast(msg: 'Expiring tapped');
                              },
                              child: StreamBuilder<int>(
                                // Directly call the function here. You do NOT need to declare a field for it.
                                stream: _thisWeekExpiringDealsCountStream,
                                builder: (context, snapshot) {
                                  int dealsCount = 0; // Default count

                                  if (snapshot.connectionState ==
                                      ConnectionState.active) {
                                    if (snapshot.hasData) {
                                      dealsCount = snapshot.data!;
                                    } else if (snapshot.hasError) {
                                      debugPrint(
                                        'Error fetching expiring deals count: ${snapshot.error}',
                                      );
                                      dealsCount =
                                          0; // Display 0 or handle error as needed
                                    }
                                  } else if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    dealsCount =
                                        0; // Or show a loading indicator like '...'
                                  }

                                  return _buildRecommendationCardContent(
                                    color: const Color(0xFFE56060),
                                    icon: Icons.access_time,
                                    dealsCount:
                                        dealsCount, // This is the dynamically updated count
                                    title: 'Expiring',
                                    subtitle: 'Ending this \nweek!',
                                  );
                                },
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
                    _buildCategoryFilterButton(
                      'Shopping',
                      _selectedCategory == 'Shopping',
                      const Color.fromARGB(255, 233, 198, 57),
                      () => _selectCategoryFilter('Shopping'),
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
                      validUntil: DateFormat(
                        'MMM dd, yyyy',
                      ).format(deal.validUntil),
                      rightTagText: deal.bank,
                      rightTagColor: deal.rightTagColor,
                      discountDetails: deal.discountDetails,
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
  final String discountDetails;
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
    required this.discountDetails,
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
                                color: Color.fromARGB(255, 255, 255, 255),
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
                          Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: 5.0,
                              vertical: 0,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 164, 231, 156),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              discountDetails,
                              style: TextStyle(
                                fontSize: 10,
                                color: const Color.fromARGB(255, 34, 98, 53),
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

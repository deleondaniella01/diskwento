// main.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:myapp/screens/login.dart';
import 'package:myapp/screens/profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/nearby_deals_screen.dart';
import 'screens/new_deals_screen.dart';
import 'screens/expiring_deals_screen.dart';
import 'package:rxdart/rxdart.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_ai/firebase_ai.dart' as fb_ai;
import 'dart:convert';

import 'widgets/deal_details_modal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      name: 'Dibs App',
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final analytics = FirebaseAnalytics.instance;
  final observer = FirebaseAnalyticsObserver(analytics: analytics);

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
      home: AuthPage(title: 'Dibs', analytics: analytics, observer: observer),
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
  MyHomePage({
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
  final List<String> categories;
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
  final String? termsAndConditions;

  Deal({
    required this.id,
    required this.title,
    required this.description,
    required this.bank,
    required this.eligibleCards,
    required this.termsAndConditions,
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
      try {
        parsedValidUntil = DateTime.parse(data['valid_until']);
      } catch (_) {
        try {
          parsedValidUntil = DateFormat(
            'MMMM d, yyyy',
          ).parse(data['valid_until']);
        } catch (_) {
          parsedValidUntil = DateTime.now().add(const Duration(days: 30));
        }
      }
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
      categories: data['categories'] is List
          ? List<String>.from(data['categories'])
          : [data['categories'] ?? 'General'],
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
      termsAndConditions:
          data['terms_and_conditions'] ?? 'No terms and conditions available.',
      eligibleCards: _parseEligibleCards(data['eligible_cards']),
    );
  }

  static List<String> _parseEligibleCards(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      // Convert all items to String
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is String) {
      // If it's a single string, wrap in a list
      return [raw];
    }
    return [];
  }
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  String _selectedCategory = 'All Categories';
  loc.LocationData? _currentLocation;
  String _locationStatus = 'Checking location...';
  String _locationAddress = 'Fetching address...';

  // Initialize Location instance
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

  // Add a field to store the user email in your _MyHomePageState:
  String? _userEmail;

  // Add fields to store user preferences
  List<String> _selectedBanks = [];
  List<String> _selectedInterests = [];

  bool _isLoadingDeals = false;

  // Function to fetch AI-generated deals based on user input
  Future<List<Map<String, dynamic>>> fetchAIDeals({
    String? bank,
    String? category,
    String? merchant,
  }) async {
    // Build your prompt
    String prompt = 'Find active credit card deals';
    if (bank != null && bank.isNotEmpty) prompt += ' for $bank';
    if (category != null && category.isNotEmpty)
      prompt += ' in the category $category';
    if (merchant != null && merchant.isNotEmpty) prompt += ' at $merchant';

    // Optionally add source link if you want to restrict the AI
    final String sourceLink = getBankSourceLink(bank);
    if (sourceLink.isNotEmpty) {
      prompt += '. Only use deals from this source: $sourceLink';
    }

    prompt +=
        '. Return ONLY a valid JSON array, where each item has these fields: title, description, bank, merchant_name, merchant_branch_name, merchant_address, terms_and_conditions, eligible_cards, discount_details, valid_until, categories. Do not include any explanation or text outside the JSON array.';

    // Call Firebase AI (Vertex AI via Firebase Extensions)
    final ai = fb_ai.FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
    );

    // Call the model and get the response
    final response = await ai.generateContent([fb_ai.Content.text(prompt)]);

    // Debug print the raw AI response
    debugPrint('Raw AI response: ${response.text}');

    // Parse the response
    List<Map<String, dynamic>> deals = [];
    try {
      final text = response.text;
      if (text != null && text.isNotEmpty) {
        // Extract JSON array if AI adds extra text
        final jsonArrayMatch = RegExp(
          r'(\[\s*\{[\s\S]*?\}\s*\])',
        ).firstMatch(text);
        final jsonString = jsonArrayMatch != null
            ? jsonArrayMatch.group(1)
            : text;
        final decoded = jsonDecode(jsonString!);
        if (decoded is List) {
          deals = List<Map<String, dynamic>>.from(decoded);
        } else if (decoded is Map) {
          deals = [Map<String, dynamic>.from(decoded)];
        }
      }
    } catch (e) {
      debugPrint('Failed to parse AI response: $e');
    }
    return deals;
  }

  // List of categories for dropdown
  final List<String> _categories = [
    'Food & Dining',
    'Travel',
    'Shopping',
    'Groceries',
    'Health & Wellness',
    'Entertainment',
    'Utilities',
  ];

  // List of banks for dropdown
  final List<String> _banks = [
    'BDO',
    'BPI',
    'Metrobank',
    'Security Bank',
    'UnionBank',
    'RCBC',
  ];

  // Function to get tag color hex based on bank name
  String getTagColorHex(String bank) {
    switch (bank.toUpperCase()) {
      case 'BDO':
        return '3b71ed';
      case 'BPI':
        return 'f75454';
      case 'METROBANK':
        return '0f03fc';
      case 'SECURITY BANK':
        return '54ba5b';
      case 'UNIONBANK':
      case 'UNION BANK':
        return 'de7f3c';
      case 'RCBC':
        return '03cffc';
      default:
        return '1c1c1c'; // default color
    }
  }

  // source link for each bank
  String getBankSourceLink(String? bank) {
    switch ((bank ?? '').toUpperCase()) {
      case 'BPI':
        return 'https://www.bpi.com.ph/personal/rewards-and-promotions/promos?tab=Credit_cards';
      case 'RCBC':
        return 'https://rcbccredit.com/promos';
      case 'BDO':
        return 'https://www.deals.bdo.com.ph/catalog-page?type=credit-card';
      case 'METROBANK':
        return 'https://www.metrobank.com.ph/promos/credit-card-promos';
      case 'SECURITY BANK':
        return 'https://www.google.com';
      case 'UNIONBANK':
      case 'UNION BANK':
        return ''; // No available link
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer
    _geoDealsCollection = GeoCollectionReference(_dealsCollection);
    _checkLocationAndGet();
    _thisMonthDealsCountStream = _getThisMonthDealsCountStream();
    _thisWeekExpiringDealsCountStream = _getThisWeekExpiringDealsCountStream();

    // Fetch current user email
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _userEmail = user?.email ?? '';
    });

    _loadUserPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh the stream when app comes to foreground
      setState(() {
        _thisWeekExpiringDealsCountStream =
            _getThisWeekExpiringDealsCountStream();
      });
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
      name: 'deals_added',
      parameters: <String, Object>{
        'date_added': DateTime.now().toIso8601String(),
      },
    );
  }

  void _showAddDealPrompt() {
    String? selectedBank;
    String? selectedCategory;
    String? selectedMerchant;
    String customMerchantName = '';
    final List<String> merchants = ['Jollibee', 'SM', 'Starbucks', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Can't find a deal you are looking for?",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text("Let's check for any new deals!"),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedBank,
                    decoration: const InputDecoration(labelText: 'Bank'),
                    items: _banks.map((bank) {
                      final isUnionBank =
                          bank.toUpperCase() == 'UNIONBANK' ||
                          bank.toUpperCase() == 'UNION BANK';
                      return DropdownMenuItem<String>(
                        value: isUnionBank ? null : bank,
                        enabled: !isUnionBank,
                        child: Text(
                          bank,
                          style: TextStyle(
                            color: isUnionBank ? Colors.grey : Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedBank = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setModalState(() => selectedCategory = val),
                  ),
                  // const SizedBox(height: 12),
                  // DropdownButtonFormField<String>(
                  //   value: selectedMerchant,
                  //   decoration: const InputDecoration(labelText: 'Merchant'),
                  //   items: merchants.map((m) => DropdownMenuItem(
                  //     value: m,
                  //     child: Text(m),
                  //   )).toList(),
                  //   onChanged: (val) => setModalState(() => selectedMerchant = val),
                  // ),
                  // if (selectedMerchant == 'Other')
                  //   Padding(
                  //     padding: const EdgeInsets.only(top: 8.0),
                  //     child: TextField(
                  //       decoration: const InputDecoration(labelText: 'Merchant Name'),
                  //       onChanged: (val) => customMerchantName = val,
                  //     ),
                  //   ),
                  // const SizedBox(height: 20),
                  ElevatedButton(
                    child: const Text('Search Deals'),
                    onPressed: _isLoadingDeals
                        ? null
                        : () async {
                            setState(() => _isLoadingDeals = true);
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            final merchantName = selectedMerchant == 'Other'
                                ? customMerchantName
                                : selectedMerchant;

                            // Call your AI function here with selectedBank, selectedCategory, merchantName
                            final aiDeals = await fetchAIDeals(
                              bank: selectedBank,
                              category: selectedCategory,
                              // merchant: merchantName,
                            );

                            Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pop(); // Hide loading dialog
                            setState(() => _isLoadingDeals = false);

                            // Get the source link for the selected bank
                            // final String sourceLink = getBankSourceLink(selectedBank);

                            // String aiPrompt = 'Find active credit card deals';
                            // if (selectedBank?.isNotEmpty == true) {
                            //   aiPrompt += ' for $selectedBank';
                            // }
                            // if (selectedCategory?.isNotEmpty == true) {
                            //   aiPrompt += ' in the category $selectedCategory';
                            // }
                            // if (merchantName?.isNotEmpty == true) {
                            //   aiPrompt += ' at $merchantName';
                            // }
                            // if (sourceLink.isNotEmpty) {
                            //   aiPrompt += '. Only use deals from this source: $sourceLink';
                            // }

                            // Check Firestore for existing deals
                            int newDealsCount = 0;
                            List<Map<String, dynamic>> newDeals = [];
                            for (final aiDeal in aiDeals) {
                              final query = await FirebaseFirestore.instance
                                  .collection('deals')
                                  .where('title', isEqualTo: aiDeal['title'])
                                  .where(
                                    'description',
                                    isEqualTo: aiDeal['description'],
                                  )
                                  .where('bank', isEqualTo: aiDeal['bank'])
                                  .where(
                                    'merchant_name',
                                    isEqualTo: aiDeal['merchant_name'],
                                  )
                                  .get();
                              if (query.docs.isEmpty) {
                                newDealsCount++;
                                newDeals.add(aiDeal);
                              }
                            }

                            Navigator.pop(context); // Close the bottom sheet

                            // 3. If new deals found, show dialog
                            if (newDealsCount > 0) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('New Deals Found!'),
                                  content: Text(
                                    'There ${newDealsCount == 1 ? "is" : "are"} $newDealsCount new deal${newDealsCount == 1 ? "" : "s"} available. Add it to dibs?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        // Add newDeals to Firestore
                                        for (final deal in newDeals) {
                                          final dealWithColor =
                                              Map<String, dynamic>.from(deal);
                                          dealWithColor['tag_color_hex'] =
                                              getTagColorHex(
                                                deal['bank'] ?? '',
                                              );

                                          final merchantAddress =
                                              deal['merchant_address'] ?? '';
                                          final description =
                                              deal['description'] ??
                                              'No description available.';
                                          final merchantName =
                                              deal['merchant_name'] ??
                                              'Unknown Merchant';
                                          final title =
                                              deal['title'] ?? 'No Title';
                                          final bank = deal['bank'] ?? 'N/A';
                                          final merchantBranchName =
                                              deal['merchant_branch_name'] ??
                                              '';
                                          final termsAndConditions =
                                              deal['terms_and_conditions'] ??
                                              'No terms and conditions available.';
                                          final eligibleCards =
                                              (deal['eligible_cards'] is List)
                                              ? List<String>.from(
                                                  deal['eligible_cards'],
                                                )
                                              : <String>['All Cards'];
                                          final discountDetails =
                                              deal['discount_details'] ??
                                              'No Discount';
                                          final validUntil =
                                              deal['valid_until'] ??
                                              DateTime.now()
                                                  .add(const Duration(days: 30))
                                                  .toIso8601String();
                                          final categories =
                                              deal['categories'] ?? 'General';

                                          dealWithColor['title'] = title;
                                          dealWithColor['bank'] = bank;
                                          dealWithColor['merchant_name'] =
                                              merchantName;
                                          dealWithColor['merchant_branch_name'] =
                                              merchantBranchName;
                                          dealWithColor['merchant_address'] =
                                              merchantAddress;
                                          dealWithColor['terms_and_conditions'] =
                                              termsAndConditions;
                                          dealWithColor['eligible_cards'] =
                                              eligibleCards;
                                          dealWithColor['discount_details'] =
                                              discountDetails;
                                          dealWithColor['valid_until'] =
                                              validUntil;
                                          dealWithColor['categories'] =
                                              categories is List
                                              ? categories
                                              : categories
                                                    .toString()
                                                    .split(',')
                                                    .map((e) => e.trim())
                                                    .toList();

                                          // Geocode merchant_address
                                          if (merchantAddress.isNotEmpty) {
                                            try {
                                              List<Location> locations =
                                                  await locationFromAddress(
                                                    deal['merchant_address'],
                                                  );
                                              if (locations.isNotEmpty) {
                                                final lat =
                                                    locations.first.latitude;
                                                final lng =
                                                    locations.first.longitude;
                                                dealWithColor['geopoint'] =
                                                    GeoPoint(lat, lng);

                                                // Generate geohash using geoflutterfire_plus
                                                final geo = GeoFirePoint(
                                                  GeoPoint(lat, lng),
                                                );
                                                dealWithColor['geohash'] =
                                                    geo.geohash;
                                              }
                                            } catch (e) {
                                              debugPrint(
                                                'Geocoding failed for address: ${deal['merchant_address']} - $e',
                                              );
                                            }
                                          }

                                          // Add the deal to Firestore
                                          await FirebaseFirestore.instance
                                              .collection('deals')
                                              .add(dealWithColor);
                                        }
                                        await _sendAnalyticsEvent();
                                        Navigator.pop(context);
                                        Fluttertoast.showToast(
                                          msg: 'Deals added!',
                                        );
                                      },
                                      child: const Text('Add'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              Fluttertoast.showToast(
                                msg: 'No new deals found.',
                              );
                            }
                          },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _selectCategoryFilter(String category) {
    setState(() {
      _selectedCategory = category;
    });
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
        // Update the nearby deals stream when location is available
        _nearbyDealsCountStream = _getNearbyDealsCountStream(_currentLocation);
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

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedBanks = prefs.getStringList('selectedBanks') ?? [];
      _selectedInterests = prefs.getStringList('selectedInterests') ?? [];
    });
  }

  Stream<int> _getNearbyDealsCountStream(
    loc.LocationData? userLocation,
  ) async* {
    if (userLocation == null ||
        userLocation.latitude == null ||
        userLocation.longitude == null) {
      yield 0;
      return;
    }
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('deals')
        .get();
    final List<DocumentSnapshot> deals = snapshot.docs.where((doc) {
      final data = (doc as DocumentSnapshot<Map<String, dynamic>>).data();
      if (data == null || !data.containsKey('geopoint')) return false;
      final geo = data['geopoint'];
      if (geo is! GeoPoint) return false;
      final double distance = Geolocator.distanceBetween(
        userLocation.latitude!,
        userLocation.longitude!,
        geo.latitude,
        geo.longitude,
      );
      return distance <= 10000;
    }).toList();
    yield deals.length;
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
    return null;
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

  // Method to log out the user
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => AuthPage(
          title: 'Dibs',
          analytics: widget.analytics,
          observer: widget.observer,
        ),
      ),
      (route) => false,
    );
  }

  Stream<int> _getThisWeekExpiringDealsCountStream() {
    return _dealsCollection
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.where((doc) {
            final data = doc.data();
            final validUntil = data['valid_until'];
            DateTime? validUntilDate;
            if (validUntil is Timestamp) {
              validUntilDate = validUntil.toDate();
            } else if (validUntil is String) {
              try {
                validUntilDate = DateTime.parse(validUntil);
              } catch (_) {
                try {
                  validUntilDate = DateFormat('MMMM d, yyyy').parse(validUntil);
                } catch (_) {
                  return false;
                }
              }
            } else {
              return false;
            }
            final nowDate = DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            );
            final validUntilDateOnly = DateTime(
              validUntilDate.year,
              validUntilDate.month,
              validUntilDate.day,
            );
            final sevenDaysFromNowDate = nowDate.add(const Duration(days: 7));
            return !validUntilDateOnly.isBefore(nowDate) &&
                !validUntilDateOnly.isAfter(sevenDaysFromNowDate);
          }).length;
        })
        .onErrorReturn(0);
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
                    width: 50,
                    height: 450,
                    child: Center(child: Image.asset('assets/dibs.png')),
                  ),
                  const SizedBox(width: 14),
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
                  return InkWell(
                    onTap: () {
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
                          child: Center(
                            child: Text(
                              (_userEmail != null && _userEmail!.isNotEmpty)
                                  ? _userEmail![0].toUpperCase()
                                  : '',
                              style: const TextStyle(
                                color: Color(0xFF5B69E4),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // IconButton(
              //   icon: const Icon(Icons.logout, color: Colors.red),
              //   onPressed: _logout,
              //   tooltip: 'Logout',
              // ),
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
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF5B69E4), // Match your app's primary color
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      (_userEmail != null && _userEmail!.isNotEmpty)
                          ? _userEmail![0].toUpperCase()
                          : '',
                      style: const TextStyle(
                        color: Color(0xFF5B69E4),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      _userEmail ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Example ListTiles for navigation
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () async {
                Navigator.pop(context); // Close the drawer
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
                if (updated == true) {
                  await _loadUserPreferences(); // Reload preferences from SharedPreferences
                  setState(() {}); // Trigger rebuild to update sorting and UI
                }
              },
            ),
            // ListTile(
            //   leading: const Icon(Icons.settings),
            //   title: const Text('Settings'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     setMessage(
            //        'Coming soon..',
            //     ); // Close the drawer
            //   },
            // ),
            const Divider(), // A visual separator
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                _logout();
              },
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                _getGreeting(),
                style: const TextStyle(
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
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          InkWell(
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
                            child: SizedBox(
                              width: 103.2, // Set your preferred fixed width
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
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const NewDealsScreen(),
                                ),
                              );
                            },
                            child: SizedBox(
                              width: 103.2,
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
                                        '${DateFormat('MMM').format(DateTime.now())} Deals',
                                    subtitle: 'Exclusive deals',
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
                              },
                              child: StreamBuilder<int>(
                                stream: _thisWeekExpiringDealsCountStream,
                                builder: (context, snapshot) {
                                  int dealsCount = 0;

                                  if (snapshot.connectionState ==
                                      ConnectionState.active) {
                                    if (snapshot.hasData) {
                                      dealsCount = snapshot.data!;
                                    } else if (snapshot.hasError) {
                                      debugPrint(
                                        'Error fetching expiring deals count: ${snapshot.error}',
                                      );
                                      dealsCount = 0;
                                    }
                                  } else if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    dealsCount = 0;
                                  }

                                  // Change subtitle if no expiring deals
                                  final String subtitle = dealsCount == 0
                                      ? 'No expiring deals this week'
                                      : 'Ending this \nweek!';

                                  return _buildRecommendationCardContent(
                                    color: const Color(0xFFE56060),
                                    icon: Icons.access_time,
                                    dealsCount: dealsCount,
                                    title: 'Expiring',
                                    subtitle: subtitle,
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
                    ..._categories.map(
                      (cat) => _buildCategoryFilterButton(
                        cat,
                        _selectedCategory == cat,
                        Colors
                            .orange, // You can customize color per category if you want
                        () => _selectCategoryFilter(cat),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _dealsCollection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                List<Deal> deals = snapshot.data!.docs
                    .map((doc) => Deal.fromFirestore(doc))
                    .where((deal) {
                      if (_selectedCategory == 'All Categories') return true;
                      return deal.categories.contains(_selectedCategory);
                    })
                    .toList();

                if (deals.isEmpty) {
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

                // Sort deals: prioritize (1) both bank & category, (2) bank only, (3) category only, (4) others
                deals.sort((a, b) {
                  bool aBankMatch = _selectedBanks.contains(a.bank);
                  bool bBankMatch = _selectedBanks.contains(b.bank);
                  bool aCategoryMatch =
                      _selectedCategory == 'All Categories' ||
                      a.categories == _selectedCategory;
                  bool bCategoryMatch =
                      _selectedCategory == 'All Categories' ||
                      b.categories == _selectedCategory;

                  int aPriority = (aBankMatch && aCategoryMatch)
                      ? 0
                      : (aBankMatch)
                      ? 1
                      : (aCategoryMatch)
                      ? 2
                      : 3;
                  int bPriority = (bBankMatch && bCategoryMatch)
                      ? 0
                      : (bBankMatch)
                      ? 1
                      : (bCategoryMatch)
                      ? 2
                      : 3;

                  if (aPriority != bPriority) {
                    return aPriority - bPriority;
                  }

                  // Optionally, further sort by interests or other criteria here

                  return 0;
                });

                return Column(
                  children: deals.map((deal) {
                    return NewDealCard(
                      merchantIcon: deal.merchantIcon,
                      merchantName: deal.merchantName,
                      categories: deal.categories,
                      description: deal.description,
                      validUntil: DateFormat(
                        'MMM dd, yyyy',
                      ).format(deal.validUntil),
                      rightTagText: deal.bank,
                      rightTagColor: deal.rightTagColor,
                      discountDetails: deal.discountDetails,
                      distance: deal.distance,
                      availability: deal.availability,
                      termsAndConditions:
                          deal.termsAndConditions ??
                          'No terms and conditions available.',
                      eligibleCards: deal.eligibleCards,
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'addDealBtn',
            onPressed: _showAddDealPrompt,
            backgroundColor: const Color(0xFF5B69E4),
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            elevation: 6,
            tooltip: 'Add new deal',
            child: const Icon(Icons.add, size: 30),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning, Ka-Dibs! 👋';
    } else if (hour < 18) {
      return 'Good afternoon, Ka-Dibs! 👋';
    } else {
      return 'Good evening, Ka-Dibs! 👋';
    }
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
  final List<String> categories;
  final String description;
  final String validUntil;
  final String rightTagText;
  final Color rightTagColor;
  final String discountDetails;
  final String? distance;
  final String? availability;
  final String? termsAndConditions;
  final List<String>? eligibleCards;

  const NewDealCard({
    super.key,
    required this.merchantIcon,
    required this.merchantName,
    required this.categories,
    required this.description,
    required this.validUntil,
    required this.rightTagText,
    required this.rightTagColor,
    required this.discountDetails,
    this.distance,
    this.availability,
    this.termsAndConditions,
    this.eligibleCards,
  });

  void _showDealDetailsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return DealDetailsModal(
          title: merchantName,
          description: description,
          categories: categories,
          bank: rightTagText,
          termsAndConditions:
              termsAndConditions ?? 'No terms and conditions available.',
          eligibleCards: eligibleCards ?? [],
          validUntil: validUntil,
        );
      },
    );
  }

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
                              categories.join(', '),
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
                              discountDetails.length > 10
                                  ? '${discountDetails.substring(0, 15)}...'
                                  : discountDetails,
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
                  onPressed: () => _showDealDetailsModal(context),
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

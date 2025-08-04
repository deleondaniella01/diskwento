// lib/screens/nearby_deals_screen.dart

import 'dart:async';
import 'dart:convert'; // Import for json.decode
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart'; // Still needed for distance calculation
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart'; // Import for DateFormat
import 'package:firebase_app_check/firebase_app_check.dart';
import '../widgets/deal_details_modal.dart';
import '../utils/merchant_icons.dart';

// Import with alias for firebase_ai
import 'package:firebase_ai/firebase_ai.dart' as fb_ai;

class NearbyDealsScreen extends StatefulWidget {
  final LocationData userLocation;

  const NearbyDealsScreen({super.key, required this.userLocation});

  @override
  State<NearbyDealsScreen> createState() => _NearbyDealsScreenState();
}

class _NearbyDealsScreenState extends State<NearbyDealsScreen> {
  late final fb_ai.GenerativeModel _generativeModel;

  late TextEditingController _searchQueryController;
  String? _selectedBank;
  final List<String> _selectedCategories = [];

  String? _currentBankFilter;
  List<String> _currentKeywordsList = [];

  final List<String> _banks = ['BDO', 'BPI', 'Metrobank', 'Landbank', 'PNB'];
  final List<String> _categories = [
    'Food & Dining',
    'Shopping',
    'Travel',
    'Electronics',
    'Health & Beauty',
  ];

  // New Future to hold the filtered deals
  late Future<List<DocumentSnapshot>> _filteredDealsFuture;

  @override
  void initState() {
    super.initState();

    // Initialize the Generative Model using FirebaseAI
    _generativeModel = fb_ai.FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
    );

    _searchQueryController = TextEditingController();

    // Initialize _filteredDealsFuture with an initial call to _applyFilters
    _filteredDealsFuture = _applyFilters();
  }

  @override
  void dispose() {
    _searchQueryController.dispose();
    super.dispose();
  }

  // Helper method to extract GeoPoint from a DocumentSnapshot
  GeoPoint _extractGeoPointFromDoc(DocumentSnapshot doc) {
    final Map<String, dynamic>? data =
        (doc as DocumentSnapshot<Map<String, dynamic>>).data();
    if (data != null && data.containsKey('geopoint')) {
      final GeoPoint geoPoint = data['geopoint'] as GeoPoint;
      return geoPoint;
    }
    // Fallback or error handling if 'geopoint' is not found
    throw Exception('GeoPoint not found in document ${doc.id}');
  }

  // Updated _getAIKeywordsAndBank function to include user location in the prompt
  Future<Map<String, String?>> _getAIKeywordsAndBank(
    String userNaturalQuery,
    String? preferredBank,
    List<String> preferredCategories,
    double? userLatitude, // New parameter
    double? userLongitude, // New parameter
  ) async {
    try {
      final categoriesStr = preferredCategories.isEmpty
          ? 'No preferred categories'
          : preferredCategories.join(', ');

      final String locationInfo =
          (userLatitude != null && userLongitude != null)
          ? 'User Location: Latitude $userLatitude, Longitude $userLongitude.'
          : 'User Location: Not provided.';

      final prompt = fb_ai.Content.text('''
        Analyze the following information to extract a 'bank_filter' and 'deal_keywords'.
        'bank_filter': Should be the most relevant bank name (e.g., 'BDO', 'BPI'). Prioritize 'preferred bank' if provided, otherwise try to extract from 'user query'. If neither is clear, return "null".
        'deal_keywords': A comma-separated list of 2-3 most relevant keywords describing the deal (e.g., 'free coffee', 'discount shoes'). Extract these primarily from the 'user query', considering 'preferred categories' and 'User Location' for context. If no clear keywords, return "null".

        Return the output as a JSON object. Only include the JSON object in your response.

        User Query: "$userNaturalQuery"
        Preferred Bank: "${preferredBank ?? 'None'}"
        Preferred Categories: "$categoriesStr"
        $locationInfo
      ''');

      final response = await _generativeModel.generateContent([prompt]);
      final text = response.text;

      if (text != null) {
        final cleanText = text
            .replaceFirst('```json', '')
            .replaceFirst('```', '')
            .trim();
        final Map<String, dynamic> aiResponse = json.decode(cleanText);

        return {
          'bank_filter': aiResponse['bank_filter']?.toString(),
          'deal_keywords': aiResponse['deal_keywords']?.toString(),
        };
      }
    } catch (e) {
      debugPrint('Error calling Gemini from Flutter client: $e');
      Fluttertoast.showToast(msg: 'Error processing AI query: $e');
    }
    return {'bank_filter': null, 'deal_keywords': null};
  }

  // Modified _applyFilters to fetch all deals and apply client-side filtering
  Future<List<DocumentSnapshot>> _applyFilters() async {
    final String userNaturalQuery = _searchQueryController.text;

    setState(() {
      // You can show a loading indicator here by updating a state variable
      // For now, _filteredDealsFuture being rebuilt will handle it.
    });

    // Call AI with user location included
    final Map<String, String?> aiFilters = await _getAIKeywordsAndBank(
      userNaturalQuery,
      _selectedBank,
      _selectedCategories,
      widget.userLocation.latitude,
      widget.userLocation.longitude,
    );

    final String? aiBankFilter = aiFilters['bank_filter'];
    final String? aiDealKeywords = aiFilters['deal_keywords'];

    debugPrint('AI Bank Filter: $aiBankFilter');
    debugPrint('AI Deal Keywords: $aiDealKeywords');

    setState(() {
      _currentBankFilter =
          (aiBankFilter != null &&
              aiBankFilter.toLowerCase() != 'null' &&
              aiBankFilter.isNotEmpty)
          ? aiBankFilter
          : _selectedBank;

      if (aiDealKeywords != null &&
          aiDealKeywords.isNotEmpty &&
          aiDealKeywords.toLowerCase() != 'null') {
        _currentKeywordsList = aiDealKeywords
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .toList();
      } else if (userNaturalQuery.isNotEmpty) {
        _currentKeywordsList = userNaturalQuery
            .split(' ')
            .map((e) => e.trim().toLowerCase())
            .toList();
      } else {
        _currentKeywordsList = [];
      }
    });

    // Fetch ALL deals from Firestore
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('deals')
        .get();
    List<DocumentSnapshot> deals = snapshot.docs;

    // Apply client-side filtering based on _currentBankFilter and _currentKeywordsList
    if (_currentBankFilter != null &&
        _currentBankFilter!.toLowerCase() != 'null' &&
        _currentBankFilter!.isNotEmpty) {
      deals = deals.where((doc) {
        final Map<String, dynamic> dealData =
            (doc as DocumentSnapshot<Map<String, dynamic>>).data()!;
        final String bankName = (dealData['bank'] ?? '').toLowerCase();
        return bankName == _currentBankFilter!.toLowerCase();
      }).toList();
    }

    if (_currentKeywordsList.isNotEmpty) {
      deals = deals.where((doc) {
        final Map<String, dynamic> dealData =
            (doc as DocumentSnapshot<Map<String, dynamic>>).data()!;
        final String dealTitle = (dealData['title'] ?? '').toLowerCase();
        final String merchantName = (dealData['merchant_name'] ?? '')
            .toLowerCase();
        final String discountDetails = (dealData['description'] ?? '')
            .toLowerCase();

        return _currentKeywordsList.any(
          (keyword) =>
              dealTitle.contains(keyword) ||
              merchantName.contains(keyword) ||
              discountDetails.contains(keyword),
        );
      }).toList();
    }

    // Filter deals by distance
    if (widget.userLocation.latitude != null &&
        widget.userLocation.longitude != null) {
      deals = deals.where((doc) {
        try {
          final GeoPoint geoPoint = _extractGeoPointFromDoc(doc);
          final double distance = Geolocator.distanceBetween(
            widget.userLocation.latitude!,
            widget.userLocation.longitude!,
            geoPoint.latitude,
            geoPoint.longitude,
          );
          return distance <=
              10000; // proximity within the customer's current location
        } catch (e) {
          // If geopoint is missing or invalid, exclude the deal
          return false;
        }
      }).toList();
    }

    return deals;
  }

  // Function to show the filter bottom sheet
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Filter Deals',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchQueryController,
                    decoration: InputDecoration(
                      labelText: 'Search Deals',
                      border: OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          setModalState(() {
                            _searchQueryController.clear();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedBank,
                    decoration: InputDecoration(
                      labelText: 'Preferred Bank',
                      border: OutlineInputBorder(),
                    ),
                    items: _banks.map((String bank) {
                      return DropdownMenuItem<String>(
                        value: bank,
                        child: Text(bank),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setModalState(() {
                        _selectedBank = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preferred Categories:',
                        style: TextStyle(fontSize: 16),
                      ),
                      Wrap(
                        spacing: 8.0,
                        children: _categories.map((category) {
                          final isSelected = _selectedCategories.contains(
                            category,
                          );
                          return ChoiceChip(
                            label: Text(category),
                            selected: isSelected,
                            selectedColor: Theme.of(
                              context,
                            ).primaryColor.withAlpha(100),
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  _selectedCategories.add(category);
                                } else {
                                  _selectedCategories.remove(category);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Update the future when filters are applied
                      setState(() {
                        _filteredDealsFuture = _applyFilters();
                      });
                      Navigator.pop(context); // Close the bottom sheet
                    },
                    child: const Text('Apply Filters'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Deals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Trigger a refresh of the deals by re-applying filters
              setState(() {
                _filteredDealsFuture = _applyFilters();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Row(
          //     children: [
          //       Expanded(
          //         child: TextField(
          //           controller: _searchQueryController,
          //           decoration: InputDecoration(
          //             labelText: 'Search deals by keywords or bank',
          //             suffixIcon: IconButton(
          //               icon: const Icon(Icons.search),
          //               onPressed: () {
          //                 setState(() {
          //                   _filteredDealsFuture =
          //                       _applyFilters(); // Apply filters on search icon press
          //                 });
          //               },
          //             ),
          //             border: OutlineInputBorder(),
          //           ),
          //           onSubmitted: (value) {
          //             setState(() {
          //               _filteredDealsFuture =
          //                   _applyFilters(); // Apply filters on keyboard submit
          //             });
          //           },
          //         ),
          //       ), //Expanded
          //     ],
          //   ),
          // ), //Padding
          Expanded(
            // Display Nearby Deals
            child: FutureBuilder<List<DocumentSnapshot>>(
              future: _filteredDealsFuture, // Use the new future
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  // Provide more specific message if filters applied
                  if (_currentBankFilter != null ||
                      _currentKeywordsList.isNotEmpty) {
                    return const Center(
                      child: Text('No deals found with the applied filters.'),
                    );
                  }
                  return const Center(child: Text('No deals found.'));
                }

                // Deals are already filtered by _applyFilters()
                List<DocumentSnapshot> deals = snapshot.data!;

                return ListView.builder(
                  itemCount: deals.length,
                  itemBuilder: (context, index) {
                    final Map<String, dynamic> deal =
                        (deals[index] as DocumentSnapshot<Map<String, dynamic>>)
                            .data()!;
                    final String dealTitle = deal['title'] ?? 'N/A';
                    final String merchantName = deal['merchant_name'] ?? 'N/A';
                    final String discountDetails = deal['description'] ?? 'N/A';

                    // Distance calculation still relevant for display
                    final GeoPoint dealGeoPoint = _extractGeoPointFromDoc(
                      deals[index],
                    );
                    final double distance = Geolocator.distanceBetween(
                      widget.userLocation.latitude!,
                      widget.userLocation.longitude!,
                      dealGeoPoint.latitude,
                      dealGeoPoint.longitude,
                    );
                    final String locationText =
                        '${(distance / 1000).toStringAsFixed(2)} km away';

                    String formattedValidUntil = '';
                    final dynamic validUntilRaw = deal['valid_until'];
                    if (validUntilRaw != null) {
                      if (validUntilRaw is Timestamp) {
                        formattedValidUntil = DateFormat('MMM dd, yyyy').format(validUntilRaw.toDate());
                      } else if (validUntilRaw is String) {
                        try {
                          formattedValidUntil = DateFormat('MMM dd, yyyy').format(DateTime.parse(validUntilRaw));
                        } catch (_) {
                          formattedValidUntil = validUntilRaw; // fallback to raw string
                        }
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
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
                                      // Use your own logic to get the icon, e.g.:
                                      getMerchantIcon(
                                        deal['merchant_id'] ?? '',
                                      ),
                                      size: 32,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
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
                                            child: Text(
                                              locationText,
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          // Categories field
                                          if (deal['categories'] != null &&
                                              deal['categories']
                                                  .toString()
                                                  .isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              margin: const EdgeInsets.only(
                                                right: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                deal['categories'] is List
                                                    ? (deal['categories'] as List).join(', ')
                                                    : (deal['categories'] ?? ''),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          // Bank field
                                          if (deal['bank'] != null &&
                                              deal['bank']
                                                  .toString()
                                                  .isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF5B69E4),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                deal['bank'],
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
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
                            const SizedBox(height: 15),
                            Text(
                              discountDetails,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                      'Valid until: $formattedValidUntil',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    // Show modal with deal details
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (BuildContext context) {
                                        final String termsAndConditions =
                                            deal['terms_and_conditions'] ??
                                            'No terms and conditions available.';
                                        final List<String> eligibleCards =
                                            List<String>.from(
                                              deal['eligible_cards'] ?? [],
                                            );
                                        return DealDetailsModal(
                                          title: dealTitle,
                                          description: discountDetails,
                                          categories:
                                              (deal['categories'] is List)
                                              ? List<String>.from(
                                                  deal['categories'],
                                                )
                                              : (deal['categories'] != null
                                                    ? deal['categories']
                                                          .toString()
                                                          .split(',')
                                                          .map((e) => e.trim())
                                                          .toList()
                                                    : <String>[]),
                                          bank: deal['bank'] ?? '',
                                          termsAndConditions:
                                              termsAndConditions,
                                          eligibleCards: eligibleCards,
                                          validUntil: formattedValidUntil,
                                        );
                                      },
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

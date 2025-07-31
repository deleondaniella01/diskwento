import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart'; // Import LocationData
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart'; // Make sure this import is correct
import 'package:geolocator/geolocator.dart';

class NearbyDealsScreen extends StatefulWidget {
  final LocationData userLocation;

  const NearbyDealsScreen({super.key, required this.userLocation});

  @override
  State<NearbyDealsScreen> createState() => _NearbyDealsScreenState();
}

class _NearbyDealsScreenState extends State<NearbyDealsScreen> {
  late final GeoFirePoint center;
  final double radiusInKm = 50; // You can adjust the radius as needed

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

  @override
  void initState() {
    super.initState();
    center = GeoFirePoint(
      GeoPoint(widget.userLocation.latitude!, widget.userLocation.longitude!),
    );
    // Initialize _geoDealsCollection with the correctly typed _dealsCollection
    _geoDealsCollection = GeoCollectionReference(_dealsCollection);
  }

  // Helper function to extract GeoPoint from Firestore document
  // Returns GeoPoint(0, 0) if a valid GeoPoint cannot be extracted
  GeoPoint _extractGeoPointFromDoc(
    Map<String, dynamic> data,
    String geoPointFieldName,
  ) {
    final dynamic rawGeopoint = data[geoPointFieldName];
    final String docId = data['id'] ?? 'unknown';

    if (rawGeopoint == null) {
      debugPrint(
        'geopointFrom: $geoPointFieldName field is null or missing for doc ID: $docId',
      );
      return GeoPoint(0, 0);
    }

    if (rawGeopoint is GeoPoint) {
      debugPrint(
        'geopointFrom: Found native GeoPoint: ${rawGeopoint.latitude}, ${rawGeopoint.longitude} for doc ID: $docId',
      );
      return rawGeopoint;
    }

    if (rawGeopoint is Map<String, dynamic>) {
      final double? latitude = (rawGeopoint['latitude'] as num?)?.toDouble();
      final double? longitude = (rawGeopoint['longitude'] as num?)?.toDouble();

      if (latitude != null && longitude != null) {
        debugPrint(
          'geopointFrom: Found map GeoPoint: $latitude, $longitude for doc ID: $docId',
        );
        return GeoPoint(latitude, longitude);
      }
      debugPrint(
        'geopointFrom: Failed to parse lat/lon from map for doc ID: $docId. Invalid numbers or keys.',
      );
      return GeoPoint(0, 0);
    }

    if (rawGeopoint is String) {
      final RegExp regex = RegExp(r'[(-?d+.?d*)° N, (-?d+.?d*)° E]');
      final Match? match = regex.firstMatch(rawGeopoint);

      if (match != null && match.groupCount == 2) {
        final double? latitude = double.tryParse(match.group(1)!);
        final double? longitude = double.tryParse(match.group(2)!);

        if (latitude != null && longitude != null) {
          debugPrint(
            'geopointFrom: Parsed string GeoPoint: $latitude, $longitude for doc ID: $docId',
          );
          return GeoPoint(latitude, longitude);
        }
      }
      debugPrint(
        'geopointFrom: Unrecognized string format for GeoPoint: "$rawGeopoint" for doc ID: $docId',
      );
      return GeoPoint(0, 0);
    }

    debugPrint(
      'geopointFrom: Unhandled type for $geoPointFieldName: ${rawGeopoint.runtimeType} for doc ID: $docId',
    );
    return GeoPoint(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Deals'),
        backgroundColor: const Color(0xFF5B69E4),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot>>(
              stream: _geoDealsCollection.subscribeWithin(
                center: center,
                radiusInKm: radiusInKm, // Use radiusInKm
                field: 'merchant_geopoint',
                geopointFrom: (data) =>
                    _extractGeoPointFromDoc(data, 'merchant_geopoint'),
                strictMode: true,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint('Error fetching deals: ${snapshot.error}');
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No deals found nearby.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                final List<DocumentSnapshot> nearbyDocs = snapshot.data!;
                // Filter out documents with GeoPoint(0, 0) before building the list
                final List<DocumentSnapshot> validNearbyDocs = nearbyDocs.where(
                  (doc) {
                    final dealData = doc.data() as Map<String, dynamic>?;
                    if (dealData == null) return false;
                    final GeoPoint dealLocation = _extractGeoPointFromDoc(
                      dealData,
                      'merchant_geopoint',
                    );
                    return dealLocation.latitude != 0 ||
                        dealLocation.longitude != 0;
                  },
                ).toList();

                if (validNearbyDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No deals with valid locations found nearby.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: validNearbyDocs.length,
                  itemBuilder: (context, index) {
                    final dealData =
                        validNearbyDocs[index].data() as Map<String, dynamic>?;
                    if (dealData == null) {
                      return const SizedBox.shrink();
                    }

                    final String title = dealData['title'] ?? 'No Title';
                    final String merchantName =
                        dealData['merchant_name'] ?? 'Unknown Merchant';
                    final String discountDetails =
                        dealData['discount_details'] ?? 'No Discount Info';
                    final GeoPoint dealLocation = _extractGeoPointFromDoc(
                      dealData,
                      'merchant_geopoint',
                    );

                    String locationText = 'Location: N/A';
                    // Only calculate and display distance for valid locations
                    if (dealLocation.latitude != 0 ||
                        dealLocation.longitude != 0) {
                      final double distance = Geolocator.distanceBetween(
                        dealLocation.latitude,
                        dealLocation.longitude,
                        center.latitude,
                        center.longitude,
                      );
                      // Display distance in kilometers
                      locationText =
                          'Distance: ${(distance / 1000).toStringAsFixed(2)} km';
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5B69E4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              merchantName,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              discountDetails,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              locationText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
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

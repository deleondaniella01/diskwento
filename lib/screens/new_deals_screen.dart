// lib/screens/new_deals_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../widgets/deal_details_modal.dart';
import '../utils/merchant_icons.dart';

// Helper function to convert hex string to Color object
Color colorFromHex(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll("#", "");
  if (hexColor.length == 6) {
    hexColor = "FF$hexColor";
  }
  return Color(int.parse(hexColor, radix: 16));
}

class NewDealsScreen extends StatefulWidget {
  const NewDealsScreen({super.key});

  @override
  State<NewDealsScreen> createState() => _NewDealsScreenState();
}

class _NewDealsScreenState extends State<NewDealsScreen> {
  // Get the first day of the current month
  final DateTime _startOfMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  // Get the last day of the current month (last millisecond)
  final DateTime _endOfMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
    23,
    59,
    59,
    999,
  );

  void _showDealDetailsModal(
    BuildContext context,
    String merchantName,
    String dealDescription,
    String formattedValidUntil,
    List<String> categories,
    String bank,
    String termsAndConditions,
    List<String> eligibleCards,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return DealDetailsModal(
          title: merchantName,
          description: dealDescription,
          categories: categories,
          bank: bank,
          termsAndConditions: termsAndConditions,
          eligibleCards: eligibleCards,
          validUntil: formattedValidUntil,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deals for this Month'),
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Querying for deals where 'valid_until' falls within the current month
        stream: FirebaseFirestore.instance
            .collection('deals')
            .where(
              'valid_until',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfMonth),
            )
            .where(
              'valid_until',
              isLessThanOrEqualTo: Timestamp.fromDate(_endOfMonth),
            )
            .orderBy(
              'valid_until',
              descending: true,
            ) // Order by valid_until date
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No new deals available for this month.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Display the deals
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var deal = snapshot.data!.docs[index];
              String merchantName = deal['merchant_name'] ?? 'N/A';
              String dealDescription = deal['description'] ?? 'No description';
              Timestamp validUntil = deal['valid_until'] as Timestamp;
              String merchantId = deal['merchant_id'] ?? 'unknown';
              String termsAndConditions =
                  deal['terms_and_conditions'] ??
                  'No terms and conditions available.';
              List<String> eligibleCards = List<String>.from(
                deal['eligible_cards'] ?? [],
              );
              String rightTagText = deal['bank'] ?? ''; // Get bank for tag text
              String tagColorHex =
                  deal['tag_color_hex'] ?? '#1c1c1c'; // Get tag color hex
              Color rightTagColor = colorFromHex(
                tagColorHex,
              ); // Convert hex to Color

              // Format date for display
             String formattedValidUntil = '';
              final validUntilRaw = deal['valid_until'];
              if (validUntilRaw is Timestamp) {
                formattedValidUntil = DateFormat('MMM dd, yyyy').format(validUntilRaw.toDate());
              } else if (validUntilRaw is String) {
                try {
                  formattedValidUntil = DateFormat('MMM dd, yyyy').format(DateTime.parse(validUntilRaw));
                } catch (_) {
                  formattedValidUntil = validUntilRaw; // fallback to raw string
                }
              }

              // Get the appropriate icon using the helper function
              IconData merchantIcon = getMerchantIcon(merchantId);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    // Categories field
                                    if (deal['categories'] != null &&
                                        deal['categories']
                                            .toString()
                                            .isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          deal['categories'],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    // BDO field
                                    if (deal['bank'] != null &&
                                        deal['bank'].toString().isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF5B69E4),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
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
                        dealDescription,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
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
                                    'Valid until: $formattedValidUntil',
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
                              _showDealDetailsModal(
                                context,
                                merchantName,
                                dealDescription,
                                formattedValidUntil,
                                (deal['categories'] is List)
                                    ? List<String>.from(deal['categories'])
                                    : (deal['categories'] != null
                                          ? deal['categories']
                                                .toString()
                                                .split(',')
                                                .map((e) => e.trim())
                                                .toList()
                                          : <String>[]),
                                rightTagText,
                                termsAndConditions,
                                eligibleCards,
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
    );
  }
}

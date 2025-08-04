// lib/screens/expiring_deals_screen.dart
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

class ExpiringDealsScreen extends StatefulWidget {
  const ExpiringDealsScreen({super.key});

  @override
  State<ExpiringDealsScreen> createState() => _ExpiringDealsScreenState();
}

class _ExpiringDealsScreenState extends State<ExpiringDealsScreen> {
  // Get the current date
  final DateTime _now = DateTime.now();

  // Calculate the start of the current week (Monday at 00:00:00)
  // Dart's weekday: Monday is 1, Sunday is 7.
  late final DateTime _startOfWeek;

  // Calculate the end of the current week (Sunday at 23:59:59.999)
  late final DateTime _endOfWeek;

  @override
  void initState() {
    super.initState();
    // Initialize date ranges in initState
    _startOfWeek = DateTime(
      _now.year,
      _now.month,
      _now.day,
    ).subtract(Duration(days: _now.weekday - 1));

    _endOfWeek =
        DateTime(_startOfWeek.year, _startOfWeek.month, _startOfWeek.day).add(
          const Duration(
            days: 6,
            hours: 23,
            minutes: 59,
            seconds: 59,
            milliseconds: 999,
          ),
        );
  }

  void _showDealDetailsModal(
    BuildContext context,
    String dealTitle,
    String dealDescription,
    String validUntil,
    List<String> categories,
    String bank,
    String termsAndConditions,
    List<String> eligibleCards,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return DealDetailsModal(
          title: dealTitle,
          description: dealDescription,
          categories: categories,
          bank: bank,
          termsAndConditions: termsAndConditions,
          eligibleCards: eligibleCards,
          validUntil: validUntil,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final DateTime endOfWeek =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day).add(
          const Duration(
            days: 6,
            hours: 23,
            minutes: 59,
            seconds: 59,
            milliseconds: 999,
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiring Deals'),
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('deals')
            .orderBy('valid_until', descending: false)
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
                'No deals expiring this week.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final allDocs = snapshot.data!.docs.where((deal) {
            final validUntilRaw = deal['valid_until'];
            DateTime? validUntilDate;

            if (validUntilRaw is Timestamp) {
              validUntilDate = validUntilRaw.toDate();
            } else if (validUntilRaw is String) {
              try {
                validUntilDate = DateTime.parse(validUntilRaw);
              } catch (_) {
                try {
                  validUntilDate = DateFormat(
                    'MMMM d, yyyy',
                  ).parse(validUntilRaw);
                } catch (_) {
                  return false;
                }
              }
            } else {
              return false;
            }

            // Rolling 7-day window
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
          }).toList();
          if (allDocs.isEmpty) {
            return const Center(
              child: Text(
                'No deals expiring this week.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // 2. Use the filtered list for the ListView
          return ListView.builder(
            itemCount: allDocs.length,
            itemBuilder: (context, index) {
              var deal = allDocs[index];
              String merchantName = deal['merchant_name'] ?? 'N/A';
              String dealDescription = deal['description'] ?? 'No description';
              DateTime validUntilDate;
              final validUntilRaw = deal['valid_until'];
              if (validUntilRaw is Timestamp) {
                validUntilDate = validUntilRaw.toDate();
              } else if (validUntilRaw is String) {
                try {
                  validUntilDate = DateTime.parse(validUntilRaw);
                } catch (_) {
                  // fallback if string is not ISO format
                  validUntilDate = DateTime.now().add(const Duration(days: 30));
                }
              } else {
                validUntilDate = DateTime.now().add(const Duration(days: 30));
              }

              // Format the validUntilDate
              String formattedValidUntil = DateFormat(
                'MMM dd, yyyy',
              ).format(validUntilDate);

              final data = deal.data() as Map<String, dynamic>;
              String merchantId = data.containsKey('merchant_id')
                  ? data['merchant_id']
                  : 'unknown';

              String termsAndConditions =
                  deal['terms_and_conditions'] ??
                  'No terms and conditions available.';
              List<String> eligibleCards = List<String>.from(
                deal['eligible_cards'] ?? [],
              );
              String rightTagText = deal['bank'] ?? '';
              String tagColorHex = deal['tag_color_hex'] ?? '#1c1c1c';
              Color rightTagColor = colorFromHex(tagColorHex);

              IconData merchantIcon = getMerchantIcon(merchantId);

              // Calculate days until expiration
              final now = DateTime.now();
              final expiryDate = validUntilDate;

              // Normalize both dates to remove time component
              final nowDate = DateTime(now.year, now.month, now.day);
              final expiryDateOnly = DateTime(
                expiryDate.year,
                expiryDate.month,
                expiryDate.day,
              );

              final int daysLeft = expiryDateOnly.difference(nowDate).inDays;

              // If the deal expires today, show "Expiring today"
              String expiringText;
              if (daysLeft == 0) {
                expiringText = "Expiring today";
              } else if (daysLeft == 1) {
                expiringText = "Expiring in 1 day";
              } else {
                expiringText = "Expiring in $daysLeft days";
              }

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
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          merchantName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF323B60),
                                          ),
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
                                                  (deal['categories'] is List)
                                                      ? (deal['categories']
                                                                as List)
                                                            .join(', ')
                                                      : (deal['categories'] ??
                                                            ''),
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            // BDO field
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
                                                  color: const Color(
                                                    0xFF5B69E4,
                                                  ),
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
                                    // Expiring text container (right side)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 4.0,
                                      ),
                                      decoration: BoxDecoration(),
                                      child: Text(
                                        expiringText,
                                        style: const TextStyle(
                                          color: Color.fromARGB(
                                            255,
                                            225,
                                            65,
                                            65,
                                          ),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dealDescription,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
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
                                    'Expires: $formattedValidUntil',
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
                                deal['bank'] ?? '',
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

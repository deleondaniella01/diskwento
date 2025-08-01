// lib/screens/expiring_deals_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting

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
    String merchantName,
    String dealDescription,
    String validUntil,
    String termsAndConditions,
    List<String> eligibleCards,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  merchantName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(
                      0xFFE56060,
                    ), // Use red color for expiring deals modal title
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  dealDescription,
                  style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                ),
                const SizedBox(height: 10),
                Text(
                  'Expires: $validUntil', // Changed text to 'Expires:'
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Terms and Conditions:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  termsAndConditions,
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Eligible Cards:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: eligibleCards
                      .map((card) => Text('- $card'))
                      .toList(),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiring Deals'),
        backgroundColor: const Color(0xFFE56060),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('deals')
            .where(
              'valid_until',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfWeek),
            )
            .where(
              'valid_until',
              isLessThanOrEqualTo: Timestamp.fromDate(_endOfWeek),
            )
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
              String rightTagText = deal['bank'] ?? '';
              String tagColorHex = deal['tag_color_hex'] ?? '#1c1c1c';
              Color rightTagColor = colorFromHex(tagColorHex);

              String formattedValidUntil = DateFormat(
                'MMM dd, yyyy',
              ).format(validUntil.toDate());

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
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 4.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: rightTagColor,
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ),
                                      ),
                                      child: Text(
                                        rightTagText,
                                        style: const TextStyle(
                                          color: Color.fromARGB(
                                            255,
                                            255,
                                            255,
                                            255,
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

// lib/screens/new_deals_screen.dart
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
            // Added SingleChildScrollView
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  merchantName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5B69E4),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  dealDescription,
                  style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                ),
                const SizedBox(height: 10),
                Text(
                  'Valid until: $validUntil',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Terms and Conditions:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  termsAndConditions, // Display terms and conditions
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Eligible Cards:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                // Display eligible cards as a list
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
        title: const Text('Deals for this Month'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
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
              String formattedValidUntil = DateFormat(
                'MMM dd, yyyy',
              ).format(validUntil.toDate());

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
                                    Container(
                                      // Added Container for the bank tag
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 4.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            rightTagColor, // Use the determined tag color
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ),
                                      ),
                                      child: Text(
                                        rightTagText, // Use the bank name as tag text
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

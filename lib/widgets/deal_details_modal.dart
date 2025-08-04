import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/bank_links.dart';

class DealDetailsModal extends StatelessWidget {
  final String title;
  final String description;
  final List<String> categories;
  final String bank;
  final String termsAndConditions;
  final List<String> eligibleCards;
  final String validUntil;

  const DealDetailsModal({
    super.key,
    required this.title,
    required this.description,
    required this.categories,
    required this.bank,
    required this.termsAndConditions,
    required this.eligibleCards,
    required this.validUntil,
  });

  @override
  Widget build(BuildContext context) {
    final String officialWebsite = getBankSourceLink(bank);
    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5B69E4),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                if (categories.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      categories.join(', '),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (bank.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B69E4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bank,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Valid until: $validUntil',
                  style: const TextStyle(fontSize: 13, color: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Terms & Conditions:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              termsAndConditions,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            if (officialWebsite.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Official website:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse(officialWebsite);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: Text(
                  officialWebsite,
                  style: const TextStyle(
                    color: Color(0xFF5B69E4),
                    decoration: TextDecoration.underline,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            if (eligibleCards.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Eligible Cards:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: eligibleCards
                    .map(
                      (card) => Chip(
                        label: Text(card),
                        backgroundColor: Colors.blue[50],
                      ),
                    )
                    .toList(),
              ),
            ],
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
  }
}

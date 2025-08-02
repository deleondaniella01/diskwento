import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'interests_page.dart';

class BanksPage extends StatefulWidget {
  final String title;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const BanksPage({
    super.key,
    required this.title,
    required this.analytics,
    required this.observer,
  });

  @override
  _BanksPageState createState() => _BanksPageState();
}

class _BanksPageState extends State<BanksPage> {
  List<String> _selectedBanks = [];

  final List<Map<String, dynamic>> banks = [
    {
      'name': 'Bank of the Philippine Islands',
      'details': 'Credit & Debit Cards',
      'icon': 'assets/bpi_logo.png' // Assuming you have bank logos in assets
    },
    {
      'name': 'Banco de Oro',
      'details': 'Credit & Debit Cards',
      'icon': 'assets/bdo_logo.png'
    },
    {
      'name': 'UnionBank',
      'details': 'Credit & Debit Cards',
      'icon': 'assets/unionbank_logo.png'
    },
    {
      'name': 'Metrobank',
      'details': 'Credit & Debit Cards',
      'icon': 'assets/metrobank_logo.png'
    },
    {
      'name': 'Security Bank',
      'details': 'Credit & Debit Cards',
      'icon': 'assets/securitybank_logo.png'
    },
    {
      'name': 'RCBC',
      'details': 'Credit & Debit Cards',
      'icon': 'assets/rcbc_logo.png'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Dibs!'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Let's set up your account to find the best deals",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == 0 ? Colors.blueAccent : Colors.grey[300],
                    ),
                    child: Text(
                      (index + 1).toString(),
                      style: TextStyle(
                        color: index == 0 ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),
              Card(
                elevation: 2.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Your First Card',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Select at least one card to start discovering personalized deals',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: banks.length,
                          itemBuilder: (context, index) {
                            final bank = banks[index];
                            final isSelected = _selectedBanks.contains(bank['name']);
                            return CheckboxListTile(
                              title: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    color: Colors.grey, // Placeholder
                                    // child: Image.asset(bank['icon']),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bank['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          bank['details'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              value: isSelected,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedBanks.add(bank['name']);
                                  } else {
                                    _selectedBanks.remove(bank['name']);
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _selectedBanks.isNotEmpty
                    ? () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InterestsPage(
                              title: 'Dibs',
                              analytics: widget.analytics,
                              observer: widget.observer,
                            ),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF29B6F6),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Continue',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
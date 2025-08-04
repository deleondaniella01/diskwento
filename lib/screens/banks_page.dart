import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'interests_page.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

void setupStorage() {
  // Get the default Firebase Storage instance.
  final storage = FirebaseStorage.instance;
}

class _BanksPageState extends State<BanksPage> {
  List<String> _selectedBanks = [];

  final List<Map<String, dynamic>> banks = [
    {'name': 'BPI', 'details': 'Credit & Debit Cards', 'key': 'bpi'},
    {'name': 'BDO', 'details': 'Credit & Debit Cards', 'key': 'bdo'},
    {
      'name': 'UnionBank',
      'details': 'Credit & Debit Cards',
      'key': 'unionbank',
    },
    {
      'name': 'Metrobank',
      'details': 'Credit & Debit Cards',
      'key': 'metrobank',
    },
    {
      'name': 'Security Bank',
      'details': 'Credit & Debit Cards',
      'key': 'securitybank',
    },
    {'name': 'RCBC', 'details': 'Credit & Debit Cards', 'key': 'rcbc'},
  ];

  void _toggleBank(String bankName) {
    setState(() {
      if (_selectedBanks.contains(bankName)) {
        _selectedBanks.remove(bankName);
      } else {
        _selectedBanks.add(bankName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFB3E5FC), // Light blue
              Color(0xFFE1F5FE), // Lighter blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Header
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Image.asset('assets/dibs.png', fit: BoxFit.contain),
                    ),
                  ),
                  const Text(
                    'Welcome to Dibs!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0277BD),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Let's set up your account to find the best deals",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // Progress Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 30,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == 0 ? Colors.blueAccent : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 30),
              Expanded(
                // This Expanded widget is key
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    // Removed SingleChildScrollView here
                    child: Column(
                      // Use Column directly if it's the only child
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Your Preferred Card',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Select at least one card to start discovering personalized deals',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        // Flexible( // Wrap GridView.builder in Flexible
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 15,
                                childAspectRatio: 2.0,
                              ),
                          itemCount: banks.length,
                          itemBuilder: (context, index) {
                            final bank = banks[index];
                            final isSelected = _selectedBanks.contains(
                              bank['name'],
                            );
                            return GestureDetector(
                              onTap: () => _toggleBank(bank['name']),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blueAccent
                                        : Colors.grey[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    FutureBuilder<String>(
                                      future: bank['key'] != null
                                          ? getBankIconUrl(bank['key'])
                                          : Future.value(null),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          );
                                        }
                                        if (snapshot.hasError ||
                                            !snapshot.hasData ||
                                            snapshot.data == null) {
                                          return const Icon(
                                            Icons.credit_card,
                                            size: 32,
                                            color: Colors.grey,
                                          );
                                        }
                                        return Container(
                                          width: 30,
                                          height: 30,
                                          margin: const EdgeInsets.only(
                                            right: 10,
                                          ),
                                          child: Image.network(
                                            snapshot.data!,
                                            fit: BoxFit.contain,
                                          ),
                                        );
                                      },
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            bank['name'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? Colors.blueAccent
                                                  : Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
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
                              ),
                            );
                          },
                        ),
                        // ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: _selectedBanks.isNotEmpty
                                  ? () async {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setStringList(
                                        'selectedBanks',
                                        _selectedBanks,
                                      );

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
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Continue'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String> getBankIconUrl(String bankKey) async {
  final storage = FirebaseStorage.instance;
  final List<String> extensions = ['png', 'jpg', 'jpeg'];

  for (final ext in extensions) {
    try {
      final ref = storage.ref().child('bank/$bankKey.$ext');
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error fetching $bankKey.$ext: $e');
      continue;
    }
  }
  // If none found, throw error
  throw Exception('No icon found for $bankKey');
}

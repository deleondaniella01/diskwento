import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:myapp/main.dart';
import 'package:myapp/screens/banks_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InterestsPage extends StatefulWidget {
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final String title;

  const InterestsPage({
    super.key,
    required this.title,
    required this.analytics,
    required this.observer,
  });

  @override
  // ignore: library_private_types_in_public_api
  InterestsPageState createState() => InterestsPageState();
}

class InterestsPageState extends State<InterestsPage> {
  final List<Map<String, dynamic>> interests = [
    {
      'name': 'Food & Dining',
      'icon': Icons.fastfood,
      'details': 'Restaurants, cafes, delivery',
    },
    {
      'name': 'Electronics',
      'icon': Icons.electrical_services,
      'details': 'Gadgets, appliances',
    },
    {
      'name': 'Shopping',
      'icon': Icons.shopping_bag,
      'details': 'Fashion, lifestyle',
    },
    {
      'name': 'Travel',
      'icon': Icons.travel_explore,
      'details': 'Hotels, flights, tours',
    },
    {
      'name': 'Transportation',
      'icon': Icons.directions_car,
      'details': 'Grab, taxi, gas',
    },
    {
      'name': 'Health',
      'icon': Icons.health_and_safety,
      'details': 'Medical, pharmacy',
    },
    {
      'name': 'Groceries',
      'icon': Icons.local_grocery_store,
      'details': 'Supermarkets, stores',
    },
    {
      'name': 'Entertainment',
      'icon': Icons.movie,
      'details': 'Movies, games, events',
    },
  ];

  final List<String> selectedInterests = [];

  void _toggleInterest(String interestName) {
    setState(() {
      if (selectedInterests.contains(interestName)) {
        selectedInterests.remove(interestName);
      } else {
        selectedInterests.add(interestName);
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
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 50,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome to Dibs!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0277BD), // Darker blue
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
                      color: index == 0 ? Colors.lightGreen : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Choose Your Interests',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Select categories you're interested in to get personalized deals",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 15,
                                  mainAxisSpacing: 15,
                                  childAspectRatio: 1.3,
                                ),
                            itemCount: interests.length,
                            itemBuilder: (context, index) {
                              final interest = interests[index];
                              final isSelected = selectedInterests.contains(
                                interest['name'],
                              );
                              return GestureDetector(
                                onTap: () => _toggleInterest(interest['name']),
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
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        interest['icon'],
                                        size: 30,
                                        color: isSelected
                                            ? Colors.blueAccent
                                            : Colors.black54,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        interest['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.blueAccent
                                              : Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: true,
                                      ),
                                      Text(
                                        interest['details'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: true,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                // TODO: Implement navigation back
                                Navigator.pop(context);
                              },
                              child: const Text('Back'),
                            ),
                            ElevatedButton(
                              onPressed: selectedInterests.isNotEmpty
                                  ? () async {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setBool('interestsSet', true);
                                      await prefs.setStringList(
                                        'selectedInterests',
                                        selectedInterests,
                                      );

                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MyHomePage(
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

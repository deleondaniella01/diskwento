import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For simpler preference storage

class PersonalizedDealsScreen extends StatefulWidget {
  const PersonalizedDealsScreen({super.key});

  @override
  State<PersonalizedDealsScreen> createState() =>
      _PersonalizedDealsScreenState();
}

class _PersonalizedDealsScreenState extends State<PersonalizedDealsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GenerativeModel _geminiModel = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-pro', // Use 'gemini-1.5-flash' for faster responses
  );

  List<String> _selectedBanks = [];
  List<String> _selectedCategories = [];
  final List<String> _availableBanks = [
    'BDO',
    'Metrobank',
    'BPI',
    'RCBC',
    'EastWest',
  ]; // Example list
  final List<String> _availableCategories = [
    'Food & Dining',
    'Electronics',
    'Travel',
    'Fashion',
    'Health & Beauty',
    'Groceries',
  ]; // Example list

  List<Map<String, dynamic>> _personalizedDeals = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedBanks = prefs.getStringList('preferred_banks') ?? [];
      _selectedCategories = prefs.getStringList('preferred_categories') ?? [];
    });
    // Fetch deals immediately after loading preferences
    _fetchAndPersonalizeDeals();
  }

  Future<void> _saveUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('preferred_banks', _selectedBanks);
    await prefs.setStringList('preferred_categories', _selectedCategories);
  }

  Future<void> _fetchAndPersonalizeDeals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _personalizedDeals = [];
    });

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('deals');

      // 1. Basic Filtering (Firestore)
      // Filter by selected banks (if any)
      if (_selectedBanks.isNotEmpty) {
        // Use 'whereIn' for multiple bank selections (up to 10 values)
        query = query.where('bank', whereIn: _selectedBanks);
      }

      // Filter by selected categories using 'arrayContainsAny'
      // Firestore limitation: only one 'arrayContainsAny' or 'arrayContains' per query.
      // If you need to filter by multiple array fields, you'd fetch broadly and filter in-app,
      // or restructure data/use Cloud Functions for more complex queries.
      if (_selectedCategories.isNotEmpty) {
        query = query.where(
          'categories',
          arrayContainsAny: _selectedCategories,
        );
      }

      final querySnapshot = await query.get();
      List<Map<String, dynamic>> rawDeals = querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        }; // Include doc ID for AI to reference
      }).toList();

      if (rawDeals.isEmpty) {
        setState(() {
          _errorMessage =
              'No deals found matching your selected filters. Try broadening your preferences.';
        });
        return;
      }

      // 2. Advanced Personalization using Gemini (Client-Side)
      await _personalizeDealsWithAI(rawDeals);
    } catch (e) {
      _errorMessage = 'Error fetching deals: ${e.toString()}';
      print('Deals Fetch Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _personalizeDealsWithAI(
    List<Map<String, dynamic>> dealsToPersonalize,
  ) async {
    if (dealsToPersonalize.isEmpty) return;

    // Construct a comprehensive user preference string for the AI
    String userPreferenceString =
        "User's preferred banks: ${_selectedBanks.join(', ')}. "
        "User's preferred categories: ${_selectedCategories.join(', ')}. "
        "Prioritize deals with discounts and relevant to their choices.";
    // You could add more: "User has clicked on electronics deals 5 times recently."
    // "User previously saved travel deals."

    final prompt =
        """
    Based on the following user preferences: "$userPreferenceString"

    Here is a list of deals:
    ${json.encode(dealsToPersonalize)}

    Please re-order the deals based on their relevance to the user's preferences, putting the most relevant deals first.
    For each deal, also provide a 'relevance_score' (from 0 to 100, where 100 is most relevant) and a short 'personalized_reason' (1-2 sentences) why this deal is suitable for the user.
    Ensure the output is a JSON array of objects, including all original deal fields plus 'relevance_score' and 'personalized_reason'.
    """;

    try {
      final response = await _geminiModel.generateContent([
        Content.text(prompt),
      ]);
      final rawText = response.text;

      if (rawText == null || rawText.isEmpty) {
        print("Gemini returned empty response for personalization.");
        return;
      }

      List<dynamic> personalizedDealsJson;
      try {
        final jsonMatch = RegExp(
          r'```json\n([\s\S]*?)\n```',
        ).firstMatch(rawText);
        if (jsonMatch != null && jsonMatch.groupCount >= 1) {
          personalizedDealsJson = json.decode(jsonMatch.group(1)!);
        } else {
          personalizedDealsJson = json.decode(rawText);
        }
      } catch (e) {
        print("Failed to parse personalized deals JSON from AI: $rawText, $e");
        _errorMessage = 'AI returned malformed data. Please try again.';
        return;
      }

      List<Map<String, dynamic>> finalPersonalizedList = personalizedDealsJson
          .map((item) => item as Map<String, dynamic>)
          .toList();

      // Sort by relevance score (descending)
      finalPersonalizedList.sort(
        (a, b) =>
            (b['relevance_score'] ?? 0).compareTo(a['relevance_score'] ?? 0),
      );

      setState(() {
        _personalizedDeals = finalPersonalizedList;
      });
    } catch (e) {
      _errorMessage = 'Error personalizing deals with AI: ${e.toString()}';
      print('AI Personalization Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personalized Deals')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Preferred Banks:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 8.0,
                  children: _availableBanks.map((bank) {
                    final isSelected = _selectedBanks.contains(bank);
                    return FilterChip(
                      label: Text(bank),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedBanks.add(bank);
                          } else {
                            _selectedBanks.remove(bank);
                          }
                        });
                        _saveUserPreferences(); // Save preferences
                        _fetchAndPersonalizeDeals(); // Re-fetch deals
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Select Preferred Categories:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 8.0,
                  children: _availableCategories.map((category) {
                    final isSelected = _selectedCategories.contains(category);
                    return FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategories.add(category);
                          } else {
                            _selectedCategories.remove(category);
                          }
                        });
                        _saveUserPreferences(); // Save preferences
                        _fetchAndPersonalizeDeals(); // Re-fetch deals
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_errorMessage != null)
                  Center(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                else if (_personalizedDeals.isEmpty)
                  const Center(
                    child: Text('No personalized deals to display.'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _personalizedDeals.length,
              itemBuilder: (context, index) {
                final deal = _personalizedDeals[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deal['title'] ?? 'No Title',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(deal['merchant_name'] ?? 'Unknown Merchant'),
                        if (deal['discount_details'] != null)
                          Text('Discount: ${deal['discount_details']}'),
                        if (deal['categories'] != null)
                          Text(
                            'Categories: ${(deal['categories'] as List).join(', ')}',
                          ),
                        if (deal['bank'] != null) Text('Bank: ${deal['bank']}'),
                        if (deal['personalized_reason'] != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'AI Recommendation: ${deal['personalized_reason']}',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ],
                        if (deal['relevance_score'] != null)
                          Text(
                            'Relevance Score: ${deal['relevance_score']}/100',
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

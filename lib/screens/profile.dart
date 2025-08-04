import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<String> _selectedBanks = [];
  List<String> _selectedInterests = [];

  // Define your available banks and interests here
  final List<String> _allBanks = [
    'BPI',
    'BDO',
    'UnionBank',
    'Metrobank',
    'Security Bank',
    'RCBC',
  ];
  final List<String> _allInterests = [
    'Food & Dining',
    'Travel',
    'Shopping',
    'Groceries',
    'Health',
    'Entertainment',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedBanks = prefs.getStringList('selectedBanks') ?? [];
      _selectedInterests = prefs.getStringList('selectedInterests') ?? [];
    });
  }

  Future<void> _editBanks() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        List<String> tempSelected = List.from(_selectedBanks);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select Banks',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: _allBanks.map((bank) {
                        final selected = tempSelected.contains(bank);
                        return FilterChip(
                          label: Text(bank),
                          selected: selected,
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                tempSelected.add(bank);
                              } else {
                                tempSelected.remove(bank);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, tempSelected);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('selectedBanks', result);
      setState(() {
        _selectedBanks = result;
      });
    }
  }

  Future<void> _editInterests() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        List<String> tempSelected = List.from(_selectedInterests);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select Interests',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: _allInterests.map((interest) {
                        final selected = tempSelected.contains(interest);
                        return FilterChip(
                          label: Text(interest),
                          selected: selected,
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                tempSelected.add(interest);
                              } else {
                                tempSelected.remove(interest);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, tempSelected);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('selectedInterests', result);
      setState(() {
        _selectedInterests = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true); // Always notify main screen
        return false; // Prevent default pop, since we already did it
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: const Color(0xFF5B69E4),
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selected Banks:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _selectedBanks.isNotEmpty
                    ? _selectedBanks
                          .map((bank) => Chip(label: Text(bank)))
                          .toList()
                    : [const Text('No banks selected')],
              ),
              TextButton.icon(
                onPressed: _editBanks,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Banks'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Selected Interests:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _selectedInterests.isNotEmpty
                    ? _selectedInterests
                          .map((interest) => Chip(label: Text(interest)))
                          .toList()
                    : [const Text('No interests selected')],
              ),
              TextButton.icon(
                onPressed: _editInterests,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Interests'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

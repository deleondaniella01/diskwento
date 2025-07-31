// lib/screens/new_deals_screen.dart
import 'package:flutter/material.dart';

class NewDealsScreen extends StatelessWidget {
  const NewDealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Deals'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Displaying Deals for this Month',
          style: TextStyle(fontSize: 20, color: Colors.grey),
        ),
      ),
    );
  }
}
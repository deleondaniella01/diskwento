// lib/screens/expiring_deals_screen.dart
import 'package:flutter/material.dart';

class ExpiringDealsScreen extends StatelessWidget {
  const ExpiringDealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiring Deals'),
        backgroundColor: const Color(0xFFE56060),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Displaying Expiring Deals',
          style: TextStyle(fontSize: 20, color: Colors.grey),
        ),
      ),
    );
  }
}
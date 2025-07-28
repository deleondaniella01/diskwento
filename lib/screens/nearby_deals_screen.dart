// lib/screens/nearby_deals_screen.dart
import 'package:flutter/material.dart';
import 'package:location/location.dart'; // Import LocationData

class NearbyDealsScreen extends StatelessWidget {
  final LocationData userLocation;

  const NearbyDealsScreen({super.key, required this.userLocation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Deals'),
        backgroundColor: const Color(0xFF5B69E4),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          'Displaying Nearby Deals for Lat: ${userLocation.latitude!.toStringAsFixed(4)}, Lon: ${userLocation.longitude!.toStringAsFixed(4)}',
          style: const TextStyle(fontSize: 20, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
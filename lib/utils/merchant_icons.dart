import 'package:flutter/material.dart';

// Helper function to map merchant_id (or a specific icon field) to IconData
IconData getMerchantIcon(String merchantId) {
  switch (merchantId.toLowerCase()) {
    case 'fastfood':
      return Icons.fastfood;
    case 'restaurant':
      return Icons.local_dining;
    case 'transportation':
      return Icons.local_taxi;
    case 'shopping':
      return Icons.shopping_bag;
    case 'electronics':
      return Icons.devices_other;
    case 'cafe':
      return Icons.local_cafe;
    case 'bank':
      return Icons.account_balance;
    default:
      return Icons.store;
  }
}
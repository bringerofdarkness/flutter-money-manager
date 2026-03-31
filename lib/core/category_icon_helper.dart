import 'package:flutter/material.dart';

IconData getCategoryIcon(String categoryName) {
  switch (categoryName.toLowerCase()) {
    case 'food':
      return Icons.fastfood;
    case 'transport':
      return Icons.directions_bus;
    case 'shopping':
      return Icons.shopping_bag;
    case 'bills':
      return Icons.lightbulb;
    case 'health':
      return Icons.medication;
    case 'education':
      return Icons.menu_book;
    case 'entertainment':
      return Icons.sports_esports;
    default:
      return Icons.category;
  }
}

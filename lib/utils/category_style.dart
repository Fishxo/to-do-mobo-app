import 'package:flutter/material.dart';

/// Icons a user can assign to a category.
const List<IconData> categoryIconOptions = [
  Icons.folder_outlined,
  Icons.work_outline,
  Icons.person_outline,
  Icons.school_outlined,
  Icons.shopping_bag_outlined,
  Icons.favorite_outline,
  Icons.home_outlined,
  Icons.fitness_center,
  Icons.menu_book_outlined,
  Icons.restaurant_outlined,
  Icons.flight_takeoff,
  Icons.attach_money,
  Icons.celebration_outlined,
  Icons.lightbulb_outline,
];

/// Colors a user can assign to a category.
const List<Color> categoryColorOptions = [
  Color(0xFF3F51B5),
  Color(0xFF6750A4),
  Color(0xFF7B5EA7),
  Color(0xFF1E88E5),
  Color(0xFF00897B),
  Color(0xFF43A047),
  Color(0xFFF57C00),
  Color(0xFFEF6C00),
  Color(0xFFE53935),
  Color(0xFFD81B60),
  Color(0xFF6D4C41),
  Color(0xFF546E7A),
];

/// Rebuilds an icon from the integer stored in SQLite.
///
/// Only icons offered by the category editor are stored, so mapping back to
/// the constant [IconData] keeps icon tree-shaking enabled in release builds.
IconData iconFromCodePoint(int codePoint) {
  for (final icon in categoryIconOptions) {
    if (icon.codePoint == codePoint) return icon;
  }
  return Icons.folder_outlined;
}

Color colorFromValue(int value) => Color(value);

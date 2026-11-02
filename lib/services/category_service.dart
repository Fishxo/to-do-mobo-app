import 'package:flutter/material.dart';

import '../models/category.dart';
import '../utils/category_style.dart';
import 'database_service.dart';

/// Owns category validation and default-category creation.
class CategoryService {
  CategoryService({TaskStore? store})
    : _store = store ?? DatabaseService.instance;

  static final CategoryService instance = CategoryService();

  final TaskStore _store;

  Future<List<Category>> getCategories() => _store.getCategories();

  /// Inserts the five starter categories the first time the app runs.
  Future<void> ensureDefaultCategories() async {
    final List<Category> existing = await _store.getCategories();
    if (existing.isNotEmpty) return;

    final DateTime now = DateTime.now();
    final List<Category> defaults = [
      Category(
        id: 0,
        name: 'Work',
        colorValue: categoryColorOptions[0].toARGB32(),
        iconCodePoint: Icons.work_outline.codePoint,
        isDefault: true,
        createdAt: now,
      ),
      Category(
        id: 0,
        name: 'Personal',
        colorValue: categoryColorOptions[2].toARGB32(),
        iconCodePoint: Icons.person_outline.codePoint,
        isDefault: true,
        createdAt: now.add(const Duration(milliseconds: 1)),
      ),
      Category(
        id: 0,
        name: 'Study',
        colorValue: categoryColorOptions[6].toARGB32(),
        iconCodePoint: Icons.school_outlined.codePoint,
        isDefault: true,
        createdAt: now.add(const Duration(milliseconds: 2)),
      ),
      Category(
        id: 0,
        name: 'Shopping',
        colorValue: categoryColorOptions[5].toARGB32(),
        iconCodePoint: Icons.shopping_bag_outlined.codePoint,
        isDefault: true,
        createdAt: now.add(const Duration(milliseconds: 3)),
      ),
      Category(
        id: 0,
        name: 'Health',
        colorValue: categoryColorOptions[8].toARGB32(),
        iconCodePoint: Icons.favorite_outline.codePoint,
        isDefault: true,
        createdAt: now.add(const Duration(milliseconds: 4)),
      ),
    ];

    for (final Category category in defaults) {
      await _store.insertCategory(category);
    }
  }

  Future<Category> addCategory({
    required String name,
    required int colorValue,
    required int iconCodePoint,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Category name cannot be empty');
    }

    return _store.insertCategory(
      Category(
        id: 0,
        name: trimmed,
        colorValue: colorValue,
        iconCodePoint: iconCodePoint,
        isDefault: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> updateCategory({
    required Category category,
    required String name,
    required int colorValue,
    required int iconCodePoint,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Category name cannot be empty');
    }

    await _store.updateCategory(
      category.copyWith(
        name: trimmed,
        colorValue: colorValue,
        iconCodePoint: iconCodePoint,
      ),
    );
  }

  /// Deletes a category. Its tasks are unassigned, never deleted.
  Future<void> deleteCategory(int id) => _store.deleteCategory(id);
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/category_model.dart';
import 'auth_service.dart';
import 'transaction_service.dart';

class CategoryService {
  static const String _categoriesKey = 'categories';

  static final List<CategoryModel> _defaultCategories = [
    CategoryModel(name: 'Food', icon: 'burger'),
    CategoryModel(name: 'Transport', icon: 'bus'),
    CategoryModel(name: 'Shopping', icon: 'shopping'),
    CategoryModel(name: 'Bills', icon: 'bulb'),
    CategoryModel(name: 'Health', icon: 'capsule'),
    CategoryModel(name: 'Education', icon: 'book'),
    CategoryModel(name: 'Entertainment', icon: 'game'),
    CategoryModel(name: 'Other', icon: 'category'),
  ];

  static final List<CategoryModel> _categories = [];
  static bool _isLoaded = false;

  static List<CategoryModel> getCategories() {
    final String? currentUserId = AuthService.currentUserId;

    final categories = _categories
        .where((category) {
      if (currentUserId == null) return false;

      // Keep legacy local categories visible for now until Firestore migration.
      return category.userId == null || category.userId == currentUserId;
    })
        .map((category) => category.userId == currentUserId
        ? category
        : category.copyWith(
      userId: currentUserId,
      createdAt: category.createdAt ?? DateTime.now(),
    ))
        .toList();

    categories.sort((a, b) {
      final aIsDefault = isDefaultCategory(a.name);
      final bIsDefault = isDefaultCategory(b.name);

      if (aIsDefault != bIsDefault) {
        return aIsDefault ? 1 : -1;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return categories;
  }

  static Future<void> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final dynamic rawData = prefs.get(_categoriesKey);

      if (rawData == null) {
        _categories
          ..clear()
          ..addAll(_defaultCategories);
        await saveCategories();
      } else if (rawData is List) {
        _categories
          ..clear()
          ..addAll(
            rawData.map(
                  (item) => CategoryModel.fromMap(
                Map<String, dynamic>.from(jsonDecode(item as String)),
              ),
            ),
          );
        _ensureDefaultCategoriesExist();
        await saveCategories();
      } else if (rawData is String) {
        final decoded = jsonDecode(rawData);

        if (decoded is List) {
          _categories
            ..clear()
            ..addAll(
              decoded.map(
                    (item) => CategoryModel.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              ),
            );
          _ensureDefaultCategoriesExist();
          await saveCategories();
        } else {
          _categories
            ..clear()
            ..addAll(_defaultCategories);
          await saveCategories();
        }
      } else {
        _categories
          ..clear()
          ..addAll(_defaultCategories);
        await saveCategories();
      }
    } catch (e) {
      _categories
        ..clear()
        ..addAll(_defaultCategories);
      await saveCategories();
    }

    _isLoaded = true;
  }

  static Future<void> _ensureLoaded() async {
    if (!_isLoaded) {
      await loadCategories();
    }
  }

  static Future<void> saveCategories() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String> encodedCategories = _categories
        .map((category) => jsonEncode(category.toMap()))
        .toList();

    await prefs.setStringList(_categoriesKey, encodedCategories);
  }

  static void _ensureDefaultCategoriesExist() {
    final String? currentUserId = AuthService.currentUserId;

    for (final defaultCategory in _defaultCategories) {
      final exists = _categories.any(
            (category) =>
        category.name.toLowerCase() ==
            defaultCategory.name.toLowerCase() &&
            (category.userId == currentUserId ||
                category.userId == null ||
                currentUserId == null),
      );

      if (!exists) {
        _categories.add(
          defaultCategory.copyWith(
            userId: currentUserId,
            createdAt: DateTime.now(),
          ),
        );
      }
    }
  }

  static String normalizeCategoryName(String categoryName) {
    final trimmed = categoryName.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) => word[0].toUpperCase() + word.substring(1).toLowerCase(),
    )
        .toList();

    return words.join(' ');
  }

  static bool isDefaultCategory(String categoryName) {
    const defaultCategoryNames = [
      'Food',
      'Transport',
      'Shopping',
      'Bills',
      'Health',
      'Education',
      'Entertainment',
      'Other',
    ];

    return defaultCategoryNames.contains(normalizeCategoryName(categoryName));
  }

  static bool categoryExists(String categoryName) {
    final normalizedName = normalizeCategoryName(categoryName);
    final String? currentUserId = AuthService.currentUserId;

    return _categories.any(
          (category) =>
      category.name.toLowerCase() == normalizedName.toLowerCase() &&
          (category.userId == currentUserId ||
              category.userId == null ||
              currentUserId == null),
    );
  }

  static CategoryModel? getCategoryByName(String categoryName) {
    final normalizedName = normalizeCategoryName(categoryName);
    final String? currentUserId = AuthService.currentUserId;

    try {
      return _categories.firstWhere(
            (category) =>
        category.name.toLowerCase() == normalizedName.toLowerCase() &&
            (category.userId == currentUserId ||
                category.userId == null ||
                currentUserId == null),
      );
    } catch (e) {
      return null;
    }
  }

  static bool isCategoryUsed(String categoryName) {
    final normalizedName = normalizeCategoryName(categoryName);
    final transactions = TransactionService.getTransactions();

    return transactions.any(
          (transaction) =>
      transaction.type == 'Expense' &&
          transaction.categoryOrSource.toLowerCase() ==
              normalizedName.toLowerCase(),
    );
  }

  static Future<bool> addCategory(String categoryName) async {
    await _ensureLoaded();

    final String? currentUserId = AuthService.currentUserId;
    final normalizedName = normalizeCategoryName(categoryName);

    if (normalizedName.isEmpty) {
      return false;
    }

    if (categoryExists(normalizedName)) {
      return false;
    }

    _categories.add(
      CategoryModel(
        name: normalizedName,
        icon: 'category',
        userId: currentUserId,
        createdAt: DateTime.now(),
      ),
    );

    await saveCategories();
    return true;
  }

  static Future<bool> updateCategoryBudget(
      String categoryName,
      double? monthlyBudget,
      ) async {
    await _ensureLoaded();

    final String? currentUserId = AuthService.currentUserId;
    final normalizedName = normalizeCategoryName(categoryName);

    final index = _categories.indexWhere(
          (category) =>
      category.name.toLowerCase() == normalizedName.toLowerCase() &&
          (category.userId == currentUserId ||
              category.userId == null ||
              currentUserId == null),
    );

    if (index == -1) {
      return false;
    }

    _categories[index] = _categories[index].copyWith(
      monthlyBudget: monthlyBudget,
      clearMonthlyBudget: monthlyBudget == null,
      userId: currentUserId ?? _categories[index].userId,
      createdAt: _categories[index].createdAt ?? DateTime.now(),
    );

    await saveCategories();
    return true;
  }

  static Future<bool> deleteCategory(CategoryModel category) async {
    await _ensureLoaded();

    final String? currentUserId = AuthService.currentUserId;

    if (isDefaultCategory(category.name)) {
      return false;
    }

    if (isCategoryUsed(category.name)) {
      return false;
    }

    _categories.removeWhere(
          (item) =>
      item.name.toLowerCase() == category.name.toLowerCase() &&
          (item.userId == currentUserId ||
              item.userId == null ||
              currentUserId == null),
    );

    await saveCategories();
    return true;
  }

  static Future<void> replaceAllCategories(
      List<CategoryModel> newCategories,
      ) async {
    await _ensureLoaded();

    final String? currentUserId = AuthService.currentUserId;

    _categories
      ..clear()
      ..addAll(
        newCategories.map(
              (category) => category.copyWith(
            userId: category.userId ?? currentUserId,
            createdAt: category.createdAt ?? DateTime.now(),
          ),
        ),
      );

    _ensureDefaultCategoriesExist();
    await saveCategories();
  }
}
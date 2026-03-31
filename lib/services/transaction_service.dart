import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction_model.dart';
import 'auth_service.dart';

class TransactionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _transactionsKey = 'transactions';
  static const String _skippedRecurringIdsKey = 'skipped_recurring_ids';

  static final List<TransactionModel> _transactions = [];
  static final List<String> _skippedRecurringIds = [];

  static bool _isLoaded = false;

  static Future<void> replaceAllTransactions(
      List<TransactionModel> newTransactions,
      ) async {
    await _ensureLoaded();

    final String? currentUserId = AuthService.currentUserId;

    _transactions
      ..clear()
      ..addAll(
        newTransactions.map(
              (transaction) => transaction.copyWith(
            userId: transaction.userId ?? currentUserId,
            createdAt: transaction.createdAt ?? DateTime.now(),
          ),
        ),
      );

    _skippedRecurringIds.clear();

    _generateDueRecurringTransactions();
    await saveTransactions();
  }

  static Map<String, double> getMonthlyExpenseByCategory(int year, int month) {
    final Map<String, double> categoryTotals = {};

    for (final transaction in getTransactions()) {
      final bool isSameMonth =
          transaction.date.year == year && transaction.date.month == month;

      if (isSameMonth && transaction.type.toLowerCase() == 'expense') {
        final String category = transaction.categoryOrSource.trim();

        if (categoryTotals.containsKey(category)) {
          categoryTotals[category] =
              categoryTotals[category]! + transaction.amount;
        } else {
          categoryTotals[category] = transaction.amount;
        }
      }
    }

    return categoryTotals;
  }

  static List<TransactionModel> getTransactions() {
    final String? currentUserId = AuthService.currentUserId;

    final List<TransactionModel> copiedList = _transactions
        .where((transaction) {
      if (currentUserId == null) return false;

      return transaction.userId == null ||
          transaction.userId == currentUserId;
    })
        .map(
          (transaction) => transaction.userId == currentUserId
          ? transaction
          : transaction.copyWith(userId: currentUserId),
    )
        .toList();

    copiedList.sort((a, b) => b.date.compareTo(a.date));
    return copiedList;
  }

  static Future<void> loadTransactionsFromFirestore() async {
    final String? userId = AuthService.currentUserId;
    if (userId == null) return;

    final snapshot = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .get();

    _transactions.clear();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      _transactions.add(TransactionModel.fromMap(data));
    }

    _generateDueRecurringTransactions();
    _transactions.sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final dynamic rawData = prefs.get(_transactionsKey);

      if (rawData == null) {
        _transactions.clear();
      } else if (rawData is List) {
        _transactions
          ..clear()
          ..addAll(
            rawData.map(
                  (item) => TransactionModel.fromMap(
                Map<String, dynamic>.from(jsonDecode(item as String)),
              ),
            ),
          );
      } else if (rawData is String) {
        final decoded = jsonDecode(rawData);

        if (decoded is List) {
          _transactions
            ..clear()
            ..addAll(
              decoded.map(
                    (item) => TransactionModel.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              ),
            );

          await saveTransactions();
        } else {
          _transactions.clear();
        }
      } else {
        _transactions.clear();
      }
    } catch (e) {
      _transactions.clear();
    }

    _skippedRecurringIds
      ..clear()
      ..addAll(prefs.getStringList(_skippedRecurringIdsKey) ?? []);

    _generateDueRecurringTransactions();
    await saveTransactions();

    _isLoaded = true;
  }

  static Future<void> _ensureLoaded() async {
    if (!_isLoaded) {
      await loadTransactions();
    }
  }

  static Future<void> saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String> encodedTransactions = _transactions
        .map((transaction) => jsonEncode(transaction.toMap()))
        .toList();

    await prefs.setStringList(_transactionsKey, encodedTransactions);
    await prefs.setStringList(_skippedRecurringIdsKey, _skippedRecurringIds);
  }

  static Future<void> addTransaction(TransactionModel transaction) async {
    await _ensureLoaded();

    final String? currentUserId = AuthService.currentUserId;

    final TransactionModel preparedTransaction = transaction.copyWith(
      userId: currentUserId,
      createdAt: transaction.createdAt ?? DateTime.now(),
    );

    _transactions.removeWhere((item) => item.id == preparedTransaction.id);
    _transactions.add(preparedTransaction);

    await _firestore.collection('transactions').doc(preparedTransaction.id).set({
      ...preparedTransaction.toMap(),
      'userId': currentUserId,
    });

    _generateDueRecurringTransactions();
    await saveTransactions();
  }

  static Future<void> restoreTransaction(TransactionModel transaction) async {
    await _ensureLoaded();

    final String? currentUserId = AuthService.currentUserId;

    final TransactionModel preparedTransaction = transaction.copyWith(
      userId: currentUserId ?? transaction.userId,
      createdAt: transaction.createdAt ?? DateTime.now(),
    );

    final exists = _transactions.any((item) => item.id == preparedTransaction.id);
    if (!exists) {
      _transactions.add(preparedTransaction);
    }

    if (_isGeneratedRecurringId(preparedTransaction.id)) {
      _skippedRecurringIds.remove(preparedTransaction.id);
    }

    if (!_isGeneratedRecurringId(preparedTransaction.id)) {
      await _firestore
          .collection('transactions')
          .doc(preparedTransaction.id)
          .set({
        ...preparedTransaction.toMap(),
        'userId': currentUserId,
      });
    }

    await saveTransactions();
  }

  static Future<void> updateTransaction(
      TransactionModel updatedTransaction,
      ) async {
    await _ensureLoaded();

    final int index = _transactions.indexWhere(
          (transaction) => transaction.id == updatedTransaction.id,
    );

    if (index == -1) return;

    final TransactionModel oldTransaction = _transactions[index];

    final bool wasBaseRecurring =
        !_isGeneratedRecurringId(oldTransaction.id) &&
            _shouldAutoGenerate(oldTransaction);

    _transactions[index] = updatedTransaction;

    if (wasBaseRecurring) {
      _removeGeneratedChildrenForBase(oldTransaction.id);
      _removeSkippedChildrenForBase(oldTransaction.id);
    }

    _generateDueRecurringTransactions();

    if (!_isGeneratedRecurringId(updatedTransaction.id)) {
      await _firestore
          .collection('transactions')
          .doc(updatedTransaction.id)
          .update(updatedTransaction.toMap());
    }

    await saveTransactions();
  }

  static Future<void> deleteTransaction(TransactionModel transaction) async {
    await _ensureLoaded();

    final bool isGeneratedRecurring = _isGeneratedRecurringId(transaction.id);

    if (isGeneratedRecurring) {
      if (!_skippedRecurringIds.contains(transaction.id)) {
        _skippedRecurringIds.add(transaction.id);
      }

      _transactions.removeWhere((item) => item.id == transaction.id);

      await saveTransactions();
      return;
    }

    final bool isBaseRecurring = _shouldAutoGenerate(transaction);

    _transactions.removeWhere((item) => item.id == transaction.id);

    if (isBaseRecurring) {
      _removeGeneratedChildrenForBase(transaction.id);
      _removeSkippedChildrenForBase(transaction.id);
    }

    await _firestore
        .collection('transactions')
        .doc(transaction.id)
        .delete();

    await saveTransactions();
  }

  static double getMonthlyIncome(int year, int month) {
    double total = 0;

    for (final transaction in getTransactions()) {
      final bool isSameMonth =
          transaction.date.year == year && transaction.date.month == month;

      if (!isSameMonth) continue;

      if (transaction.isIncome ||
          transaction.isLoanTaken ||
          transaction.isLoanReceivedBack) {
        total += transaction.amount;
      }
    }

    return total;
  }

  static double getMonthlyExpense(int year, int month) {
    double total = 0;

    for (final transaction in getTransactions()) {
      final bool isSameMonth =
          transaction.date.year == year && transaction.date.month == month;

      if (!isSameMonth) continue;

      if (transaction.isExpense ||
          transaction.isLoanGiven ||
          transaction.isLoanPaidBack) {
        total += transaction.amount;
      }
    }

    return total;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _shouldAutoGenerate(TransactionModel transaction) {
    final String frequency = (transaction.frequency ?? '').trim();

    if (frequency.isEmpty) return false;

    final String lower = frequency.toLowerCase();

    if (lower == 'one time') return false;
    if (lower == 'daily') return true;
    if (lower == 'weekly') return true;
    if (lower == 'monthly') return true;
    if (lower == 'yearly') return true;

    if (lower.startsWith('custom:')) {
      final int? customDays = _parseCustomFrequencyDays(frequency);
      return customDays != null && customDays > 0;
    }

    return false;
  }

  static int? _parseCustomFrequencyDays(String? frequency) {
    if (frequency == null) return null;

    final String normalized = frequency.trim().toLowerCase();
    if (!normalized.startsWith('custom:')) return null;

    final String value = frequency.substring('Custom:'.length).trim();
    final int? days = int.tryParse(value);

    if (days == null || days <= 0) {
      return null;
    }

    return days;
  }

  static DateTime _getNextOccurrenceDate(DateTime date, String? frequency) {
    final String normalized = (frequency ?? '').trim().toLowerCase();
    final DateTime cleanDate = _dateOnly(date);

    switch (normalized) {
      case 'daily':
        return cleanDate.add(const Duration(days: 1));
      case 'weekly':
        return cleanDate.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(cleanDate.year, cleanDate.month + 1, cleanDate.day);
      case 'yearly':
        return DateTime(cleanDate.year + 1, cleanDate.month, cleanDate.day);
      default:
        final int? customDays = _parseCustomFrequencyDays(frequency);
        if (customDays != null) {
          return cleanDate.add(Duration(days: customDays));
        }
        return cleanDate.add(const Duration(days: 100000));
    }
  }

  static bool _isGeneratedRecurringId(String id) {
    return id.contains('__rec__');
  }

  static bool _isGeneratedChildOfBase(String id, String baseId) {
    return id.startsWith('${baseId}__rec__');
  }

  static void _removeGeneratedChildrenForBase(String baseId) {
    _transactions.removeWhere((item) => _isGeneratedChildOfBase(item.id, baseId));
  }

  static void _removeSkippedChildrenForBase(String baseId) {
    _skippedRecurringIds.removeWhere((id) => _isGeneratedChildOfBase(id, baseId));
  }

  static String _buildGeneratedRecurringId(String baseId, DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '${baseId}__rec__${year}${month}${day}';
  }

  static void _generateDueRecurringTransactions() {
    final DateTime today = _dateOnly(DateTime.now());

    final List<TransactionModel> baseTransactions = _transactions.where((item) {
      return !_isGeneratedRecurringId(item.id) && _shouldAutoGenerate(item);
    }).toList();

    for (final base in baseTransactions) {
      DateTime nextDate = _getNextOccurrenceDate(base.date, base.frequency);

      while (!nextDate.isAfter(today)) {
        final String generatedId = _buildGeneratedRecurringId(base.id, nextDate);

        final bool alreadyExists = _transactions.any((item) {
          if (item.id == generatedId) return true;

          return _dateOnly(item.date) == _dateOnly(nextDate) &&
              item.categoryOrSource == base.categoryOrSource &&
              item.type == base.type &&
              item.amount == base.amount;
        });

        final bool isSkipped = _skippedRecurringIds.contains(generatedId);

        if (!alreadyExists && !isSkipped) {
          _transactions.add(
            TransactionModel(
              id: generatedId,
              userId: base.userId,
              type: base.type,
              amount: base.amount,
              categoryOrSource: base.categoryOrSource,
              note: base.note,
              date: nextDate,
              frequency: base.frequency,
              receiptUrl: base.receiptUrl,
              createdAt: base.createdAt,
            ),
          );
        }

        nextDate = _getNextOccurrenceDate(nextDate, base.frequency);
      }
    }
  }
}
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';

class ExportService {
  static Future<String> exportTransactionsToCSV() async {
    final transactions = TransactionService.getTransactions();

    final buffer = StringBuffer();

    buffer.writeln(
      'Date,Type,Category/Person,Amount,Frequency,Note,ReceiptImagePath',
    );

    for (final t in transactions) {
      buffer.writeln(
        '${_escapeCsv(_formatDate(t.date))},'
            '${_escapeCsv(t.type)},'
            '${_escapeCsv(t.categoryOrSource)},'
            '${t.amount},'
            '${_escapeCsv(t.frequency ?? '')},'
            '${_escapeCsv(t.note)},'
            '${_escapeCsv(t.receiptImagePath ?? '')}',
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/transactions.csv');

    await file.writeAsString(buffer.toString());

    return file.path;
  }

  static Future<String> backupAllDataToJson() async {
    final transactions = TransactionService.getTransactions();
    final categories = CategoryService.getCategories();

    final backupData = {
      'backupType': 'money_manager_app_backup',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'categories': categories.map((c) => c.toMap()).toList(),
    };

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/money_manager_backup_$timestamp.json');

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(backupData),
    );

    return file.path;
  }

  static Future<Map<String, dynamic>> restoreAllDataFromJson(
      String filePath,
      ) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception('Backup file not found');
    }

    final jsonString = await file.readAsString();
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid backup file format');
    }

    if (decoded['transactions'] is! List) {
      throw Exception('Backup file does not contain transactions');
    }

    if (decoded['categories'] is! List) {
      throw Exception('Backup file does not contain categories');
    }

    final List transactionsJson = decoded['transactions'] as List;
    final List categoriesJson = decoded['categories'] as List;

    final restoredTransactions = transactionsJson
        .map(
          (item) => TransactionModel.fromMap(
        Map<String, dynamic>.from(item as Map),
      ),
    )
        .toList();

    final restoredCategories = categoriesJson
        .map(
          (item) => CategoryModel.fromMap(
        Map<String, dynamic>.from(item as Map),
      ),
    )
        .toList();

    await TransactionService.replaceAllTransactions(restoredTransactions);
    await CategoryService.replaceAllCategories(restoredCategories);

    return {
      'transactionCount': restoredTransactions.length,
      'categoryCount': restoredCategories.length,
    };
  }

  static String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();

    return '$d/$m/$y';
  }

  static String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
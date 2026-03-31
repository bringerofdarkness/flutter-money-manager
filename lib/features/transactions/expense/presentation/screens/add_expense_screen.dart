
import '../../../../../services/storage_service.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../models/category_model.dart';
import '../../../../../models/transaction_model.dart';
import '../../../../../services/category_service.dart';
import '../../../../../services/transaction_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController customFrequencyController =
  TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  DateTime selectedDate = DateTime.now();
  String? selectedCategory;
  String selectedFrequency = 'One Time';
  String? selectedReceiptImagePath;
  bool isSaving = false;

  final List<String> frequencyOptions = const [
    'One Time',
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
    'Custom',
  ];

  final List<double> quickAmounts = const [100, 500, 1000, 2000, 5000];

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    customFrequencyController.dispose();
    super.dispose();
  }

  List<CategoryModel> get expenseCategories {
    return CategoryService.getCategories();
  }

  Future<void> pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> pickReceiptImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) {
        return;
      }

      setState(() {
        selectedReceiptImagePath = image.path;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
        ),
      );
    }
  }

  void removeReceiptImage() {
    setState(() {
      selectedReceiptImagePath = null;
    });
  }

  void applyQuickAmount(double amount) {
    amountController.text = amount.toStringAsFixed(0);
  }

  String? _getFinalFrequency() {
    if (selectedFrequency == 'One Time') {
      return null;
    }

    if (selectedFrequency != 'Custom') {
      return selectedFrequency;
    }

    final customDays = int.tryParse(customFrequencyController.text.trim());

    if (customDays == null || customDays <= 0) {
      return null;
    }

    return 'Custom:$customDays';
  }

  double _getCategorySpentForMonth({
    required String categoryName,
    required int year,
    required int month,
  }) {
    final transactions = TransactionService.getTransactions();
    double total = 0;

    for (final transaction in transactions) {
      final isSameMonth =
          transaction.date.year == year && transaction.date.month == month;

      final isSameCategory =
          transaction.categoryOrSource.trim().toLowerCase() ==
              categoryName.trim().toLowerCase();

      if (isSameMonth && isSameCategory && transaction.isExpense) {
        total += transaction.amount;
      }
    }

    return total;
  }

  Future<bool> _confirmBudgetOverflow({
    required String categoryName,
    required double amount,
  }) async {
    final category = CategoryService.getCategoryByName(categoryName);

    if (category == null || category.monthlyBudget == null) {
      return true;
    }

    final monthlyBudget = category.monthlyBudget!;
    final currentSpent = _getCategorySpentForMonth(
      categoryName: categoryName,
      year: selectedDate.year,
      month: selectedDate.month,
    );

    final newSpent = currentSpent + amount;

    if (newSpent <= monthlyBudget) {
      return true;
    }

    final overAmount = newSpent - monthlyBudget;

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Budget Warning'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category: $categoryName'),
              const SizedBox(height: 8),
              Text('Monthly budget: ৳ ${monthlyBudget.toStringAsFixed(2)}'),
              Text('Already spent: ৳ ${currentSpent.toStringAsFixed(2)}'),
              Text('This expense: ৳ ${amount.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text(
                'After saving, you will be over budget by ৳ ${overAmount.toStringAsFixed(2)}.',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save Anyway'),
            ),
          ],
        );
      },
    );

    return shouldContinue ?? false;
  }

  Future<void> saveExpense() async {
    final amountText = amountController.text.trim();
    final note = noteController.text.trim();

    if (amountText.isEmpty || selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter amount and select category'),
        ),
      );
      return;
    }

    if (selectedFrequency == 'Custom') {
      final customDays = int.tryParse(customFrequencyController.text.trim());

      if (customDays == null || customDays <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid custom days'),
          ),
        );
        return;
      }
    }

    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
        ),
      );
      return;
    }

    final shouldSave = await _confirmBudgetOverflow(
      categoryName: selectedCategory!,
      amount: amount,
    );

    if (!shouldSave) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
     /* String? uploadedReceiptUrl;

      if (selectedReceiptImagePath != null &&
          selectedReceiptImagePath!.trim().isNotEmpty) {
        uploadedReceiptUrl =
        await StorageService.uploadReceiptImage(selectedReceiptImagePath!);

        if (uploadedReceiptUrl == null) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload receipt image'),
            ),
          );

          setState(() {
            isSaving = false;
          });
          return;
        }
      }*/
      String? uploadedReceiptUrl;
      final transaction = TransactionModel(
        type: 'Expense',
        amount: amount,
        categoryOrSource: selectedCategory!,
        note: note,
        date: selectedDate,
        frequency: _getFinalFrequency(),
        // receiptUrl: uploadedReceiptUrl,
      );

      await TransactionService.addTransaction(transaction);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense saved successfully'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save expense: $e'),
        ),
      );

      setState(() {
        isSaving = false;
      });
    }
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String customFrequencyHelpText() {
    final text = customFrequencyController.text.trim();
    final days = int.tryParse(text);

    if (days == null || days <= 0) {
      return 'Repeat every custom number of days';
    }

    return 'Will repeat every $days day${days == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final categories = expenseCategories;

    if (selectedCategory == null && categories.isNotEmpty) {
      selectedCategory = categories.first.name;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter expense amount',
                border: OutlineInputBorder(),
                prefixText: '৳ ',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickAmounts.map((amount) {
                return ActionChip(
                  label: Text('৳ ${amount.toStringAsFixed(0)}'),
                  onPressed: () => applyQuickAmount(amount),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category.name,
                  child: Text(category.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedFrequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                border: OutlineInputBorder(),
              ),
              items: frequencyOptions.map((frequency) {
                return DropdownMenuItem<String>(
                  value: frequency,
                  child: Text(frequency),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedFrequency = value;
                  if (selectedFrequency != 'Custom') {
                    customFrequencyController.clear();
                  }
                });
              },
            ),
            if (selectedFrequency == 'Custom') ...[
              const SizedBox(height: 16),
              TextField(
                controller: customFrequencyController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (_) {
                  setState(() {});
                },
                decoration: const InputDecoration(
                  labelText: 'Custom Days',
                  hintText: 'Example: 45',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                customFrequencyHelpText(),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'Add note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            /*Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(*\



                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Receipt Image (Optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (selectedReceiptImagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(selectedReceiptImagePath!),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 180,
                            width: double.infinity,
                            alignment: Alignment.center,
                            color: Colors.grey.shade200,
                            child: const Text('Could not preview image'),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickReceiptImage,
                            icon: const Icon(Icons.image),
                            label: const Text('Change Image'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: removeReceiptImage,
                            icon: const Icon(Icons.delete),
                            label: const Text('Remove'),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: pickReceiptImage,
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Attach Receipt Image'),
                      ),
                    ),
                ],
              ),
            ),*/
            const SizedBox(height: 16),
            InkWell(
              onTap: pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade500),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Date: ${formatDate(selectedDate)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const Text(
                      'Pick',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : saveExpense,
                icon: isSaving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.save),
                label: const Text('Save Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
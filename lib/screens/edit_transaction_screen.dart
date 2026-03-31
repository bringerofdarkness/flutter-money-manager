import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';

class EditTransactionScreen extends StatefulWidget {
  final TransactionModel transaction;

  const EditTransactionScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController customFrequencyController =
  TextEditingController();
  final TextEditingController sourceOrPersonController =
  TextEditingController();

  DateTime selectedDate = DateTime.now();
  String? selectedCategoryOrSource;
  String selectedFrequency = 'One Time';
  bool isSaving = false;
  String? selectedReceiptImagePath;
  String? existingReceiptUrl;
  bool removeExistingReceipt = false;

  final ImagePicker _imagePicker = ImagePicker();

  final List<String> frequencyOptions = const [
    'One Time',
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
    'Custom',
  ];

  final List<double> quickAmounts = const [100, 500, 1000, 2000, 5000];

  bool get isExpense => widget.transaction.isExpense;
  bool get isIncome => widget.transaction.isIncome;
  bool get isLoanGiven => widget.transaction.isLoanGiven;
  bool get isLoanTaken => widget.transaction.isLoanTaken;
  bool get isLoanReceivedBack => widget.transaction.isLoanReceivedBack;
  bool get isLoanPaidBack => widget.transaction.isLoanPaidBack;

  String get screenTitle {
    if (isIncome) return 'Edit Income';
    if (isExpense) return 'Edit Expense';
    if (isLoanGiven) return 'Edit Loan Given';
    if (isLoanTaken) return 'Edit Loan Taken';
    if (isLoanReceivedBack) return 'Edit Loan Received Back';
    if (isLoanPaidBack) return 'Edit Loan Paid Back';
    return 'Edit Transaction';
  }

  String get saveButtonText {
    if (isIncome) return 'Update Income';
    if (isExpense) return 'Update Expense';
    if (isLoanGiven) return 'Update Loan Given';
    if (isLoanTaken) return 'Update Loan Taken';
    if (isLoanReceivedBack) return 'Update Loan Received Back';
    if (isLoanPaidBack) return 'Update Loan Paid Back';
    return 'Update Transaction';
  }

  String get categoryLabel {
    if (isIncome) return 'Source';
    if (isExpense) return 'Category';
    return 'Person Name';
  }

  String get categoryHint {
    if (isIncome) return 'Enter income source';
    if (isExpense) return 'Select category';
    return 'Enter person name';
  }

  bool get showFrequencySection => isExpense || isIncome;

  List<CategoryModel> get expenseCategories {
    return CategoryService.getCategories();
  }

  @override
  void initState() {
    super.initState();
    _fillInitialValues();
  }

  void _fillInitialValues() {
    final transaction = widget.transaction;

    amountController.text = transaction.amount % 1 == 0
        ? transaction.amount.toStringAsFixed(0)
        : transaction.amount.toStringAsFixed(2);

    noteController.text = transaction.note;
    selectedDate = transaction.date;
    selectedCategoryOrSource = transaction.categoryOrSource;
    sourceOrPersonController.text = transaction.categoryOrSource;
    selectedReceiptImagePath = null;
    existingReceiptUrl = transaction.receiptUrl;
    removeExistingReceipt = false;

    if (showFrequencySection) {
      final frequency = transaction.frequency?.trim() ?? '';
      final lower = frequency.toLowerCase();

      if (frequency.isEmpty || lower == 'one time') {
        selectedFrequency = 'One Time';
      } else if (lower == 'daily') {
        selectedFrequency = 'Daily';
      } else if (lower == 'weekly') {
        selectedFrequency = 'Weekly';
      } else if (lower == 'monthly') {
        selectedFrequency = 'Monthly';
      } else if (lower == 'yearly') {
        selectedFrequency = 'Yearly';
      } else if (lower.startsWith('custom:')) {
        selectedFrequency = 'Custom';
        customFrequencyController.text =
            frequency.substring('Custom:'.length).trim();
      } else {
        selectedFrequency = 'Custom';
        customFrequencyController.text = '';
      }
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    customFrequencyController.dispose();
    sourceOrPersonController.dispose();
    super.dispose();
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
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        selectedReceiptImagePath = pickedFile.path;
        removeExistingReceipt = false;
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

      if (existingReceiptUrl != null && existingReceiptUrl!.trim().isNotEmpty) {
        removeExistingReceipt = true;
      }
    });
  }

  void applyQuickAmount(double amount) {
    amountController.text = amount.toStringAsFixed(0);
  }

  String? _getFinalFrequency() {
    if (!showFrequencySection) {
      return null;
    }

    if (selectedFrequency == 'One Time') {
      return null;
    }

    if (selectedFrequency != 'Custom') {
      return selectedFrequency;
    }

    final customText = customFrequencyController.text.trim();
    final customDays = int.tryParse(customText);

    if (customDays == null || customDays <= 0) {
      return null;
    }

    return 'Custom:$customDays';
  }

  double _getCategorySpentForMonthExcludingCurrent({
    required String categoryName,
    required int year,
    required int month,
  }) {
    final transactions = TransactionService.getTransactions();
    double total = 0;

    for (final transaction in transactions) {
      if (transaction.id == widget.transaction.id) {
        continue;
      }

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

  Future<bool> _confirmBudgetOverflowIfNeeded({
    required String categoryName,
    required double amount,
  }) async {
    if (!isExpense) {
      return true;
    }

    final category = CategoryService.getCategoryByName(categoryName);

    if (category == null || category.monthlyBudget == null) {
      return true;
    }

    final monthlyBudget = category.monthlyBudget!;
    final currentSpent = _getCategorySpentForMonthExcludingCurrent(
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
              Text(
                'Other expenses this month: ৳ ${currentSpent.toStringAsFixed(2)}',
              ),
              Text('Updated expense: ৳ ${amount.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text(
                'After updating, you will be over budget by ৳ ${overAmount.toStringAsFixed(2)}.',
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
              child: const Text('Update Anyway'),
            ),
          ],
        );
      },
    );

    return shouldContinue ?? false;
  }

  Future<void> saveChanges() async {
    final amountText = amountController.text.trim();
    final note = noteController.text.trim();

    final categoryOrSource = isExpense
        ? (selectedCategoryOrSource?.trim() ?? '')
        : sourceOrPersonController.text.trim();

    if (amountText.isEmpty || categoryOrSource.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isExpense
                ? 'Please enter amount and select category'
                : 'Please enter amount and $categoryLabel',
          ),
        ),
      );
      return;
    }

    if (showFrequencySection && selectedFrequency == 'Custom') {
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

    final shouldContinue = await _confirmBudgetOverflowIfNeeded(
      categoryName: categoryOrSource,
      amount: amount,
    );

    if (!shouldContinue) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      /*String? finalReceiptUrl = existingReceiptUrl;

      final bool hasNewLocalImage = selectedReceiptImagePath != null &&
          selectedReceiptImagePath!.trim().isNotEmpty;

      final bool hadOldRemoteImage =
          existingReceiptUrl != null && existingReceiptUrl!.trim().isNotEmpty;

      if (hasNewLocalImage) {
        final uploadedReceiptUrl =
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

        if (hadOldRemoteImage) {
          await StorageService.deleteReceiptImage(existingReceiptUrl!);
        }

        finalReceiptUrl = uploadedReceiptUrl;
      } else if (removeExistingReceipt) {
        if (hadOldRemoteImage) {
          await StorageService.deleteReceiptImage(existingReceiptUrl!);
        }
        finalReceiptUrl = null;
      }

       */
      String? finalReceiptUrl = widget.transaction.receiptUrl;
      final updatedTransaction = TransactionModel(
        id: widget.transaction.id,
        userId: widget.transaction.userId,
        type: widget.transaction.type,
        amount: amount,
        categoryOrSource: categoryOrSource,
        note: note,
        date: selectedDate,
        frequency: _getFinalFrequency(),
        receiptUrl: finalReceiptUrl,
        createdAt: widget.transaction.createdAt,
      );

      await TransactionService.updateTransaction(updatedTransaction);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction updated successfully'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
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

  Widget buildReceiptPreview() {
    final bool hasNewLocalImage =
        selectedReceiptImagePath != null &&
            selectedReceiptImagePath!.trim().isNotEmpty;

    final bool hasExistingRemoteImage =
        !removeExistingReceipt &&
            existingReceiptUrl != null &&
            existingReceiptUrl!.trim().isNotEmpty;

    if (!hasNewLocalImage && !hasExistingRemoteImage) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.attachment_outlined),
            SizedBox(width: 10),
            Expanded(
              child: Text('No receipt image attached'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attached Receipt',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: hasNewLocalImage
              ? Image.file(
            File(selectedReceiptImagePath!),
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 180,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Could not preview selected image'),
              );
            },
          )
              : Image.network(
            existingReceiptUrl!,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 180,
                width: double.infinity,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 180,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Could not load receipt image'),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = expenseCategories;

    if (isExpense &&
        (selectedCategoryOrSource == null ||
            selectedCategoryOrSource!.isEmpty) &&
        categories.isNotEmpty) {
      selectedCategoryOrSource = categories.first.name;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
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
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter amount',
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
            if (isExpense)
              DropdownButtonFormField<String>(
                value: selectedCategoryOrSource,
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
                    selectedCategoryOrSource = value;
                  });
                },
              )
            else
              TextField(
                controller: sourceOrPersonController,
                decoration: InputDecoration(
                  labelText: categoryLabel,
                  hintText: categoryHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            if (showFrequencySection) ...[
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
            /*const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: pickReceiptImage,
                icon: const Icon(Icons.attach_file),
                label: Text(
                    ((selectedReceiptImagePath != null &&
                        selectedReceiptImagePath!.trim().isNotEmpty) ||
                        (!removeExistingReceipt &&
                            existingReceiptUrl != null &&
                            existingReceiptUrl!.trim().isNotEmpty))
                        ? 'Change Receipt Image'
                        : 'Attach Receipt Image (Optional)'
                ),
              ),
            ),
            const SizedBox(height: 16),
            buildReceiptPreview(),
            if ((selectedReceiptImagePath != null &&
                selectedReceiptImagePath!.trim().isNotEmpty) ||
                (!removeExistingReceipt &&
                    existingReceiptUrl != null &&
                    existingReceiptUrl!.trim().isNotEmpty)) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: removeReceiptImage,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove Receipt Image'),
                ),
              ),
            ],

             */
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : saveChanges,
                icon: isSaving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.save),
                label: Text(saveButtonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../models/transaction_model.dart';
import '../../../../../services/transaction_service.dart';

class AddLoanScreen extends StatefulWidget {
  final String loanType;

  const AddLoanScreen({
    super.key,
    required this.loanType,
  });

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController personController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  bool isSaving = false;
  String? receiptImagePath;

  final ImagePicker _imagePicker = ImagePicker();

  String get normalizedLoanType => widget.loanType.trim().toLowerCase();

  bool get isLoanGiven => normalizedLoanType == 'loan given';
  bool get isLoanTaken => normalizedLoanType == 'loan taken';
  bool get isLoanReceivedBack => normalizedLoanType == 'loan received back';
  bool get isLoanPaidBack => normalizedLoanType == 'loan paid back';

  String get screenTitle {
    if (isLoanGiven) return 'Add Loan Given';
    if (isLoanTaken) return 'Add Loan Taken';
    if (isLoanReceivedBack) return 'Add Loan Received Back';
    if (isLoanPaidBack) return 'Add Loan Paid Back';
    return 'Add Loan';
  }

  String get buttonText {
    if (isLoanGiven) return 'Save Loan Given';
    if (isLoanTaken) return 'Save Loan Taken';
    if (isLoanReceivedBack) return 'Save Loan Received Back';
    if (isLoanPaidBack) return 'Save Loan Paid Back';
    return 'Save Loan';
  }

  String get personLabel {
    if (isLoanGiven) return 'Given To';
    if (isLoanTaken) return 'Taken From';
    if (isLoanReceivedBack) return 'Received Back From';
    if (isLoanPaidBack) return 'Paid Back To';
    return 'Person';
  }

  String get helperText {
    if (isLoanGiven) {
      return 'Track money you gave to someone.';
    }
    if (isLoanTaken) {
      return 'Track money you took from someone.';
    }
    if (isLoanReceivedBack) {
      return 'Track money someone paid back to you.';
    }
    if (isLoanPaidBack) {
      return 'Track money you paid back to someone.';
    }
    return 'Track loan activity.';
  }

  IconData get loanIcon {
    if (isLoanGiven) return Icons.north_east;
    if (isLoanTaken) return Icons.south_west;
    if (isLoanReceivedBack) return Icons.arrow_downward;
    if (isLoanPaidBack) return Icons.arrow_upward;
    return Icons.account_balance_wallet;
  }

  Color get loanColor {
    if (isLoanGiven) return Colors.orange;
    if (isLoanTaken) return Colors.blue;
    if (isLoanReceivedBack) return Colors.green;
    if (isLoanPaidBack) return Colors.purple;
    return Colors.teal;
  }

  @override
  void dispose() {
    amountController.dispose();
    personController.dispose();
    noteController.dispose();
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
        receiptImagePath = pickedFile.path;
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
      receiptImagePath = null;
    });
  }

  double _getOutstandingBalanceForPerson(String personName) {
    final transactions = TransactionService.getTransactions();
    double balance = 0;

    for (final transaction in transactions) {
      final samePerson =
          transaction.categoryOrSource.trim().toLowerCase() ==
              personName.trim().toLowerCase();

      if (!samePerson) continue;

      if (transaction.isLoanGiven) {
        balance += transaction.amount;
      } else if (transaction.isLoanTaken) {
        balance -= transaction.amount;
      } else if (transaction.isLoanReceivedBack) {
        balance -= transaction.amount;
      } else if (transaction.isLoanPaidBack) {
        balance += transaction.amount;
      }
    }

    return balance;
  }

  Future<void> saveLoan() async {
    final String amountText = amountController.text.trim();
    final String personName = personController.text.trim();
    final String note = noteController.text.trim();

    if (amountText.isEmpty || personName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter amount and person name'),
        ),
      );
      return;
    }

    final double? amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
        ),
      );
      return;
    }

    final outstandingBalance = _getOutstandingBalanceForPerson(personName);

    if (isLoanReceivedBack) {
      if (outstandingBalance <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This person does not currently owe you money'),
          ),
        );
        return;
      }

      if (amount > outstandingBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Repayment exceeds outstanding amount. Max allowed: ৳ ${outstandingBalance.toStringAsFixed(2)}',
            ),
          ),
        );
        return;
      }
    }

    if (isLoanPaidBack) {
      final amountYouOwe = outstandingBalance < 0 ? outstandingBalance.abs() : 0;

      if (amountYouOwe <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not currently owe this person money'),
          ),
        );
        return;
      }

      if (amount > amountYouOwe) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Repayment exceeds outstanding amount. Max allowed: ৳ ${amountYouOwe.toStringAsFixed(2)}',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      isSaving = true;
    });

    final transaction = TransactionModel(
      type: widget.loanType,
      amount: amount,
      categoryOrSource: personName,
      note: note,
      date: selectedDate,
      receiptImagePath: receiptImagePath,
    );

    await TransactionService.addTransaction(transaction);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.loanType} saved successfully'),
      ),
    );

    Navigator.pop(context, true);
  }

  String formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String year = date.year.toString();
    return '$day/$month/$year';
  }

  Widget buildReceiptPreview() {
    if (receiptImagePath == null) {
      return const SizedBox.shrink();
    }

    final File imageFile = File(receiptImagePath!);

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
          child: Image.file(
            imageFile,
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
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: pickReceiptImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Change Image'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: removeReceiptImage,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: loanColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: loanColor.withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: loanColor.withOpacity(0.15),
                    child: Icon(loanIcon, color: loanColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      helperText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
            TextField(
              controller: personController,
              decoration: InputDecoration(
                labelText: personLabel,
                hintText: 'Enter person name',
                border: const OutlineInputBorder(),
              ),
            ),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: pickReceiptImage,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  receiptImagePath == null
                      ? 'Attach Receipt Image (Optional)'
                      : 'Receipt Image Selected',
                ),
              ),
            ),
            if (receiptImagePath != null) ...[
              const SizedBox(height: 16),
              buildReceiptPreview(),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : saveLoan,
                icon: isSaving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(loanIcon),
                label: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
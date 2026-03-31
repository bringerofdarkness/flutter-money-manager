import '../../../../../services/storage_service.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../models/transaction_model.dart';
import '../../../../../services/transaction_service.dart';

class AddIncomeScreen extends StatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController sourceController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  String selectedFrequency = 'One Time';
  String? receiptImagePath;

  final ImagePicker _imagePicker = ImagePicker();

  final List<String> frequencyOptions = const [
    'One Time',
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
    'Custom',
  ];

  @override
  void dispose() {
    amountController.dispose();
    sourceController.dispose();
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

  Future<void> saveIncome() async {
    final double? amount = double.tryParse(amountController.text.trim());
    final String source = sourceController.text.trim();
    final String note = noteController.text.trim();

    if (amount == null || amount <= 0 || source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid amount and source'),
        ),
      );
      return;
    }

    /*String? uploadedReceiptUrl;

    if (receiptImagePath != null && receiptImagePath!.trim().isNotEmpty) {
      uploadedReceiptUrl =
      await StorageService.uploadReceiptImage(receiptImagePath!);
    } */

    String? uploadedReceiptUrl;
    final transaction = TransactionModel(
      type: 'Income',
      amount: amount,
      categoryOrSource: source,
      note: note,
      date: selectedDate,
      frequency: selectedFrequency == 'One Time' ? null : selectedFrequency,
      // receiptImagePath: receiptImagePath,
      // receiptUrl: uploadedReceiptUrl,
    );
    await TransactionService.addTransaction(transaction);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Income saved successfully'),
      ),
    );

    amountController.clear();
    sourceController.clear();
    noteController.clear();

    setState(() {
      selectedDate = DateTime.now();
      selectedFrequency = 'One Time';
      receiptImagePath = null;
    });
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
    final String formattedDate =
    selectedDate.toLocal().toString().split(' ')[0];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Add Income'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: sourceController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                ),
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
                  });
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: pickDate,
                  child: Text('Selected Date: $formattedDate'),
                ),
              ),
              const SizedBox(height: 16),
              /*SizedBox(
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
              ), */
            /*  if (receiptImagePath != null) ...[
                const SizedBox(height: 16),
                buildReceiptPreview(),
              ], */
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saveIncome,
                  child: const Text('Save Income'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
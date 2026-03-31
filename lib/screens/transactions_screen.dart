

import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import 'edit_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<TransactionModel> transactions = [];
  String selectedFilter = 'All';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  void loadTransactions() {
    final loadedTransactions = TransactionService.getTransactions();

    setState(() {
      transactions = loadedTransactions;
    });
  }

  Future<void> duplicateTransaction(TransactionModel t) async {
    final duplicate = TransactionModel(
      type: t.type,
      amount: t.amount,
      categoryOrSource: t.categoryOrSource,
      note: t.note,
      date: DateTime.now(),
      frequency: t.frequency,
      receiptUrl: t.receiptUrl,
    );

    await TransactionService.addTransaction(duplicate);

    if (!mounted) return;

    loadTransactions();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction duplicated')),
    );
  }

  Future<void> openEditScreen(TransactionModel transaction) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTransactionScreen(transaction: transaction),
      ),
    );

    if (result == true && mounted) {
      loadTransactions();
    }
  }

  Future<void> deleteTransaction(
      TransactionModel transaction, {
        bool showUndo = true,
      }) async {
    await TransactionService.deleteTransaction(transaction);

    if (!mounted) return;

    loadTransactions();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (showUndo) {
      final messenger = ScaffoldMessenger.of(context);

      messenger.showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              await TransactionService.restoreTransaction(transaction);

              if (!mounted) return;

              loadTransactions();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction restored'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> showDeleteDialog(TransactionModel transaction) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Transaction'),
          content: const Text('Are you sure you want to delete this transaction?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await deleteTransaction(transaction);
    }
  }

  void showReceiptPreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Receipt Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;

                      return const SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        alignment: Alignment.center,
                        color: Colors.grey.shade200,
                        child: const Text('Could not load receipt image'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showTransactionSheet(TransactionModel t) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Wrap(
            runSpacing: 10,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getCardBackgroundColor(t),
                    child: Icon(
                      _getLeadingIcon(t),
                      color: _getAmountColor(t),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.type,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _getAmountColor(t),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _detailRow('Amount', '৳ ${t.amount.toStringAsFixed(2)}'),
              _detailRow('Category / Source', t.categoryOrSource),
              _detailRow('Date', _formatDate(t.date)),
              if (t.frequency != null && t.frequency!.isNotEmpty)
                _detailRow('Frequency', t.frequency!),
              if (t.note.isNotEmpty) _detailRow('Note', t.note),
              _detailRow('Receipt', t.hasReceiptImage ? 'Attached' : 'Not attached'),
              if (t.hasReceiptImage)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      showReceiptPreview(t.receiptUrl!);
                    },
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('View Receipt'),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        openEditScreen(t);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Duplicate'),
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await duplicateTransaction(t);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await showDeleteDialog(t);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 15,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  bool _isRecurringTransaction(TransactionModel t) {
    final freq = t.frequency?.trim().toLowerCase() ?? '';
    return freq.isNotEmpty && freq != 'one time';
  }

  List<TransactionModel> _getFilteredTransactions() {
    List<TransactionModel> filtered = transactions;

    if (selectedFilter == 'Income') {
      filtered = filtered.where((t) => t.isIncome).toList();
    }

    if (selectedFilter == 'Expense') {
      filtered = filtered.where((t) => t.isExpense).toList();
    }

    if (selectedFilter == 'Loans') {
      filtered = filtered.where((t) => t.isLoanRelated).toList();
    }

    if (selectedFilter == 'Recurring') {
      filtered = filtered.where(_isRecurringTransaction).toList();
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        final q = searchQuery.toLowerCase();
        return t.categoryOrSource.toLowerCase().contains(q) ||
            t.note.toLowerCase().contains(q) ||
            t.type.toLowerCase().contains(q) ||
            (t.frequency?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return filtered;
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  Color _getAmountColor(TransactionModel t) {
    if (t.isIncome) return Colors.green;
    if (t.isExpense) return Colors.red;
    if (t.isLoanGiven) return Colors.orange;
    if (t.isLoanTaken) return Colors.blue;
    if (t.isLoanReceivedBack) return Colors.green;
    if (t.isLoanPaidBack) return Colors.purple;
    return Colors.black87;
  }

  Color _getCardBackgroundColor(TransactionModel t) {
    if (t.isIncome) return Colors.green.shade50;
    if (t.isExpense) return Colors.red.shade50;
    if (t.isLoanGiven) return Colors.orange.shade50;
    if (t.isLoanTaken) return Colors.blue.shade50;
    if (t.isLoanReceivedBack) return Colors.green.shade50;
    if (t.isLoanPaidBack) return Colors.purple.shade50;
    return Colors.grey.shade100;
  }

  Color _getBorderColor(TransactionModel t) {
    if (t.isIncome) return Colors.green.shade200;
    if (t.isExpense) return Colors.red.shade200;
    if (t.isLoanGiven) return Colors.orange.shade200;
    if (t.isLoanTaken) return Colors.blue.shade200;
    if (t.isLoanReceivedBack) return Colors.green.shade200;
    if (t.isLoanPaidBack) return Colors.purple.shade200;
    return Colors.grey.shade300;
  }

  IconData _getLeadingIcon(TransactionModel t) {
    if (t.isIncome) return Icons.arrow_downward;
    if (t.isExpense) return Icons.arrow_upward;
    if (t.isLoanGiven) return Icons.north_east;
    if (t.isLoanTaken) return Icons.south_west;
    if (t.isLoanReceivedBack) return Icons.arrow_downward;
    if (t.isLoanPaidBack) return Icons.arrow_upward;
    return Icons.receipt_long;
  }

  Widget _chip(String label) {
    final selected = selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            selectedFilter = label;
          });
        },
      ),
    );
  }

  Widget _buildSwipeBackground({
    required Color color,
    required IconData icon,
    required String label,
    required Alignment alignment,
  }) {
    final isLeft = alignment == Alignment.centerLeft;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment:
        isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: isLeft
            ? [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ]
            : [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: Colors.white),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredTransactions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim();
                });
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _chip('All'),
                _chip('Income'),
                _chip('Expense'),
                _chip('Loans'),
                _chip('Recurring'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No transactions found'))
                : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final t = filtered[index];

                return Dismissible(
                  key: ValueKey(t.id),
                  background: _buildSwipeBackground(
                    color: Colors.green,
                    icon: Icons.edit,
                    label: 'Edit',
                    alignment: Alignment.centerLeft,
                  ),
                  secondaryBackground: _buildSwipeBackground(
                    color: Colors.red,
                    icon: Icons.delete,
                    label: 'Delete',
                    alignment: Alignment.centerRight,
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      await openEditScreen(t);
                      return false;
                    }

                    if (direction == DismissDirection.endToStart) {
                      final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            title: const Text('Delete Transaction'),
                            content: const Text(
                              'Are you sure you want to delete this transaction?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      );

                      if (shouldDelete == true) {
                        await deleteTransaction(t);
                        return true;
                      }

                      return false;
                    }

                    return false;
                  },
                  child: Card(
                    color: _getCardBackgroundColor(t),
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: _getBorderColor(t),
                        width: 1,
                      ),
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      onTap: () => showTransactionSheet(t),
                      onLongPress: () => showDeleteDialog(t),
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(
                          _getLeadingIcon(t),
                          color: _getAmountColor(t),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.categoryOrSource,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (t.hasReceiptImage)
                            const Icon(
                              Icons.attach_file,
                              size: 18,
                              color: Colors.blueGrey,
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            t.frequency != null && t.frequency!.isNotEmpty
                                ? '${t.type} • ${t.frequency}'
                                : t.type,
                          ),
                          Text(_formatDate(t.date)),
                          if (t.note.isNotEmpty) Text(t.note),
                          if (t.hasReceiptImage)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                'Receipt attached',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: Text(
                        '৳ ${t.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getAmountColor(t),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
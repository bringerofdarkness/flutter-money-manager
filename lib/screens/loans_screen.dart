import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';

class LoansScreen extends StatelessWidget {
  const LoansScreen({super.key});

  Map<String, double> calculateLoanBalance() {
    final transactions = TransactionService.getTransactions();
    final Map<String, double> balances = {};

    for (final transaction in transactions) {
      final type = transaction.type.toLowerCase();

      if (type != 'loan given' &&
          type != 'loan taken' &&
          type != 'loan received back' &&
          type != 'loan paid back') {
        continue;
      }

      final person = transaction.categoryOrSource.trim();

      if (person.isEmpty) {
        continue;
      }

      balances.putIfAbsent(person, () => 0);

      if (type == 'loan given') {
        balances[person] = balances[person]! + transaction.amount;
      } else if (type == 'loan taken') {
        balances[person] = balances[person]! - transaction.amount;
      } else if (type == 'loan received back') {
        balances[person] = balances[person]! - transaction.amount;
      } else if (type == 'loan paid back') {
        balances[person] = balances[person]! + transaction.amount;
      }
    }

    balances.removeWhere((key, value) => value.abs() < 0.0001);

    return balances;
  }

  List<TransactionModel> getLoanHistoryForPerson(String personName) {
    final transactions = TransactionService.getTransactions();

    final items = transactions.where((transaction) {
      if (!transaction.isLoanRelated) return false;
      return transaction.categoryOrSource.trim().toLowerCase() ==
          personName.trim().toLowerCase();
    }).toList();

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  void showLoanHistorySheet(BuildContext context, String personName) {
    final history = getLoanHistoryForPerson(personName);

    double runningBalance = 0;
    for (final item in history.reversed) {
      runningBalance += _balanceEffect(item);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.75,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        personName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        runningBalance >= 0
                            ? 'Current balance: They owe you ৳ ${runningBalance.abs().toStringAsFixed(2)} remaining'
                            : 'Current balance: You owe them ৳ ${runningBalance.abs().toStringAsFixed(2)} remaining',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: runningBalance >= 0
                              ? Colors.orange
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: history.isEmpty
                      ? const Center(
                    child: Text(
                      'No loan history found',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                      : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final transaction = history[index];
                      final effect = _balanceEffect(transaction);
                      final isPositiveForYou = effect > 0;

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _typeColor(transaction.type)
                                .withOpacity(0.12),
                            child: Icon(
                              _typeIcon(transaction.type),
                              color: _typeColor(transaction.type),
                            ),
                          ),
                          title: Text(
                            transaction.type,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(_formatDate(transaction.date)),
                              if (transaction.note.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(transaction.note.trim()),
                              ],
                            ],
                          ),
                          trailing: Text(
                            '${isPositiveForYou ? '+' : '-'}৳ ${transaction.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPositiveForYou
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                          ),
                        ),
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

  static double _balanceEffect(TransactionModel transaction) {
    final type = transaction.type.toLowerCase();

    if (type == 'loan given') return transaction.amount;
    if (type == 'loan taken') return -transaction.amount;
    if (type == 'loan received back') return -transaction.amount;
    if (type == 'loan paid back') return transaction.amount;

    return 0;
  }

  static IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'loan given':
        return Icons.north_east;
      case 'loan taken':
        return Icons.south_west;
      case 'loan received back':
        return Icons.arrow_downward;
      case 'loan paid back':
        return Icons.arrow_upward;
      default:
        return Icons.account_balance_wallet;
    }
  }

  static Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'loan given':
        return Colors.orange;
      case 'loan taken':
        return Colors.blue;
      case 'loan received back':
        return Colors.green;
      case 'loan paid back':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final balances = calculateLoanBalance();

    final entries = balances.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    double totalGiven = 0;
    double totalTaken = 0;

    for (final entry in entries) {
      if (entry.value > 0) {
        totalGiven += entry.value;
      } else {
        totalTaken += entry.value.abs();
      }
    }

    final netBalance = totalGiven - totalTaken;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans'),
      ),
      body: entries.isEmpty
          ? const Center(
        child: Text(
          'No active loans found',
          style: TextStyle(fontSize: 16),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryRow('You Gave', totalGiven, Colors.orange),
                  const SizedBox(height: 10),
                  _summaryRow('You Took', totalTaken, Colors.blue),
                  const Divider(height: 24),
                  _summaryRow(
                    'Net Loan Balance',
                    netBalance.abs(),
                    netBalance >= 0 ? Colors.green : Colors.red,
                    prefix: netBalance >= 0 ? '+' : '-',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'People',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...entries.map((entry) {
            final amount = entry.value;
            final isYouGave = amount > 0;

            return Card(
              child: ListTile(
                onTap: () => showLoanHistorySheet(context, entry.key),
                leading: CircleAvatar(
                  backgroundColor: isYouGave
                      ? Colors.orange.shade100
                      : Colors.blue.shade100,
                  child: Icon(
                    isYouGave ? Icons.north_east : Icons.south_west,
                    color: isYouGave ? Colors.orange : Colors.blue,
                  ),
                ),
                title: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isYouGave
                      ? 'They owe you • ৳ ${amount.abs().toStringAsFixed(2)} remaining • Tap for history'
                      : 'You owe them • ৳ ${amount.abs().toStringAsFixed(2)} remaining • Tap for history',
                ),
                trailing: Text(
                  '৳ ${amount.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isYouGave ? Colors.orange : Colors.blue,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _summaryRow(
      String title,
      double value,
      Color color, {
        String prefix = '',
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Text(
          '$prefix৳ ${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
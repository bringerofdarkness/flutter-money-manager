import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../widgets/section_title.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  String selectedRangeType = 'This Month';
  late DateTime startDate;
  late DateTime endDate;
  int touchedIndex = -1;

  final List<Color> chartColors = const [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.brown,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, 1);
    endDate = DateTime(now.year, now.month + 1, 0);
  }

  List<TransactionModel> _getTransactionsInRange({
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) {
    final transactions = TransactionService.getTransactions();
    final start = rangeStart ?? startDate;
    final end = rangeEnd ?? endDate;

    return transactions.where((transaction) {
      final transactionDate = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      final normalizedStart = DateTime(start.year, start.month, start.day);
      final normalizedEnd = DateTime(end.year, end.month, end.day);

      return !transactionDate.isBefore(normalizedStart) &&
          !transactionDate.isAfter(normalizedEnd);
    }).toList();
  }

  double _getIncomeFromRange(List<TransactionModel> transactions) {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction.isIncome ||
          transaction.isLoanTaken ||
          transaction.isLoanReceivedBack) {
        total += transaction.amount;
      }
    }

    return total;
  }

  double _getExpenseFromRange(List<TransactionModel> transactions) {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction.isExpense ||
          transaction.isLoanGiven ||
          transaction.isLoanPaidBack) {
        total += transaction.amount;
      }
    }

    return total;
  }

  double _getBalanceFromRange(List<TransactionModel> transactions) {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction.isIncome) {
        total += transaction.amount;
      } else if (transaction.isExpense) {
        total -= transaction.amount;
      } else if (transaction.isLoanTaken) {
        total += transaction.amount;
      } else if (transaction.isLoanGiven) {
        total -= transaction.amount;
      } else if (transaction.isLoanReceivedBack) {
        total += transaction.amount;
      } else if (transaction.isLoanPaidBack) {
        total -= transaction.amount;
      }
    }

    return total;
  }

  Map<String, double> _getExpenseByCategoryFromRange(
      List<TransactionModel> transactions,
      ) {
    final Map<String, double> categoryTotals = {};

    for (final transaction in transactions) {
      if (!transaction.isExpense) {
        continue;
      }

      final category = transaction.categoryOrSource.trim();

      if (categoryTotals.containsKey(category)) {
        categoryTotals[category] = categoryTotals[category]! + transaction.amount;
      } else {
        categoryTotals[category] = transaction.amount;
      }
    }

    return categoryTotals;
  }

  int _getRangeDayCount() {
    return endDate.difference(startDate).inDays + 1;
  }

  double _getAverageExpensePerDay(double totalExpense) {
    final days = _getRangeDayCount();
    if (days <= 0) return 0;
    return totalExpense / days;
  }

  String _getTopExpenseCategory(Map<String, double> expenseByCategory) {
    if (expenseByCategory.isEmpty) {
      return 'No expense category';
    }

    final sorted = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  double _getTopExpenseCategoryAmount(Map<String, double> expenseByCategory) {
    if (expenseByCategory.isEmpty) {
      return 0;
    }

    final sorted = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.value;
  }

  DateTime _getPreviousRangeStart() {
    final dayCount = _getRangeDayCount();
    return startDate.subtract(Duration(days: dayCount));
  }

  DateTime _getPreviousRangeEnd() {
    return startDate.subtract(const Duration(days: 1));
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        startDate = picked;

        if (endDate.isBefore(startDate)) {
          endDate = startDate;
        }

        touchedIndex = -1;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        endDate = picked;

        if (endDate.isBefore(startDate)) {
          startDate = endDate;
        }

        touchedIndex = -1;
      });
    }
  }

  void _applyQuickRange(String rangeType) {
    final now = DateTime.now();

    setState(() {
      selectedRangeType = rangeType;
      touchedIndex = -1;

      if (rangeType == 'Today') {
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day);
      } else if (rangeType == 'This Week') {
        final weekday = now.weekday;
        final weekStart = now.subtract(Duration(days: weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));

        startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
        endDate = DateTime(weekEnd.year, weekEnd.month, weekEnd.day);
      } else if (rangeType == 'This Month') {
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
      }
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _getRangeLabel() {
    return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
  }

  Widget _buildInsightTile({
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rangeTransactions = _getTransactionsInRange();
    final income = _getIncomeFromRange(rangeTransactions);
    final expense = _getExpenseFromRange(rangeTransactions);
    final balance = _getBalanceFromRange(rangeTransactions);
    final expenseByCategory = _getExpenseByCategoryFromRange(rangeTransactions);

    final sortedEntries = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxBarValue = income > expense ? income : expense;
    final double chartMaxY =
    maxBarValue == 0 ? 100.0 : (maxBarValue * 1.25).toDouble();

    final transactionCount = rangeTransactions.length;
    final averageExpensePerDay = _getAverageExpensePerDay(expense);
    final topCategory = _getTopExpenseCategory(expenseByCategory);
    final topCategoryAmount = _getTopExpenseCategoryAmount(expenseByCategory);

    final previousStart = _getPreviousRangeStart();
    final previousEnd = _getPreviousRangeEnd();
    final previousTransactions = _getTransactionsInRange(
      rangeStart: previousStart,
      rangeEnd: previousEnd,
    );
    final previousExpense = _getExpenseFromRange(previousTransactions);
    final expenseDifference = expense - previousExpense;
    final isIncrease = expenseDifference > 0;
    final isDecrease = expenseDifference < 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(title: 'Select Range'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Today'),
                  selected: selectedRangeType == 'Today',
                  onSelected: (_) => _applyQuickRange('Today'),
                ),
                ChoiceChip(
                  label: const Text('This Week'),
                  selected: selectedRangeType == 'This Week',
                  onSelected: (_) => _applyQuickRange('This Week'),
                ),
                ChoiceChip(
                  label: const Text('This Month'),
                  selected: selectedRangeType == 'This Month',
                  onSelected: (_) => _applyQuickRange('This Month'),
                ),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: selectedRangeType == 'Custom',
                  onSelected: (_) {
                    setState(() {
                      selectedRangeType = 'Custom';
                      touchedIndex = -1;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Range: ${_getRangeLabel()}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            setState(() {
                              selectedRangeType = 'Custom';
                            });
                            await _pickStartDate();
                          },
                          icon: const Icon(Icons.date_range),
                          label: const Text('Start Date'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            setState(() {
                              selectedRangeType = 'Custom';
                            });
                            await _pickEndDate();
                          },
                          icon: const Icon(Icons.event),
                          label: const Text('End Date'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Summary'),
            const SizedBox(height: 12),
            _buildSummaryCard(
              title: 'Total Income',
              amount: income,
              amountColor: Colors.green,
              icon: Icons.arrow_downward,
              iconColor: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(
              title: 'Total Expense',
              amount: expense,
              amountColor: Colors.red,
              icon: Icons.arrow_upward,
              iconColor: Colors.red,
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(
              title: 'Balance',
              amount: balance,
              amountColor: balance >= 0 ? Colors.blue : Colors.red,
              icon: Icons.account_balance_wallet,
              iconColor: balance >= 0 ? Colors.blue : Colors.red,
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Insights'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInsightTile(
                    title: 'Transactions',
                    value: transactionCount.toString(),
                    valueColor: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInsightTile(
                    title: 'Avg Expense / Day',
                    value: '৳ ${averageExpensePerDay.toStringAsFixed(2)}',
                    valueColor: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInsightTile(
              title: 'Top Expense Category',
              value: topCategoryAmount > 0
                  ? '$topCategory • ৳ ${topCategoryAmount.toStringAsFixed(2)}'
                  : topCategory,
              valueColor: Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildInsightTile(
              title: 'Expense vs Previous Period',
              value:
              'Previous: ৳ ${previousExpense.toStringAsFixed(2)} • ${isIncrease ? 'Increased' : isDecrease ? 'Decreased' : 'No change'} ${expenseDifference.abs().toStringAsFixed(2)}',
              valueColor: isIncrease
                  ? Colors.red
                  : isDecrease
                  ? Colors.green
                  : Colors.blue,
            ),
            const SizedBox(height: 8),
            Text(
              'Compared with ${_formatDate(previousStart)} - ${_formatDate(previousEnd)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Income vs Expense'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 240,
                    child: BarChart(
                      BarChartData(
                        maxY: chartMaxY,
                        alignment: BarChartAlignment.spaceAround,
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 52,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                switch (value.toInt()) {
                                  case 0:
                                    return const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Income',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  case 1:
                                    return const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Expense',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  default:
                                    return const SizedBox.shrink();
                                }
                              },
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final label = group.x == 0 ? 'Income' : 'Expense';
                              return BarTooltipItem(
                                '$label\n৳ ${rod.toY.toStringAsFixed(2)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: income,
                                color: Colors.green,
                                width: 36,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 1,
                            barRods: [
                              BarChartRodData(
                                toY: expense,
                                color: Colors.red,
                                width: 36,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildLegendItem(
                        color: Colors.green,
                        label: 'Income',
                        amount: income,
                      ),
                      const SizedBox(width: 16),
                      _buildLegendItem(
                        color: Colors.red,
                        label: 'Expense',
                        amount: expense,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Expense by Category'),
            const SizedBox(height: 12),
            if (sortedEntries.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No expense data for this selected range.',
                  style: TextStyle(fontSize: 16),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 240,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  touchedIndex = -1;
                                  return;
                                }
                                touchedIndex = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: _buildPieSections(sortedEntries, expense),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      children: List.generate(sortedEntries.length, (index) {
                        final entry = sortedEntries[index];
                        final color = chartColors[index % chartColors.length];
                        final percent =
                        expense == 0 ? 0 : (entry.value / expense) * 100;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${percent.toStringAsFixed(1)}%  •  ৳ ${entry.value.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
      List<MapEntry<String, double>> entries,
      double totalExpense,
      ) {
    return List.generate(entries.length, (index) {
      final isTouched = index == touchedIndex;
      final entry = entries[index];
      final color = chartColors[index % chartColors.length];
      final percent =
      totalExpense == 0 ? 0.0 : (entry.value / totalExpense) * 100;

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${percent.toStringAsFixed(0)}%',
        radius: isTouched ? 70 : 60,
        titleStyle: TextStyle(
          fontSize: isTouched ? 16 : 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required Color amountColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.12),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '৳ ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required double amount,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ৳ ${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
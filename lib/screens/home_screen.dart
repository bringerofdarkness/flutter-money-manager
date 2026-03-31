import '../services/auth_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/app_spacing.dart';
import '../widgets/buttons/primary_action_button.dart';
import '../widgets/balance_summary_card.dart';
import '../widgets/section_title.dart';
import '../features/transactions/income/presentation/screens/add_income_screen.dart';
import '../features/transactions/expense/presentation/screens/add_expense_screen.dart';
import '../features/transactions/loan/presentation/screens/add_loan_screen.dart';
import '../services/transaction_service.dart';
import '../services/export_service.dart';
import '../services/category_service.dart';
import 'transactions_screen.dart';
import 'categories_screen.dart';
import 'monthly_report_screen.dart';
import 'loans_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double totalIncome = 0;
  double totalExpense = 0;
  double balance = 0;
  double totalBudget = 0;
  double currentMonthSpent = 0;
  double remainingBudget = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshHomeData();
  }

  void refreshHomeData() {
    final transactions = TransactionService.getTransactions();
    final categories = CategoryService.getCategories();
    final now = DateTime.now();

    double income = 0;
    double expense = 0;
    double monthlyBudget = 0;

    for (final transaction in transactions) {
      final type = transaction.type.toLowerCase();

      if (type == 'income' ||
          type == 'loan taken' ||
          type == 'loan received back') {
        income += transaction.amount;
      }

      if (type == 'expense' ||
          type == 'loan given' ||
          type == 'loan paid back') {
        expense += transaction.amount;
      }
    }

    for (final category in categories) {
      if (category.monthlyBudget != null) {
        monthlyBudget += category.monthlyBudget!;
      }
    }

    final monthSpent = TransactionService.getMonthlyExpense(now.year, now.month);

    setState(() {
      totalIncome = income;
      totalExpense = expense;
      balance = income - expense;
      totalBudget = monthlyBudget;
      currentMonthSpent = monthSpent;
      remainingBudget = monthlyBudget - monthSpent;
      isLoading = false;
    });
  }

  Future<void> openScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => screen,
      ),
    );

    if (!mounted) return;

    refreshHomeData();
  }

  Future<void> exportTransactions() async {
    try {
      final filePath = await ExportService.exportTransactionsToCSV();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV exported successfully:\n$filePath'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
        ),
      );
    }
  }

  Future<void> backupData() async {
    try {
      final filePath = await ExportService.backupAllDataToJson();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup created successfully:\n$filePath'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $e'),
        ),
      );
    }
  }

  Future<void> restoreData() async {
    try {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Restore Backup'),
            content: const Text(
              'Restoring backup will replace your current transactions and categories. Do you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Restore'),
              ),
            ],
          );
        },
      );

      if (shouldContinue != true) {
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No backup file selected'),
          ),
        );
        return;
      }

      final filePath = result.files.single.path;

      if (filePath == null || filePath.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected file path is invalid'),
          ),
        );
        return;
      }

      final restoreResult = await ExportService.restoreAllDataFromJson(filePath);

      if (!mounted) return;

      refreshHomeData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restore successful: '
                '${restoreResult['transactionCount']} transactions, '
                '${restoreResult['categoryCount']} categories',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String formatCurrency(double amount) {
    return '৳ ${amount.toStringAsFixed(2)}';
  }

  Widget buildBudgetOverviewCard({
    required double totalBudget,
    required double spent,
    required double remaining,
  }) {
    final hasBudget = totalBudget > 0;
    final isOverBudget = remaining < 0;
    final progress = hasBudget ? (spent / totalBudget).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This Month Budget',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (!hasBudget)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No category budgets set yet.',
                ),
              )
            else ...[
              Text('Total Budget: ${formatCurrency(totalBudget)}'),
              Text('Spent: ${formatCurrency(spent)}'),
              Text(
                isOverBudget
                    ? 'Over Budget: ${formatCurrency(remaining.abs())}'
                    : 'Remaining: ${formatCurrency(remaining)}',
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.signOut();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle(title: 'Overview'),
              const SizedBox(height: AppSpacing.smallGap),
              BalanceSummaryCard(
                balance: balance,
                totalIncome: totalIncome,
                totalExpense: totalExpense,
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const SectionTitle(title: 'Budget Overview'),
              const SizedBox(height: AppSpacing.smallGap),
              buildBudgetOverviewCard(
                totalBudget: totalBudget,
                spent: currentMonthSpent,
                remaining: remainingBudget,
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const SectionTitle(title: 'Actions'),
              const SizedBox(height: AppSpacing.smallGap),
              PrimaryActionButton(
                label: 'Add Income',
                icon: Icons.arrow_downward,
                onPressed: () async {
                  await openScreen(const AddIncomeScreen());
                },
              ),
              const SizedBox(height: AppSpacing.itemGap),
              PrimaryActionButton(
                label: 'Add Expense',
                icon: Icons.arrow_upward,
                onPressed: () async {
                  await openScreen(const AddExpenseScreen());
                },
              ),
              const SizedBox(height: AppSpacing.itemGap),
              PrimaryActionButton(
                label: 'Loan Given',
                icon: Icons.north_east,
                onPressed: () async {
                  await openScreen(
                    const AddLoanScreen(loanType: 'Loan Given'),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.itemGap),
              PrimaryActionButton(
                label: 'Loan Taken',
                icon: Icons.south_west,
                onPressed: () async {
                  await openScreen(
                    const AddLoanScreen(loanType: 'Loan Taken'),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.itemGap),
              PrimaryActionButton(
                label: 'View Transactions',
                icon: Icons.list,
                onPressed: () async {
                  await openScreen(const TransactionsScreen());
                },
              ),
              const SizedBox(height: AppSpacing.itemGap),
              PrimaryActionButton(
                label: 'Categories',
                icon: Icons.category,
                onPressed: () async {
                  await openScreen(const CategoriesScreen());
                },
              ),
              const SizedBox(height: AppSpacing.itemGap),
              PrimaryActionButton(
                label: 'Monthly Report',
                icon: Icons.bar_chart,
                onPressed: () async {
                  await openScreen(const MonthlyReportScreen());
                },
              ),
              const SizedBox(height: AppSpacing.itemGap),
              PrimaryActionButton(
                label: 'Loans Overview',
                icon: Icons.account_balance_wallet,
                onPressed: () async {
                  await openScreen(const LoansScreen());
                },
              ),
              const SizedBox(height: AppSpacing.itemGap),
              PrimaryActionButton(
                label: 'Export CSV',
                icon: Icons.file_download,
                onPressed: () async {
                  await exportTransactions();
                },
              ),
              const SizedBox(height: AppSpacing.itemGap),
              PrimaryActionButton(
                label: 'Backup Data',
                icon: Icons.backup,
                onPressed: () async {
                  await backupData();
                },
              ),
              const SizedBox(height: AppSpacing.itemGap),
              PrimaryActionButton(
                label: 'Restore Data',
                icon: Icons.restore,
                onPressed: () async {
                  await restoreData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
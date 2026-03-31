import 'package:flutter/material.dart';
import '../core/category_icon_helper.dart';
import '../models/category_model.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  Future<void> showAddCategoryDialog() async {
    final TextEditingController categoryNameController =
    TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: TextField(
            controller: categoryNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Enter category name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final rawName = categoryNameController.text;
                final normalizedName =
                CategoryService.normalizeCategoryName(rawName);

                if (normalizedName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category name cannot be empty'),
                    ),
                  );
                  return;
                }

                if (CategoryService.categoryExists(normalizedName)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category already exists'),
                    ),
                  );
                  return;
                }

                final added = await CategoryService.addCategory(normalizedName);

                if (!mounted) return;

                if (added) {
                  Navigator.pop(dialogContext);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$normalizedName added successfully'),
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> showDeleteCategoryDialog(CategoryModel category) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Category'),
          content: Text('Are you sure you want to delete "${category.name}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final deleted = await CategoryService.deleteCategory(category);

                if (!mounted) return;

                Navigator.pop(dialogContext);

                if (deleted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category deleted successfully'),
                    ),
                  );
                } else {
                  String message = 'Category cannot be deleted';

                  if (CategoryService.isDefaultCategory(category.name)) {
                    message = 'Default categories cannot be deleted';
                  } else if (CategoryService.isCategoryUsed(category.name)) {
                    message =
                    'This category is used in expenses and cannot be deleted';
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> showBudgetDialog(CategoryModel category) async {
    final TextEditingController budgetController = TextEditingController(
      text: category.monthlyBudget == null
          ? ''
          : category.monthlyBudget!.toStringAsFixed(
        category.monthlyBudget! % 1 == 0 ? 0 : 2,
      ),
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Set Budget - ${category.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: budgetController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monthly Budget',
                  hintText: 'Enter amount',
                  border: OutlineInputBorder(),
                  prefixText: '৳ ',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Leave empty to remove budget for this category.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final updated = await CategoryService.updateCategoryBudget(
                  category.name,
                  null,
                );

                if (!mounted) return;

                Navigator.pop(dialogContext);

                if (updated) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${category.name} budget removed'),
                    ),
                  );
                }
              },
              child: const Text('Remove'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = budgetController.text.trim();

                if (text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a budget or press Remove'),
                    ),
                  );
                  return;
                }

                final amount = double.tryParse(text);

                if (amount == null || amount < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid budget amount'),
                    ),
                  );
                  return;
                }

                final updated = await CategoryService.updateCategoryBudget(
                  category.name,
                  amount,
                );

                if (!mounted) return;

                Navigator.pop(dialogContext);

                if (updated) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${category.name} budget updated'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  double getSpentForCurrentMonth(String categoryName) {
    final now = DateTime.now();
    final expenseMap =
    TransactionService.getMonthlyExpenseByCategory(now.year, now.month);

    return expenseMap[categoryName] ?? 0;
  }

  String formatCurrency(double amount) {
    return '৳ ${amount.toStringAsFixed(2)}';
  }

  Color getBudgetStatusColor(double spent, double budget) {
    if (budget <= 0) {
      return Colors.grey;
    }

    final ratio = spent / budget;

    if (ratio > 1) {
      return Colors.red;
    }

    if (ratio >= 0.8) {
      return Colors.orange;
    }

    return Colors.green;
  }

  String getBudgetStatusLabel(double spent, double budget) {
    if (budget <= 0) {
      return 'No budget';
    }

    final ratio = spent / budget;

    if (ratio > 1) {
      return 'Over budget';
    }

    if (ratio >= 0.8) {
      return 'Near limit';
    }

    return 'Safe';
  }

  Widget buildBudgetStatus(CategoryModel category) {
    final spent = getSpentForCurrentMonth(category.name);
    final budget = category.monthlyBudget;

    if (budget == null) {
      return const Text(
        'No monthly budget set',
        style: TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final remaining = budget - spent;
    final progress = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    final isOverBudget = spent > budget;
    final statusColor = getBudgetStatusColor(spent, budget);
    final statusLabel = getBudgetStatusLabel(spent, budget);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Budget: ${formatCurrency(budget)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withOpacity(0.35),
                ),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Spent this month: ${formatCurrency(spent)}'),
        const SizedBox(height: 4),
        Text(
          isOverBudget
              ? 'Over budget: ${formatCurrency(spent - budget)}'
              : 'Remaining: ${formatCurrency(remaining)}',
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(20),
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
        ),
      ],
    );
  }

  Widget buildCategoryTile(CategoryModel category, {required bool isDefault}) {
    final hasBudget = category.monthlyBudget != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(getCategoryIcon(category.name)),
          ),
          title: Text(category.name),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: buildBudgetStatus(category),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Set Budget',
                onPressed: () => showBudgetDialog(category),
                icon: Icon(
                  hasBudget
                      ? Icons.account_balance_wallet
                      : Icons.account_balance_wallet_outlined,
                  color: Colors.blue,
                ),
              ),
              if (isDefault)
                const Icon(Icons.lock_outline)
              else
                IconButton(
                  tooltip: 'Delete Category',
                  onPressed: () {
                    showDeleteCategoryDialog(category);
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<CategoryModel> categories = CategoryService.getCategories();

    final customCategories = categories
        .where((category) => !CategoryService.isDefaultCategory(category.name))
        .toList();

    final defaultCategories = categories
        .where((category) => CategoryService.isDefaultCategory(category.name))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories & Budgets'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddCategoryDialog,
        child: const Icon(Icons.add),
      ),
      body: categories.isEmpty
          ? const Center(
        child: Text('No categories available'),
      )
          : Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Tap the wallet icon to set a monthly budget for a category. Green means safe, orange means near limit, red means over budget.',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Custom Categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (customCategories.isEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'No custom categories yet. Tap + to add one.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...customCategories.map(
                        (category) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: buildCategoryTile(
                        category,
                        isDefault: false,
                      ),
                    ),
                  ),
                if (defaultCategories.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      'Default Categories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...defaultCategories.map(
                        (category) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: buildCategoryTile(
                        category,
                        isDefault: true,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
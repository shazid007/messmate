import 'package:flutter/material.dart';
import '../data/hive_helper.dart';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  List<Map<String, dynamic>> expenses = [];
  List<Map<String, dynamic>> members = [];
  String currentUser = '';

  final List<String> categories = [
    'Bazaar',
    'Gas',
    'Electricity',
    'Water',
    'Bua',
    'Internet',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      expenses = HiveHelper.getExpenses();
      members = HiveHelper.getMembers();
      currentUser = HiveHelper.getCurrentUser();
    });
  }

  bool _isAdmin() {
    for (final member in members) {
      final name = member['name']?.toString() ?? '';
      final role = member['role']?.toString().toLowerCase().trim() ?? '';

      if (name == currentUser && role == 'admin') {
        return true;
      }
    }
    return false;
  }

  bool _canEditExpense(Map<String, dynamic> expense) {
    if (_isAdmin()) return true;

    final paidBy = expense['paidBy'];

    if (paidBy is List) {
      return paidBy.map((e) => e.toString()).contains(currentUser);
    }

    return paidBy?.toString() == currentUser;
  }

  String _formatDate(dynamic rawDate) {
    final date = DateTime.tryParse(rawDate?.toString() ?? '');
    if (date == null) return 'No date';

    const monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${monthNames[date.month]} ${date.year}';
  }

  String _paidByText(dynamic paidBy) {
    if (paidBy is List) {
      return paidBy.join(', ');
    }
    return paidBy?.toString() ?? '';
  }

  Future<void> _deleteExpense(int index) async {
    final expense = expenses[index];

    if (!_canEditExpense(expense)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only delete your own expense entry'),
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Expense'),
          content: const Text('Are you sure you want to delete this expense?'),
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

    if (result == true) {
      await HiveHelper.deleteExpense(index);
      _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted')),
      );
    }
  }

  Future<void> _editExpenseDialog(
    int index,
    Map<String, dynamic> expense,
  ) async {
    if (!_canEditExpense(expense)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only edit your own expense entry'),
        ),
      );
      return;
    }

    final titleController =
        TextEditingController(text: expense['title']?.toString() ?? '');
    final amountController =
        TextEditingController(text: expense['amount']?.toString() ?? '');

    String selectedCategory = expense['category']?.toString() ?? 'Bazaar';
    DateTime selectedDate =
        DateTime.tryParse(expense['date']?.toString() ?? '') ?? DateTime.now();

    List<String> selectedPaidByMembers = [];
    final existingPaidBy = expense['paidBy'];

    if (existingPaidBy is List) {
      selectedPaidByMembers = existingPaidBy.map((e) => e.toString()).toList();
    } else if (existingPaidBy != null &&
        existingPaidBy.toString().trim().isNotEmpty) {
      selectedPaidByMembers = [existingPaidBy.toString()];
    }

    if (!_isAdmin()) {
      selectedPaidByMembers = [currentUser];
    }

    Future<void> pickDate(StateSetter setDialogState) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2023),
        lastDate: DateTime(2100),
      );

      if (picked != null) {
        setDialogState(() {
          selectedDate = picked;
        });
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategory = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Expense Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => pickDate(setDialogState),
                        icon: const Icon(Icons.calendar_today),
                        label: Text('Date: ${_formatDate(selectedDate)}'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Paid By',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_isAdmin())
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: members.map((member) {
                          final name = member['name']?.toString() ?? '';
                          final isSelected =
                              selectedPaidByMembers.contains(name);

                          return FilterChip(
                            label: Text(name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedPaidByMembers.add(name);
                                } else {
                                  selectedPaidByMembers.remove(name);
                                }
                              });
                            },
                          );
                        }).toList(),
                      )
                    else
                      TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Paid By',
                          border: const OutlineInputBorder(),
                          hintText: currentUser,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final amount = double.tryParse(amountController.text.trim());

                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                        ),
                      );
                      return;
                    }

                    if (_isAdmin() && selectedPaidByMembers.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select paid by member'),
                        ),
                      );
                      return;
                    }

                    final paidByValue =
                        _isAdmin() ? selectedPaidByMembers : currentUser;

                    await HiveHelper.updateExpense(
                      index,
                      {
                        'category': selectedCategory,
                        'title': title.isEmpty ? selectedCategory : title,
                        'amount': amount,
                        'paidBy': paidByValue,
                        'date': selectedDate.toIso8601String(),
                      },
                    );

                    _loadData();

                    if (!mounted) return;
                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Expense updated')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense History'),
      ),
      body: expenses.isEmpty
          ? const Center(child: Text('No expense entries found'))
          : ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final expense = expenses[index];
                final canEdit = _canEditExpense(expense);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.green,
                    ),
                    title: Text(expense['title']?.toString() ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${expense['category'] ?? ''} • Added By ${_paidByText(expense['paidBy'])}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${_formatDate(expense['date'])}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (!isAdmin && !canEdit)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'View only',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '৳ ${((expense['amount'] ?? 0) as num).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (canEdit) ...[
                          IconButton(
                            onPressed: () => _editExpenseDialog(index, expense),
                            icon: const Icon(Icons.edit, color: Colors.blue),
                          ),
                          IconButton(
                            onPressed: () => _deleteExpense(index),
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
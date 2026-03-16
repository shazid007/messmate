import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_mess_service.dart';

class ExpenseEntryScreen extends StatefulWidget {
  const ExpenseEntryScreen({super.key});

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  final categories = const ['Bazaar', 'Other'];

  String selectedCategory = 'Bazaar';
  String currentUser = '';
  String? uid;
  String? messId;
  String? editingExpenseId;
  bool isCurrentUserActive = true;
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();

  bool get isEditMode => editingExpenseId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await FirestoreMessService.getCurrentUserData();
      uid = data?['uid']?.toString();
      currentUser = (data?['name'] ?? '').toString();
      messId = data?['messId']?.toString();
      if (messId == null || messId!.isEmpty || uid == null) throw Exception();
      final memberDoc = await FirestoreMessService.membersRef(
        messId!,
      ).doc(uid!).get();
      isCurrentUserActive = memberDoc.data()?['isActive'] != false;
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  void _startEditExpense(String expenseId, Map<String, dynamic> data) {
    final amount = (data['amount'] ?? 0) as num;
    final date = (data['date'] is Timestamp)
        ? (data['date'] as Timestamp).toDate()
        : DateTime.now();
    setState(() {
      editingExpenseId = expenseId;
      selectedCategory = (data['category'] ?? 'Other').toString();
      titleController.text = (data['title'] ?? '').toString();
      amountController.text = amount.toString();
      selectedDate = date;
    });
  }

  void _cancelEditExpense() {
    setState(() {
      editingExpenseId = null;
      titleController.clear();
      amountController.clear();
      selectedCategory = 'Bazaar';
      selectedDate = DateTime.now();
    });
  }

  Future<void> _saveExpense() async {
    final amount = double.tryParse(amountController.text.trim());
    if (!isCurrentUserActive)
      return _show('Inactive members cannot add expenses');
    if (titleController.text.trim().isEmpty) return _show('Give expense title');
    if (amount == null || amount <= 0)
      return _show('Please enter a valid amount');

    try {
      if (isEditMode) {
        await FirestoreMessService.updateExpense(
          messId: messId!,
          expenseId: editingExpenseId!,
          title: titleController.text.trim(),
          category: selectedCategory,
          amount: amount,
          date: selectedDate,
        );
        _show('Expense updated successfully');
      } else {
        await FirestoreMessService.saveExpense(
          title: titleController.text.trim(),
          category: selectedCategory,
          amount: amount,
          date: selectedDate,
        );
        _show('Expense saved successfully');
      }

      titleController.clear();
      amountController.clear();
      if (!mounted) return;
      setState(() {
        selectedDate = DateTime.now();
        editingExpenseId = null;
      });
    } catch (e) {
      _show(
        isEditMode ? 'Expense update failed: $e' : 'Expense save failed: $e',
      );
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (currentUser.trim().isEmpty)
      return const Center(child: Text('No logged in user found'));

    return ValueListenableBuilder<int>(
      valueListenable: FirestoreMessService.refreshNotifier,
      builder: (context, _, __) {
        return FutureBuilder<String>(
          future: FirestoreMessService.requireMessId(),
          builder: (context, messSnap) {
            if (messSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!messSnap.hasData) {
              return Center(
                child: Text(messSnap.error?.toString() ?? 'No mess joined'),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _UserInfoCard(
                    title: 'Logged in member',
                    subtitle: isCurrentUserActive
                        ? currentUser
                        : '$currentUser (Inactive)',
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 16),
                  _FormShell(
                    title: 'Add Expense',
                    subtitle: '',
                    child: Column(
                      children: [
                        TextField(
                          controller: titleController,
                          enabled: isCurrentUserActive,
                          decoration: const InputDecoration(
                            labelText: 'Expense Title',
                            hintText: 'Bazar, Wifi, gas Bill...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: amountController,
                          enabled: isCurrentUserActive,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          items: categories
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ),
                              )
                              .toList(),
                          onChanged: isCurrentUserActive
                              ? (value) {
                                  if (value != null)
                                    setState(() => selectedCategory = value);
                                }
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isCurrentUserActive ? _pickDate : null,
                            icon: const Icon(Icons.calendar_today_rounded),
                            label: Text('Date: ${_formatDate(selectedDate)}'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: isCurrentUserActive
                                ? _saveExpense
                                : null,
                            child: Text(
                              isEditMode ? 'Update Expense' : 'Save Expense',
                            ),
                          ),
                        ),
                        if (isEditMode) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _cancelEditExpense,
                              child: const Text('Cancel edit'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _HistorySection(
                    title: 'Your Expense History',
                    emptyText: 'You have not added any expense yet.',
                    future: FirestoreMessService.expensesRef(messSnap.data!)
                        .where('uid', isEqualTo: uid)
                        .orderBy('date', descending: true)
                        .get(),
                    itemBuilder: (id, data) => _HistoryTile(
                      title: (data['title'] ?? 'Expense').toString(),
                      subtitle:
                          '${(data['category'] ?? 'Other').toString()} • ${_formatDateTime(data['date'])}',
                      amount: ((data['amount'] ?? 0) as num).toDouble(),
                      onEdit: () => _startEditExpense(id, data),
                      onDelete: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Expense?'),
                            content: const Text(
                              'This expense record will be removed permanently.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await FirestoreMessService.deleteExpense(
                            messId: messSnap.data!,
                            expenseId: id,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _formatDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  static String _formatDateTime(dynamic raw) {
    final dt = (raw is Timestamp) ? raw.toDate() : null;
    if (dt == null) return 'No date';
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} • $h:$mm';
  }
}

class _UserInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _UserInfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _FormShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _FormShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final String title;
  final String emptyText;
  final Future<QuerySnapshot<Map<String, dynamic>>> future;
  final Widget Function(String, Map<String, dynamic>) itemBuilder;

  const _HistorySection({
    required this.title,
    required this.emptyText,
    required this.future,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(18),
      child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final docs = snap.data?.docs ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              if (docs.isEmpty)
                Text(emptyText)
              else
                ...List.generate(docs.length, (index) {
                  final doc = docs[index];
                  final tile = itemBuilder(doc.id, doc.data());
                  return Column(
                    children: [
                      tile,
                      if (index != docs.length - 1) const Divider(height: 20),
                    ],
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final double amount;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _HistoryTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 18,
          child: Icon(Icons.receipt_long_rounded, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '৳ ${amount.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit',
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: onDelete,
                    color: Theme.of(context).colorScheme.error,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete',
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? null : null,
    gradient: isDark
        ? LinearGradient(
            colors: [Colors.blue.withValues(alpha: 0.1), Colors.purple.withValues(alpha: 0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [Colors.lightBlue.shade100, Colors.lightGreen.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.45)),
    boxShadow: const [
      BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );
}

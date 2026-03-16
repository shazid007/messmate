import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_mess_service.dart';

enum ActivityType { expense, payment }

class MemberActivityScreen extends StatefulWidget {
  final ActivityType type;

  const MemberActivityScreen({
    super.key,
    required this.type,
  });

  @override
  State<MemberActivityScreen> createState() => _MemberActivityScreenState();
}

class _MemberActivityScreenState extends State<MemberActivityScreen> {
  bool get isExpense => widget.type == ActivityType.expense;
  String get title => isExpense ? 'Expense History' : 'Payment History';

  Future<bool> _canManageEntry(Map<String, dynamic> data) async {
    final userData = await FirestoreMessService.getCurrentUserData();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final currentRole = (userData?['role'] ?? '').toString().toLowerCase();
    final entryUid = (data['uid'] ?? '').toString();

    return currentRole == 'owner' || currentRole == 'admin' || currentUid == entryUid;
  }

  Future<void> _deleteExpense({
    required String messId,
    required String expenseId,
    required Map<String, dynamic> data,
  }) async {
    final allowed = await _canManageEntry(data);
    if (!allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can edit only your own expense')),
        );
      }
      return;
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirestoreMessService.deleteExpense(messId: messId, expenseId: expenseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _editExpense({
    required String messId,
    required String expenseId,
    required Map<String, dynamic> data,
  }) async {
    final allowed = await _canManageEntry(data);
    if (!allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can edit only your own expense')),
        );
      }
      return;
    }

    if (!mounted) return;

    final titleController = TextEditingController(text: (data['title'] ?? '').toString());
    final amountController = TextEditingController(
      text: ((data['amount'] ?? 0) as num).toString(),
    );
    var selectedCategory = (data['category'] ?? 'Other').toString();
    var selectedDate = (data['date'] is Timestamp)
        ? (data['date'] as Timestamp).toDate()
        : DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Expense Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      items: const [
                        DropdownMenuItem(value: 'Bazaar', child: Text('Bazaar')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedCategory = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2023),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: Text('Date: ${_formatDate(selectedDate)}'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim());
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense title dao')),
                      );
                      return;
                    }
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount')),
                      );
                      return;
                    }

                    try {
                      await FirestoreMessService.updateExpense(
                        messId: messId,
                        expenseId: expenseId,
                        title: titleController.text.trim(),
                        category: selectedCategory,
                        amount: amount,
                        date: selectedDate,
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Update failed: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: FirestoreMessService.requireMessId(),
      builder: (context, messIdSnap) {
        if (messIdSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!messIdSnap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: Center(child: Text(messIdSnap.error?.toString() ?? 'No mess joined')),
          );
        }

        final messId = messIdSnap.data!;
        final collection = isExpense
            ? FirestoreMessService.expensesRef(messId)
            : FirestoreMessService.paymentsRef(messId);

        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: collection.orderBy('date', descending: true).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Load failed: ${snap.error}'));
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    isExpense ? 'No expense history yet' : 'No payment history yet',
                  ),
                );
              }

              final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};
              for (final doc in docs) {
                final data = doc.data();
                final name = (data['memberName'] ?? 'Unknown').toString();
                grouped.putIfAbsent(name, () => []).add(doc);
              }

              final names = grouped.keys.toList()..sort();
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: names.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final name = names[index];
                  final entries = grouped[name]!;
                  double total = 0;
                  for (final entry in entries) {
                    total += ((entry.data()['amount'] ?? 0) as num).toDouble();
                  }

                  return Container(
                    decoration: _cardDecoration(context),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      leading: CircleAvatar(
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${entries.length} entries • ৳ ${total.toStringAsFixed(0)}',
                      ),
                      children: [
                        for (final entry in entries) ...[
                          _HistoryRow(
                            title: isExpense
                                ? (entry.data()['title'] ?? 'Expense').toString()
                                : 'Payment added',
                            subtitle: isExpense
                                ? '${(entry.data()['category'] ?? 'Other').toString()} • ${_formatDateTime(entry.data()['date'])}'
                                : _formatDateTime(entry.data()['date']),
                            amount: ((entry.data()['amount'] ?? 0) as num).toDouble(),
                            trailing: isExpense
                                ? FutureBuilder<bool>(
                                    future: _canManageEntry(entry.data()),
                                    builder: (context, permissionSnap) {
                                      if (permissionSnap.data != true) {
                                        return const SizedBox.shrink();
                                      }
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Edit',
                                            onPressed: () => _editExpense(
                                              messId: messId,
                                              expenseId: entry.id,
                                              data: entry.data(),
                                            ),
                                            icon: const Icon(Icons.edit_rounded, size: 20),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete',
                                            onPressed: () => _deleteExpense(
                                              messId: messId,
                                              expenseId: entry.id,
                                              data: entry.data(),
                                            ),
                                            icon: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 20,
                                              color: Theme.of(context).colorScheme.error,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  )
                                : null,
                          ),
                          if (entry != entries.last) const Divider(height: 20),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  static String _formatDateTime(dynamic raw) {
    final dt = (raw is Timestamp) ? raw.toDate() : null;
    if (dt == null) return 'No date';
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} • $hh:$min';
  }
}

class _HistoryRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final double amount;
  final Widget? trailing;

  const _HistoryRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
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
        Text(
          '৳ ${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          trailing!,
        ],
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
      BoxShadow(
        color: Color(0x12000000),
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
    ],
  );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_mess_service.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  late int selectedMonth;
  late int selectedYear;
  DateTime selectedDate = DateTime.now();
  String reportMode = 'monthly';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = now.month;
    selectedYear = now.year;
  }

  Future<void> _pickReportDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedMonth = picked.month;
        selectedYear = picked.year;
      });
    }
  }

  void _showOtherExpenseDetails(List<_ExpenseDetail> entries) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Other Expenses',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                const Text('No other expenses in selected period.')
              else
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: ListView.separated(
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.title),
                        subtitle: Text(
                          '${e.category} • ${_formatDate(e.date)}',
                        ),
                        trailing: Text(
                          '৳ ${e.amount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPaymentDetails(List<_PaymentDetail> entries) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payments',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                const Text('No payments in selected period.')
              else
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: ListView.separated(
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.memberName),
                        subtitle: Text(_formatDate(e.date)),
                        trailing: Text(
                          '৳ ${e.amount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_ReportData> _loadData() async {
    final messId = await FirestoreMessService.requireMessId();
    final membersSnap = await FirestoreMessService.membersRef(messId).get();
    final mealsSnap = await FirestoreMessService.mealsRef(messId).get();
    final expensesSnap = await FirestoreMessService.expensesRef(messId).get();
    final paymentsSnap = await FirestoreMessService.paymentsRef(messId).get();

    final members = membersSnap.docs.map((e) => e.data()).toList();
    final activeMembers = members.where((m) => m['isActive'] != false).toList();

    bool includeDate(DateTime date) {
      if (reportMode == 'daily') {
        return date.year == selectedDate.year &&
            date.month == selectedDate.month &&
            date.day == selectedDate.day;
      }
      return date.month == selectedMonth && date.year == selectedYear;
    }

    int totalMeals = 0;
    final Map<String, int> memberMeals = {};
    for (final doc in mealsSnap.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp?)?.toDate();
      if (date == null || !includeDate(date)) continue;
      int count = 0;
      if (data['breakfast'] == true) count++;
      if (data['lunch'] == true) count++;
      if (data['dinner'] == true) count++;
      totalMeals += count;
      final name = (data['memberName'] ?? 'Unknown').toString();
      memberMeals[name] = (memberMeals[name] ?? 0) + count;
    }

    double bazaarExpense = 0;
    double otherExpense = 0;
    final List<_ExpenseDetail> otherExpenseDetails = [];
    for (final doc in expensesSnap.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp?)?.toDate();
      if (date == null || !includeDate(date)) continue;
      final amount = ((data['amount'] ?? 0) as num).toDouble();
      final cat = (data['category'] ?? '').toString().toLowerCase();
      if (cat == 'bazaar') {
        bazaarExpense += amount;
      } else {
        otherExpense += amount;
        otherExpenseDetails.add(
          _ExpenseDetail(
            id: doc.id,
            title: (data['title'] ?? 'Other expense').toString(),
            category: (data['category'] ?? 'Other').toString(),
            amount: amount,
            date: date,
          ),
        );
      }
    }

    final Map<String, double> paidMap = {};
    double totalPaid = 0;
    final List<_PaymentDetail> paymentDetails = [];
    for (final doc in paymentsSnap.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp?)?.toDate();
      if (date == null || !includeDate(date)) continue;
      final amount = ((data['amount'] ?? 0) as num).toDouble();
      final name = (data['memberName'] ?? 'Unknown').toString();
      paidMap[name] = (paidMap[name] ?? 0) + amount;
      totalPaid += amount;

      paymentDetails.add(
        _PaymentDetail(
          id: doc.id,
          memberName: name,
          amount: amount,
          date: date,
        ),
      );
    }

    final mealRate = totalMeals > 0 ? bazaarExpense / totalMeals : 0.0;
    final otherShare = activeMembers.isNotEmpty
        ? otherExpense / activeMembers.length
        : 0.0;

    final summaries = members.map((m) {
      final name = (m['name'] ?? 'Unknown').toString();
      final active = m['isActive'] != false;
      final meals = memberMeals[name] ?? 0;
      final bill = meals * mealRate + (active ? otherShare : 0.0);
      final paid = paidMap[name] ?? 0.0;
      return _MemberSummary(
        name: name,
        isActive: active,
        meals: meals,
        paid: paid,
        bill: bill,
        balance: paid - bill,
      );
    }).toList();

    return _ReportData(
      totalMeals: totalMeals,
      totalExpense: bazaarExpense + otherExpense,
      totalPaid: totalPaid,
      bazaarExpense: bazaarExpense,
      otherExpense: otherExpense,
      mealRate: mealRate,
      summaries: summaries,
      otherExpenses: otherExpenseDetails,
      paymentDetails: paymentDetails,
    );
  }

  List<int> _yearList() {
    final now = DateTime.now().year;
    return [now - 1, now, now + 1];
  }

  String _monthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month];
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: FirestoreMessService.refreshNotifier,
      builder: (context, _, __) {
        return FutureBuilder<_ReportData>(
          future: _loadData(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (snap.hasError)
              return Center(child: Text('Report load failed: ${snap.error}'));
            final data = snap.data ?? const _ReportData();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'daily',
                            label: Text('Daily Report'),
                            icon: Icon(Icons.today_rounded),
                          ),
                          ButtonSegment(
                            value: 'monthly',
                            label: Text('Monthly Report'),
                            icon: Icon(Icons.calendar_month_rounded),
                          ),
                        ],
                        selected: {reportMode},
                        onSelectionChanged: (value) =>
                            setState(() => reportMode = value.first),
                      ),
                      const SizedBox(height: 16),
                      if (reportMode == 'daily')
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _pickReportDate,
                            icon: const Icon(Icons.calendar_today_rounded),
                            label: Text('Date: ${_formatDate(selectedDate)}'),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: selectedMonth,
                                decoration: const InputDecoration(
                                  labelText: 'Month',
                                ),
                                items: List.generate(12, (i) {
                                  final m = i + 1;
                                  return DropdownMenuItem(
                                    value: m,
                                    child: Text(_monthName(m)),
                                  );
                                }),
                                onChanged: (v) {
                                  if (v != null)
                                    setState(() => selectedMonth = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: selectedYear,
                                decoration: const InputDecoration(
                                  labelText: 'Year',
                                ),
                                items: _yearList()
                                    .map(
                                      (y) => DropdownMenuItem(
                                        value: y,
                                        child: Text('$y'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null)
                                    setState(() => selectedYear = v);
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.25,
                  children: [
                    _SummaryCard(
                      label: 'Total Meal',
                      value: '${data.totalMeals}',
                      icon: Icons.restaurant_rounded,
                    ),
                    _SummaryCard(
                      label: 'Per Meal Rate',
                      value: '৳ ${data.mealRate.toStringAsFixed(2)}',
                      icon: Icons.calculate_rounded,
                    ),
                    _SummaryCard(
                      label: 'Total Bazar Expense',
                      value: '৳ ${data.bazaarExpense.toStringAsFixed(0)}',
                      icon: Icons.shopping_bag_rounded,
                    ),
                    _SummaryCard(
                      label: 'Total Other Expense',
                      value: '৳ ${data.otherExpense.toStringAsFixed(0)}',
                      icon: Icons.receipt_long_rounded,
                      onTap: data.otherExpenses.isEmpty
                          ? null
                          : () => _showOtherExpenseDetails(data.otherExpenses),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _CardShell(
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Total Expense',
                        value: '৳ ${data.totalExpense.toStringAsFixed(0)}',
                      ),
                      const Divider(height: 22),
                      _InfoRow(
                        label: 'Total Paid',
                        value: '৳ ${data.totalPaid.toStringAsFixed(0)}',
                        onTap: data.paymentDetails.isEmpty
                            ? null
                            : () => _showPaymentDetails(data.paymentDetails),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Member Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ...data.summaries.map(
                  (m) => _CardShell(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text(
                          m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                        ),
                      ),
                      title: Text(
                        m.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${m.isActive ? 'Active' : 'Inactive'} • Meals: ${m.meals}\nPaid: ৳ ${m.paid.toStringAsFixed(0)} • Bill: ৳ ${m.bill.toStringAsFixed(0)}',
                      ),
                      trailing: Text(
                        '${m.balance >= 0 ? '+' : '-'}৳ ${m.balance.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          color: m.balance > 0
                              ? Colors.green
                              : (m.balance < 0 ? Colors.red : Colors.grey),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ReportData {
  final int totalMeals;
  final double totalExpense;
  final double totalPaid;
  final double bazaarExpense;
  final double otherExpense;
  final double mealRate;
  final List<_MemberSummary> summaries;
  final List<_ExpenseDetail> otherExpenses;
  final List<_PaymentDetail> paymentDetails;

  const _ReportData({
    this.totalMeals = 0,
    this.totalExpense = 0,
    this.totalPaid = 0,
    this.bazaarExpense = 0,
    this.otherExpense = 0,
    this.mealRate = 0,
    this.summaries = const [],
    this.otherExpenses = const [],
    this.paymentDetails = const [],
  });
}

class _ExpenseDetail {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;

  const _ExpenseDetail({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
  });
}

class _PaymentDetail {
  final String id;
  final String memberName;
  final double amount;
  final DateTime date;

  const _PaymentDetail({
    required this.id,
    required this.memberName,
    required this.amount,
    required this.date,
  });
}

class _MemberSummary {
  final String name;
  final bool isActive;
  final int meals;
  final double paid;
  final double bill;
  final double balance;

  const _MemberSummary({
    required this.name,
    required this.isActive,
    required this.meals,
    required this.paid,
    required this.bill,
    required this.balance,
  });
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(child: Icon(icon)),
          const Spacer(),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: card,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: row,
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const _CardShell({required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
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
      ),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';
import '../data/hive_helper.dart';

class DailyDetailScreen extends StatefulWidget {
  const DailyDetailScreen({super.key});

  @override
  State<DailyDetailScreen> createState() => _DailyDetailScreenState();
}

class _DailyDetailScreenState extends State<DailyDetailScreen> {
  DateTime selectedDate = DateTime.now();

  List<Map<String, dynamic>> allMeals = [];
  List<Map<String, dynamic>> allExpenses = [];
  List<Map<String, dynamic>> allPayments = [];

  List<Map<String, dynamic>> filteredMeals = [];
  List<Map<String, dynamic>> filteredExpenses = [];
  List<Map<String, dynamic>> filteredPayments = [];

  int breakfastCount = 0;
  int lunchCount = 0;
  int dinnerCount = 0;
  int totalMeals = 0;
  double totalExpenseCost = 0;
  double totalPayment = 0;

  @override
  void initState() {
    super.initState();
    _loadDailyData();
  }

  void _loadDailyData() {
    allMeals = HiveHelper.getMeals();
    allExpenses = HiveHelper.getExpenses();
    allPayments = HiveHelper.getPayments();

    filteredMeals = allMeals.where((meal) {
      final date = DateTime.tryParse(meal['date']?.toString() ?? '');
      if (date == null) return false;

      return date.year == selectedDate.year &&
          date.month == selectedDate.month &&
          date.day == selectedDate.day;
    }).toList();

    filteredExpenses = allExpenses.where((expense) {
      final date = DateTime.tryParse(expense['date']?.toString() ?? '');
      if (date == null) return false;

      return date.year == selectedDate.year &&
          date.month == selectedDate.month &&
          date.day == selectedDate.day;
    }).toList();

    filteredPayments = allPayments.where((payment) {
      final date = DateTime.tryParse(payment['date']?.toString() ?? '');
      if (date == null) return false;

      return date.year == selectedDate.year &&
          date.month == selectedDate.month &&
          date.day == selectedDate.day;
    }).toList();

    int b = 0;
    int l = 0;
    int d = 0;
    double e = 0;
    double p = 0;

    for (final meal in filteredMeals) {
      if (meal['breakfast'] == true) b++;
      if (meal['lunch'] == true) l++;
      if (meal['dinner'] == true) d++;
    }

    for (final expense in filteredExpenses) {
      e += ((expense['amount'] ?? 0) as num).toDouble();
    }

    for (final payment in filteredPayments) {
      p += ((payment['amount'] ?? 0) as num).toDouble();
    }

    setState(() {
      breakfastCount = b;
      lunchCount = l;
      dinnerCount = d;
      totalMeals = b + l + d;
      totalExpenseCost = e;
      totalPayment = p;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
      _loadDailyData();
    }
  }

  String _formatDate(DateTime date) {
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

  String _mealSummary(Map<String, dynamic> meal) {
    final parts = <String>[];

    if (meal['breakfast'] == true) {
      parts.add('Breakfast');
    }
    if (meal['lunch'] == true) {
      parts.add('Lunch');
    }
    if (meal['dinner'] == true) {
      parts.add('Dinner');
    }

    return parts.isEmpty ? 'No meal' : parts.join(' • ');
  }

  String _paidByText(dynamic paidBy) {
    if (paidBy is List) {
      return paidBy.join(', ');
    }
    return paidBy?.toString() ?? '';
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Detail'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadDailyData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(_formatDate(selectedDate)),
            ),
            const SizedBox(height: 16),

            _buildSummaryCard(
              'Breakfast Count',
              breakfastCount.toString(),
              Icons.free_breakfast,
            ),
            _buildSummaryCard(
              'Lunch Count',
              lunchCount.toString(),
              Icons.lunch_dining,
            ),
            _buildSummaryCard(
              'Dinner Count',
              dinnerCount.toString(),
              Icons.dinner_dining,
            ),
            _buildSummaryCard(
              'Total Meals',
              totalMeals.toString(),
              Icons.restaurant,
            ),
            _buildSummaryCard(
              'Total Expense',
              '৳ ${totalExpenseCost.toStringAsFixed(0)}',
              Icons.account_balance_wallet,
            ),
            _buildSummaryCard(
              'Total Payment',
              '৳ ${totalPayment.toStringAsFixed(0)}',
              Icons.payments,
            ),

            _buildSectionTitle('Meals'),

            filteredMeals.isEmpty
                ? const Card(
                    child: ListTile(
                      title: Text('No meals found for this date'),
                    ),
                  )
                : Column(
                    children: filteredMeals.map((meal) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.person, color: Colors.green),
                          title: Text(meal['member']?.toString() ?? ''),
                          subtitle: Text(_mealSummary(meal)),
                        ),
                      );
                    }).toList(),
                  ),

            _buildSectionTitle('Expenses'),

            filteredExpenses.isEmpty
                ? const Card(
                    child: ListTile(
                      title: Text('No expenses found for this date'),
                    ),
                  )
                : Column(
                    children: filteredExpenses.map((expense) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.receipt_long,
                            color: Colors.green,
                          ),
                          title: Text(expense['title']?.toString() ?? ''),
                          subtitle: Text(
                            '${expense['category'] ?? ''} • Added By ${_paidByText(expense['paidBy'])}',
                          ),
                          trailing: Text(
                            '৳ ${((expense['amount'] ?? 0) as num).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

            _buildSectionTitle('Payments'),

            filteredPayments.isEmpty
                ? const Card(
                    child: ListTile(
                      title: Text('No payments found for this date'),
                    ),
                  )
                : Column(
                    children: filteredPayments.map((payment) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.payments,
                            color: Colors.green,
                          ),
                          title: Text(payment['member']?.toString() ?? ''),
                          subtitle: const Text('Payment Entry'),
                          trailing: Text(
                            '৳ ${((payment['amount'] ?? 0) as num).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}
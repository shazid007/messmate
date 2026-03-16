class Expense {
  final String category;
  final String title;
  final double amount;
  final String paidBy;
  final DateTime date;

  Expense({
    required this.category,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.date,
  });
}
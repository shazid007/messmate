import '../models/member.dart';
import '../models/meal_entry.dart';
import '../models/expense.dart';

class AppData {
  static final List<Member> members = [
    Member(name: 'Shazid', role: 'Admin'),
    Member(name: 'Rahim', role: 'Member'),
    Member(name: 'Karim', role: 'Member'),
    Member(name: 'Nayeem', role: 'Member'),
  ];

  static final List<MealEntry> meals = [
    MealEntry(
      memberName: 'Shazid',
      date: DateTime.now(),
      breakfast: true,
      lunch: true,
      dinner: true,
    ),
    MealEntry(
      memberName: 'Rahim',
      date: DateTime.now(),
      breakfast: true,
      lunch: true,
      dinner: false,
    ),
  ];

  static final List<Expense> expenses = [
    Expense(
      category: 'Bazaar',
      title: 'Daily Market',
      amount: 500,
      paidBy: 'Shazid',
      date: DateTime.now(),
    ),
    Expense(
      category: 'Gas',
      title: 'Gas Bill',
      amount: 1200,
      paidBy: 'Rahim',
      date: DateTime.now(),
    ),
  ];

  static void addMember(Member member) {
    members.add(member);
  }

  static void addMeal(MealEntry meal) {
    meals.add(meal);
  }

  static void addExpense(Expense expense) {
    expenses.add(expense);
  }

  static int get totalMembers => members.length;

  static int get totalMeals =>
      meals.fold(0, (sum, item) => sum + item.totalMeals);

  static double get totalExpense =>
      expenses.fold(0, (sum, item) => sum + item.amount);

  static double get mealRate {
    if (totalMeals == 0) return 0;
    return totalExpense / totalMeals;
  }
}
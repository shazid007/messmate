class MealEntry {
  final String memberName;
  final DateTime date;
  final bool breakfast;
  final bool lunch;
  final bool dinner;

  MealEntry({
    required this.memberName,
    required this.date,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
  });

  int get totalMeals {
    int total = 0;
    if (breakfast) total++;
    if (lunch) total++;
    if (dinner) total++;
    return total;
  }
}
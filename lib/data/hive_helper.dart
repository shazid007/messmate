import 'package:hive/hive.dart';

class HiveHelper {
  static Box get _box => Hive.box('messmate_box');

  /* ===================== MESS INFO ===================== */

  static Map<String, dynamic> getMessInfo() {
    final data = _box.get('mess_info', defaultValue: {});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> saveMessInfo(Map<String, dynamic> messInfo) async {
    await _box.put('mess_info', messInfo);
  }

  static String getMessName() {
    final messInfo = getMessInfo();
    return messInfo['mess_name']?.toString() ?? '';
  }

  static String getOwnerName() {
    final messInfo = getMessInfo();
    return messInfo['owner_name']?.toString() ?? '';
  }

  static bool hasMess() {
    final messName = getMessName().trim();
    return messName.isNotEmpty;
  }

  /* ===================== MEMBERS ===================== */

  static List<Map<String, dynamic>> getMembers() {
    final data = _box.get('members', defaultValue: []);
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) {
        final member = Map<String, dynamic>.from(e);
        member['isActive'] = member['isActive'] ?? true;
        return member;
      }),
    );
  }

  static Future<void> addMember(
    String name,
    String role, {
    bool isActive = true,
  }) async {
    final members = getMembers();
    members.add({
      'name': name,
      'role': role,
      'isActive': isActive,
    });
    await _box.put('members', members);
  }

  static Future<void> updateMember(
    int index,
    String name,
    String role, {
    bool isActive = true,
  }) async {
    final members = getMembers();

    if (index >= 0 && index < members.length) {
      members[index] = {
        'name': name,
        'role': role,
        'isActive': isActive,
      };
      await _box.put('members', members);
    }
  }

  static Future<void> deleteMember(int index) async {
    final members = getMembers();
    if (index >= 0 && index < members.length) {
      members.removeAt(index);
      await _box.put('members', members);
    }
  }

  static Future<void> saveAllMembers(List<Map<String, dynamic>> members) async {
    final normalizedMembers = members.map((member) {
      final data = Map<String, dynamic>.from(member);
      data['isActive'] = data['isActive'] ?? true;
      return data;
    }).toList();

    await _box.put('members', normalizedMembers);
  }

  static List<Map<String, dynamic>> getActiveMembers() {
    return getMembers()
        .where((member) => member['isActive'] == true)
        .toList();
  }

  /* ===================== MEALS ===================== */

  static List<Map<String, dynamic>> getMeals() {
    final data = _box.get('meals', defaultValue: []);
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  static Future<void> addMeal(Map<String, dynamic> meal) async {
    final meals = getMeals();
    meals.add(meal);
    await _box.put('meals', meals);
  }

  static Future<void> updateMeal(
    int index,
    Map<String, dynamic> updatedMeal,
  ) async {
    final meals = getMeals();

    if (index >= 0 && index < meals.length) {
      meals[index] = updatedMeal;
      await _box.put('meals', meals);
    }
  }

  static Future<void> deleteMeal(int index) async {
    final meals = getMeals();
    if (index >= 0 && index < meals.length) {
      meals.removeAt(index);
      await _box.put('meals', meals);
    }
  }

  /* ===================== EXPENSES ===================== */

  static List<Map<String, dynamic>> getExpenses() {
    final data = _box.get('expenses', defaultValue: []);
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  static Future<void> addExpense(Map<String, dynamic> expense) async {
    final expenses = getExpenses();
    expenses.add(expense);
    await _box.put('expenses', expenses);
  }

  static Future<void> updateExpense(
    int index,
    Map<String, dynamic> updatedExpense,
  ) async {
    final expenses = getExpenses();

    if (index >= 0 && index < expenses.length) {
      expenses[index] = updatedExpense;
      await _box.put('expenses', expenses);
    }
  }

  static Future<void> deleteExpense(int index) async {
    final expenses = getExpenses();
    if (index >= 0 && index < expenses.length) {
      expenses.removeAt(index);
      await _box.put('expenses', expenses);
    }
  }

  /* ===================== PAYMENTS ===================== */

  static List<Map<String, dynamic>> getPayments() {
    final data = _box.get('payments', defaultValue: []);
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  static Future<void> addPayment(Map<String, dynamic> payment) async {
    final payments = getPayments();
    payments.add(payment);
    await _box.put('payments', payments);
  }

  static Future<void> deletePayment(int index) async {
    final payments = getPayments();
    if (index >= 0 && index < payments.length) {
      payments.removeAt(index);
      await _box.put('payments', payments);
    }
  }

  static Future<void> updatePayment(
    int index,
    Map<String, dynamic> updatedPayment,
  ) async {
    final payments = getPayments();

    if (index >= 0 && index < payments.length) {
      payments[index] = updatedPayment;
      await _box.put('payments', payments);
    }
  }

  /* ===================== CURRENT USER ===================== */

  static Future<void> setCurrentUser(String name) async {
    await _box.put('current_user', name);
  }

  static String getCurrentUser() {
    return _box.get('current_user', defaultValue: '');
  }

  static bool isLoggedIn() {
    return getCurrentUser().toString().trim().isNotEmpty;
  }

  static Future<void> logout() async {
    await _box.delete('current_user');
  }

  /* ===================== UTIL ===================== */

  static Future<void> clearAll() async {
    await _box.clear();
  }
}
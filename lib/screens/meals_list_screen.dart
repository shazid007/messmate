import 'package:flutter/material.dart';
import '../data/hive_helper.dart';

class MealsListScreen extends StatefulWidget {
  const MealsListScreen({super.key});

  @override
  State<MealsListScreen> createState() => _MealsListScreenState();
}

class _MealsListScreenState extends State<MealsListScreen> {
  List<Map<String, dynamic>> meals = [];
  List<Map<String, dynamic>> members = [];
  String currentUser = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      meals = HiveHelper.getMeals();
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

  bool _canEditMeal(Map<String, dynamic> meal) {
    if (_isAdmin()) return true;
    return meal['member']?.toString() == currentUser;
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

  int _mealCount(Map<String, dynamic> meal) {
    int total = 0;
    if (meal['breakfast'] == true) total++;
    if (meal['lunch'] == true) total++;
    if (meal['dinner'] == true) total++;
    return total;
  }

  Future<void> _deleteMeal(int index) async {
    final meal = meals[index];

    if (!_canEditMeal(meal)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only delete your own meal entry'),
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Meal Entry'),
          content: const Text('Are you sure you want to delete this meal entry?'),
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
      await HiveHelper.deleteMeal(index);
      _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal entry deleted')),
      );
    }
  }

  Future<void> _editMealDialog(int index, Map<String, dynamic> meal) async {
    if (!_canEditMeal(meal)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only edit your own meal entry'),
        ),
      );
      return;
    }

    String selectedMember = meal['member']?.toString() ?? currentUser;

    bool breakfast = meal['breakfast'] == true;
    bool lunch = meal['lunch'] == true;
    bool dinner = meal['dinner'] == true;

    DateTime selectedDate =
        DateTime.tryParse(meal['date']?.toString() ?? '') ?? DateTime.now();

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
              title: const Text('Edit Meal Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isAdmin())
                      DropdownButtonFormField<String>(
                        initialValue: selectedMember,
                        decoration: const InputDecoration(
                          labelText: 'Select Member',
                          border: OutlineInputBorder(),
                        ),
                        items: members.map((member) {
                          return DropdownMenuItem<String>(
                            value: member['name'],
                            child: Text(member['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedMember = value ?? selectedMember;
                          });
                        },
                      )
                    else
                      TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Member',
                          border: const OutlineInputBorder(),
                          hintText: selectedMember,
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
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: breakfast,
                      title: const Text('Breakfast'),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setDialogState(() {
                          breakfast = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      value: lunch,
                      title: const Text('Lunch'),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setDialogState(() {
                          lunch = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      value: dinner,
                      title: const Text('Dinner'),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setDialogState(() {
                          dinner = value ?? false;
                        });
                      },
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
                    if (!breakfast && !lunch && !dinner) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least one meal'),
                        ),
                      );
                      return;
                    }

                    await HiveHelper.updateMeal(
                      index,
                      {
                        'member': _isAdmin() ? selectedMember : currentUser,
                        'breakfast': breakfast,
                        'breakfast_cost': 0,
                        'lunch': lunch,
                        'lunch_cost': 0,
                        'dinner': dinner,
                        'dinner_cost': 0,
                        'date': selectedDate.toIso8601String(),
                      },
                    );

                    _loadData();

                    if (!mounted) return;
                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Meal entry updated')),
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

    return parts.isEmpty ? 'No meal' : parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal History'),
      ),
      body: meals.isEmpty
          ? const Center(child: Text('No meal entries found'))
          : ListView.builder(
              itemCount: meals.length,
              itemBuilder: (context, index) {
                final meal = meals[index];
                final memberName = meal['member']?.toString() ?? '';
                final total = _mealCount(meal);
                final canEdit = _canEditMeal(meal);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.restaurant, color: Colors.green),
                    title: Text(memberName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_mealSummary(meal)),
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${_formatDate(meal['date'])}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (!isAdmin && memberName != currentUser)
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
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$total meal',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (canEdit) ...[
                          IconButton(
                            onPressed: () => _editMealDialog(index, meal),
                            icon: const Icon(Icons.edit, color: Colors.blue),
                          ),
                          IconButton(
                            onPressed: () => _deleteMeal(index),
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
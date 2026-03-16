import 'package:flutter/material.dart';
import '../services/firestore_mess_service.dart';

class MealEntryScreen extends StatefulWidget {
  const MealEntryScreen({super.key});

  @override
  State<MealEntryScreen> createState() => _MealEntryScreenState();
}

class _MealEntryScreenState extends State<MealEntryScreen> {
  String currentUser = '';
  String? uid;
  String? messId;
  bool isCurrentUserActive = true;
  bool isOwner = false;

  // For owners: allow selecting a member to edit.
  List<Map<String, String>> members = [];
  String? selectedMemberId;
  String selectedMemberName = '';

  bool breakfast = false;
  bool lunch = false;
  bool dinner = false;
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final data = await FirestoreMessService.getCurrentUserData();
      uid = data?['uid']?.toString();
      currentUser = (data?['name'] ?? '').toString();
      messId = data?['messId']?.toString();
      if (messId == null || messId!.isEmpty || uid == null) throw Exception('No mess joined yet');

      final memberDoc = await FirestoreMessService.membersRef(messId!).doc(uid).get();
      final memberData = memberDoc.data() ?? {};
      isCurrentUserActive = memberData['isActive'] != false;
      isOwner = memberData['role'] == 'owner';
      selectedMemberId = uid;
      selectedMemberName = currentUser;

      if (isOwner) {
        await _loadMembers();
      }

      await _loadMealForSelectedDate();
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadMembers() async {
    if (messId == null) return;
    final snapshot = await FirestoreMessService.membersRef(messId!).where('isActive', isEqualTo: true).get();
    final items = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': (data['name'] ?? '').toString(),
      };
    }).toList();

    if (!mounted) return;
    setState(() {
      members = items;
      if (selectedMemberId == null && members.isNotEmpty) {
        selectedMemberId = members.first['id'];
        selectedMemberName = members.first['name'] ?? '';
      }
    });
  }

  Future<void> _loadMealForSelectedDate({String? memberId}) async {
    if (messId == null) return;
    final targetUid = memberId ?? uid;
    if (targetUid == null) return;

    final key = '${targetUid}_${_dayKey(selectedDate)}';
    final doc = await FirestoreMessService.mealsRef(messId!).doc(key).get();
    final data = doc.data() ?? {};
    if (!mounted) return;
    setState(() {
      breakfast = data['breakfast'] == true;
      lunch = data['lunch'] == true;
      dinner = data['dinner'] == true;
      isLoading = false;
    });
  }

  String _dayKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  int get totalMeal => (breakfast ? 1 : 0) + (lunch ? 1 : 0) + (dinner ? 1 : 0);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2023), lastDate: DateTime(2100));
    if (picked != null) {
      selectedDate = picked;
      await _loadMealForSelectedDate(memberId: selectedMemberId);
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Future<void> _saveMeal() async {
    if (!isCurrentUserActive) return _show('Inactive members are in view only mode');
    if (currentUser.trim().isEmpty) return _show('No logged in user found');

    final targetId = isOwner ? selectedMemberId : uid;
    final targetName = isOwner ? selectedMemberName : currentUser;

    await FirestoreMessService.saveMeal(
      date: selectedDate,
      breakfast: breakfast,
      lunch: lunch,
      dinner: dinner,
      memberUid: targetId,
      memberName: targetName,
    );

    if (!mounted) return;
    _show(totalMeal == 0 ? 'Meal cleared for ${_formatDate(selectedDate)}' : 'Meal saved for ${_formatDate(selectedDate)}');
  }

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (currentUser.trim().isEmpty) return const Center(child: Text('No logged in user found'));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(child: ListTile(leading: const Icon(Icons.person, color: Colors.green), title: const Text('Logged in as'), trailing: Text(currentUser, style: const TextStyle(fontWeight: FontWeight.bold)))),
        const SizedBox(height: 12),
        if (!isCurrentUserActive) Card(color: Colors.orange.shade50, child: const ListTile(leading: Icon(Icons.visibility, color: Colors.orange), title: Text('View Only Mode'), subtitle: Text('This member is inactive. You can view data only.'))),
        if (isOwner) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: DropdownButtonFormField<String>(
                initialValue: selectedMemberId,
                items: members
                    .map(
                      (m) => DropdownMenuItem(
                        value: m['id'],
                        child: Text(m['name'] ?? ''),
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(border: InputBorder.none, labelText: 'Select member'),
                onChanged: (value) async {
                  if (value == null) return;
                  final member = members.firstWhere((m) => m['id'] == value, orElse: () => {});
                  setState(() {
                    selectedMemberId = value;
                    selectedMemberName = member['name'] ?? '';
                    isLoading = true;
                  });
                  await _loadMealForSelectedDate(memberId: value);
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: isCurrentUserActive ? _pickDate : null, icon: const Icon(Icons.calendar_today), label: Text('Date: ${_formatDate(selectedDate)}'))),
        const SizedBox(height: 20),
        CheckboxListTile(title: const Text('Breakfast'), value: breakfast, onChanged: isCurrentUserActive ? (v) => setState(() => breakfast = v ?? false) : null),
        CheckboxListTile(title: const Text('Lunch'), value: lunch, onChanged: isCurrentUserActive ? (v) => setState(() => lunch = v ?? false) : null),
        CheckboxListTile(title: const Text('Dinner'), value: dinner, onChanged: isCurrentUserActive ? (v) => setState(() => dinner = v ?? false) : null),
        const SizedBox(height: 16),
        Card(child: ListTile(title: const Text('Total Meal'), trailing: Text(totalMeal.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: isCurrentUserActive ? _saveMeal : null, child: const Text('Save Meal'))),
      ]),
    );
  }
}

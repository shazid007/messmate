import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_mess_service.dart';
import 'dashboard_screen.dart';
import 'members_screen.dart';
import 'meal_entry_screen.dart';
import 'notifications_screen.dart';
import 'expense_entry_screen.dart';
import 'payment_entry_screen.dart';
import 'monthly_report_screen.dart';
import 'theme_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;
  bool isDeleting = false;

  final List<Widget> pages = const [
    DashboardScreen(),
    MembersScreen(),
    MealEntryScreen(),
    ExpenseEntryScreen(),
    PaymentEntryScreen(),
    MonthlyReportScreen(),
  ];

  final List<String> titles = const [
    'Dashboard',
    'Members',
    'Meal Entry',
    'Expense Entry',
    'Payment Entry',
    'Monthly Report',
  ];

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _deleteMess(String messId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => isDeleting = true);
    try {
      final db = FirebaseFirestore.instance;
      final messRef = db.collection('messes').doc(messId);
      final messDoc = await messRef.get();
      final ownerUid = messDoc.data()?['ownerId'];
      if (ownerUid != user.uid) throw Exception('Only owner can delete this mess');

      final members = await messRef.collection('members').get();
      final meals = await messRef.collection('meals').get();
      final expenses = await messRef.collection('expenses').get();
      final payments = await messRef.collection('payments').get();
      final invites = await db.collection('invites').where('messId', isEqualTo: messId).get();
      final batch = db.batch();

      for (final doc in members.docs) {
        batch.delete(doc.reference);
        batch.set(db.collection('users').doc(doc.id), {'messId': null, 'role': null}, SetOptions(merge: true));
      }
      for (final doc in meals.docs) { batch.delete(doc.reference); }
      for (final doc in expenses.docs) { batch.delete(doc.reference); }
      for (final doc in payments.docs) { batch.delete(doc.reference); }
      for (final doc in invites.docs) { batch.delete(doc.reference); }
      batch.delete(messRef);
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mess deleted successfully')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) setState(() => isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? {};
        final name = (userData['name'] ?? FirebaseAuth.instance.currentUser?.email ?? '').toString();
        final messId = (userData['messId'] ?? '').toString();
        final isOwner = userData['role'] == 'owner';

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
            title: Text(titles[currentIndex]),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Center(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'logout') {
                    await _logout();
                  } else if (value == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Mess'),
                        content: const Text('Are you sure? This will delete members, meals, expenses, payments and invites.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await _deleteMess(messId);
                    }
                  } else if (value == 'theme') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
                    );
                  } else if (value == 'edit') {
                    final newName = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        final controller = TextEditingController(text: (userData['messName'] ?? userData['name'] ?? '').toString());
                        return AlertDialog(
                          title: const Text('Edit Mess Name'),
                          content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Mess Name')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
                          ],
                        );
                      },
                    );
                    if (newName != null && newName.isNotEmpty && messId.isNotEmpty) {
                      await FirestoreMessService.updateMessName(messId, newName);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mess name updated')));
                    }
                  }
                },
                itemBuilder: (context) {
                  return <PopupMenuEntry<String>>[
                    const PopupMenuItem(value: 'theme', child: Text('Theme Settings')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit Mess Name')),
                    if (isOwner && messId.isNotEmpty) const PopupMenuItem(value: 'delete', child: Text('Delete Mess')), 
                    const PopupMenuItem(value: 'logout', child: Text('Logout')),
                  ];
                },
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
          body: SafeArea(
            child: IndexedStack(index: currentIndex, children: pages),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => setState(() => currentIndex = index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
              NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Members'),
              NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Meal'),
              NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Expense'),
              NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'Payment'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Report'),
            ],
          ),
        );
      },
    );
  }
}

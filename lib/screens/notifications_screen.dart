
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_mess_service.dart';
// import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<void> _onRefresh() async {
    // Rebuild the widget to refresh Firestore stream subscriptions.
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 300));
  }

  static String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static String _mealSummary(Map<String, dynamic> data) {
    final parts = <String>[];
    if (data['breakfast'] == true) parts.add('Breakfast');
    if (data['lunch'] == true) parts.add('Lunch');
    if (data['dinner'] == true) parts.add('Dinner');
    return parts.isEmpty ? 'No meals selected' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear notifications',
            onPressed: () async {
              // await NotificationService.cancelAllNotifications();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications cleared')),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: FirestoreMessService.requireMessId(),
        builder: (context, messIdSnap) {
          if (messIdSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!messIdSnap.hasData) {
            return Center(child: Text(messIdSnap.error?.toString() ?? 'No mess joined'));
          }

          final messId = messIdSnap.data!;
          final stream = FirestoreMessService.mealsRef(messId)
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('date', isLessThan: Timestamp.fromDate(endOfDay))
              .orderBy('date', descending: true)
              .snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('No meal updates for today'));
              }

              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: docs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: Text('${docs.length} member${docs.length == 1 ? '' : 's'} updated today'),
                            subtitle: const Text('Tap a member to see meal details'),
                          ),
                        ),
                      );
                    }

                    final data = docs[index - 1].data();
                    final updatedAt = _formatTime(data['updatedAt'] as Timestamp?);

                    return ListTile(
                      leading: const Icon(Icons.restaurant_menu),
                      title: Text(data['memberName'] ?? 'Unknown'),
                      subtitle: Text(_mealSummary(data)),
                      trailing: Text(
                        updatedAt,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

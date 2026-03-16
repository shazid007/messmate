
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_mess_service.dart';
import 'member_activity_screen.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<void> _onRefresh() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _openHistory(BuildContext context, ActivityType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberActivityScreen(type: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<String>(
      future: FirestoreMessService.requireMessId(),
      builder: (context, messIdSnap) {
        if (messIdSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!messIdSnap.hasData) {
          return Center(child: Text(messIdSnap.error?.toString() ?? 'No mess joined'));
        }

        final messId = messIdSnap.data!;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('messes').doc(messId).snapshots(),
          builder: (context, messSnap) {
            final messData = messSnap.data?.data() ?? {};
            final messName = (messData['name'] ?? messData['messName'] ?? 'My Mess').toString();
            final joinCode = (messData['joinCode'] ?? '').toString();
            final ownerName = (messData['ownerName'] ?? messData['ownerEmail'] ?? 'Unknown').toString();

            return ValueListenableBuilder<int>(
              valueListenable: FirestoreMessService.refreshNotifier,
              builder: (context, _, __) {
                return FutureBuilder<_DashData>(
                  future: _loadDashData(messId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final data = snap.data ?? const _DashData();
                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                        children: [
                          _OverviewCard(messName: messName, joinCode: joinCode),
                          const SizedBox(height: 16),
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.update),
                              title: Text('${data.todayUpdates} member${data.todayUpdates == 1 ? '' : 's'} updated today'),
                              subtitle: const Text('Tap to view meal updates'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _OwnerCard(ownerName: ownerName),
                          const SizedBox(height: 18),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              'Overview',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 11,
                            childAspectRatio: 1.15,
                            children: [
                              _StatCard(
                                label: 'Members',
                                value: '${data.memberCount}',
                                icon: Icons.groups_rounded,
                                note: 'All active members',
                              ),
                              _StatCard(
                                label: 'Meals',
                                value: '${data.totalMeals}',
                                icon: Icons.restaurant_rounded,
                                note: 'Total meals',
                              ),
                              _StatCard(
                                label: 'Expense',
                                value: '৳ ${data.totalExpense.toStringAsFixed(0)}',
                                icon: Icons.account_balance_wallet_rounded,
                                note: 'Tap for member history',
                                onTap: () => _openHistory(context, ActivityType.expense),
                              ),
                              _StatCard(
                                label: 'Paid',
                                value: '৳ ${data.totalPaid.toStringAsFixed(0)}',
                                icon: Icons.payments_rounded,
                                note: 'Tap for member history',
                                onTap: () => _openHistory(context, ActivityType.payment),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<_DashData> _loadDashData(String messId) async {
    final members = await FirestoreMessService.membersRef(messId).get();
    final meals = await FirestoreMessService.mealsRef(messId).get();
    final expenses = await FirestoreMessService.expensesRef(messId).get();
    final payments = await FirestoreMessService.paymentsRef(messId).get();

    int totalMeals = 0;
    for (final doc in meals.docs) {
      final m = doc.data();
      if (m['breakfast'] == true) totalMeals++;
      if (m['lunch'] == true) totalMeals++;
      if (m['dinner'] == true) totalMeals++;
    }

    double totalExpense = 0;
    for (final doc in expenses.docs) {
      totalExpense += ((doc.data()['amount'] ?? 0) as num).toDouble();
    }

    double totalPaid = 0;
    for (final doc in payments.docs) {
      totalPaid += ((doc.data()['amount'] ?? 0) as num).toDouble();
    }

    final messDoc = await FirebaseFirestore.instance.collection('messes').doc(messId).get();
    final ownerId = messDoc.data()?['ownerId']?.toString();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final canDelete = currentUid != null && currentUid == ownerId;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final todayUpdatesSnapshot = await FirestoreMessService.mealsRef(messId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();
    final todayUpdates = todayUpdatesSnapshot.docs.length;

    return _DashData(
      memberCount: members.docs.length,
      totalMeals: totalMeals,
      totalExpense: totalExpense,
      totalPaid: totalPaid,
      canDelete: canDelete,
      todayUpdates: todayUpdates,
    );
  }
}

class _DashData {
  final int memberCount;
  final int totalMeals;
  final double totalExpense;
  final double totalPaid;
  final bool canDelete;
  final int todayUpdates;

  const _DashData({
    this.memberCount = 0,
    this.totalMeals = 0,
    this.totalExpense = 0,
    this.totalPaid = 0,
    this.canDelete = false,
    this.todayUpdates = 0,
  });
}

class _OverviewCard extends StatelessWidget {
  final String messName;
  final String joinCode;

  const _OverviewCard({required this.messName, required this.joinCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messNameWidget = isDark
        ? ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              messName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          )
        : Text(
            messName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.home_work_rounded, color: colors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                messNameWidget,
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Join code',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        joinCode.isEmpty ? 'Not available' : joinCode,
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _OwnerCard extends StatelessWidget {
  final String ownerName;

  const _OwnerCard({required this.ownerName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colors.primaryContainer,
            child: Icon(Icons.person_rounded, color: colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ownerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mess owner',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String note;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final body = Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colors.primary),
          ),
          const Spacer(),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (value.isNotEmpty)
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          const SizedBox(height: 4),
          Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );

    return onTap == null
        ? body
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: body,
          );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
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
  );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_mess_service.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  String? messId;
  bool isOwner = false;
  bool isAdmin = false;
  bool isPageLoading = true;
  String? currentUid;

  @override
  void initState() {
    super.initState();
    _loadMessInfo();
  }

  Future<void> _loadMessInfo() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => isPageLoading = false);
      return;
    }
    currentUid = currentUser.uid;
    try {
      final userData = await FirestoreMessService.getCurrentUserData();
      if (!mounted) return;
      setState(() {
        messId = userData?['messId']?.toString();
        final role = userData?['role']?.toString();
        isOwner = role == 'owner';
        isAdmin = role == 'admin';
        isPageLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isPageLoading = false);
      _show('Mess info load failed: $e');
    }
  }

  Future<void> sendInvite() async {
    final email = emailController.text.trim().toLowerCase();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (email.isEmpty) return _show('Email dao');
    if (currentUser == null) return _show('User not logged in');
    if (messId == null || messId!.isEmpty) return _show('Age mess create/join koro');
    setState(() => isLoading = true);
    try {
      final messDoc = await FirebaseFirestore.instance.collection('messes').doc(messId).get();
      final messName = messDoc.data()?['name'] ?? 'My Mess';
      final senderData = await FirestoreMessService.getCurrentUserData();
      final senderName = (senderData?['name'] ?? currentUser.displayName ?? 'User').toString();

      final userQuery = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).limit(1).get();
      if (userQuery.docs.isEmpty) throw Exception('Ei email diye kono account nai');
      final invitedData = userQuery.docs.first.data();
      final invitedUid = invitedData['uid'];
      if (invitedUid == currentUser.uid) throw Exception('Nijer kache invite pathano jabe na');
      if ((invitedData['messId'] ?? '').toString().trim().isNotEmpty) throw Exception('Ei user already onno mess e ase');
      final existingInvite = await FirebaseFirestore.instance.collection('invites')
          .where('messId', isEqualTo: messId)
          .where('toUid', isEqualTo: invitedUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existingInvite.docs.isNotEmpty) throw Exception('Invite agei pathano hoise');

      await FirebaseFirestore.instance.collection('invites').add({
        'messId': messId,
        'messName': messName,
        'fromUid': currentUser.uid,
        'fromName': senderName,
        'toUid': invitedUid,
        'toEmail': email,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      emailController.clear();
      _show('Invite pathano hoise');
    } catch (e) {
      _show('Invite send failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> toggleMemberStatus(String memberUid, bool value) async {
    if (!isOwner || messId == null || messId!.isEmpty) return;
    if (memberUid == currentUid) return _show('Owner nijer status change korte parbe na');
    try {
      await FirestoreMessService.setMemberActive(messId!, memberUid, value);
      _show(value ? 'Member active kora hoise' : 'Member inactive kora hoise');
    } catch (e) {
      _show('Status update failed: $e');
    }
  }

  Future<void> changeMemberRole(String memberUid, String targetRole) async {
    if (!(isOwner || isAdmin) || messId == null || messId!.isEmpty) return;
    if (memberUid == currentUid) return _show('Nijer role change kora jabe na');
    try {
      if (isOwner) {
        await FirestoreMessService.setMemberRole(messId!, memberUid, targetRole);
      } else if (isAdmin && targetRole == 'admin') {
        await FirestoreMessService.promoteToAdminWithSacrifice(messId!, memberUid, currentUid!);
      } else {
        await FirestoreMessService.setMemberRole(messId!, memberUid, targetRole);
      }
      _show('Member role changed to $targetRole');
    } catch (e) {
      _show('Role update failed: $e');
    }
  }

  Future<void> kickMember(String memberUid) async {
    if (!(isOwner || isAdmin) || messId == null || messId!.isEmpty) return;
    if (memberUid == currentUid) return _show('Nijer kike kora jabe na');
    try {
      await FirestoreMessService.removeMember(messId!, memberUid);
      _show('Member removed successfully');
    } catch (e) {
      _show('Remove failed: $e');
    }
  }

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isPageLoading) return const Center(child: CircularProgressIndicator());
    if (messId == null || messId!.isEmpty) return const Center(child: Text('No mess joined yet'));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (isOwner) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Member Email', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: isLoading ? null : sendInvite, child: isLoading ? const CircularProgressIndicator() : const Text('Send Invite'))),
                ]),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('messes').doc(messId).collection('members').orderBy('joinedAt').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Members load failed: ${snapshot.error}'));
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) return const Center(child: Text('No members found'));
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final memberUid = doc.id;
                    final name = (data['name'] ?? 'No Name').toString();
                    final email = (data['email'] ?? '').toString();
                    final role = (data['role'] ?? 'member').toString();
                    final isActive = data['isActive'] != false;
                    final isCurrentOwner = memberUid == currentUid;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(radius: 18, child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U')),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(email, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Chip(
                                  label: Text(role.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.white)),
                                  backgroundColor: role == 'owner'
                                      ? Colors.blue
                                      : role == 'admin'
                                          ? Colors.green
                                          : Colors.grey,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Chip(
                                  label: Text(isActive ? 'Active' : 'Inactive', style: const TextStyle(fontSize: 12, color: Colors.white)),
                                  backgroundColor: isActive ? Colors.green : Colors.orange,
                                ),
                                if (isOwner && !isCurrentOwner)
                                  Row(
                                    children: [
                                      const Text('State', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        height: 24,
                                        child: Switch(
                                          value: isActive,
                                          onChanged: (value) => toggleMemberStatus(memberUid, value),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        tooltip: 'Member actions',
                                        onSelected: (value) {
                                          if (value == 'kick') {
                                            kickMember(memberUid);
                                          } else {
                                            changeMemberRole(memberUid, value);
                                          }
                                        },
                                        itemBuilder: (context) {
                                          final items = <PopupMenuEntry<String>>[];
                                          if (role != 'admin') {
                                            items.add(const PopupMenuItem(value: 'admin', child: Text('Set as Admin')));
                                          }
                                          if (role != 'member') {
                                            items.add(const PopupMenuItem(value: 'member', child: Text('Set as Member')));
                                          }
                                          items.add(const PopupMenuDivider());
                                          items.add(const PopupMenuItem(value: 'kick', child: Text('Remove/Kick Member')));
                                          return items;
                                        },
                                        icon: const Icon(Icons.more_vert, size: 20),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

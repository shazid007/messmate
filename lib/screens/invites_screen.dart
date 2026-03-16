import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InvitesScreen extends StatelessWidget {
  const InvitesScreen({super.key});

  Future<void> acceptInvite(
    BuildContext context,
    String inviteId,
    Map<String, dynamic> inviteData,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      final userRef = firestore.collection('users').doc(user.uid);
      final inviteRef = firestore.collection('invites').doc(inviteId);
      final messRef = firestore.collection('messes').doc(inviteData['messId']);
      final memberRef = messRef.collection('members').doc(user.uid);

      final userDoc = await userRef.get();
      final messDoc = await messRef.get();
      final inviteDoc = await inviteRef.get();

      if (!inviteDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite not found')),
        );
        return;
      }

      if (!messDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This mess no longer exists')),
        );
        await inviteRef.update({'status': 'expired'});
        return;
      }

      final userData = userDoc.data();
      if (userData?['messId'] != null &&
          userData!['messId'].toString().trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tumi already ekta mess e aso')),
        );
        return;
      }

      final batch = firestore.batch();

      batch.set(memberRef, {
        'uid': user.uid,
        'name': user.displayName ?? 'User',
        'email': user.email ?? '',
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      batch.set(userRef, {
        'uid': user.uid,
        'name': user.displayName ?? 'User',
        'email': user.email ?? '',
        'messId': inviteData['messId'],
        'role': 'member',
      }, SetOptions(merge: true));

      batch.update(inviteRef, {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite accepted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept failed: $e')),
      );
    }
  }

  Future<void> rejectInvite(
    BuildContext context,
    String inviteId,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('invites').doc(inviteId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite rejected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invites'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('invites')
            .where('toUid', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Invite load failed: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('No pending invites'),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['messName'] ?? 'Unknown Mess',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('From: ${data['fromName'] ?? ''}'),
                      const SizedBox(height: 4),
                      Text('Email: ${data['toEmail'] ?? ''}'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => acceptInvite(
                                context,
                                doc.id,
                                data,
                              ),
                              child: const Text('Accept'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => rejectInvite(
                                context,
                                doc.id,
                              ),
                              child: const Text('Reject'),
                            ),
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
    );
  }
}
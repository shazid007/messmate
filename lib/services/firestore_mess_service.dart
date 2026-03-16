import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

// import 'notification_service.dart';

class FirestoreMessService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);
  static void notifyDataChanged() => refreshNotifier.value++;

  static CollectionReference<Map<String, dynamic>> get usersRef =>
      _firestore.collection('users');

  static CollectionReference<Map<String, dynamic>> get messesRef =>
      _firestore.collection('messes');

  static CollectionReference<Map<String, dynamic>> get invitesRef =>
      _firestore.collection('invites');

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _generateJoinCode([int length = 6]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final snapshot = await usersRef.doc(user.uid).get();
    return snapshot.data();
  }

  static Future<String> requireMessId() async {
    final data = await getCurrentUserData();
    final messId = data?['messId']?.toString().trim();
    if (messId == null || messId.isEmpty) {
      throw Exception('No mess joined');
    }
    return messId;
  }

  static CollectionReference<Map<String, dynamic>> membersRef(String messId) =>
      messesRef.doc(messId).collection('members');

  static CollectionReference<Map<String, dynamic>> mealsRef(String messId) =>
      messesRef.doc(messId).collection('meals');

  static CollectionReference<Map<String, dynamic>> expensesRef(String messId) =>
      messesRef.doc(messId).collection('expenses');

  static CollectionReference<Map<String, dynamic>> paymentsRef(String messId) =>
      messesRef.doc(messId).collection('payments');

  static Future<void> upsertUserProfile({required User user}) async {
    final userRef = usersRef.doc(user.uid);
    final snapshot = await userRef.get();
    final existingData = snapshot.data();

    await userRef.set({
      'uid': user.uid,
      'name': (user.displayName ?? existingData?['name'] ?? '').trim(),
      'email': (user.email ?? '').toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),

      // only set these first time
      if (!snapshot.exists) 'messId': null,
      if (!snapshot.exists) 'role': null,
      if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(
    String uid,
  ) async {
    return await usersRef.doc(uid).get();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserDoc(
    String uid,
  ) {
    return usersRef.doc(uid).snapshots();
  }

  static Future<void> createMess({
    required String messName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user logged in');

    final messRef = messesRef.doc();
    final email = (user.email ?? '').toLowerCase();
    final joinCode = _generateJoinCode();
    final ownerName = (user.displayName ?? '').trim();

    await _firestore.runTransaction((transaction) async {
      final userRef = usersRef.doc(user.uid);

      transaction.set(messRef, {
        'messId': messRef.id,
        'name': messName.trim(),
        'joinCode': joinCode,
        'ownerId': user.uid,
        'ownerName': ownerName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(userRef, {
        'uid': user.uid,
        'name': ownerName,
        'email': email,
        'messId': messRef.id,
        'role': 'owner',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final memberRef = membersRef(messRef.id).doc(user.uid);
      transaction.set(memberRef, {
        'uid': user.uid,
        'name': ownerName,
        'email': email,
        'role': 'owner',
        'isActive': true,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> joinMessByCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw Exception('Join code is required');
    }

    final querySnapshot = await messesRef
        .where('joinCode', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Mess not found with join code $code');
    }

    final messDoc = querySnapshot.docs.first;
    final messId = messDoc.id;
    final existingUserDoc = await usersRef.doc(user.uid).get();

    if (existingUserDoc.exists &&
        (existingUserDoc.data()?['messId']?.toString().trim().isNotEmpty ?? false)) {
      throw Exception('You already joined a mess');
    }

    final memberDoc = await membersRef(messId).doc(user.uid).get();
    if (memberDoc.exists) {
      throw Exception('Already member of this mess');
    }

    await _firestore.runTransaction((transaction) async {
      final userRef = usersRef.doc(user.uid);
      final memberRef = membersRef(messId).doc(user.uid);

      transaction.set(memberRef, {
        'uid': user.uid,
        'name': (user.displayName ?? '').trim(),
        'email': (user.email ?? '').toLowerCase(),
        'role': 'member',
        'isActive': true,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(userRef, {
        'messId': messId,
        'role': 'member',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  static Future<void> saveMeal({
    required DateTime date,
    required bool breakfast,
    required bool lunch,
    required bool dinner,
    String? memberUid,
    String? memberName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    final messId = await requireMessId();

    // If no explicit member was provided, default to current user.
    final effectiveUid = memberUid ?? user.uid;
    final effectiveName = memberName ?? (await getCurrentUserData())?['name']?.toString() ?? user.displayName ?? '';

    final key = '${effectiveUid}_${_dayKey(date)}';
    final docRef = mealsRef(messId).doc(key);

    if (!breakfast && !lunch && !dinner) {
      final existing = await docRef.get();
      if (existing.exists) {
        await docRef.delete();
      }
      return;
    }

    await docRef.set({
      'uid': effectiveUid,
      'memberName': effectiveName,
      'date': Timestamp.fromDate(date),
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    notifyDataChanged();

    // Notification system removed
  }

  static Future<void> saveExpense({
    required String title,
    required String category,
    required double amount,
    required DateTime date,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    final messId = await requireMessId();
    final userData = await getCurrentUserData();
    final memberName = (userData?['name'] ?? user.displayName ?? '').toString();

    await expensesRef(messId).add({
      'uid': user.uid,
      'memberName': memberName,
      'title': title.trim(),
      'category': category.trim(),
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    });

    notifyDataChanged();
  }

  static Future<void> savePayment({
    required double amount,
    required DateTime date,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    final messId = await requireMessId();
    final userData = await getCurrentUserData();
    final memberName = (userData?['name'] ?? user.displayName ?? '').toString();

    await paymentsRef(messId).add({
      'uid': user.uid,
      'memberName': memberName,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    });

    notifyDataChanged();
  }

  static Future<void> updatePayment({
    required String messId,
    required String paymentId,
    required double amount,
    required DateTime date,
  }) async {
    await paymentsRef(messId).doc(paymentId).update({
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    notifyDataChanged();
  }

  static Future<void> deletePayment({
    required String messId,
    required String paymentId,
  }) async {
    await paymentsRef(messId).doc(paymentId).delete();
    notifyDataChanged();
  }

  static Future<void> updateExpense({
    required String messId,
    required String expenseId,
    required String title,
    required String category,
    required double amount,
    required DateTime date,
  }) async {
    await expensesRef(messId).doc(expenseId).update({
      'title': title.trim(),
      'category': category.trim(),
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    notifyDataChanged();
  }

  static Future<void> deleteExpense({
    required String messId,
    required String expenseId,
  }) async {
    await expensesRef(messId).doc(expenseId).delete();
    notifyDataChanged();
  }

  static Future<void> joinMess({
    required User user,
    required String messId,
  }) async {
    final messDoc = await messesRef.doc(messId).get();

    if (!messDoc.exists) {
      throw Exception('Mess not found');
    }

    await usersRef.doc(user.uid).set({
      'uid': user.uid,
      'name': (user.displayName ?? '').trim(),
      'email': (user.email ?? '').toLowerCase(),
      'messId': messId,
      'role': 'member',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final memberRef = membersRef(messId).doc(user.uid);
    await memberRef.set({
      'uid': user.uid,
      'name': (user.displayName ?? '').trim(),
      'email': (user.email ?? '').toLowerCase(),
      'role': 'member',
      'isActive': true,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setMemberActive(String messId, String memberUid, bool isActive) async {
    await membersRef(messId).doc(memberUid).update({'isActive': isActive});
  }

  static Future<void> setMemberRole(String messId, String memberUid, String role) async {
    if (role != 'member' && role != 'admin') {
      throw Exception('Invalid role: $role');
    }

    final memberRef = membersRef(messId).doc(memberUid);
    final userRef = usersRef.doc(memberUid);

    await _firestore.runTransaction((transaction) async {
      final memberSnapshot = await transaction.get(memberRef);
      if (!memberSnapshot.exists) {
        throw Exception('Member not found');
      }

      final currentRole = memberSnapshot.data()?['role']?.toString();
      if (currentRole == 'owner') {
        throw Exception('Cannot change owner role');
      }

      transaction.update(memberRef, {'role': role});
      transaction.set(userRef, {'role': role}, SetOptions(merge: true));
    });
  }

  static Future<void> promoteToAdminWithSacrifice(String messId, String targetMemberUid, String performerUid) async {
    final targetRef = membersRef(messId).doc(targetMemberUid);
    final performerRef = membersRef(messId).doc(performerUid);

    await _firestore.runTransaction((transaction) async {
      final targetSnapshot = await transaction.get(targetRef);
      final performerSnapshot = await transaction.get(performerRef);

      if (!targetSnapshot.exists || !performerSnapshot.exists) {
        throw Exception('Member not found');
      }

      final performerRole = performerSnapshot.data()?['role']?.toString();
      if (performerRole != 'admin' && performerRole != 'owner') {
        throw Exception('Only admin or owner can promote');
      }

      final targetRole = targetSnapshot.data()?['role']?.toString();
      if (targetRole == 'owner') {
        throw Exception('Cannot change owner role');
      }

      transaction.update(targetRef, {'role': 'admin'});
      transaction.set(usersRef.doc(targetMemberUid), {'role': 'admin'}, SetOptions(merge: true));

      if (performerRole == 'admin' && performerUid != targetMemberUid) {
        transaction.update(performerRef, {'role': 'member'});
        transaction.set(usersRef.doc(performerUid), {'role': 'member'}, SetOptions(merge: true));
      }
    });
  }

  static Future<void> removeMember(String messId, String memberUid) async {
    final memberRef = membersRef(messId).doc(memberUid);
    final userRef = usersRef.doc(memberUid);

    final memberSnapshot = await memberRef.get();
    if (!memberSnapshot.exists) return;

    final role = memberSnapshot.data()?['role']?.toString();
    if (role == 'owner') {
      throw Exception('Cannot remove owner');
    }

    final batch = _firestore.batch();
    batch.delete(memberRef);
    batch.set(userRef, {
      'messId': null,
      'role': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  static Future<void> updateMessName(String messId, String newName) async {
    await messesRef.doc(messId).update({'name': newName});
  }

  static Future<void> deleteMess(String messId, String ownerUid) async {
    final messRef = messesRef.doc(messId);
    final messDoc = await messRef.get();
    if (!messDoc.exists) throw Exception('Mess not found');

    final ownerId = messDoc.data()?['ownerId'] ?? messDoc.data()?['ownerid'] ?? messDoc.data()?['owner'];
    if (ownerId == null || ownerId.toString().trim().isEmpty) {
      throw Exception('Mess owner data missing');
    }
    if (ownerId.toString() != ownerUid) throw Exception('Only owner can delete the mess');

    final db = FirebaseFirestore.instance;
    final members = await messRef.collection('members').get();
    final meals = await messRef.collection('meals').get();
    final expenses = await messRef.collection('expenses').get();
    final payments = await messRef.collection('payments').get();
    final invites = await db.collection('invites').where('messId', isEqualTo: messId).get();

    final batch = db.batch();

    for (final doc in members.docs) {
      batch.delete(doc.reference);
      batch.set(db.collection('users').doc(doc.id), {'messId': null, 'role': null, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    for (final doc in meals.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in expenses.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in payments.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in invites.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(messRef);
    await batch.commit();
  }

  static Future<void> leaveMess({
    required String uid,
  }) async {
    final userDoc = await usersRef.doc(uid).get();
    final messId = userDoc.data()?['messId']?.toString().trim();

    if (messId != null && messId.isNotEmpty) {
      final memberRef = membersRef(messId).doc(uid);
      await memberRef.delete();
    }

    await usersRef.doc(uid).set({
      'messId': null,
      'role': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

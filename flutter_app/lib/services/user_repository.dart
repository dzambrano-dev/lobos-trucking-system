import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<AppUser?> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return AppUser.fromMap(snapshot.id, data);
    });
  }

  Future<List<AppUser>> getActiveDrivers() async {
    final snapshot = await _firestore
        .collection('users')
        .where('active', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.id, doc.data()))
        .where((user) => user.permissions.updateAssignedLoads)
        .toList()
      ..sort(
        (first, second) => first.displayName.toLowerCase().compareTo(
          second.displayName.toLowerCase(),
        ),
      );
  }
}

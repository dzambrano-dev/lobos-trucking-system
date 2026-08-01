import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/client_record.dart';

class ClientRepository {
  ClientRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _clients =>
      _firestore.collection('clients');

  Stream<List<ClientRecord>> watchClients() {
    return _clients
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClientRecord.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<List<ClientRecord>> getClients() async {
    final snapshot = await _clients.orderBy('name').get();
    return snapshot.docs
        .map((doc) => ClientRecord.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  Future<void> createClient({
    required String name,
    required String contact,
    required String phone,
    required String email,
    required String address,
  }) {
    return _clients.add({
      'name': name.trim(),
      'contact': contact.trim(),
      'phone': phone.trim(),
      'email': email.trim().toLowerCase(),
      'address': address.trim(),
      // Server timestamps make the audit fields trustworthy across phones
      // whose local clocks may be wrong.
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateClient({
    required String id,
    required String name,
    required String contact,
    required String phone,
    required String email,
    required String address,
  }) {
    return _clients.doc(id).update({
      'name': name.trim(),
      'contact': contact.trim(),
      'phone': phone.trim(),
      'email': email.trim().toLowerCase(),
      'address': address.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

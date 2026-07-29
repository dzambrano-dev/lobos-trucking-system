import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_user.dart';
import '../models/load_record.dart';
import '../models/load_status.dart';

class LoadRepository {
  LoadRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _loads =>
      _firestore.collection('loads');

  Stream<List<LoadRecord>> watchAllLoads() {
    return _loads
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(_recordsFromSnapshot);
  }

  Stream<List<LoadRecord>> watchAssignedLoads(String driverUid) {
    return _loads
        .where('assignedDriverId', isEqualTo: driverUid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(_recordsFromSnapshot);
  }

  Future<String> createLoad({
    required String clientId,
    required String clientName,
    required String pickupAddress,
    required String deliveryAddress,
    required DateTime scheduledPickupAt,
    required AppUser driver,
    required AppUser actor,
  }) async {
    final loadRef = _loads.doc();
    final eventRef = loadRef.collection('events').doc();
    final now = DateTime.now();
    final loadNumber =
        'LD-${now.year}-${loadRef.id.substring(0, 6).toUpperCase()}';
    final batch = _firestore.batch();

    batch.set(loadRef, {
      'loadNumber': loadNumber,
      'clientId': clientId,
      'clientName': clientName.trim(),
      'pickupAddress': pickupAddress.trim(),
      'deliveryAddress': deliveryAddress.trim(),
      'scheduledPickupAt': Timestamp.fromDate(scheduledPickupAt),
      'assignedDriverId': driver.uid,
      'assignedDriverName': driver.displayName,
      'status': LoadProgressStatus.assigned.value,
      'needsAttention': false,
      'createdBy': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      eventRef,
      _eventData(
        actor: actor,
        type: 'assigned',
        status: LoadProgressStatus.assigned,
        note: 'Assigned to ${driver.displayName}',
      ),
    );

    await batch.commit();
    return loadRef.id;
  }

  Future<void> updateProgress({
    required LoadRecord load,
    required LoadProgressStatus next,
    required AppUser actor,
  }) async {
    if (!load.status.canTransitionTo(next)) {
      throw StateError(
        '${load.status.label} cannot move directly to ${next.label}.',
      );
    }
    if (next == LoadProgressStatus.delivered) {
      throw StateError('A customer signature is required for delivery.');
    }

    final loadRef = _loads.doc(load.id);
    final eventRef = loadRef.collection('events').doc();
    final batch = _firestore.batch();

    batch.update(loadRef, {
      'status': next.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      eventRef,
      _eventData(actor: actor, type: next.value, status: next),
    );

    await batch.commit();
  }

  Future<void> reportIssue({
    required LoadRecord load,
    required AppUser actor,
    required String note,
  }) async {
    final trimmedNote = note.trim();
    if (trimmedNote.isEmpty) {
      throw ArgumentError('Describe the delay or problem.');
    }

    final loadRef = _loads.doc(load.id);
    final eventRef = loadRef.collection('events').doc();
    final batch = _firestore.batch();

    batch.update(loadRef, {
      'needsAttention': true,
      'issueSummary': trimmedNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      eventRef,
      _eventData(
        actor: actor,
        type: 'issue_reported',
        status: load.status,
        note: trimmedNote,
      ),
    );

    await batch.commit();
  }

  Future<void> resolveIssue({
    required LoadRecord load,
    required AppUser actor,
  }) async {
    final loadRef = _loads.doc(load.id);
    final eventRef = loadRef.collection('events').doc();
    final batch = _firestore.batch();

    batch.update(loadRef, {
      'needsAttention': false,
      'issueSummary': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      eventRef,
      _eventData(actor: actor, type: 'issue_resolved', status: load.status),
    );

    await batch.commit();
  }

  Future<void> completeDelivery({
    required LoadRecord load,
    required AppUser actor,
    required Uint8List signaturePng,
  }) async {
    if (!load.status.canTransitionTo(LoadProgressStatus.delivered)) {
      throw StateError('The load must be in transit before delivery.');
    }
    if (signaturePng.isEmpty) {
      throw ArgumentError('A customer signature is required.');
    }

    final fileName =
        '${actor.uid}-${DateTime.now().microsecondsSinceEpoch}.png';
    final signatureRef = _storage
        .ref()
        .child('load-signatures')
        .child(load.id)
        .child(fileName);

    await signatureRef.putData(
      signaturePng,
      SettableMetadata(
        contentType: 'image/png',
        customMetadata: {'loadId': load.id, 'capturedBy': actor.uid},
      ),
    );

    try {
      final loadRef = _loads.doc(load.id);
      final eventRef = loadRef.collection('events').doc();
      final batch = _firestore.batch();

      batch.update(loadRef, {
        'status': LoadProgressStatus.delivered.value,
        'delivery': {
          'signatureStoragePath': signatureRef.fullPath,
          'signedAt': FieldValue.serverTimestamp(),
          'capturedBy': actor.uid,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        eventRef,
        _eventData(
          actor: actor,
          type: LoadProgressStatus.delivered.value,
          status: LoadProgressStatus.delivered,
          note: 'Customer signature captured',
        ),
      );

      await batch.commit();
    } catch (_) {
      await signatureRef.delete().catchError((_) {});
      rethrow;
    }
  }

  List<LoadRecord> _recordsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => LoadRecord.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  Map<String, dynamic> _eventData({
    required AppUser actor,
    required String type,
    required LoadProgressStatus status,
    String? note,
  }) {
    return {
      'type': type,
      'status': status.value,
      'actorUid': actor.uid,
      'actorName': actor.displayName,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

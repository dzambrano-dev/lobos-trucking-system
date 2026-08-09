import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/delivery_proof.dart';
import '../models/load_record.dart';
import '../models/load_status.dart';

class LoadRepository {
  LoadRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const customerSignatureProofId = 'customerSignature';

  // A signature is mostly white space, so a 350 KiB ceiling is generous while
  // still leaving plenty of room below Firestore's 1 MiB document limit.
  static const maxSignatureBytes = 350 * 1024;

  final FirebaseFirestore _firestore;

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
      'lastEventId': eventRef.id,
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

    // The load and its audit entry succeed or fail together. Keeping those
    // writes in one batch prevents an unexplained status change in the log.
    batch.update(loadRef, {
      'status': next.value,
      'lastEventId': eventRef.id,
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
    if (trimmedNote.length > 1000) {
      throw ArgumentError('Keep the report under 1,000 characters.');
    }

    final loadRef = _loads.doc(load.id);
    final eventRef = loadRef.collection('events').doc();
    final batch = _firestore.batch();

    batch.update(loadRef, {
      'needsAttention': true,
      'issueSummary': trimmedNote,
      'lastEventId': eventRef.id,
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
      'lastEventId': eventRef.id,
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
    required String signedByName,
  }) async {
    if (!load.status.canTransitionTo(LoadProgressStatus.delivered)) {
      throw StateError('The load must be in transit before delivery.');
    }
    if (signaturePng.isEmpty) {
      throw ArgumentError('A customer signature is required.');
    }
    if (signaturePng.lengthInBytes > maxSignatureBytes) {
      throw ArgumentError('The signature image is too large. Clear and retry.');
    }
    final signer = signedByName.trim();
    if (signer.isEmpty || signer.length > 120) {
      throw ArgumentError('Enter the customer name shown with the signature.');
    }

    final loadRef = _loads.doc(load.id);
    final proofRef = loadRef.collection('proofs').doc(customerSignatureProofId);
    final eventRef = loadRef.collection('events').doc();
    final batch = _firestore.batch();

    // The proof is intentionally a separate document. A normal load query now
    // downloads only a few metadata fields, not every customer's PNG.
    batch.set(proofRef, {
      'signaturePng': Blob(signaturePng),
      'contentType': 'image/png',
      'byteLength': signaturePng.lengthInBytes,
      'signedByName': signer,
      'signedAt': FieldValue.serverTimestamp(),
      'capturedBy': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(loadRef, {
      'status': LoadProgressStatus.delivered.value,
      'delivery': {
        'proofId': customerSignatureProofId,
        'signedByName': signer,
        'signedAt': FieldValue.serverTimestamp(),
        'capturedBy': actor.uid,
      },
      'lastEventId': eventRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      eventRef,
      _eventData(
        actor: actor,
        type: LoadProgressStatus.delivered.value,
        status: LoadProgressStatus.delivered,
        note: 'Delivery signed by $signer',
      ),
    );

    await batch.commit();
  }

  Future<DeliveryProof> getDeliveryProof(String loadId) async {
    final snapshot = await _loads
        .doc(loadId)
        .collection('proofs')
        .doc(customerSignatureProofId)
        .get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw StateError('No customer signature was found for this load.');
    }
    return DeliveryProof.fromFirestore(data);
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

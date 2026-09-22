import 'dart:typed_data';
import 'package:intl/intl.dart';

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
    final assigned = _loads.where('assignedDriverId', isEqualTo: driverUid);
    final active = assigned
        .where(
          'status',
          whereIn: ['assigned', 'accepted', 'arrived_at_pickup', 'in_transit'],
        )
        .orderBy('updatedAt', descending: true);
    final history = assigned
        .where('status', whereIn: ['delivered', 'cancelled'])
        .orderBy('updatedAt', descending: true)
        .limit(10);
    return Stream<List<LoadRecord>>.multi((controller) {
      List<LoadRecord>? open, closed;
      void emit() {
        if (open == null || closed == null) return;
        final rows = {
          for (final load in [...open!, ...closed!]) load.id: load,
        }.values.toList();
        rows.sort(
          (a, b) => (b.updatedAt ?? DateTime(1970)).compareTo(
            a.updatedAt ?? DateTime(1970),
          ),
        );
        controller.add(rows);
      }

      final first = active.snapshots().listen((s) {
        open = _recordsFromSnapshot(s);
        emit();
      }, onError: controller.addError);
      final second = history.snapshots().listen((s) {
        closed = _recordsFromSnapshot(s);
        emit();
      }, onError: controller.addError);
      controller.onCancel = () async {
        await first.cancel();
        await second.cancel();
      };
    });
  }

  Future<String> createLoad({
    Map<String, dynamic> information = const {},
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
      ...validatedInformation(information, scheduledPickupAt),
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

  static Map<String, dynamic> validatedInformation(
    Map<String, dynamic> data,
    DateTime pickup,
  ) {
    final result = <String, dynamic>{};
    for (final entry in {
      'pickupNumber': 80,
      'reference': 80,
      'driverNotes': 1000,
    }.entries) {
      final value = (data[entry.key] ?? '').toString().trim();
      if (value.length > entry.value) {
        throw StateError('${entry.key} is too long.');
      }
      result[entry.key] = value;
    }
    final contact = Map<String, dynamic>.from(data['contact'] as Map? ?? {});
    final clean = <String, String>{};
    for (final entry in {'name': 120, 'phone': 40, 'email': 254}.entries) {
      final value = (contact[entry.key] ?? '').toString().trim();
      if (value.length > entry.value) {
        throw StateError('Contact ${entry.key} is too long.');
      }
      clean[entry.key] = value;
    }
    result['contact'] = clean;
    final raw = data['scheduledDeliveryAt'];
    DateTime? delivery;
    if (raw is DateTime) {
      delivery = raw;
    } else if (raw is Timestamp) {
      delivery = raw.toDate();
    } else if (raw != null && raw.toString().trim().isNotEmpty) {
      try {
        delivery = DateFormat(
          'yyyy-MM-dd HH:mm',
        ).parseStrict(raw.toString().trim());
      } on FormatException {
        throw StateError('Use YYYY-MM-DD HH:MM for planned delivery.');
      }
    }
    if (delivery != null && delivery.isBefore(pickup)) {
      throw StateError('Planned delivery cannot be before pickup.');
    }
    result['scheduledDeliveryAt'] = delivery == null
        ? null
        : Timestamp.fromDate(delivery);
    return result;
  }

  Future<void> updateInformation({
    required String loadId,
    required AppUser actor,
    required Map<String, dynamic> information,
  }) async {
    final ref = _loads.doc(loadId),
        event = _loads.doc(loadId).collection('events').doc();
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) throw StateError('Load no longer exists.');
      final load = LoadRecord.fromFirestore(snapshot.id, snapshot.data()!);
      if (load.isClosed && !actor.isAdmin) {
        throw StateError(
          'Only an admin can edit completed or cancelled loads.',
        );
      }
      tx.update(ref, {
        ...validatedInformation(
          information,
          load.scheduledPickupAt ?? DateTime(1970),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastEventId': event.id,
      });
      tx.set(
        event,
        _eventData(
          actor: actor,
          type: 'load_updated',
          status: load.status,
          note: 'Office updated driver instructions / load details',
        ),
      );
    });
  }

  Future<void> correctStatus({
    required LoadRecord load,
    required LoadProgressStatus next,
    required AppUser actor,
    required String reason,
  }) async {
    if (!actor.isAdmin) {
      throw StateError('Only an admin can correct load status.');
    }
    final note = reason.trim();
    if (note.isEmpty || note.length > 800) {
      throw StateError('Enter a reason, up to 800 characters.');
    }
    final ref = _loads.doc(load.id),
        event = _loads.doc(load.id).collection('events').doc();
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) throw StateError('Load no longer exists.');
      final current = LoadRecord.fromFirestore(snapshot.id, snapshot.data()!);
      if (current.status != load.status) {
        throw StateError(
          'Status changed. Close this form and review the latest load.',
        );
      }
      if (next == current.status) {
        throw StateError('Choose a different status.');
      }
      tx.update(ref, {
        if (next == LoadProgressStatus.delivered)
          'officeDelivery': {
            'confirmedBy': actor.uid,
            'confirmedAt': FieldValue.serverTimestamp(),
            'reason': note,
          },
        'status': next.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastEventId': event.id,
      });
      tx.set(
        event,
        _eventData(
          actor: actor,
          type: 'status_corrected',
          status: next,
          note: '${current.status.label} → ${next.label}: $note',
        ),
      );
    });
  }

  Future<void> adjustSchedule({
    required String loadId,
    required AppUser actor,
    DateTime? pickupAt,
    bool cancel = false,
  }) async {
    final ref = _loads.doc(loadId);
    final event = ref.collection('events').doc();
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) throw StateError('This load no longer exists.');
      final current = LoadRecord.fromFirestore(snapshot.id, snapshot.data()!);
      if (current.isClosed) throw StateError('This load is already closed.');
      if (!cancel && current.status != LoadProgressStatus.assigned) {
        throw StateError(
          'The driver has already started this load. Refresh to see the latest progress.',
        );
      }
      if (!cancel && pickupAt == null) {
        throw StateError('Choose a pickup date and time.');
      }
      if (!cancel &&
          current.scheduledDeliveryAt != null &&
          pickupAt!.isAfter(current.scheduledDeliveryAt!)) {
        throw StateError(
          'Update planned delivery before moving pickup beyond it.',
        );
      }
      final status = cancel ? LoadProgressStatus.cancelled : current.status;
      tx.update(ref, {
        if (cancel) 'status': status.value,
        if (!cancel) 'scheduledPickupAt': Timestamp.fromDate(pickupAt!),
        'lastEventId': event.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        event,
        _eventData(
          actor: actor,
          type: cancel ? 'cancelled' : 'load_updated',
          status: status,
          note: cancel ? 'Cancelled by office' : 'Pickup rescheduled by office',
        ),
      );
    });
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

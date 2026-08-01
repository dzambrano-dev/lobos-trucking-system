import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lobos_trucking/models/delivery_proof.dart';
import 'package:lobos_trucking/models/load_record.dart';

void main() {
  test('load record exposes delivery metadata without loading proof bytes', () {
    final signedAt = DateTime.utc(2026, 8, 1, 19, 30);
    final load = LoadRecord.fromFirestore('load-1', {
      'loadNumber': 'LD-2026-ABC123',
      'clientId': 'client-1',
      'clientName': 'Demo Client',
      'pickupAddress': '100 Pickup Street',
      'deliveryAddress': '200 Delivery Avenue',
      'assignedDriverId': 'driver-1',
      'assignedDriverName': 'Driver One',
      'status': 'delivered',
      'needsAttention': false,
      'delivery': {
        'proofId': 'customerSignature',
        'signedByName': 'Receiving Customer',
        'signedAt': Timestamp.fromDate(signedAt),
        'capturedBy': 'driver-1',
      },
    });

    expect(load.hasDeliveryProof, isTrue);
    expect(load.signedByName, 'Receiving Customer');
    expect(load.signedAt, signedAt);
    expect(load.deliveryCapturedBy, 'driver-1');
  });

  test('delivery proof converts Firestore bytes and timestamp safely', () {
    final signedAt = DateTime.utc(2026, 8, 1, 19, 30);
    final proof = DeliveryProof.fromFirestore({
      'signaturePng': Blob(Uint8List.fromList([137, 80, 78, 71])),
      'signedByName': 'Receiving Customer',
      'signedAt': Timestamp.fromDate(signedAt),
      'capturedBy': 'driver-1',
    });

    expect(proof.signaturePng, orderedEquals([137, 80, 78, 71]));
    expect(proof.signedByName, 'Receiving Customer');
    expect(proof.signedAt, signedAt);
    expect(proof.capturedBy, 'driver-1');
  });

  test('delivery proof rejects a missing byte field', () {
    expect(
      () => DeliveryProof.fromFirestore({
        'signedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 1)),
      }),
      throwsFormatException,
    );
  });
}

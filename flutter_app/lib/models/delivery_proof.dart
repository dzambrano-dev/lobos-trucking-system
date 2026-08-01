import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

/// The immutable proof captured when a customer receives a load.
///
/// We keep the image in a small Firestore subdocument instead of Firebase
/// Storage. That avoids the Storage billing requirement and, just as
/// importantly, keeps the large byte field out of normal load-list queries.
class DeliveryProof {
  const DeliveryProof({
    required this.signaturePng,
    required this.signedByName,
    required this.signedAt,
    required this.capturedBy,
  });

  final Uint8List signaturePng;
  final String signedByName;
  final DateTime signedAt;
  final String capturedBy;

  factory DeliveryProof.fromFirestore(Map<String, dynamic> data) {
    final rawSignature = data['signaturePng'];
    final rawSignedAt = data['signedAt'];

    if (rawSignature is! Blob) {
      throw const FormatException('Delivery proof is missing its signature.');
    }
    if (rawSignedAt is! Timestamp) {
      throw const FormatException('Delivery proof is missing its timestamp.');
    }

    return DeliveryProof(
      signaturePng: rawSignature.bytes,
      signedByName: data['signedByName'] as String? ?? 'Customer',
      signedAt: rawSignedAt.toDate(),
      capturedBy: data['capturedBy'] as String? ?? '',
    );
  }
}

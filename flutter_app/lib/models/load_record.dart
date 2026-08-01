import 'package:cloud_firestore/cloud_firestore.dart';

import 'load_status.dart';

class LoadRecord {
  const LoadRecord({
    required this.id,
    required this.loadNumber,
    required this.clientId,
    required this.clientName,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.scheduledPickupAt,
    required this.assignedDriverId,
    required this.assignedDriverName,
    required this.status,
    required this.needsAttention,
    required this.issueSummary,
    required this.deliveryProofId,
    required this.signedByName,
    required this.signedAt,
    required this.deliveryCapturedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String loadNumber;
  final String clientId;
  final String clientName;
  final String pickupAddress;
  final String deliveryAddress;
  final DateTime? scheduledPickupAt;
  final String assignedDriverId;
  final String assignedDriverName;
  final LoadProgressStatus status;
  final bool needsAttention;
  final String? issueSummary;
  final String? deliveryProofId;
  final String? signedByName;
  final DateTime? signedAt;
  final String? deliveryCapturedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory LoadRecord.fromFirestore(String id, Map<String, dynamic> data) {
    final delivery = data['delivery'] as Map<String, dynamic>?;

    return LoadRecord(
      id: id,
      loadNumber: data['loadNumber'] as String? ?? id,
      clientId: data['clientId'] as String? ?? '',
      clientName: data['clientName'] as String? ?? 'Unknown client',
      pickupAddress: data['pickupAddress'] as String? ?? '',
      deliveryAddress: data['deliveryAddress'] as String? ?? '',
      scheduledPickupAt: _dateFrom(data['scheduledPickupAt']),
      assignedDriverId: data['assignedDriverId'] as String? ?? '',
      assignedDriverName: data['assignedDriverName'] as String? ?? 'Unassigned',
      status: LoadProgressStatus.fromValue(data['status'] as String?),
      needsAttention: data['needsAttention'] == true,
      issueSummary: data['issueSummary'] as String?,
      deliveryProofId: delivery?['proofId'] as String?,
      signedByName: delivery?['signedByName'] as String?,
      signedAt: _dateFrom(delivery?['signedAt']),
      deliveryCapturedBy: delivery?['capturedBy'] as String?,
      createdAt: _dateFrom(data['createdAt']),
      updatedAt: _dateFrom(data['updatedAt']),
    );
  }

  bool get hasDeliveryProof => deliveryProofId != null;
  bool get isComplete => status == LoadProgressStatus.delivered;
  bool get isClosed =>
      status == LoadProgressStatus.delivered ||
      status == LoadProgressStatus.cancelled;

  static DateTime? _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

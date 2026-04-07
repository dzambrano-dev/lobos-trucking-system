import 'package:cloud_firestore/cloud_firestore.dart';

class Invoice {
  final String id; // Firestore doc ID
  final String jobId; // relation to Job
  final String client; // cached for UI
  final double amount;
  final DateTime createdAt;

  final String status; // "pending", "paid", "overdue"
  final String invoiceNumber;
  final String? notes;

  Invoice({
    required this.id,
    required this.jobId,
    required this.client,
    required this.amount,
    required this.createdAt,
    required this.status,
    required this.invoiceNumber,
    this.notes,
  });

  // ================= TO FIRESTORE =================
  Map<String, dynamic> toMap() {
    return {
      "jobId": jobId,
      "client": client,
      "amount": amount,

      // 🔥 FIX: Always store as Firestore Timestamp
      "createdAt": Timestamp.fromDate(createdAt),

      "status": status,
      "invoiceNumber": invoiceNumber,
      "notes": notes,
    };
  }

  // ================= FROM FIRESTORE =================
  factory Invoice.fromFirestore(String id, Map<String, dynamic> map) {
    // 🔥 SAFE timestamp handling (handles multiple formats)
    DateTime parsedDate;

    final rawDate = map["createdAt"];

    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return Invoice(
      id: id,
      jobId: map["jobId"] ?? "",
      client: map["client"] ?? "",
      amount: (map["amount"] as num?)?.toDouble() ?? 0.0,

      createdAt: parsedDate,

      status: map["status"] ?? "pending",

      // 🔥 Better fallback
      invoiceNumber:
          map["invoiceNumber"] ?? "INV-${id.substring(0, 5).toUpperCase()}",

      notes: map["notes"],
    );
  }

  // ================= COPY =================
  Invoice copyWith({
    String? jobId,
    String? client,
    double? amount,
    DateTime? createdAt,
    String? status,
    String? invoiceNumber,
    String? notes,
  }) {
    return Invoice(
      id: id,
      jobId: jobId ?? this.jobId,
      client: client ?? this.client,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      notes: notes ?? this.notes,
    );
  }
}

class Invoice {
  final String id; // Firestore doc ID
  final String jobId; // relation to Job
  final String client; // cached for UI
  final double amount;
  final DateTime createdAt;

  // 🔥 NEW FIELDS
  final String status; // "pending", "paid", "overdue"
  final String invoiceNumber; // human-friendly ID
  final String? notes; // optional notes

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
      "createdAt": createdAt,
      "status": status,
      "invoiceNumber": invoiceNumber,
      "notes": notes,
    };
  }

  // ================= FROM FIRESTORE =================
  factory Invoice.fromFirestore(String id, Map<String, dynamic> map) {
    return Invoice(
      id: id,
      jobId: map["jobId"] ?? "",
      client: map["client"] ?? "",
      amount: (map["amount"] as num?)?.toDouble() ?? 0.0,

      createdAt: map["createdAt"] != null
          ? (map["createdAt"] as dynamic).toDate()
          : DateTime.now(),

      // 🔥 SAFE DEFAULTS
      status: map["status"] ?? "pending",
      invoiceNumber: map["invoiceNumber"] ?? id.substring(0, 6),
      notes: map["notes"],
    );
  }

  // ================= COPY =================
  Invoice copyWith({
    String? jobId,
    String? client,
    double? amount,
    String? status,
    String? invoiceNumber,
    String? notes,
  }) {
    return Invoice(
      id: id,
      jobId: jobId ?? this.jobId,
      client: client ?? this.client,
      amount: amount ?? this.amount,
      createdAt: createdAt,
      status: status ?? this.status,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      notes: notes ?? this.notes,
    );
  }
}

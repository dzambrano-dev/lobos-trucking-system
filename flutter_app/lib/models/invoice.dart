class Invoice {
  final String id; // Firestore doc ID
  final String jobId; // relation to Job
  final String client; // cached for UI (can remove later)
  final double amount;
  final DateTime createdAt;

  Invoice({
    required this.id,
    required this.jobId,
    required this.client,
    required this.amount,
    required this.createdAt,
  });

  // ================= TO FIRESTORE =================
  Map<String, dynamic> toMap() {
    return {
      "jobId": jobId,
      "client": client,
      "amount": amount,
      "createdAt": createdAt, // Firestore handles DateTime
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
    );
  }

  // ================= COPY =================
  Invoice copyWith({String? jobId, String? client, double? amount}) {
    return Invoice(
      id: id,
      jobId: jobId ?? this.jobId,
      client: client ?? this.client,
      amount: amount ?? this.amount,
      createdAt: createdAt,
    );
  }
}

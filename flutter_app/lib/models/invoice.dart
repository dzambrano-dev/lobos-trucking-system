class Invoice {
  final String id;
  final String jobId;
  final String client;
  final double amount;
  final DateTime createdAt;

  Invoice({
    String? id,
    required this.jobId,
    required this.client,
    required this.amount,
    DateTime? createdAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "jobId": jobId,
      "client": client,
      "amount": amount,
      "createdAt": createdAt.toIso8601String(),
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map["id"],
      jobId: map["jobId"],
      client: map["client"],
      amount: (map["amount"] as num).toDouble(),
      createdAt: DateTime.parse(map["createdAt"]),
    );
  }
}

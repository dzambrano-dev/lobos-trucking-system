class Job {
  final String id; // Firestore document ID
  final String clientId; //REAL relationship
  final String clientName; // cached for UI
  final String pickup;
  final String dropoff;
  final double price;
  final String status;
  final String? notes;
  final DateTime createdAt;

  Job({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.pickup,
    required this.dropoff,
    required this.price,
    required this.status,
    required this.createdAt,
    this.notes,
  });

  // ================= TO MAP (Firestore) =================
  Map<String, dynamic> toMap() {
    return {
      "clientId": clientId,
      "clientName": clientName,
      "pickup": pickup,
      "dropoff": dropoff,
      "price": price,
      "status": status,
      "notes": notes,
      "createdAt": createdAt, // Firestore handles DateTime
    };
  }

  // ================= FROM FIRESTORE =================
  factory Job.fromFirestore(String id, Map<String, dynamic> map) {
    return Job(
      id: id,
      clientId: map["clientId"] ?? "",
      clientName: map["clientName"] ?? "",
      pickup: map["pickup"] ?? "",
      dropoff: map["dropoff"] ?? "",
      price: (map["price"] as num?)?.toDouble() ?? 0.0,
      status: map["status"] ?? "pending",
      notes: map["notes"],
      createdAt: map["createdAt"] != null
          ? (map["createdAt"] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  // ================= COPY =================
  Job copyWith({
    String? clientId,
    String? clientName,
    String? pickup,
    String? dropoff,
    double? price,
    String? status,
    String? notes,
  }) {
    return Job(
      id: id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      price: price ?? this.price,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}

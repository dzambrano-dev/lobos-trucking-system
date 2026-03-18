class Job {
  final String id; // unique identifier (important for scaling)
  final String client;
  final String pickup;
  final String dropoff;
  final double price;
  final String status;
  final DateTime createdAt;
  final String? notes; // optional extra info

  Job({
    String? id,
    required this.client,
    required this.pickup,
    required this.dropoff,
    required this.price,
    this.status = "pending",
    this.notes,
    DateTime? createdAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  // Convert Job → Map (for saving)
  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "client": client,
      "pickup": pickup,
      "dropoff": dropoff,
      "price": price,
      "status": status,
      "notes": notes,
      "createdAt": createdAt.toIso8601String(),
    };
  }

  // Convert Map → Job (safe parsing)
  factory Job.fromMap(Map<String, dynamic> map) {
    return Job(
      id: map["id"]?.toString(),
      client: map["client"] ?? "",
      pickup: map["pickup"] ?? "",
      dropoff: map["dropoff"] ?? "",
      price: (map["price"] as num?)?.toDouble() ?? 0.0,
      status: map["status"] ?? "pending",
      notes: map["notes"],
      createdAt: map["createdAt"] != null
          ? DateTime.tryParse(map["createdAt"]) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // Copy method (used for editing later)
  Job copyWith({
    String? client,
    String? pickup,
    String? dropoff,
    double? price,
    String? status,
    String? notes,
  }) {
    return Job(
      id: id,
      client: client ?? this.client,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      price: price ?? this.price,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}

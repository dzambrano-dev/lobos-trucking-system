class Job {
  final String client;
  final String pickup;
  final String dropoff;
  final double price;
  final String status;
  final DateTime createdAt;

  Job({
    required this.client,
    required this.pickup,
    required this.dropoff,
    required this.price,
    this.status = "pending",
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert Job → Map (for saving later)
  Map<String, dynamic> toMap() {
    return {
      "client": client,
      "pickup": pickup,
      "dropoff": dropoff,
      "price": price,
      "status": status,
      "createdAt": createdAt.toIso8601String(),
    };
  }

  // Convert Map → Job (for loading later)
  factory Job.fromMap(Map<String, dynamic> map) {
    return Job(
      client: map["client"],
      pickup: map["pickup"],
      dropoff: map["dropoff"],
      price: map["price"],
      status: map["status"] ?? "pending",
      createdAt: DateTime.parse(map["createdAt"]),
    );
  }
}

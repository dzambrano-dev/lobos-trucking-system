import 'package:cloud_firestore/cloud_firestore.dart';

class ClientRecord {
  const ClientRecord({
    required this.id,
    required this.name,
    required this.contact,
    required this.phone,
    required this.email,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String contact;
  final String phone;
  final String email;
  final String address;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ClientRecord.fromFirestore(String id, Map<String, dynamic> data) {
    return ClientRecord(
      id: id,
      name: data['name'] as String? ?? 'Unnamed client',
      contact: data['contact'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      address: data['address'] as String? ?? '',
      createdAt: _dateFrom(data['createdAt']),
      updatedAt: _dateFrom(data['updatedAt']),
    );
  }

  static DateTime? _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

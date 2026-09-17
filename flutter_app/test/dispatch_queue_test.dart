import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/dispatch_queue.dart';
import 'package:flutter_app/models/load_record.dart';

void main() {
  test('queue keeps overdue work visible and billed deliveries in history', () {
    final today = DateTime(2026, 9, 15, 12);
    LoadRecord load(String status, DateTime date, {bool issue = false}) =>
        LoadRecord.fromFirestore('load', {
          'status': status,
          'scheduledPickupAt': Timestamp.fromDate(date),
          'needsAttention': issue,
        });
    expect(
      dispatchGroup(load('assigned', DateTime(2026, 9, 14)), {}, today),
      0,
    );
    expect(dispatchGroup(load('assigned', today), {}, today), 1);
    expect(dispatchGroup(load('delivered', today), {}, today), 2);
    expect(
      dispatchGroup(load('assigned', DateTime(2026, 9, 16)), {}, today),
      3,
    );
    expect(dispatchGroup(load('delivered', today), {'load'}, today), 4);
    expect(
      dispatchGroup(load('delivered', today, issue: true), {'load'}, today),
      0,
    );
    expect(dispatchGroup(load('cancelled', today), {}, today), 4);
  });
}

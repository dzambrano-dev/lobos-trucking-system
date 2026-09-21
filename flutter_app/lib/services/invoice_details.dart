import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'operations.dart';

String invoiceLabel(Record row) =>
    (row['invoiceNumber'] ?? row['id'] ?? '').toString();
String invoiceClient(Record row) =>
    (row['client'] ?? row['clientName'] ?? 'Unknown client').toString();
String invoiceSearchText(Record row) {
  final dates = [
    row['createdAt'],
    row['pickupDate'],
    row['dueDate'],
  ].map(dateOf).whereType<DateTime>();
  return [
    ...row.values.map((v) => v.toString()),
    invoiceLabel(row),
    invoiceClient(row),
    for (final d in dates)
      '${DateFormat('yyyy-MM-dd').format(d)} ${DateFormat.yMd().format(d)} ${DateFormat.yMMMd().format(d)}',
  ].join(' ').toLowerCase();
}

String invoiceReferences(Record row) => [
  if ((row['loadNumber'] ?? '').toString().isNotEmpty)
    'Load #: ${row['loadNumber']}',
  if ((row['pickupNumber'] ?? '').toString().isNotEmpty)
    'Pickup #: ${row['pickupNumber']}',
  if ((row['reference'] ?? '').toString().isNotEmpty)
    'Reference #: ${row['reference']}',
  if ((row['jobId'] ?? '').toString().isNotEmpty) 'Job #: ${row['jobId']}',
].join(' · ');

class InvoiceDetails {
  InvoiceDetails(this.db);
  final FirebaseFirestore db;
  final jobs = <String, Record>{}, loads = <String, Record>{};
  Future<List<Record>> readIds(String collection, Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    final result = <Record>[];
    for (var i = 0; i < unique.length; i += 30) {
      final docs = await db
          .collection(collection)
          .where(
            FieldPath.documentId,
            whereIn: unique.sublist(i, (i + 30).clamp(0, unique.length)),
          )
          .get(const GetOptions(source: Source.server));
      result.addAll(docs.docs.map((d) => {...d.data(), 'id': d.id}));
    }
    return result;
  }

  Future<void> cache(
    String collection,
    Iterable<String> ids,
    Map<String, Record> target,
  ) async {
    final missing = ids
        .where((id) => id.isNotEmpty && !target.containsKey(id))
        .toSet();
    if (missing.isEmpty) return;
    final rows = await readIds(collection, missing);
    for (final id in missing) {
      target[id] = {};
    }
    for (final row in rows) {
      target[row['id'] as String] = row;
    }
  }

  Future<List<Record>> enrich(List<Record> rows) async {
    final legacy = rows.where((r) => r['metadataVersion'] != 1).toList();
    await cache('jobs', legacy.map((r) => (r['jobId'] ?? '').toString()), jobs);
    await cache(
      'loads',
      legacy.map((r) => (jobs[r['jobId']]?['loadId'] ?? '').toString()),
      loads,
    );
    return rows.map((r) {
      if (r['metadataVersion'] == 1) return r;
      final job = jobs[r['jobId']] ?? {}, load = loads[job['loadId']] ?? {};
      return {
        ...r,
        'loadNumber':
            r['loadNumber'] ?? load['loadNumber'] ?? job['loadNumber'] ?? '',
        'pickupNumber':
            r['pickupNumber'] ??
            load['pickupNumber'] ??
            job['pickupNumber'] ??
            '',
        'reference':
            r['reference'] ?? job['reference'] ?? load['reference'] ?? '',
        'pickupDate':
            r['pickupDate'] ??
            job['scheduledDate'] ??
            load['scheduledPickupAt'],
        'pickup': r['pickup'] ?? job['pickup'] ?? load['pickupAddress'],
        'dropoff': r['dropoff'] ?? job['dropoff'] ?? load['deliveryAddress'],
      };
    }).toList();
  }
}

void validateStatement(List<Record> invoices) {
  if (invoices.length < 2) throw StateError('Select at least two invoices.');
  final client = (invoices.first['clientId'] ?? '').toString();
  if (client.isEmpty || invoices.any((i) => i['clientId'] != client)) {
    throw StateError('Every invoice must have the same verified client ID.');
  }
  final ids = invoices.map((i) => (i['id'] ?? '').toString()).toSet();
  if (ids.contains('') || ids.length != invoices.length) {
    throw StateError('Duplicate or missing invoice identifiers.');
  }
}

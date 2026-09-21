import 'package:cloud_firestore/cloud_firestore.dart';

typedef Record = Map<String, dynamic>;

DateTime? dateOf(dynamic value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
    ? value
    : value is String
    ? DateTime.tryParse(value)
    : null;
double number(dynamic value) => value is num ? value.toDouble() : 0;
int cents(dynamic value) => (number(value) * 100).round();
String money(dynamic value) => '\$${number(value).toStringAsFixed(2)}';
String shortDate(dynamic value) {
  final d = dateOf(value);
  return d == null ? 'Not scheduled' : '${d.month}/${d.day}/${d.year}';
}

double paidAmount(Record invoice) => invoice.containsKey('amountPaid')
    ? number(invoice['amountPaid'])
    : invoice['status'] == 'paid'
    ? number(invoice['amount'])
    : 0;
double balanceOf(Record invoice) {
  final remaining = cents(invoice['amount']) - cents(paidAmount(invoice));
  return remaining > 0 ? remaining / 100 : 0;
}

String invoiceStatus(Record invoice, [DateTime? now]) {
  if (balanceOf(invoice) == 0) return 'paid';
  final due = dateOf(invoice['dueDate']);
  final today = now ?? DateTime.now();
  if (due != null &&
      DateTime(
        due.year,
        due.month,
        due.day,
      ).isBefore(DateTime(today.year, today.month, today.day))) {
    return 'overdue';
  }
  if (due == null && invoice['status'] == 'overdue') return 'overdue';
  return paidAmount(invoice) > 0 ? 'partial' : 'pending';
}

/// All mutations go through one service. Financial writes use transactions.
class Operations {
  Operations([FirebaseFirestore? database])
    : db = database ?? FirebaseFirestore.instance;
  final FirebaseFirestore db;
  Future<void> saveCompany(Record data) async {
    if ((data['name'] ?? '').toString().trim().isEmpty ||
        (data['address'] ?? '').toString().trim().isEmpty) {
      throw StateError('Company name and remittance address are required.');
    }
    await db.collection('settings').doc('company').set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Record>> watch(String collection) =>
      db.collection(collection).snapshots().map((s) {
        final rows = s.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        rows.sort(
          (a, b) => (dateOf(b['createdAt']) ?? DateTime(1970)).compareTo(
            dateOf(a['createdAt']) ?? DateTime(1970),
          ),
        );
        return rows;
      });

  Future<void> save(String collection, Record data, {String? id}) async {
    if (!['clients', 'jobs', 'expenses', 'invoices'].contains(collection)) {
      throw StateError('Unsupported record type.');
    }
    if (collection == 'jobs' || collection == 'expenses') {
      final value = number(data[collection == 'jobs' ? 'price' : 'amount']);
      if (!value.isFinite ||
          value <= 0 ||
          value > 999999999 ||
          (value * 100 - (value * 100).round()).abs() > 0.00001) {
        throw StateError('Enter a positive amount with up to two decimals.');
      }
    }
    if (collection == 'clients' &&
        (data['name'] ?? '').toString().trim().isEmpty) {
      throw StateError('A company name is required.');
    }
    if (collection == 'invoices' &&
        (id == null ||
            data.keys.any((k) => !['dueDate', 'notes'].contains(k)))) {
      throw StateError('Only invoice due dates and notes can be edited.');
    }
    final ref = db.collection(collection).doc(id);
    if (collection == 'jobs') {
      if (id != null) {
        final billed = await db
            .collection('invoices')
            .where('jobId', isEqualTo: id)
            .limit(1)
            .get();
        if (billed.docs.isNotEmpty) {
          throw StateError('This job has been invoiced and is locked.');
        }
      }
      await db.runTransaction((tx) async {
        final current = await tx.get(ref);
        final client = await tx.get(
          db.collection('clients').doc(data['clientId'] as String),
        );
        if (!client.exists || client.data()?['archived'] == true) {
          throw StateError('Choose an active client.');
        }
        if (current.data()?['invoiceId'] != null) {
          throw StateError('This job has been invoiced and is locked.');
        }
        if (id != null && !current.exists) {
          throw StateError('This job no longer exists.');
        }
        tx.set(ref, {
          ...data,
          'clientName': client.data()!['name'],
          if (id == null) 'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } else {
      final changes = {
        ...data,
        if (id == null) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (id == null) {
        await ref.set(changes);
      } else {
        await ref.update(changes);
      }
    }
  }

  Future<void> archive(String collection, String id, bool archived) async {
    await db.collection(collection).doc(id).update({
      'archived': archived,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> billDeliveredLoad(String loadId, double amount) async {
    if (!amount.isFinite ||
        amount <= 0 ||
        amount > 999999999 ||
        (amount * 100 - (amount * 100).round()).abs() > 0.00001) {
      throw StateError('Enter a positive amount with up to two decimals.');
    }
    final jobId = 'load_$loadId';
    final ref = db.collection('jobs').doc(jobId);
    await db.runTransaction((tx) async {
      final load = await tx.get(db.collection('loads').doc(loadId));
      final existing = await tx.get(ref);
      if (!load.exists || load.data()?['status'] != 'delivered') {
        throw StateError('The driver must complete delivery before billing.');
      }
      if (existing.exists) {
        if (existing.data()?['loadId'] != loadId) {
          throw StateError('Billing reference conflict.');
        }
        return;
      }
      final data = load.data()!;
      final client = await tx.get(
        db.collection('clients').doc(data['clientId'] as String),
      );
      if (!client.exists || client.data()?['archived'] == true) {
        throw StateError('Restore the client before billing.');
      }
      tx.set(ref, {
        'loadId': loadId,
        'clientId': data['clientId'],
        'clientName': data['clientName'],
        'pickup': data['pickupAddress'],
        'dropoff': data['deliveryAddress'],
        'driver': data['assignedDriverName'],
        'reference': (data['reference'] ?? '').toString().isNotEmpty
            ? data['reference']
            : data['loadNumber'],
        'loadNumber': data['loadNumber'],
        'pickupNumber': data['pickupNumber'] ?? '',
        'scheduledDate': data['scheduledPickupAt'],
        'price': amount,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return invoiceJob(jobId);
  }

  Future<String> invoiceJob(String jobId) async {
    // Legacy invoices used random IDs. Resolve those before creating the
    // deterministic per-job invoice used by the new transaction protocol.
    final legacy = await db
        .collection('invoices')
        .where('jobId', isEqualTo: jobId)
        .get();
    if (legacy.docs.length > 1) {
      throw StateError(
        'Multiple invoices already reference this job. Ask the owner to reconcile them before continuing.',
      );
    }
    final jobRef = db.collection('jobs').doc(jobId);
    final ref = db.collection('invoices').doc(jobId);
    return db.runTransaction((tx) async {
      final job = await tx.get(jobRef);
      final existing = await tx.get(ref);
      final data = job.data();
      if (data == null) throw StateError('Job no longer exists.');
      final linked = data['invoiceId'] as String?;
      if (linked != null) {
        final invoice = await tx.get(db.collection('invoices').doc(linked));
        if (!invoice.exists || invoice.data()?['jobId'] != jobId) {
          throw StateError(
            'The invoice link is invalid. Ask the owner to reconcile this job.',
          );
        }
        return linked;
      }
      if (existing.exists && existing.data()?['jobId'] != jobId) {
        throw StateError(
          'An unrelated invoice uses this job identifier. Ask the owner to reconcile the records.',
        );
      }
      if (existing.exists || legacy.docs.isNotEmpty) {
        final id = existing.exists ? ref.id : legacy.docs.first.id;
        tx.update(jobRef, {'invoiceId': id});
        return id;
      }
      if (data['status'] != 'completed' || data['archived'] == true) {
        throw StateError(
          'Complete this active job before creating an invoice.',
        );
      }
      if (cents(data['price']) <= 0) {
        throw StateError('Enter a positive job rate first.');
      }
      final now = DateTime.now();
      final customer = await tx.get(
        db.collection('clients').doc(data['clientId'] as String),
      );
      if (!customer.exists) {
        throw StateError(
          'The client record is missing. Restore it before invoicing.',
        );
      }
      final loadId = (data['loadId'] ?? '').toString();
      final load = loadId.isEmpty
          ? <String, dynamic>{}
          : (await tx.get(db.collection('loads').doc(loadId))).data() ??
                <String, dynamic>{};
      tx.set(ref, {
        'metadataVersion': 1,
        'loadNumber': data['loadNumber'] ?? load['loadNumber'] ?? '',
        'pickupNumber': data['pickupNumber'] ?? load['pickupNumber'] ?? '',
        'reference': data['reference'] ?? load['reference'] ?? '',
        'pickupDate': data['scheduledDate'] ?? load['scheduledPickupAt'],
        'jobId': jobId,
        'clientId': data['clientId'],
        'client': customer.data()!['name'],
        'clientAddress': customer.data()!['address'] ?? '',
        'clientEmail': customer.data()!['email'] ?? '',
        'pickup': data['pickup'],
        'dropoff': data['dropoff'],
        'amount': cents(data['price']) / 100,
        'amountPaid': 0,
        'status': 'pending',
        'invoiceNumber': 'INV-${jobId.toUpperCase()}',
        'createdAt': Timestamp.fromDate(now),
        'dueDate': Timestamp.fromDate(now.add(const Duration(days: 30))),
        'notes': '',
      });
      tx.update(jobRef, {'invoiceId': ref.id});
      return ref.id;
    });
  }

  Future<void> recordPayment(
    String invoiceId,
    double amount,
    String reference, {
    required String paymentId,
  }) async {
    if (!amount.isFinite ||
        cents(amount) <= 0 ||
        amount > 999999999 ||
        (amount * 100 - (amount * 100).round()).abs() > 0.00001) {
      throw StateError('Enter a positive payment with up to two decimals.');
    }
    if (reference.trim().isEmpty) {
      throw StateError('Enter a payment reference.');
    }
    final ref = db.collection('invoices').doc(invoiceId);
    final payment = db.collection('payments').doc(paymentId);
    await db.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final prior = await tx.get(payment);
      if (prior.exists) {
        if (prior.data()?['invoiceId'] != invoiceId ||
            cents(prior.data()?['amount']) != cents(amount) ||
            prior.data()?['reference'] != reference.trim()) {
          throw StateError(
            'This payment was already recorded with different details. Reopen the payment form.',
          );
        }
        return; // Retrying the same submitted payment is safe.
      }
      final data = snapshot.data();
      if (data == null) throw StateError('Invoice no longer exists.');
      final amountCents = cents(amount);
      if (amountCents > cents(balanceOf(data))) {
        throw StateError('Payment exceeds the outstanding balance.');
      }
      final total = cents(paidAmount(data)) + amountCents;
      tx.set(payment, {
        'invoiceId': invoiceId,
        'amount': amountCents / 100,
        'reference': reference.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        'amountPaid': total / 100,
        'lastPaymentId': payment.id,
        'status': total >= cents(data['amount']) ? 'paid' : 'partial',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Corrects a recorded receipt; this does not initiate a bank refund.
  Future<void> reversePayment(String paymentId, String reason) async {
    if (reason.trim().isEmpty) {
      throw StateError('Enter a reason for the correction.');
    }
    final paymentRef = db.collection('payments').doc(paymentId);
    final reversalRef = db.collection('payment_reversals').doc(paymentId);
    await db.runTransaction((tx) async {
      final payment = await tx.get(paymentRef);
      final prior = await tx.get(reversalRef);
      if (prior.exists) return;
      final p = payment.data();
      if (p == null) throw StateError('Payment no longer exists.');
      final invoiceRef = db
          .collection('invoices')
          .doc(p['invoiceId'] as String);
      final invoice = await tx.get(invoiceRef);
      final data = invoice.data();
      if (data == null) throw StateError('Invoice no longer exists.');
      final total = cents(paidAmount(data)) - cents(p['amount']);
      if (total < 0) {
        throw StateError(
          'The balance does not match this payment. Ask the owner to reconcile the invoice.',
        );
      }
      tx.set(reversalRef, {
        'invoiceId': invoiceRef.id,
        'paymentId': paymentId,
        'amount': p['amount'],
        'reason': reason.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(invoiceRef, {
        'amountPaid': total / 100,
        'status': total == 0 ? 'pending' : 'partial',
        'lastReversalId': paymentId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

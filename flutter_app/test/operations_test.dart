import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/operations.dart';

void main() {
  late FakeFirebaseFirestore db;
  late Operations store;
  setUp(() async {
    db = FakeFirebaseFirestore();
    store = Operations(db);
    await db.collection('clients').doc('client').set({'name': 'Acme'});
    await db.collection('jobs').doc('job').set({
      'clientId': 'client',
      'clientName': 'Acme',
      'pickup': 'Yard',
      'dropoff': 'Site',
      'price': 100.30,
      'status': 'completed',
    });
  });
  test('invoice is idempotent and locks the source job', () async {
    final first = await store.invoiceJob('job');
    expect(await store.invoiceJob('job'), first);
    expect((await db.collection('invoices').get()).docs, hasLength(1));
    expect(
      (await db.collection('jobs').doc('job').get()).data()!['invoiceId'],
      first,
    );
    await expectLater(
      store.save('jobs', {'clientId': 'client', 'price': 200}, id: 'job'),
      throwsStateError,
    );
  });
  test('legacy invoices are linked instead of duplicated', () async {
    await db.collection('invoices').doc('legacy').set({
      'jobId': 'job',
      'amount': 100.30,
    });
    expect(await store.invoiceJob('job'), 'legacy');
    expect((await db.collection('invoices').get()).docs, hasLength(1));
  });
  test('incomplete jobs cannot be invoiced', () async {
    await db.collection('jobs').doc('job').update({'status': 'pending'});
    await expectLater(store.invoiceJob('job'), throwsStateError);
    expect((await db.collection('invoices').get()).docs, isEmpty);
  });
  test('ambiguous legacy invoices and broken links block invoicing', () async {
    await db.collection('invoices').doc('one').set({
      'jobId': 'job',
      'amount': 100,
    });
    await db.collection('invoices').doc('two').set({
      'jobId': 'job',
      'amount': 100,
    });
    await expectLater(store.invoiceJob('job'), throwsStateError);
    await db.collection('invoices').doc('two').delete();
    await db.collection('jobs').doc('job').update({'invoiceId': 'missing'});
    await expectLater(store.invoiceJob('job'), throwsStateError);
  });
  test(
    'payment reversal is idempotent and preserves original history',
    () async {
      final id = await store.invoiceJob('job');
      await store.recordPayment(id, 100.30, 'Check', paymentId: 'p1');
      await store.reversePayment('p1', 'Wrong invoice');
      await store.reversePayment('p1', 'Retry');
      final invoice = (await db.collection('invoices').doc(id).get()).data()!;
      expect(balanceOf(invoice), 100.30);
      expect(paidAmount(invoice), 0);
      expect(
        (await db.collection('payments').doc('p1').get()).data()!['amount'],
        100.30,
      );
      expect(
        (await db.collection('payment_reversals').get()).docs,
        hasLength(1),
      );
      await store.recordPayment(id, 50, 'Correct check', paymentId: 'p2');
      expect(
        balanceOf((await db.collection('invoices').doc(id).get()).data()!),
        50.30,
      );
    },
  );
  test(
    'partial payments, retries, overpayment and settlement use cents',
    () async {
      final id = await store.invoiceJob('job');
      await store.recordPayment(id, 30.10, 'Check 123', paymentId: 'p1');
      await store.recordPayment(id, 30.10, 'Check 123', paymentId: 'p1');
      var invoice = (await db.collection('invoices').doc(id).get()).data()!;
      expect(paidAmount(invoice), 30.10);
      expect(balanceOf(invoice), 70.20);
      expect(invoiceStatus(invoice), 'partial');
      await expectLater(
        store.recordPayment(id, 70.21, 'Too much', paymentId: 'p2'),
        throwsStateError,
      );
      await store.recordPayment(id, 70.20, 'ACH', paymentId: 'p3');
      invoice = (await db.collection('invoices').doc(id).get()).data()!;
      expect(balanceOf(invoice), 0);
      expect(invoiceStatus(invoice), 'paid');
      expect((await db.collection('payments').get()).docs, hasLength(2));
    },
  );
  test('invalid payment amounts are rejected without writing', () async {
    final id = await store.invoiceJob('job');
    for (final amount in [0.0, -2.0, double.nan, double.infinity]) {
      await expectLater(
        store.recordPayment(id, amount, 'Invalid', paymentId: 'bad'),
        throwsStateError,
      );
    }
    expect((await db.collection('payments').get()).docs, isEmpty);
  });
  test(
    'overdue is derived by calendar date and paid legacy invoices retain balance',
    () {
      expect(
        invoiceStatus({
          'amount': 100,
          'dueDate': Timestamp.fromDate(DateTime(2026, 9, 9)),
        }, DateTime(2026, 9, 10)),
        'overdue',
      );
      expect(
        invoiceStatus({
          'amount': 100,
          'dueDate': DateTime(2026, 9, 10),
        }, DateTime(2026, 9, 10, 23)),
        'pending',
      );
      expect(balanceOf({'amount': 100, 'status': 'paid'}), 0);
      expect(dateOf('2026-09-10'), DateTime(2026, 9, 10));
      expect(dateOf('broken'), isNull);
    },
  );
  test('archive and restore preserve customer history', () async {
    await store.archive('clients', 'client', true);
    expect((await db.collection('jobs').doc('job').get()).exists, isTrue);
    await expectLater(
      store.save('jobs', {'clientId': 'client'}, id: 'job'),
      throwsStateError,
    );
    await store.archive('clients', 'client', false);
    expect(
      (await db.collection('clients').doc('client').get()).data()!['archived'],
      false,
    );
  });
}

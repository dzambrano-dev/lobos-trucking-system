import 'package:cloud_firestore/cloud_firestore.dart';
import 'operations.dart';

class ExpenseAccounts {
  ExpenseAccounts(this.db);
  final FirebaseFirestore db;
  void validate(double amount) {
    if (!amount.isFinite ||
        amount <= 0 ||
        amount > 999999999 ||
        (amount * 100 - (amount * 100).round()).abs() > 0.00001) {
      throw StateError('Enter a positive amount with up to two decimals.');
    }
  }

  Future<void> save(
    Record data, {
    required String id,
    bool paidNow = false,
  }) async {
    validate(number(data['amount']));
    final ref = db.collection('expenses').doc(id);
    final receipt = db.collection('expense_payments').doc('opening_$id');
    await db.runTransaction((tx) async {
      final old = await tx.get(ref);
      final previous = old.data();
      final changes = Map<String, dynamic>.from(data)
        ..remove('paymentState')
        ..remove('paidAt');
      if (previous != null) {
        if (cents(data['amount']) < cents(previous['amountPaid'])) {
          throw StateError(
            'The bill cannot be less than payments already recorded.',
          );
        }
        tx.update(ref, {...changes, 'updatedAt': FieldValue.serverTimestamp()});
        return;
      }
      tx.set(ref, {
        ...changes,
        'amountPaid': paidNow ? data['amount'] : 0,
        'paymentReviewed': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (paidNow) 'lastPaymentId': receipt.id,
      });
      if (paidNow) {
        tx.set(receipt, {
          'expenseId': id,
          'amount': data['amount'],
          'reference': 'Paid when bill was entered',
          'paidAt': data['paidAt'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> reviewUnpaid(String id) =>
      db.collection('expenses').doc(id).update({
        'paymentReviewed': true,
        'amountPaid': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> pay(String id, Record data, String paymentId) async {
    validate(number(data['amount']));
    final ref = db.collection('expenses').doc(id);
    final receipt = db.collection('expense_payments').doc(paymentId);
    await db.runTransaction((tx) async {
      final bill = await tx.get(ref);
      final prior = await tx.get(receipt);
      if (prior.exists) {
        if (prior.data()?['expenseId'] != id ||
            cents(prior.data()?['amount']) != cents(data['amount'])) {
          throw StateError('Payment reference conflict.');
        }
        return;
      }
      if (!bill.exists) throw StateError('Bill no longer exists.');
      final total = cents(bill.data()?['amountPaid']) + cents(data['amount']);
      if (total > cents(bill.data()?['amount'])) {
        throw StateError('Payment exceeds the amount owed.');
      }
      tx.set(receipt, {
        ...data,
        'expenseId': id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        'amountPaid': total / 100,
        'paymentReviewed': true,
        'lastPaymentId': paymentId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> reverse(String id, String reason) async {
    if (reason.trim().isEmpty) throw StateError('Enter a reason.');
    final payment = db.collection('expense_payments').doc(id);
    final reversal = db.collection('expense_reversals').doc(id);
    await db.runTransaction((tx) async {
      final p = await tx.get(payment), existing = await tx.get(reversal);
      if (existing.exists) return;
      if (!p.exists) throw StateError('Payment no longer exists.');
      final ref = db
          .collection('expenses')
          .doc(p.data()!['expenseId'] as String);
      final bill = await tx.get(ref);
      final total =
          cents(bill.data()?['amountPaid']) - cents(p.data()?['amount']);
      if (!bill.exists || total < 0) {
        throw StateError('Payment balance needs review.');
      }
      tx.set(reversal, {
        'expenseId': ref.id,
        'paymentId': id,
        'amount': p.data()!['amount'],
        'reason': reason.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        'amountPaid': total / 100,
        'lastReversalId': id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

String expenseStatus(Record bill) => bill['paymentReviewed'] != true
    ? 'Needs review'
    : cents(bill['amountPaid']) >= cents(bill['amount'])
    ? 'Paid'
    : cents(bill['amountPaid']) > 0
    ? 'Partially paid'
    : 'Unpaid';

Map<String, int> expenseSummary(
  Map<String, List<Record>> data,
  DateTime month,
) {
  bool within(Object? date) {
    final d = dateOf(date);
    return d != null && d.year == month.year && d.month == month.month;
  }

  int sum(String name, String field, String date) => (data[name] ?? [])
      .where((r) => within(r[date]))
      .fold(0, (a, r) => a + cents(r[field]));
  final incurred = sum('expenses', 'amount', 'expenseDate');
  int activePayments(String payments, String reversals, String date) {
    final reversed = (data[reversals] ?? [])
        .map((r) => r['paymentId'] ?? r['id'])
        .whereType<String>()
        .toSet();
    return (data[payments] ?? [])
        .where((r) => !reversed.contains(r['id']) && within(r[date]))
        .fold(0, (a, r) => a + cents(r['amount']));
  }

  final cashOut = activePayments(
    'expense_payments',
    'expense_reversals',
    'paidAt',
  );
  final cashIn = activePayments('payments', 'payment_reversals', 'createdAt');
  return {
    'incurred': incurred,
    'cashOut': cashOut,
    'cashIn': cashIn,
    'profit': sum('invoices', 'amount', 'createdAt') - incurred,
    'netCash': cashIn - cashOut,
    'owed': (data['expenses'] ?? [])
        .where((r) => r['paymentReviewed'] == true)
        .fold(0, (a, r) => a + cents(r['amount']) - cents(r['amountPaid'])),
    'review': (data['expenses'] ?? [])
        .where((r) => r['paymentReviewed'] != true)
        .length,
  };
}

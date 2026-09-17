import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/expense_accounts.dart';

void main() {
  test(
    'bill payments are partial, bounded, retry safe and reversible',
    () async {
      final db = FakeFirebaseFirestore(),
          date = Timestamp.fromDate(DateTime(2026, 9, 15));
      final accounts = ExpenseAccounts(db);
      await accounts.save({
        'amount': 500,
        'category': 'Fuel',
        'expenseDate': date,
      }, id: 'bill');
      await accounts.pay('bill', {
        'amount': 200,
        'paidAt': date,
        'reference': 'Check',
      }, 'payment');
      await accounts.pay('bill', {
        'amount': 200,
        'paidAt': date,
        'reference': 'Check',
      }, 'payment');
      expect(
        (await db.collection('expenses').doc('bill').get())
            .data()!['amountPaid'],
        200,
      );
      expect(
        (await db.collection('expense_payments').get()).docs,
        hasLength(1),
      );
      await expectLater(
        accounts.pay('bill', {
          'amount': 301,
          'paidAt': date,
          'reference': 'Check',
        }, 'over'),
        throwsStateError,
      );
      await expectLater(
        accounts.save({'amount': 100}, id: 'bill'),
        throwsStateError,
      );
      await accounts.reverse('payment', 'Wrong entry');
      await accounts.reverse('payment', 'Retry');
      expect(
        (await db.collection('expenses').doc('bill').get())
            .data()!['amountPaid'],
        0,
      );
      expect(
        (await db.collection('expense_payments').get()).docs,
        hasLength(1),
      );
    },
  );
  test(
    'paid on entry creates one receipt; legacy payment state stays unknown',
    () async {
      final db = FakeFirebaseFirestore();
      final store = ExpenseAccounts(db);
      final data = {
        'amount': 50,
        'category': 'Fuel',
        'expenseDate': Timestamp.now(),
        'paidAt': Timestamp.now(),
      };
      await store.save(data, id: 'paid', paidNow: true);
      await store.save(data, id: 'paid', paidNow: true);
      expect(
        (await db.collection('expense_payments').get()).docs,
        hasLength(1),
      );
      expect(expenseStatus({'amount': 50}), 'Needs review');
      await db.collection('expenses').doc('legacy').set({'amount': 50});
      await store.reviewUnpaid('legacy');
      expect(
        expenseStatus(
          (await db.collection('expenses').doc('legacy').get()).data()!,
        ),
        'Unpaid',
      );
    },
  );
  test(
    'month summary separates incurred costs, actual cash and outstanding bills',
    () {
      final sept = DateTime(2026, 9, 15), oct = DateTime(2026, 10, 2);
      final result = expenseSummary({
        'expenses': [
          {
            'amount': 500,
            'amountPaid': 200,
            'paymentReviewed': true,
            'expenseDate': sept,
          },
          {'amount': 50, 'expenseDate': sept},
        ],
        'expense_payments': [
          {'amount': 200, 'paidAt': oct},
        ],
        'invoices': [
          {'amount': 1000, 'createdAt': sept},
        ],
        'payments': [
          {'id': 'receipt', 'amount': 400, 'createdAt': sept},
          {'id': 'mistake', 'amount': 100, 'createdAt': sept},
        ],
        'payment_reversals': [
          {'paymentId': 'mistake', 'amount': 100, 'createdAt': oct},
        ],
      }, sept);
      expect(result['incurred'], 55000);
      expect(result['owed'], 30000);
      expect(result['cashOut'], 0);
      expect(result['cashIn'], 40000);
      expect(result['profit'], 45000);
      expect(result['review'], 1);
    },
  );
}

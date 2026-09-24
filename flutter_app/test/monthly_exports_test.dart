import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/monthly_exports.dart';

void main() {
  test('CSV escapes quotes, commas, Unicode and spreadsheet formulas', () {
    final csv = csvText([
      ['Vendor, "East"', '=SUM(A1)', '  @danger', 'Lobos é'],
      [-5],
    ]);
    expect(
      csvText([
        ['-200.00'],
      ]),
      contains('"-200.00"'),
    );
    expect(csv, startsWith('\ufeff'));
    expect(csv, contains('"Vendor, ""East"""'));
    expect(csv, contains("\"'=SUM(A1)\""));
    expect(csv, contains("\"'  @danger\""));
    expect(csv, contains('"-5"'));
  });
  test(
    'exports separate current balances, monthly activity and reversed payments',
    () {
      final month = DateTime(2026, 9), prior = DateTime(2026, 8);
      final reports = monthlyExports({
        'expenses': [
          {
            'id': 'fuel',
            'amount': 500,
            'amountPaid': 200,
            'paymentReviewed': true,
            'expenseDate': month,
            'category': 'Fuel',
          },
          {
            'id': 'old',
            'amount': 80,
            'amountPaid': 0,
            'paymentReviewed': true,
            'expenseDate': prior,
          },
          {'id': 'unknown', 'amount': 50, 'expenseDate': prior},
          {
            'id': 'old-paid',
            'amount': 30,
            'amountPaid': 30,
            'paymentReviewed': true,
            'expenseDate': prior,
          },
        ],
        'invoices': [
          {
            'id': 'invoice',
            'amount': 1000,
            'amountPaid': 200,
            'createdAt': month,
          },
        ],
        'expense_payments': [
          {
            'id': 'payment',
            'expenseId': 'fuel',
            'amount': 200,
            'paidAt': month,
            'reference': 'Cash',
          },
        ],
        'payments': [
          {
            'id': 'mistake',
            'invoiceId': 'invoice',
            'amount': 100,
            'createdAt': month,
          },
        ],
        'payment_reversals': [
          {'paymentId': 'mistake', 'createdAt': DateTime(2026, 10)},
        ],
      }, month);
      expect(reports['summary'], contains('"Expense balance owed","380.00"'));
      expect(reports['summary'], contains('"Customer balance owed","800.00"'));
      expect(reports['summary'], contains('"Customer receipts","0.00"'));
      expect(reports['expenses'], contains('"old"'));
      expect(reports['expenses'], contains('"unknown"'));
      expect(reports['expenses'], isNot(contains('"old-paid"')));
      expect(reports['payments'], contains('"100.00","0.00","Reversed"'));
      expect(
        reports['summary'],
        contains('"Operating profit estimate","500.00"'),
      );
    },
  );
}

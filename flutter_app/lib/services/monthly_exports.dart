import 'operations.dart';
import 'expense_accounts.dart';

String csvText(List<List<Object?>> rows) =>
    '\ufeff${rows.map((row) => row.map((value) {
      var text = value?.toString() ?? '';
      // Treat user-entered spreadsheet formulas as text, including leading whitespace.
      if (value is String && !RegExp(r'^-?[0-9]+(?:\.[0-9]+)?$').hasMatch(text) && RegExp(r'^[\s]*[=+@-]|^[\t\r\n]').hasMatch(text)) {
        text = "'$text";
      }
      return '"${text.replaceAll('"', '""')}"';
    }).join(',')).join('\r\n')}\r\n';

String reportDate(Object? value) {
  final d = dateOf(value);
  return d == null
      ? ''
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Map<String, String> monthlyExports(
  Map<String, List<Record>> data,
  DateTime month,
) {
  bool within(Object? value) {
    final d = dateOf(value);
    return d != null && d.year == month.year && d.month == month.month;
  }

  final period = reportDate(month).substring(0, 7);
  final summary = expenseSummary(data, month);
  String amount(Object? n) => (cents(n) / 100).toStringAsFixed(2);
  final bills = data['expenses'] ?? [];
  final invoices = data['invoices'] ?? [];
  final expenseById = {for (final b in bills) b['id']: b};
  final invoiceById = {for (final b in invoices) b['id']: b};
  final paymentRows = <List<Object?>>[
    [
      'Direction',
      'Payment ID',
      'Related ID',
      'Payment date',
      'Party',
      'Original amount USD',
      'Included cash USD',
      'Status',
      'Reference',
    ],
  ];
  for (final expense in [false, true]) {
    final collection = expense ? 'expense_payments' : 'payments';
    final reversals =
        data[expense ? 'expense_reversals' : 'payment_reversals'] ?? [];
    final reversed = reversals.map((r) => r['paymentId'] ?? r['id']).toSet();
    for (final p in data[collection] ?? <Record>[]) {
      final date = p[expense ? 'paidAt' : 'createdAt'];
      if (!within(date)) continue;
      final id = p[expense ? 'expenseId' : 'invoiceId'];
      final related = (expense ? expenseById : invoiceById)[id];
      final isReversed = reversed.contains(p['id']);
      paymentRows.add([
        expense ? 'Out' : 'In',
        p['id'],
        id,
        reportDate(date),
        expense
            ? (related?['vendor'])
            : (related?['client'] ?? related?['clientName']),
        amount(p['amount']),
        isReversed ? '0.00' : amount(p['amount']),
        isReversed ? 'Reversed' : 'Recorded',
        p['reference'],
      ]);
    }
  }
  return {
    'summary': csvText([
      ['Metric', 'Value USD unless count', 'Scope'],
      [
        'Expenses incurred',
        (summary['incurred']! / 100).toStringAsFixed(2),
        period,
      ],
      [
        'Expense payments',
        (summary['cashOut']! / 100).toStringAsFixed(2),
        period,
      ],
      [
        'Customer receipts',
        (summary['cashIn']! / 100).toStringAsFixed(2),
        period,
      ],
      ['Net cash flow', (summary['netCash']! / 100).toStringAsFixed(2), period],
      [
        'Operating profit estimate',
        (summary['profit']! / 100).toStringAsFixed(2),
        period,
      ],
      [
        'Expense balance owed',
        (summary['owed']! / 100).toStringAsFixed(2),
        'All dates; current balance',
      ],
      [
        'Customer balance owed',
        amount(invoices.fold<double>(0, (v, i) => v + balanceOf(i))),
        'All dates; current balance',
      ],
      ['Expenses needing review (count)', summary['review'], 'All dates'],
      [
        'Basis',
        'USD; invoice-date revenue less expense-date costs. Cash uses recorded payments excluding reversals.',
        period,
      ],
      [
        'Limitations',
        'Older paid invoices may lack payment entries. Unknown expense balances excluded. Not a tax report.',
        '',
      ],
    ]),
    'expenses': csvText([
      [
        'Expense ID',
        'Expense date',
        'Vendor',
        'Category',
        'Bill USD',
        'Paid USD',
        'Owed USD',
        'Status',
        'Due date',
        'Truck',
        'Job ID',
        'Notes',
        'Scope',
      ],
      for (final b in bills)
        if (within(b['expenseDate']) || expenseStatus(b) != 'Paid')
          [
            b['id'],
            reportDate(b['expenseDate']),
            b['vendor'],
            b['category'],
            amount(b['amount']),
            b['paymentReviewed'] == true ? amount(b['amountPaid']) : '',
            b['paymentReviewed'] == true
                ? amount(number(b['amount']) - number(b['amountPaid']))
                : '',
            expenseStatus(b),
            reportDate(b['dueDate']),
            b['truck'],
            b['jobId'],
            b['notes'],
            within(b['expenseDate'])
                ? period
                : 'Outstanding / needs review; other date',
          ],
    ]),
    'invoices': csvText([
      [
        'Invoice ID',
        'Invoice date',
        'Customer',
        'Billed USD',
        'Paid USD',
        'Owed USD',
        'Status',
        'Due date',
        'Scope',
      ],
      for (final i in invoices)
        if (within(i['createdAt']) || balanceOf(i) > 0)
          [
            i['id'],
            reportDate(i['createdAt']),
            i['client'] ?? i['clientName'],
            amount(i['amount']),
            amount(paidAmount(i)),
            amount(balanceOf(i)),
            invoiceStatus(i),
            reportDate(i['dueDate']),
            within(i['createdAt']) ? period : 'Outstanding; other date',
          ],
    ]),
    'payments': csvText(paymentRows),
  };
}

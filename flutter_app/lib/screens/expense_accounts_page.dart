import 'package:flutter/material.dart';
import '../services/operations.dart';
import '../services/expense_accounts.dart';
import '../services/monthly_exports.dart';
import '../services/download.dart';
import '../widgets/record_editor.dart';

class ExpenseAccountsPage extends StatefulWidget {
  const ExpenseAccountsPage({
    super.key,
    required this.store,
    this.onOpenInvoices,
  });
  final Operations store;
  final VoidCallback? onOpenInvoices;
  @override
  State<ExpenseAccountsPage> createState() => _ExpenseAccountsPageState();
}

class _ExpenseAccountsPageState extends State<ExpenseAccountsPage> {
  static const names = [
    'expenses',
    'expense_payments',
    'expense_reversals',
    'invoices',
    'payments',
    'payment_reversals',
  ];
  late final streams = {
    for (final name in names) name: widget.store.watch(name),
  };
  late final accounts = ExpenseAccounts(widget.store.db);
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String filter = 'All', search = '';

  Future<void> edit([Record? bill]) async {
    try {
      await editBill(bill);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Unable to open expense. Check your connection and try again.",
          ),
        ),
      );
    }
  }

  Future<void> editBill(Record? bill) async {
    final id =
        bill?['id'] as String? ??
        widget.store.db.collection('expenses').doc().id;
    final jobs = await widget.store.db.collection('jobs').get();
    if (!mounted) return;
    await editRecord(
      context,
      title: bill == null ? 'Add expense' : 'Edit expense',
      initial: {
        'category': 'Fuel',
        'expenseDate': DateTime.now(),
        'paidAt': DateTime.now(),
        'paymentState': 'Unpaid',
        ...?bill,
      },
      fields: [
        const FieldSpec(
          'category',
          'Category',
          required: true,
          options: {
            'Fuel': 'Fuel',
            'Maintenance': 'Maintenance',
            'Tolls': 'Tolls',
            'Insurance': 'Insurance',
            'Driver pay': 'Driver pay',
            'Other': 'Other',
          },
        ),
        const FieldSpec('vendor', 'Vendor', required: true),
        const FieldSpec('amount', 'Bill total (USD)', numeric: true),
        const FieldSpec(
          'expenseDate',
          'Expense date',
          date: true,
          required: true,
        ),
        const FieldSpec('dueDate', 'Due date (optional)', date: true),
        const FieldSpec('truck', 'Truck / unit (optional)'),
        FieldSpec(
          'jobId',
          'Related billing job (optional)',
          options: {
            '': 'General operating expense',
            for (final d in jobs.docs)
              d.id: '${d.data()['clientName'] ?? 'Job'} · ${d.id}',
          },
        ),
        const FieldSpec(
          'notes',
          'Description / receipt reference',
          multiline: true,
        ),
        if (bill == null) ...[
          const FieldSpec(
            'paymentState',
            'Payment',
            required: true,
            options: {'Unpaid': 'Unpaid', 'Paid': 'Paid in full'},
          ),
          const FieldSpec(
            'paidAt',
            'Date paid (used only for paid bills)',
            date: true,
            required: true,
          ),
        ],
      ],
      onSave: (data) =>
          accounts.save(data, id: id, paidNow: data['paymentState'] == 'Paid'),
    );
  }

  Future<void> pay(Record bill) async {
    final id = widget.store.db.collection('expense_payments').doc().id;
    await editRecord(
      context,
      title: expenseStatus(bill) == 'Needs review'
          ? 'Record known historical payment'
          : 'Record expense payment',
      initial: {
        'amount': (cents(bill['amount']) - cents(bill['amountPaid'])) / 100,
        'paidAt': DateTime.now(),
      },
      fields: const [
        FieldSpec('amount', 'Amount paid (USD)', numeric: true),
        FieldSpec('paidAt', 'Actual payment date', date: true, required: true),
        FieldSpec('reference', 'Payment method / reference', required: true),
      ],
      onSave: (data) => accounts.pay(bill['id'] as String, data, id),
    );
  }

  Future<void> history(
    Record bill,
    List<Record> payments,
    List<Record> reversals,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Payments · ${bill['vendor'] ?? bill['category']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'These entries track payments already made. They do not move money.',
            ),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No payment entries yet.'),
              ),
            for (final p in payments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${money(p['amount'])} · ${shortDate(p['paidAt'])}',
                ),
                subtitle: Text(
                  '${p['reference'] ?? ''}${reversals.any((r) => r['id'] == p['id']) ? ' · Reversed' : ''}',
                ),
                trailing: reversals.any((r) => r['id'] == p['id'])
                    ? null
                    : TextButton(
                        child: const Text('Reverse'),
                        onPressed: () async {
                          final saved = await editRecord(
                            context,
                            title: 'Reverse expense payment',
                            fields: const [
                              FieldSpec(
                                'reason',
                                'Reason (corrects records; does not refund money)',
                                required: true,
                                multiline: true,
                              ),
                            ],
                            onSave: (data) => accounts.reverse(
                              p['id'] as String,
                              data['reason'] as String,
                            ),
                          );
                          if (saved == true && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget collect(int index, Map<String, List<Record>> data) {
    if (index == names.length) return content(data);
    final name = names[index];
    return StreamBuilder<List<Record>>(
      stream: streams[name],
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load expense accounts. Check your connection and access.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return collect(index + 1, {...data, name: snapshot.data!});
      },
    );
  }

  Widget content(Map<String, List<Record>> data) {
    final summary = expenseSummary(data, month);
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day + 8);
    bool dueSoon(Record bill) {
      final due = dateOf(bill['dueDate']);
      return expenseStatus(bill) != 'Paid' &&
          due != null &&
          due.isBefore(cutoff);
    }

    final dueCount = data['expenses']!.where(dueSoon).length;
    final overdueInvoices = data['invoices']!
        .where((i) => invoiceStatus(i, now) == 'overdue')
        .length;
    final bills = data['expenses']!.where((b) {
      final status = expenseStatus(b), date = dateOf(b['expenseDate']);
      final period = filter == 'All'
          ? date != null && date.year == month.year && date.month == month.month
          : true;
      final matches =
          filter == 'All' ||
          filter == status ||
          (filter == 'Due soon' && dueSoon(b)) ||
          (filter == 'Unpaid' && status == 'Partially paid');
      return period &&
          matches &&
          '${b['vendor']} ${b['category']} ${b['notes']} ${b['truck']}'
              .toLowerCase()
              .contains(search);
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Expense accounts',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FilledButton.icon(
              onPressed: () => edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            ),
            PopupMenuButton<String>(
              tooltip: 'Export selected month as CSV',
              onSelected: (report) {
                try {
                  final period = reportDate(month).substring(0, 7);
                  downloadCsv(
                    'lobos-$period-$report.csv',
                    monthlyExports(data, month)[report]!,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'CSV download requested. Check your browser downloads.',
                      ),
                    ),
                  );
                } catch (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to download. Open the web app and try again.',
                      ),
                    ),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'summary', child: Text('Monthly summary')),
                PopupMenuItem(
                  value: 'expenses',
                  child: Text('Expenses and unpaid bills'),
                ),
                PopupMenuItem(
                  value: 'invoices',
                  child: Text('Invoices and balances'),
                ),
                PopupMenuItem(
                  value: 'payments',
                  child: Text('Payment activity'),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export CSV'),
                  ],
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () =>
                  setState(() => month = DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${month.year}-${month.month.toString().padLeft(2, '0')}'),
            IconButton(
              tooltip: 'Next month',
              onPressed: () =>
                  setState(() => month = DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in {
              'Expenses incurred': 'incurred',
              'Expense payments, net': 'cashOut',
              'Still owed · all dates': 'owed',
              'Customer receipts, net': 'cashIn',
              'Net cash flow': 'netCash',
              'Operating profit estimate': 'profit',
            }.entries)
              SizedBox(
                width: 225,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key),
                        Text(
                          money(summary[entry.value]! / 100),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Monthly profit estimate = invoiced revenue minus expenses incurred. Cash flow uses payment dates and excludes reversed entries from their original month. Cash totals include only recorded payment entries; older paid invoices may lack entries. This excludes taxes, depreciation and costs not entered here.',
          ),
        ),
        if (summary['review']! > 0)
          Text(
            '${summary['review']} older expense(s) need payment review. Amount owed and cash out are incomplete until reviewed.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (dueCount > 0 || overdueInvoices > 0)
          Wrap(
            spacing: 8,
            children: [
              if (dueCount > 0)
                TextButton.icon(
                  onPressed: () => setState(() {
                    filter = 'Due soon';
                  }),
                  icon: const Icon(Icons.schedule),
                  label: Text('$dueCount bills overdue / due within 7 days'),
                ),
              if (overdueInvoices > 0 && widget.onOpenInvoices != null)
                TextButton.icon(
                  onPressed: widget.onOpenInvoices,
                  icon: const Icon(Icons.receipt_long),
                  label: Text('$overdueInvoices overdue invoices'),
                ),
            ],
          ),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search vendor, category, truck or notes',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v.toLowerCase()),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final value in [
              'All',
              'Unpaid',
              'Due soon',
              'Paid',
              'Needs review',
            ])
              ChoiceChip(
                label: Text(value),
                selected: filter == value,
                onSelected: (_) => setState(() => filter = value),
              ),
          ],
        ),
        Text(
          filter == 'All'
              ? 'Bills incurred in selected month'
              : '$filter bills · all dates',
        ),
        const SizedBox(height: 12),
        if (bills.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No expenses match this view.'),
          ),
        for (final bill in bills)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${bill['category']} · ${bill['vendor'] ?? 'Vendor not entered'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${shortDate(bill['expenseDate'])} · ${expenseStatus(bill)}',
                  ),
                  Text('Bill: ${money(bill['amount'])}'),
                  if (expenseStatus(bill) != 'Needs review')
                    Text(
                      'Paid: ${money(bill['amountPaid'])} · Owed: ${money((cents(bill['amount']) - cents(bill['amountPaid'])) / 100)}',
                    ),
                  if (dateOf(bill['dueDate']) != null)
                    Text('Due ${shortDate(bill['dueDate'])}'),
                  if ((bill['notes'] ?? '').toString().isNotEmpty)
                    Text(bill['notes'].toString()),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (expenseStatus(bill) != 'Paid')
                        FilledButton(
                          onPressed: () => pay(bill),
                          child: Text(
                            expenseStatus(bill) == 'Needs review'
                                ? 'Record known payment'
                                : 'Record payment',
                          ),
                        ),
                      if (expenseStatus(bill) == 'Needs review')
                        TextButton(
                          onPressed: () async {
                            await editRecord(
                              context,
                              title: 'Confirm this bill is entirely unpaid',
                              fields: const [],
                              onSave: (_) =>
                                  accounts.reviewUnpaid(bill['id'] as String),
                            );
                          },
                          child: const Text('Confirm unpaid'),
                        ),
                      TextButton(
                        onPressed: () => edit(bill),
                        child: const Text('Edit bill'),
                      ),
                      TextButton(
                        onPressed: () => history(
                          bill,
                          data['expense_payments']!
                              .where((p) => p['expenseId'] == bill['id'])
                              .toList(),
                          data['expense_reversals']!,
                        ),
                        child: const Text('Payment history'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => collect(0, {});
}

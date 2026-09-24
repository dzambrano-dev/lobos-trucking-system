import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/expense_insights.dart';
import '../services/operations.dart';
import '../services/expense_accounts.dart';
import '../services/expense_reports.dart';
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
  late final reports = ExpenseReports(widget.store.db);
  Map<String, List<Record>>? reportData;
  late Future<Map<String, List<Record>>> report = fetch();
  Future<Map<String, List<Record>>> fetch({bool reuseBalances = false}) async {
    final result = await reports.load(
      month,
      balances: reuseBalances ? reportData : null,
    );
    reportData = result;
    return result;
  }

  void refresh() {
    if (mounted) {
      setState(() {
        report = fetch();
      });
    }
  }

  void changeMonth(int direction) {
    setState(() {
      month = DateTime(month.year, month.month + direction);
      report = fetch(reuseBalances: true);
    });
  }

  Future<void> change(Future<void> Function() action) async {
    await action();
    refresh();
  }

  Future<void> openHistory(Record bill) async {
    try {
      final rows = await reports.history(bill['id'] as String);
      if (!mounted) return;
      await history(bill, rows['payments']!, rows['reversals']!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to load payment history. Check your connection and try again.',
            ),
          ),
        );
      }
    }
  }

  late final accounts = ExpenseAccounts(widget.store.db);
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String filter = 'All', search = '';
  bool insights = false;

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
      onSave: (data) => change(
        () => accounts.save(
          data,
          id: id,
          paidNow: data['paymentState'] == 'Paid',
        ),
      ),
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
      onSave: (data) =>
          change(() => accounts.pay(bill['id'] as String, data, id)),
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
                            onSave: (data) => change(
                              () => accounts.reverse(
                                p['id'] as String,
                                data['reason'] as String,
                              ),
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
        Row(
          children: [
            Expanded(
              child: Text(
                'Expenses',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh financial report',
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
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
              onPressed: () => changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                DateFormat.yMMMM().format(month),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => changeMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ExpenseMetric(
                label: 'Expenses this month',
                value: money(summary['incurred']! / 100),
                detail: 'Paid + unpaid bills',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ExpenseMetric(
                label: 'Still owed',
                value: money(summary['owed']! / 100),
                detail: 'All dates · reviewed bills',
                emphasis: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.receipt_long_outlined),
              label: Text('Bills'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.donut_large),
              label: Text('Insights'),
            ),
          ],
          selected: {insights},
          onSelectionChanged: (value) => setState(() => insights = value.first),
        ),
        const SizedBox(height: 16),
        if (insights) ...[
          ExpenseInsights(
            categories: expenseCategories(data['expenses']!, month),
            summary: summary,
          ),
          const ExpansionTile(
            title: Text(
              'How these figures work',
              style: TextStyle(fontSize: 14),
            ),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Charts cover the selected month and all expense categories, regardless of bill filters. Profit uses invoiced revenue minus expenses incurred. Cash uses recorded payment dates and excludes reversed entries. Older paid invoices may lack payment entries. These estimates exclude taxes, depreciation and missing costs. Refresh for updates from other users.',
                ),
              ),
            ],
          ),
        ] else ...[
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
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final value in [
                  'All',
                  'Unpaid',
                  'Due soon',
                  'Paid',
                  'Needs review',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(value),
                      selected: filter == value,
                      onSelected: (_) => setState(() => filter = value),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
                      Text(
                        bill['notes'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
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
                                onSave: (_) => change(
                                  () => accounts.reviewUnpaid(
                                    bill['id'] as String,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Confirm unpaid'),
                          ),
                        TextButton(
                          onPressed: () => edit(bill),
                          child: const Text('Edit bill'),
                        ),
                        TextButton(
                          onPressed: () => openHistory(bill),
                          child: const Text('Payment history'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<Map<String, List<Record>>>(
        future: report,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Unable to load financial report. Check your connection.',
                  ),
                  TextButton(onPressed: refresh, child: const Text('Retry')),
                ],
              ),
            );
          }
          final loading = snapshot.connectionState != ConnectionState.done;
          return Stack(
            children: [
              AbsorbPointer(absorbing: loading, child: content(snapshot.data!)),
              if (loading)
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(),
                ),
            ],
          );
        },
      );
}

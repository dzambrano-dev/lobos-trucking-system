import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/operations.dart';
import '../services/invoice_details.dart';
import '../services/statement_pdf.dart';

class InvoiceBrowser extends StatefulWidget {
  const InvoiceBrowser({super.key, required this.store, required this.onOpen});
  final Operations store;
  final Future<void> Function(String) onOpen;
  @override
  State<InvoiceBrowser> createState() => _InvoiceBrowserState();
}

class _InvoiceBrowserState extends State<InvoiceBrowser> {
  late final details = InvoiceDetails(widget.store.db);
  late Stream<List<Record>> stream = widget.store
      .watch('invoices')
      .asyncMap(details.enrich);
  String client = '', search = '', status = 'all', period = 'All dates';
  String dateBasis = 'createdAt';
  DateTimeRange? range;
  final selected = <String>{};
  bool busy = false;
  void change(VoidCallback action) => setState(() {
    action();
    selected.clear();
  });
  Future<void> choosePeriod(String value) async {
    final now = DateTime.now(),
        today = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
    DateTimeRange? next;
    if (value == 'Custom') {
      next = await showDateRangePicker(
        context: context,
        initialDateRange: range,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 5),
      );
      if (next == null || !mounted) return;
    } else if (value == 'Today') {
      next = DateTimeRange(start: today, end: today);
    } else if (value == 'This week') {
      final start = today.subtract(Duration(days: today.weekday - 1));
      next = DateTimeRange(
        start: start,
        end: start.add(const Duration(days: 6)),
      );
    } else if (value == 'Last week') {
      final start = today.subtract(Duration(days: today.weekday + 6));
      next = DateTimeRange(
        start: start,
        end: start.add(const Duration(days: 6)),
      );
    } else if (value == 'Last month') {
      next = DateTimeRange(
        start: DateTime(now.year, now.month - 1),
        end: DateTime(now.year, now.month, 0),
      );
    } else if (value == 'This month') {
      next = DateTimeRange(
        start: DateTime(now.year, now.month),
        end: DateTime(now.year, now.month + 1, 0),
      );
    }
    change(() {
      period = value;
      range = next;
    });
  }

  Future<void> statement() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final rows = await details.enrich(
        await details.readIds('invoices', selected),
      );
      if (rows.length != selected.length) {
        throw StateError(
          'An invoice is no longer available. Refresh the list.',
        );
      }
      validateStatement(rows);
      if (rows.any((r) => r['clientId'] != client)) {
        throw StateError(
          'The selected customer changed. Select invoices again.',
        );
      }
      rows.sort(
        (a, b) => (dateOf(a['createdAt']) ?? DateTime(1970)).compareTo(
          dateOf(b['createdAt']) ?? DateTime(1970),
        ),
      );
      final company = await widget.store.db
          .collection('settings')
          .doc('company')
          .get(const GetOptions(source: Source.server));
      final bytes = await buildStatementPdf(
        company: company.data() ?? {},
        invoices: rows,
        generatedAt: DateTime.now(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Customer statement'),
              leading: const CloseButton(),
            ),
            body: PdfPreview(
              build: (_) => bytes,
              pdfFileName: 'lobos-customer-statement.pdf',
              canChangeOrientation: false,
              canChangePageFormat: false,
              allowPrinting: true,
              allowSharing: true,
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : 'Unable to generate statement. Check your connection and company details.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Record>>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: TextButton(
            onPressed: () => setState(() {
              details.jobs.clear();
              details.loads.clear();
              stream = widget.store.watch('invoices').asyncMap(details.enrich);
            }),
            child: const Text('Unable to load invoices. Tap to retry.'),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final all = snapshot.data!;
      final customers = <String, String>{
        for (final row in all)
          if ((row['clientId'] ?? '').toString().isNotEmpty)
            row['clientId'].toString(): invoiceClient(row),
      };
      final rows = all.where((r) {
        final date = dateOf(r[dateBasis]);
        final inRange =
            range == null ||
            (date != null &&
                !date.isBefore(range!.start) &&
                date.isBefore(
                  DateTime(
                    range!.end.year,
                    range!.end.month,
                    range!.end.day + 1,
                  ),
                ));
        return (client.isEmpty || r['clientId'] == client) &&
            inRange &&
            (status == 'all' || invoiceStatus(r) == status) &&
            search
                .split(RegExp(r'\s+'))
                .every((word) => invoiceSearchText(r).contains(word));
      }).toList();
      final selection = all.where((r) => selected.contains(r['id'])).toList();
      final hiddenCount = selected
          .difference(rows.map((r) => r['id'] as String).toSet())
          .length;
      final owed = selection.fold(0, (n, r) => n + cents(balanceOf(r)));
      return AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Invoices & payments',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search invoice, pickup, reference, client or date',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => change(() => search = v.toLowerCase().trim()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(client),
              initialValue: customers.containsKey(client) ? client : '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Customer'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All customers')),
                for (final c in customers.entries)
                  DropdownMenuItem(
                    value: c.key,
                    child: Text(
                      '${c.value} · ${c.key}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => change(() => client = v ?? ''),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: dateBasis,
              decoration: const InputDecoration(labelText: 'Group by date'),
              items: const [
                DropdownMenuItem(
                  value: 'createdAt',
                  child: Text('Invoice date'),
                ),
                DropdownMenuItem(
                  value: 'pickupDate',
                  child: Text('Pickup date'),
                ),
              ],
              onChanged: (v) => change(() => dateBasis = v ?? 'createdAt'),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in [
                    'All dates',
                    'Today',
                    'This week',
                    'Last week',
                    'This month',
                    'Last month',
                    'Custom',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(p),
                        selected: period == p,
                        onSelected: (_) => choosePeriod(p),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              range == null
                  ? '${dateBasis == 'createdAt' ? 'Invoice' : 'Pickup'} date · all dates'
                  : '${dateBasis == 'createdAt' ? 'Invoice' : 'Pickup'} date · ${DateFormat.yMd().format(range!.start)} – ${DateFormat.yMd().format(range!.end)}',
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in [
                    'all',
                    'pending',
                    'partial',
                    'overdue',
                    'paid',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(p[0].toUpperCase() + p.substring(1)),
                        selected: status == p,
                        onSelected: (_) => change(() => status = p),
                      ),
                    ),
                ],
              ),
            ),
            if (client.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Choose a customer, filter dates, then select invoices to print together.',
                ),
              ),
            if (client.isNotEmpty)
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => setState(
                      () => selected.addAll(rows.map((r) => r['id'] as String)),
                    ),
                    child: const Text('Select visible'),
                  ),
                  TextButton(
                    onPressed: () => setState(selected.clear),
                    child: const Text('Clear'),
                  ),
                  Text(
                    '${selected.length} selected · ${money(owed / 100)} due',
                  ),
                  FilledButton.icon(
                    onPressed: selected.length < 2 || hiddenCount > 0
                        ? null
                        : statement,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: const Text('Print selected together'),
                  ),
                ],
              ),
            if (hiddenCount > 0)
              Text(
                '$hiddenCount selected invoices are no longer visible. Clear the selection and select again.',
              ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No invoices match these filters.'),
              ),
            for (final row in rows)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (client.isNotEmpty)
                            Checkbox(
                              value: selected.contains(row['id']),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  selected.add(row['id'] as String);
                                } else {
                                  selected.remove(row['id']);
                                }
                              }),
                            ),
                          Expanded(
                            child: Text(
                              invoiceLabel(row),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy invoice number',
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () => Clipboard.setData(
                              ClipboardData(text: invoiceLabel(row)),
                            ),
                          ),
                        ],
                      ),
                      Text(invoiceClient(row)),
                      Text(
                        'Issued ${shortDate(row['createdAt'])} · ${invoiceStatus(row)}',
                      ),
                      if (invoiceReferences(row).isNotEmpty)
                        Text(
                          invoiceReferences(row),
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (dateOf(row['pickupDate']) != null)
                        Text('Pickup ${shortDate(row['pickupDate'])}'),
                      const SizedBox(height: 8),
                      Text(
                        '${money(balanceOf(row))} outstanding',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextButton(
                        onPressed: () => widget.onOpen(row['id'] as String),
                        child: const Text('Open invoice'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

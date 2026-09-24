import 'package:flutter/material.dart';
import '../services/operations.dart';
import '../widgets/record_editor.dart';
import 'invoice_workspace.dart';
import 'invoice_browser.dart';
import '../widgets/contact_links.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, required this.collection, required this.store});
  final String collection;
  final Operations store;
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  late Stream<List<Record>> stream;
  String query = '', filter = 'all';
  bool archived = false, busy = false;
  String get kind => widget.collection;
  bool get jobs => kind == 'jobs';
  bool get clients => kind == 'clients';
  bool get invoices => kind == 'invoices';
  String get singular => clients
      ? 'client'
      : jobs
      ? 'job'
      : invoices
      ? 'invoice'
      : 'expense';
  @override
  void initState() {
    super.initState();
    stream = widget.store.watch(kind);
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editor([Record? row]) async {
    var initial = <String, dynamic>{...?row};
    List<FieldSpec> fields;
    if (clients) {
      fields = const [
        FieldSpec('name', 'Company name', required: true),
        FieldSpec('contact', 'Contact name'),
        FieldSpec('phone', 'Phone'),
        FieldSpec('email', 'Email'),
        FieldSpec('address', 'Billing address', multiline: true),
      ];
    } else if (jobs) {
      final result = await widget.store.db.collection('clients').get();
      final options = {
        for (final d in result.docs.where((d) => d.data()['archived'] != true))
          d.id: d.data()['name']?.toString() ?? 'Unnamed client',
      };
      if (!mounted) return;
      if (options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add an active client in Clients before scheduling a job.',
            ),
          ),
        );
        return;
      }
      initial = {'status': 'pending', ...initial};
      fields = [
        FieldSpec('clientId', 'Client', required: true, options: options),
        const FieldSpec('pickup', 'Pickup location', required: true),
        const FieldSpec('dropoff', 'Delivery location', required: true),
        const FieldSpec('scheduledDate', 'Scheduled date', date: true),
        const FieldSpec('driver', 'Driver'),
        const FieldSpec('truck', 'Truck / unit'),
        const FieldSpec('reference', 'Load / reference number'),
        const FieldSpec('price', 'Agreed rate (USD)', numeric: true),
        const FieldSpec(
          'status',
          'Status',
          required: true,
          options: {
            'pending': 'Scheduled',
            'in progress': 'In progress',
            'completed': 'Completed',
            'cancelled': 'Cancelled',
          },
        ),
        const FieldSpec('notes', 'Dispatch notes', multiline: true),
      ];
    } else {
      final result = await widget.store.db.collection('jobs').get();
      if (!mounted) return;
      fields = [
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
        const FieldSpec('amount', 'Amount (USD)', numeric: true),
        const FieldSpec(
          'expenseDate',
          'Expense date',
          required: true,
          date: true,
        ),
        FieldSpec(
          'jobId',
          'Related job (optional)',
          options: {
            '': 'General operating expense',
            for (final d in result.docs)
              d.id:
                  '${d.data()['clientName'] ?? 'Client'} · ${d.data()['pickup'] ?? ''} to ${d.data()['dropoff'] ?? ''}',
          },
        ),
        const FieldSpec('vendor', 'Vendor'),
        const FieldSpec('notes', 'Receipt / notes', multiline: true),
      ];
      initial = {'expenseDate': DateTime.now(), 'category': 'Fuel', ...initial};
    }
    if (!mounted) return;
    await editRecord(
      context,
      title: '${row == null ? 'Add' : 'Edit'} $singular',
      fields: fields,
      initial: initial,
      onSave: (data) =>
          widget.store.save(kind, data, id: row?['id'] as String?),
    );
  }

  Future<void> archive(Record row) async {
    final restore = row['archived'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${restore ? 'Restore' : 'Archive'} $singular?'),
        content: Text(
          restore
              ? 'This record will appear in the active list again.'
              : 'This hides the record from the active list. Its history stays available under Archived.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(restore ? 'Restore' : 'Archive'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.store.archive(kind, row['id'] as String, !restore);
    }
  }

  Future<void> openInvoice(String id) async {
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceWorkspace(id: id, store: widget.store),
        ),
      );
    }
  }

  Widget recordCard(Record row) {
    final status = invoices ? invoiceStatus(row) : row['status']?.toString();
    final title = clients
        ? row['name']
        : jobs
        ? row['clientName']
        : invoices
        ? row['client']
        : row['category'];
    final subtitle = clients
        ? [
            row['contact'],
            row['phone'],
            row['email'],
            row['address'],
          ].where((v) => v != null && v.toString().isNotEmpty).join(' · ')
        : jobs
        ? '${row['pickup']} → ${row['dropoff']}\n${shortDate(row['scheduledDate'])} · ${row['driver'] ?? 'Unassigned'} · ${row['truck'] ?? ''}'
        : invoices
        ? '${row['invoiceNumber']}\nDue ${shortDate(row['dueDate'])} · ${money(balanceOf(row))} outstanding'
        : '${shortDate(row['expenseDate'])} · ${row['vendor'] ?? ''}\n${row['notes'] ?? ''}';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: invoices ? () => openInvoice(row['id'] as String) : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title?.toString() ?? 'Unnamed',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (!clients)
                    Text(
                      money(jobs ? row['price'] : row['amount']),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (clients)
                ClientContactCard(
                  name: (row['contact'] ?? '').toString(),
                  phone: (row['phone'] ?? '').toString(),
                  email: (row['email'] ?? '').toString(),
                  address: (row['address'] ?? '').toString(),
                )
              else
                Text(subtitle),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (status != null) StatusChip(status: status),
                  if (jobs && row['invoiceId'] != null)
                    const Chip(
                      label: Text('Invoiced · locked'),
                      avatar: Icon(Icons.lock_outline, size: 16),
                    ),
                  if (!invoices && !(jobs && row['invoiceId'] != null))
                    TextButton.icon(
                      onPressed: busy ? null : () => run(() => editor(row)),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                  if (jobs &&
                      (row['status'] == 'completed' ||
                          row['invoiceId'] != null) &&
                      !archived)
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () => run(() async {
                              final id = await widget.store.invoiceJob(
                                row['id'] as String,
                              );
                              await openInvoice(id);
                            }),
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: Text(
                        row['invoiceId'] == null
                            ? 'Create invoice'
                            : 'View invoice',
                      ),
                    ),
                  if (invoices)
                    TextButton(
                      onPressed: () => openInvoice(row['id'] as String),
                      child: const Text('Open invoice →'),
                    ),
                  if (!invoices)
                    TextButton.icon(
                      onPressed: busy ? null : () => run(() => archive(row)),
                      icon: Icon(
                        archived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                        size: 18,
                      ),
                      label: Text(archived ? 'Restore' : 'Archive'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => invoices
      ? InvoiceBrowser(store: widget.store, onOpen: openInvoice)
      : recordsBody(context);

  Widget recordsBody(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              clients
                  ? 'Client directory'
                  : jobs
                  ? 'Dispatch board'
                  : invoices
                  ? 'Invoices & payments'
                  : 'Operating expenses',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (!invoices)
              FilledButton.icon(
                onPressed: busy ? null : () => run(() => editor()),
                icon: const Icon(Icons.add),
                label: Text('Add $singular'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          clients
              ? 'Keep customer contacts and billing details together.'
              : jobs
              ? 'Schedule work, assign a driver, and invoice completed loads.'
              : invoices
              ? 'Track what is billed, collected, and still outstanding.'
              : 'Track fuel, repairs, and other costs as they happen.',
        ),
        const SizedBox(height: 20),
        TextField(
          onChanged: (v) => setState(() => query = v.toLowerCase().trim()),
          decoration: InputDecoration(
            hintText: 'Search $kind…',
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (jobs || invoices)
              for (final s
                  in jobs
                      ? [
                          'all',
                          'pending',
                          'in progress',
                          'completed',
                          'cancelled',
                        ]
                      : ['all', 'pending', 'partial', 'overdue', 'paid'])
                ChoiceChip(
                  label: Text(
                    s == 'pending' && jobs
                        ? 'Scheduled'
                        : s[0].toUpperCase() + s.substring(1),
                  ),
                  selected: filter == s,
                  onSelected: (_) => setState(() => filter = s),
                ),
            if (!invoices)
              FilterChip(
                label: const Text('Archived'),
                selected: archived,
                onSelected: (v) => setState(() => archived = v),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<Record>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to load $kind. Check your connection and access permissions.',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snapshot.data!
                  .where(
                    (r) =>
                        (invoices || (r['archived'] == true) == archived) &&
                        (filter == 'all' ||
                            (invoices ? invoiceStatus(r) : r['status']) ==
                                filter) &&
                        r.entries
                            .where((e) => e.key != 'id')
                            .any(
                              (e) => e.value.toString().toLowerCase().contains(
                                query,
                              ),
                            ),
                  )
                  .toList();
              if (rows.isEmpty) {
                return Center(
                  child: Text(
                    query.isNotEmpty || filter != 'all' || archived
                        ? 'No matching records. Try a different filter.'
                        : invoices
                        ? 'Complete a job, then choose Create invoice on the Dispatch board.'
                        : 'No $kind yet. Add your first $singular to get started.',
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${rows.length} ${rows.length == 1 ? 'record' : 'records'}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) => recordCard(rows[i]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'paid' || 'completed' => const Color(0xFF167651),
      'overdue' || 'cancelled' => const Color(0xFFB13D32),
      _ => const Color(0xFF805D16),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty
            ? 'Unknown'
            : status == 'pending'
            ? 'Pending'
            : status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

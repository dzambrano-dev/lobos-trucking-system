import 'package:flutter/material.dart';
import '../services/invoice_pdf.dart';
import '../services/invoice_details.dart';
import '../widgets/contact_links.dart';
import 'package:printing/printing.dart';
import '../services/operations.dart';
import '../widgets/record_editor.dart';
import 'records.dart';

class InvoiceWorkspace extends StatefulWidget {
  const InvoiceWorkspace({super.key, required this.id, required this.store});
  final String id;
  final Operations store;
  @override
  State<InvoiceWorkspace> createState() => _InvoiceWorkspaceState();
}

class _InvoiceWorkspaceState extends State<InvoiceWorkspace> {
  late final details = InvoiceDetails(widget.store.db);
  late final stream = widget.store.db
      .collection('invoices')
      .doc(widget.id)
      .snapshots()
      .asyncMap(
        (s) async => s.exists
            ? (await details.enrich([
                {...s.data()!, 'id': s.id},
              ])).single
            : null,
      );
  late final payments = widget.store.db
      .collection('payments')
      .where('invoiceId', isEqualTo: widget.id)
      .snapshots();
  bool printing = false;
  late final reversals = widget.store.db
      .collection('payment_reversals')
      .where('invoiceId', isEqualTo: widget.id)
      .snapshots();
  Future<void> reverse(String paymentId) => editRecord(
    context,
    title: 'Reverse recorded payment',
    fields: const [
      FieldSpec(
        'reason',
        'Reason (corrects records; does not refund money)',
        required: true,
        multiline: true,
      ),
    ],
    onSave: (data) =>
        widget.store.reversePayment(paymentId, data['reason'] as String),
  ).then((_) {});
  Future<void> payment(Record invoice) async {
    final paymentId = widget.store.db.collection('payments').doc().id;
    await editRecord(
      context,
      title: 'Record payment',
      initial: {'amount': balanceOf(invoice)},
      fields: const [
        FieldSpec('amount', 'Amount received (USD)', numeric: true),
        FieldSpec(
          'reference',
          'Payment method / check reference',
          required: true,
        ),
      ],
      onSave: (data) => widget.store.recordPayment(
        widget.id,
        data['amount'] as double,
        data['reference'] as String,
        paymentId: paymentId,
      ),
    );
  }

  Future<void> printInvoice(Record invoice, {bool download = false}) async {
    setState(() => printing = true);
    try {
      final company =
          (await widget.store.db.collection('settings').doc('company').get())
              .data();
      if (company == null ||
          (company['name'] ?? '').toString().trim().isEmpty ||
          (company['address'] ?? '').toString().trim().isEmpty) {
        throw StateError(
          'Set your business name and remittance address using Company & invoice details before printing.',
        );
      }
      var pickup = invoice['pickup']?.toString(),
          dropoff = invoice['dropoff']?.toString();
      if (pickup == null &&
          invoice['jobId'] != null &&
          invoice['jobId'] != '') {
        final job = await widget.store.db
            .collection('jobs')
            .doc(invoice['jobId'] as String)
            .get();
        pickup = job.data()?['pickup']?.toString();
        dropoff = job.data()?['dropoff']?.toString();
      }
      final bytes = await buildInvoicePdf(
        company: company,
        invoice: invoice,
        invoiceId: widget.id,
        pickup: pickup,
        dropoff: dropoff,
      );
      final baseName = '${invoice['invoiceNumber'] ?? 'invoice'}'.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );
      final filename = '$baseName.pdf';
      if (download) {
        final saved = await Printing.sharePdf(bytes: bytes, filename: filename);
        if (!saved) {
          throw StateError('The PDF could not be saved. Please try again.');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'PDF download requested. Check your browser downloads.',
              ),
            ),
          );
        }
      } else {
        await Printing.layoutPdf(
          name: filename,
          onLayout: (_) async => bytes,
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw StateError(
            'The print dialog did not respond. Use Download PDF, then open the file to print.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Unable to prepare the PDF. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Invoice details')),
    body: StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load invoice. Check connection and permissions.',
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: Text('Invoice no longer exists.'));
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['invoiceNumber']?.toString() ?? widget.id,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        StatusChip(status: invoiceStatus(data)),
                        const SizedBox(height: 24),
                        Text(
                          data['client']?.toString() ?? 'Client',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(invoiceReferences(data)),
                        if (dateOf(data['pickupDate']) != null)
                          Text('Pickup date: ${shortDate(data['pickupDate'])}'),
                        ContactLink(
                          kind: 'address',
                          text: (data['pickup'] ?? '').toString(),
                          label: 'Pickup',
                        ),
                        ContactLink(
                          kind: 'address',
                          text: (data['dropoff'] ?? '').toString(),
                          label: 'Delivery',
                        ),
                        ContactLink(
                          kind: 'email',
                          text: (data['clientEmail'] ?? '').toString(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Issued ${shortDate(data['createdAt'])} · Due ${shortDate(data['dueDate'])}',
                        ),
                        const Divider(height: 40),
                        Text('Total billed: ${money(data['amount'])}'),
                        Text('Payments received: ${money(paidAmount(data))}'),
                        const SizedBox(height: 12),
                        Text(
                          '${money(balanceOf(data))} outstanding',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if ((data['notes'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(data['notes'] as String),
                          ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: balanceOf(data) <= 0
                                  ? null
                                  : () => payment(data),
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Record payment'),
                            ),
                            OutlinedButton.icon(
                              onPressed: printing
                                  ? null
                                  : () => printInvoice(data, download: true),
                              icon: const Icon(Icons.download_outlined),
                              label: Text(
                                printing ? 'Preparing…' : 'Download PDF',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: printing
                                  ? null
                                  : () => printInvoice(data),
                              icon: const Icon(Icons.print_outlined),
                              label: Text(printing ? 'Preparing…' : 'Print'),
                            ),
                            TextButton(
                              onPressed: () => editRecord(
                                context,
                                title: 'Edit invoice details',
                                initial: data,
                                fields: const [
                                  FieldSpec(
                                    'dueDate',
                                    'Due date',
                                    required: true,
                                    date: true,
                                  ),
                                  FieldSpec(
                                    'notes',
                                    'Invoice notes',
                                    multiline: true,
                                  ),
                                ],
                                onSave: (changes) => widget.store.save(
                                  'invoices',
                                  changes,
                                  id: widget.id,
                                ),
                              ),
                              child: const Text('Edit due date / notes'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Payment history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                StreamBuilder(
                  stream: payments,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text('Unable to load payment history.');
                    }
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }
                    final rows = snapshot.data!.docs.toList()
                      ..sort(
                        (a, b) =>
                            (dateOf(b.data()['createdAt']) ?? DateTime(1970))
                                .compareTo(
                                  dateOf(a.data()['createdAt']) ??
                                      DateTime(1970),
                                ),
                      );
                    if (rows.isEmpty) {
                      return Text(
                        paidAmount(data) > 0
                            ? 'This legacy invoice has a paid balance without individual payment entries.'
                            : 'No payments recorded yet.',
                      );
                    }
                    return StreamBuilder(
                      stream: reversals,
                      builder: (context, corrections) {
                        if (corrections.hasError) {
                          return const Text(
                            'Unable to load payment corrections.',
                          );
                        }
                        if (!corrections.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final reversed = {
                          for (final d in corrections.data!.docs)
                            d.id: d.data(),
                        };
                        return Column(
                          children: rows
                              .map(
                                (d) => Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          money(d.data()['amount']),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        Text(
                                          '${shortDate(d.data()['createdAt'])} · ${d.data()['reference'] ?? ''}',
                                        ),
                                        if (reversed.containsKey(d.id))
                                          Text(
                                            'Reversed ${shortDate(reversed[d.id]!['createdAt'])}: ${reversed[d.id]!['reason']}',
                                          )
                                        else
                                          TextButton.icon(
                                            onPressed: () => reverse(d.id),
                                            icon: const Icon(
                                              Icons.undo,
                                              size: 16,
                                            ),
                                            label: const Text('Reverse entry'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

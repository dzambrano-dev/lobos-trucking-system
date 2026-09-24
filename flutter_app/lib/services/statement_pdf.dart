import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'operations.dart';
import 'invoice_details.dart';

Future<Uint8List> buildStatementPdf({
  required Record company,
  required List<Record> invoices,
  required DateTime generatedAt,
}) async {
  validateStatement(invoices);
  if ((company['name'] ?? '').toString().trim().isEmpty ||
      (company['address'] ?? '').toString().trim().isEmpty) {
    throw StateError('Set Company & invoice details before printing.');
  }
  final total = invoices.fold(0, (a, r) => a + cents(r['amount']));
  final received = invoices.fold(0, (a, r) => a + cents(paidAmount(r)));
  final balance = invoices.fold(0, (a, r) => a + cents(balanceOf(r)));
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      maxPages: 100,
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            company['name'].toString(),
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(company['address'].toString()),
          pw.SizedBox(height: 12),
          pw.Text(
            'CUSTOMER STATEMENT',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Customer: ${invoiceClient(invoices.first)}'),
          pw.Text(
            'Generated: ${shortDate(generatedAt)} - ${invoices.length} selected invoices',
          ),
          pw.SizedBox(height: 12),
        ],
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${c.pageNumber} / ${c.pagesCount}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      build: (_) => [
        pw.Text(
          'Summary of existing invoices. This statement does not create additional charges or replace the invoices.',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: [
            'Invoice / issued',
            'Load / reference / route',
            'Pickup date',
            'Charge',
            'Paid',
            'Balance',
          ],
          data: [
            for (final i in invoices)
              [
                '${invoiceLabel(i)}\n${shortDate(i['createdAt'])}',
                '${invoiceReferences(i)}\n${i['pickup'] ?? ''} to ${i['dropoff'] ?? ''}',
                dateOf(i['pickupDate']) == null
                    ? 'Not recorded'
                    : shortDate(i['pickupDate']),
                money(i['amount']),
                money(paidAmount(i)),
                money(balanceOf(i)),
              ],
          ],
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(1.4),
            3: const pw.FlexColumnWidth(1.2),
            4: const pw.FlexColumnWidth(1.2),
            5: const pw.FlexColumnWidth(1.2),
          },
        ),
        pw.SizedBox(height: 18),
        pw.Text('Total charges: ${money(total / 100)}'),
        pw.Text('Payments received: ${money(received / 100)}'),
        pw.Text(
          'Balance due: ${money(balance / 100)}',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Text((company['paymentInstructions'] ?? '').toString()),
      ],
    ),
  );
  return pdf.save();
}

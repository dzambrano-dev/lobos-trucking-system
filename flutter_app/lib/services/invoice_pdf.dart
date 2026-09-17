import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'operations.dart';

Future<Uint8List> buildInvoicePdf({
  required Record company,
  required Record invoice,
  required String invoiceId,
  String? pickup,
  String? dropoff,
}) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      build: (_) => [
        pw.Text(
          company['name'].toString(),
          style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(company['address'].toString()),
        pw.Text(
          [
            company['phone'],
            company['email'],
          ].where((v) => v != null && v.toString().isNotEmpty).join(' | '),
        ),
        pw.Text('INVOICE ${invoice['invoiceNumber'] ?? invoiceId}'),
        pw.Text(
          'Issued: ${shortDate(invoice['createdAt'])}    Due: ${shortDate(invoice['dueDate'])}',
        ),
        pw.SizedBox(height: 24),
        pw.Text('Bill to: ${invoice['client'] ?? ''}'),
        if ((invoice['clientAddress'] ?? '').toString().isNotEmpty)
          pw.Text(invoice['clientAddress'].toString()),
        if ((invoice['clientEmail'] ?? '').toString().isNotEmpty)
          pw.Text(invoice['clientEmail'].toString()),
        pw.SizedBox(height: 16),
        pw.Divider(),
        pw.Text(
          'Hauling services: ${pickup ?? 'Route unavailable'} to ${dropoff ?? ''}',
        ),
        pw.SizedBox(height: 20),
        pw.Text('Invoice total: ${money(invoice['amount'])}'),
        pw.Text('Payments received: ${money(paidAmount(invoice))}'),
        pw.Text(
          'Balance due: ${money(balanceOf(invoice))}',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Status: ${invoiceStatus(invoice).toUpperCase()}'),
        if ((invoice['notes'] ?? '').toString().isNotEmpty)
          pw.Text('Notes: ${invoice['notes']}'),
        pw.SizedBox(height: 32),
        if ((company['paymentInstructions'] ?? '').toString().isNotEmpty)
          pw.Text(company['paymentInstructions'].toString()),
        pw.Text('Thank you for your business.'),
      ],
    ),
  );
  return pdf.save();
}

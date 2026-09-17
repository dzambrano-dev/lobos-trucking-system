import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/invoice_pdf.dart';

void main() {
  test('invoice exports a PDF without a browser print dialog', () async {
    final bytes = await buildInvoicePdf(
      company: {'name': 'Test Hauling', 'address': '100 Test Road'},
      invoice: {
        'invoiceNumber': 'TEST-1',
        'client': 'Test Customer',
        'amount': 125.50,
        'amountPaid': 25.50,
        'status': 'partial',
      },
      invoiceId: 'test',
      pickup: 'Test Yard',
      dropoff: 'Test Site',
    );
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(latin1.decode(bytes), contains('%%EOF'));
    expect(bytes.length, greaterThan(1000));
  });
}

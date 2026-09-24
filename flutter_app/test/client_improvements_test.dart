import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/operations.dart';
import 'package:flutter_app/services/invoice_details.dart';
import 'package:flutter_app/services/statement_pdf.dart';
import 'package:flutter_app/services/invoice_pdf.dart';
import 'package:flutter_app/services/load_repository.dart';
import 'package:flutter_app/widgets/contact_links.dart';

void main() {
  test('statements reject mixed clients and duplicate invoices', () {
    expect(
      () => validateStatement([
        {'id': 'a', 'clientId': 'c'},
        {'id': 'b', 'clientId': 'd'},
      ]),
      throwsStateError,
    );
    expect(
      () => validateStatement([
        {'id': 'a', 'clientId': 'c'},
        {'id': 'a', 'clientId': 'c'},
      ]),
      throwsStateError,
    );
    expect(
      () => validateStatement([
        {'id': 'a'},
        {'id': 'b'},
      ]),
      throwsStateError,
    );
    validateStatement([
      {'id': 'a', 'clientId': 'c'},
      {'id': 'b', 'clientId': 'c'},
    ]);
  });
  test('delivery dates reject overflow and dates before pickup', () {
    final pickup = DateTime(2026, 9, 20, 8);
    for (final date in ['2026-99-99 12:00', '2026-09-19 12:00', 'tomorrow']) {
      expect(
        () => LoadRepository.validatedInformation({
          'scheduledDeliveryAt': date,
        }, pickup),
        throwsStateError,
      );
    }
    expect(
      LoadRepository.validatedInformation({
        'scheduledDeliveryAt': '2026-09-20 12:00',
      }, pickup)['scheduledDeliveryAt'],
      Timestamp.fromDate(DateTime(2026, 9, 20, 12)),
    );
  });
  test(
    'contact URLs encode addresses and do not dial extensions as number digits',
    () {
      expect(
        contactUri('address', '100 Main St & First').queryParameters['query'],
        '100 Main St & First',
      );
      expect(contactUri('phone', '(555) 123-4567 ext. 89').path, '5551234567');
      expect(
        contactUri('email', ' office@example.com ').path,
        'office@example.com',
      );
    },
  );
  test(
    'legacy invoice references resolve without altering balances or records',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('loads').doc('load').set({
        'loadNumber': 'LD-1',
        'pickupNumber': 'PU-42',
      });
      await db.collection('jobs').doc('job').set({
        'loadId': 'load',
        'reference': 'REF-1',
      });
      final source = <String, dynamic>{
        'id': 'inv',
        'jobId': 'job',
        'amount': 100.30,
        'amountPaid': 20.10,
      };
      final result = (await InvoiceDetails(db).enrich([source])).single;
      expect(result['pickupNumber'], 'PU-42');
      expect(invoiceSearchText(result), contains('ref-1'));
      expect(cents(balanceOf(result)), 8020);
      expect(source.containsKey('pickupNumber'), false);
      expect((await db.collection('invoices').get()).docs, isEmpty);
    },
  );
  test('new invoice snapshots references from legacy dispatch jobs', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('clients').doc('c').set({'name': 'Customer'});
    await db.collection('loads').doc('l').set({
      'loadNumber': 'LD-2',
      'pickupNumber': 'PU-2',
    });
    await db.collection('jobs').doc('j').set({
      'clientId': 'c',
      'loadId': 'l',
      'status': 'completed',
      'price': 100,
    });
    await Operations(db).invoiceJob('j');
    final invoice = (await db.collection('invoices').doc('j').get()).data()!;
    expect(invoice['pickupNumber'], 'PU-2');
    expect(invoice['loadNumber'], 'LD-2');
    expect(invoice['amount'], 100);
  });
  test(
    'multi-page statement and invoice PDFs render with long identifiers',
    () async {
      final company = <String, dynamic>{
        'name': 'Lobos Trucking QA',
        'address': '100 Test Road, Los Angeles, CA',
        'paymentInstructions': 'Reference the invoice numbers with payment.',
      };
      final invoices = List.generate(
        40,
        (n) => <String, dynamic>{
          'id': 'invoice-$n',
          'invoiceNumber': 'INV-LOAD-ABCDEFGHIJKLMNOPQRSTUVWXYZ-$n',
          'clientId': 'c',
          'client': 'Test Customer',
          'amount': 1234.56,
          'amountPaid': 234.56,
          'createdAt': DateTime(2026, 9, 20),
          'pickupDate': DateTime(2026, 9, 19),
          'pickup': '100 Long Pickup Street, Los Angeles, CA',
          'dropoff': '200 Delivery Avenue, San Diego, CA',
          'reference': 'REF-$n',
          'loadNumber': 'LD-$n',
        },
      );
      final bytes = await buildStatementPdf(
        company: company,
        invoices: invoices,
        generatedAt: DateTime(2026, 9, 20),
      );
      expect(bytes.length, greaterThan(1000));
      final dir = Directory('build/qa')..createSync(recursive: true);
      File('${dir.path}/customer-statement.pdf').writeAsBytesSync(bytes);
      File('${dir.path}/customer-invoice.pdf').writeAsBytesSync(
        await buildInvoicePdf(
          company: company,
          invoice: invoices.first,
          invoiceId: 'invoice-0',
        ),
      );
    },
  );
}

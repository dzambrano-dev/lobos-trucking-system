import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/invoice_browser.dart';
import 'package:flutter_app/services/operations.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('invoice selection and reference search fit at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      for (var i = 0; i < 3; i++) {
        await db.collection('invoices').doc('inv$i').set({
          'metadataVersion': 1,
          'invoiceNumber': 'INV-$i',
          'clientId': i == 2 ? 'other' : 'client',
          'client': i == 2 ? 'Other customer' : 'Test customer',
          'amount': 100,
          'amountPaid': 20,
          'reference': 'REF-$i',
          'createdAt': DateTime.now(),
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvoiceBrowser(store: Operations(db), onOpen: (_) async {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test customer · client').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select visible'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 selected'), findsOneWidget);
      expect(find.textContaining('Other customer'), findsNothing);
      await tester.enterText(find.byType(TextField), 'REF-1');
      await tester.pumpAndSettle();
      expect(find.textContaining('0 selected'), findsOneWidget);
      expect(find.text('INV-1'), findsOneWidget);
      expect(find.text('INV-0'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

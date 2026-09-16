import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_app/services/operations.dart';
import 'package:flutter_app/screens/expense_accounts_page.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('expense payment and history fit at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      await db.collection('expenses').doc('fuel').set({
        'category': 'Fuel',
        'vendor': 'Station',
        'amount': 500,
        'amountPaid': 0,
        'paymentReviewed': true,
        'expenseDate': DateTime.now(),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExpenseAccountsPage(store: Operations(db))),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Record payment'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount paid (USD)'),
        '200',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Payment method / reference'),
        'Check 123',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        (await db.collection('expenses').doc('fuel').get())
            .data()!['amountPaid'],
        200,
      );
      expect(find.textContaining('Owed: \$300.00'), findsOneWidget);
      await tester.ensureVisible(find.text('Payment history'));
      await tester.tap(find.text('Payment history'));
      await tester.pumpAndSettle();
      expect(find.text('Check 123'), findsOneWidget);
      expect(find.text('Reverse'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
